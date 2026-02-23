import cron from 'node-cron';
import Bet from '../models/Bet';
import BetParticipant from '../models/BetParticipant';
import BetProof from '../models/BetProof';
import ConsensusVote from '../models/ConsensusVote';
import User from '../models/User';
import AuraTransaction from '../models/AuraTransaction';
import { AURA_CONSTANTS } from '../config/auraConstants';
import {
  autoConfirmPendingResolutionClaims,
  resolveBet,
} from './betService';

let backgroundJobsStarted = false;

function inferResolutionType(bet: { resolutionType?: 'proof' | 'observable' | 'consensus'; betType: string }): 'proof' | 'observable' | 'consensus' {
  if (bet.resolutionType) {
    return bet.resolutionType;
  }

  return bet.betType === 'prediction' ? 'observable' : 'proof';
}

async function safelyRunJob(name: string, job: () => Promise<void>): Promise<void> {
  try {
    await job();
  } catch (error) {
    console.error(`[BackgroundJobs] ${name} failed:`, error);
  }
}

// JOB 1: Active deadlines and resolving windows
export async function checkDeadlines(): Promise<void> {
  const now = new Date();

  const expiredActiveBets = await Bet.find({
    status: 'active',
    deadline: { $lt: now },
  });

  for (const bet of expiredActiveBets) {
    const resolutionType = inferResolutionType(bet);

    bet.status = 'resolving';
    await bet.save();

    if (resolutionType === 'proof') {
      const existingProof = await BetProof.findOne({ betId: bet.betId });

      if (!existingProof) {
        await resolveBet({
          betId: bet.betId,
          outcome: 'no',
          resolvedBy: 'system',
          notes: 'No proof submitted before deadline',
          allowedStatuses: ['resolving'],
        });
      }
    }

    if (resolutionType === 'observable') {
      bet.deadline = new Date(Date.now() + AURA_CONSTANTS.CREATOR_DECLARE_WINDOW_MS);
      await bet.save();
    }

    if (resolutionType === 'consensus') {
      bet.deadline = new Date(Date.now() + AURA_CONSTANTS.CONSENSUS_VOTE_WINDOW_MS);
      await bet.save();
    }
  }

  // Observable bets with no creator declaration in time are refunded/expired.
  const staleObservableBets = await Bet.find({
    status: 'resolving',
    resolutionType: 'observable',
    deadline: { $lt: now },
  });

  for (const bet of staleObservableBets) {
    await resolveBet({
      betId: bet.betId,
      outcome: 'expired',
      resolvedBy: 'system',
      notes: 'Creator declaration window expired',
      allowedStatuses: ['resolving'],
    });
  }

  await autoConfirmPendingResolutionClaims();
}

// JOB 2: Proof dispute windows
export async function checkDisputeWindows(): Promise<void> {
  const now = new Date();

  const expiredProofs = await BetProof.find({
    status: 'pending',
    disputeDeadline: { $lt: now },
  });

  for (const proof of expiredProofs) {
    const bet = await Bet.findOne({ betId: proof.betId });
    if (!bet) {
      continue;
    }

    if (bet.status !== 'active' && bet.status !== 'resolving') {
      continue;
    }

    const totalStakers = await BetParticipant.countDocuments({ betId: proof.betId });
    const disputes = proof.disputes ?? 0;

    if (totalStakers > 0 && disputes > totalStakers * 0.5) {
      proof.status = 'disputed';
      await proof.save();
      continue;
    }

    proof.status = 'confirmed';
    await proof.save();

    await resolveBet({
      betId: bet.betId,
      outcome: 'yes',
      resolvedBy: proof.userId,
      notes: 'Proof confirmed after dispute window',
      allowedStatuses: ['active', 'resolving'],
    });
  }
}

// JOB 3: Consensus vote windows
export async function checkVotingWindows(): Promise<void> {
  const now = new Date();

  const expiredVoteBets = await Bet.find({
    status: 'resolving',
    resolutionType: 'consensus',
    deadline: { $lt: now },
  });

  for (const bet of expiredVoteBets) {
    const [yesVotes, noVotes] = await Promise.all([
      ConsensusVote.countDocuments({ betId: bet.betId, vote: 'yes' }),
      ConsensusVote.countDocuments({ betId: bet.betId, vote: 'no' }),
    ]);

    if (yesVotes === noVotes) {
      await resolveBet({
        betId: bet.betId,
        outcome: 'expired',
        resolvedBy: 'system',
        notes: 'Consensus vote tied or had no majority',
        allowedStatuses: ['resolving'],
      });
      continue;
    }

    await resolveBet({
      betId: bet.betId,
      outcome: yesVotes > noVotes ? 'yes' : 'no',
      resolvedBy: 'consensus',
      notes: `Consensus resolved (${yesVotes} yes / ${noVotes} no)`,
      allowedStatuses: ['resolving'],
    });
  }
}

// JOB 4: Pending threshold expirations
export async function checkThresholds(): Promise<void> {
  const staleThresholdBets = await Bet.find({
    status: 'pending',
    createdAt: { $lt: new Date(Date.now() - AURA_CONSTANTS.THRESHOLD_EXPIRY_MS) },
  });

  for (const bet of staleThresholdBets) {
    await resolveBet({
      betId: bet.betId,
      outcome: 'expired',
      resolvedBy: 'system',
      notes: 'Participation threshold not met before timeout',
      allowedStatuses: ['pending'],
    });
  }
}

// JOB 5: Daily maintenance
export async function dailyMaintenance(): Promise<void> {
  const users = await User.find({});
  const now = new Date();
  const today = new Date(now);
  today.setHours(0, 0, 0, 0);

  for (const user of users) {
    const wins = user.wins ?? user.betsCompleted ?? 0;
    const losses = user.losses ?? user.betsFailed ?? 0;
    const ducks = user.ducks ?? user.calloutsIgnored ?? 0;
    const calloutsReceived = user.calloutsReceived ?? 0;

    if (user.lastActiveDate) {
      const daysSinceActive = Math.floor(
        (now.getTime() - user.lastActiveDate.getTime()) / (24 * 60 * 60 * 1000)
      );

      if (daysSinceActive >= AURA_CONSTANTS.INACTIVITY_GRACE_DAYS && (user.auraBalance ?? 0) > 0) {
        const decay = Math.min(
          daysSinceActive * AURA_CONSTANTS.INACTIVITY_DECAY_PER_DAY,
          AURA_CONSTANTS.INACTIVITY_DECAY_MAX
        );

        const previousBalance = user.auraBalance ?? 0;
        user.auraBalance = Math.max(0, previousBalance - decay);
        const appliedDecay = previousBalance - user.auraBalance;

        if (appliedDecay > 0) {
          await AuraTransaction.create({
            transactionId: `txn_inactive_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
            userId: user._id,
            amount: -appliedDecay,
            balanceAfter: user.auraBalance,
            transactionType: 'inactivity_decay',
            description: `Inactivity decay applied after ${daysSinceActive} day(s) inactive`,
          });
        }
      }

      const yesterday = new Date(today);
      yesterday.setDate(yesterday.getDate() - 1);

      if (user.lastActiveDate >= yesterday) {
        user.streak = (user.streak ?? 0) + 1;
      } else {
        user.streak = 0;
      }
    } else {
      user.streak = 0;
    }

    user.wins = wins;
    user.losses = losses;
    user.ducks = ducks;

    const totalDecisions = wins + losses;
    user.winRate = totalDecisions > 0 ? Math.round((wins / totalDecisions) * 100) : 0;

    const totalDucks = ducks + calloutsReceived;
    user.duckRate = totalDucks > 0 ? Math.round((ducks / totalDucks) * 100) : 0;

    const participationCount = wins + losses;
    const participationScore = Math.min(100, participationCount * 5);
    const proofCount = await BetProof.countDocuments({ userId: user._id });
    const proofScore = Math.min(100, proofCount * 10);
    const inverseDuckScore = 100 - (user.duckRate ?? 0);
    const streakScore = Math.min(100, (user.streak ?? 0) * 10);

    user.vibeScore = Math.round(
      (user.winRate ?? 0) * 0.3
      + participationScore * 0.25
      + proofScore * 0.2
      + inverseDuckScore * 0.15
      + streakScore * 0.1
    );

    await user.save();
  }
}

export function startBackgroundJobs(): void {
  if (backgroundJobsStarted) {
    return;
  }

  backgroundJobsStarted = true;
  console.log('Starting background jobs...');

  setInterval(() => {
    void safelyRunJob('checkDeadlines', checkDeadlines);
  }, 60 * 1000);

  setInterval(() => {
    void safelyRunJob('checkDisputeWindows', checkDisputeWindows);
  }, 60 * 1000);

  setInterval(() => {
    void safelyRunJob('checkVotingWindows', checkVotingWindows);
  }, 60 * 1000);

  setInterval(() => {
    void safelyRunJob('checkThresholds', checkThresholds);
  }, 60 * 1000);

  cron.schedule('0 0 * * *', () => {
    void safelyRunJob('dailyMaintenance', dailyMaintenance);
  });

  // Kick off one immediate pass for fresh boots.
  void safelyRunJob('checkDeadlines', checkDeadlines);
  void safelyRunJob('checkDisputeWindows', checkDisputeWindows);
  void safelyRunJob('checkVotingWindows', checkVotingWindows);
  void safelyRunJob('checkThresholds', checkThresholds);
}
