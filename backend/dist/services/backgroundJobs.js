"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkDeadlines = checkDeadlines;
exports.checkDisputeWindows = checkDisputeWindows;
exports.checkVotingWindows = checkVotingWindows;
exports.checkThresholds = checkThresholds;
exports.dailyMaintenance = dailyMaintenance;
exports.startBackgroundJobs = startBackgroundJobs;
const node_cron_1 = __importDefault(require("node-cron"));
const Bet_1 = __importDefault(require("../models/Bet"));
const BetParticipant_1 = __importDefault(require("../models/BetParticipant"));
const BetProof_1 = __importDefault(require("../models/BetProof"));
const ConsensusVote_1 = __importDefault(require("../models/ConsensusVote"));
const User_1 = __importDefault(require("../models/User"));
const AuraTransaction_1 = __importDefault(require("../models/AuraTransaction"));
const auraConstants_1 = require("../config/auraConstants");
const betService_1 = require("./betService");
let backgroundJobsStarted = false;
function inferResolutionType(bet) {
    if (bet.resolutionType) {
        return bet.resolutionType;
    }
    return bet.betType === 'prediction' ? 'observable' : 'proof';
}
async function safelyRunJob(name, job) {
    try {
        await job();
    }
    catch (error) {
        console.error(`[BackgroundJobs] ${name} failed:`, error);
    }
}
// JOB 1: Active deadlines and resolving windows
async function checkDeadlines() {
    const now = new Date();
    const expiredActiveBets = await Bet_1.default.find({
        status: 'active',
        deadline: { $lt: now },
    });
    for (const bet of expiredActiveBets) {
        const resolutionType = inferResolutionType(bet);
        bet.status = 'resolving';
        await bet.save();
        if (resolutionType === 'proof') {
            const existingProof = await BetProof_1.default.findOne({ betId: bet.betId });
            if (!existingProof) {
                await (0, betService_1.resolveBet)({
                    betId: bet.betId,
                    outcome: 'no',
                    resolvedBy: 'system',
                    notes: 'No proof submitted before deadline',
                    allowedStatuses: ['resolving'],
                });
            }
        }
        if (resolutionType === 'observable') {
            bet.deadline = new Date(Date.now() + auraConstants_1.AURA_CONSTANTS.CREATOR_DECLARE_WINDOW_MS);
            await bet.save();
        }
        if (resolutionType === 'consensus') {
            bet.deadline = new Date(Date.now() + auraConstants_1.AURA_CONSTANTS.CONSENSUS_VOTE_WINDOW_MS);
            await bet.save();
        }
    }
    // Observable bets with no creator declaration in time are refunded/expired.
    const staleObservableBets = await Bet_1.default.find({
        status: 'resolving',
        resolutionType: 'observable',
        deadline: { $lt: now },
    });
    for (const bet of staleObservableBets) {
        await (0, betService_1.resolveBet)({
            betId: bet.betId,
            outcome: 'expired',
            resolvedBy: 'system',
            notes: 'Creator declaration window expired',
            allowedStatuses: ['resolving'],
        });
    }
    await (0, betService_1.autoConfirmPendingResolutionClaims)();
}
// JOB 2: Proof dispute windows
async function checkDisputeWindows() {
    const now = new Date();
    const expiredProofs = await BetProof_1.default.find({
        status: 'pending',
        disputeDeadline: { $lt: now },
    });
    for (const proof of expiredProofs) {
        const bet = await Bet_1.default.findOne({ betId: proof.betId });
        if (!bet) {
            continue;
        }
        if (bet.status !== 'active' && bet.status !== 'resolving') {
            continue;
        }
        const totalStakers = await BetParticipant_1.default.countDocuments({ betId: proof.betId });
        const disputes = proof.disputes ?? 0;
        if (totalStakers > 0 && disputes > totalStakers * 0.5) {
            proof.status = 'disputed';
            await proof.save();
            continue;
        }
        proof.status = 'confirmed';
        await proof.save();
        await (0, betService_1.resolveBet)({
            betId: bet.betId,
            outcome: 'yes',
            resolvedBy: proof.userId,
            notes: 'Proof confirmed after dispute window',
            allowedStatuses: ['active', 'resolving'],
        });
    }
}
// JOB 3: Consensus vote windows
async function checkVotingWindows() {
    const now = new Date();
    const expiredVoteBets = await Bet_1.default.find({
        status: 'resolving',
        resolutionType: 'consensus',
        deadline: { $lt: now },
    });
    for (const bet of expiredVoteBets) {
        const [yesVotes, noVotes] = await Promise.all([
            ConsensusVote_1.default.countDocuments({ betId: bet.betId, vote: 'yes' }),
            ConsensusVote_1.default.countDocuments({ betId: bet.betId, vote: 'no' }),
        ]);
        if (yesVotes === noVotes) {
            await (0, betService_1.resolveBet)({
                betId: bet.betId,
                outcome: 'expired',
                resolvedBy: 'system',
                notes: 'Consensus vote tied or had no majority',
                allowedStatuses: ['resolving'],
            });
            continue;
        }
        await (0, betService_1.resolveBet)({
            betId: bet.betId,
            outcome: yesVotes > noVotes ? 'yes' : 'no',
            resolvedBy: 'consensus',
            notes: `Consensus resolved (${yesVotes} yes / ${noVotes} no)`,
            allowedStatuses: ['resolving'],
        });
    }
}
// JOB 4: Pending threshold expirations
async function checkThresholds() {
    const staleThresholdBets = await Bet_1.default.find({
        status: 'pending',
        createdAt: { $lt: new Date(Date.now() - auraConstants_1.AURA_CONSTANTS.THRESHOLD_EXPIRY_MS) },
    });
    for (const bet of staleThresholdBets) {
        await (0, betService_1.resolveBet)({
            betId: bet.betId,
            outcome: 'expired',
            resolvedBy: 'system',
            notes: 'Participation threshold not met before timeout',
            allowedStatuses: ['pending'],
        });
    }
}
// JOB 5: Daily maintenance
async function dailyMaintenance() {
    const users = await User_1.default.find({});
    const now = new Date();
    const today = new Date(now);
    today.setHours(0, 0, 0, 0);
    for (const user of users) {
        const wins = user.wins ?? user.betsCompleted ?? 0;
        const losses = user.losses ?? user.betsFailed ?? 0;
        const ducks = user.ducks ?? user.calloutsIgnored ?? 0;
        const calloutsReceived = user.calloutsReceived ?? 0;
        if (user.lastActiveDate) {
            const daysSinceActive = Math.floor((now.getTime() - user.lastActiveDate.getTime()) / (24 * 60 * 60 * 1000));
            if (daysSinceActive >= auraConstants_1.AURA_CONSTANTS.INACTIVITY_GRACE_DAYS && (user.auraBalance ?? 0) > 0) {
                const decay = Math.min(daysSinceActive * auraConstants_1.AURA_CONSTANTS.INACTIVITY_DECAY_PER_DAY, auraConstants_1.AURA_CONSTANTS.INACTIVITY_DECAY_MAX);
                const previousBalance = user.auraBalance ?? 0;
                user.auraBalance = Math.max(0, previousBalance - decay);
                const appliedDecay = previousBalance - user.auraBalance;
                if (appliedDecay > 0) {
                    await AuraTransaction_1.default.create({
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
            }
            else {
                user.streak = 0;
            }
        }
        else {
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
        const proofCount = await BetProof_1.default.countDocuments({ userId: user._id });
        const proofScore = Math.min(100, proofCount * 10);
        const inverseDuckScore = 100 - (user.duckRate ?? 0);
        const streakScore = Math.min(100, (user.streak ?? 0) * 10);
        user.vibeScore = Math.round((user.winRate ?? 0) * 0.3
            + participationScore * 0.25
            + proofScore * 0.2
            + inverseDuckScore * 0.15
            + streakScore * 0.1);
        await user.save();
    }
}
function startBackgroundJobs() {
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
    node_cron_1.default.schedule('0 0 * * *', () => {
        void safelyRunJob('dailyMaintenance', dailyMaintenance);
    });
    // Kick off one immediate pass for fresh boots.
    void safelyRunJob('checkDeadlines', checkDeadlines);
    void safelyRunJob('checkDisputeWindows', checkDisputeWindows);
    void safelyRunJob('checkVotingWindows', checkVotingWindows);
    void safelyRunJob('checkThresholds', checkThresholds);
}
//# sourceMappingURL=backgroundJobs.js.map