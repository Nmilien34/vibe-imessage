/**
 * Bet Service - Business Logic Layer
 *
 * Handles all bet creation validation and transactions.
 * Validates user permissions, Aura balance, description length, deadline.
 * Creates bet + deducts Aura atomically.
 */

import { v4 as uuidv4 } from 'uuid';
import User from '../models/User';
import Bet from '../models/Bet';
import BetParticipant from '../models/BetParticipant';
import BetProof from '../models/BetProof';
import BetResolution from '../models/BetResolution';
import ResolutionClaim from '../models/ResolutionClaim';
import ConsensusVote from '../models/ConsensusVote';
import ProofReaction from '../models/ProofReaction';
import AuraTransaction from '../models/AuraTransaction';
import ChatMember from '../models/ChatMember';
import {
  BetType,
  BetStatus,
  BetResolutionType,
  IBet,
  IBetParticipant,
  IBetProof,
  IBetResolution,
  IResolutionClaim,
  IAuraTransaction
} from '../types';
import { ensureChatMembershipIfKnown } from './chatMembershipService';
import { getAudienceGraph } from './contactNetworkService';
import { AURA_CONSTANTS } from '../config/auraConstants';

const CREATION_COST = AURA_CONSTANTS.CREATION_COST;
const BET_CREATION_FEE_PER_DAY = AURA_CONSTANTS.BET_CREATION_FEE_PER_DAY;
const MAX_BET_CREATION_FEE = AURA_CONSTANTS.MAX_BET_CREATION_FEE;
const MAX_DESCRIPTION_LENGTH = 500;
const MIN_DEADLINE_HOURS = 1;
const MIN_STAKE = AURA_CONSTANTS.MIN_STAKE;
const NEW_STAKE_FEE = Math.max(0, Math.round(AURA_CONSTANTS.NEW_STAKE_FEE));
const RESOLUTION_CLAIM_WINDOW_HOURS = 6;

async function requireChatMembership(chatId: string, userId: string, errorMessage: string): Promise<void> {
  let membership = await ChatMember.findOne({ chatId, userId });
  if (!membership) {
    const repaired = await ensureChatMembershipIfKnown(chatId, userId);
    if (repaired) {
      membership = await ChatMember.findOne({ chatId, userId });
    }
  }

  if (!membership) {
    throw new Error(errorMessage);
  }
}

function isDuplicateKeyError(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code?: number }).code === 11000
  );
}

interface CreateBetInput {
  chatId: string;
  creatorId: string;
  betType: BetType;
  description: string;
  deadline: Date;
  initialStake: number;
  initialSide: 'yes' | 'no';
  targetUserId?: string;
  participationThreshold?: number;
  resolutionType?: BetResolutionType;
  isAnonymous?: boolean;
}

function resolveBetResolutionType(params: {
  betType: BetType;
  resolutionType?: BetResolutionType;
}): BetResolutionType {
  const { betType, resolutionType } = params;
  if (resolutionType) return resolutionType;
  if (betType === 'prediction') return 'observable';
  return 'proof';
}

function calculateWinRateValue(wins: number, losses: number): number {
  const total = wins + losses;
  if (total <= 0) return 0;
  return Math.round((wins / total) * 100);
}

function calculateDuckRateValue(ducks: number, calloutsReceived: number): number {
  const total = ducks + calloutsReceived;
  if (total <= 0) return 0;
  return Math.round((ducks / total) * 100);
}

function calculateBetCreationCost(params: { deadline: Date; now: Date }): number {
  const { deadline, now } = params;
  const rawHours = (deadline.getTime() - now.getTime()) / (60 * 60 * 1000);
  const safeHours = Math.max(0, rawHours);
  const deadlineBasedFee = Math.floor(safeHours / 24) * BET_CREATION_FEE_PER_DAY;
  const boundedFee = Math.min(MAX_BET_CREATION_FEE, Math.max(0, deadlineBasedFee));
  return Math.min(MAX_BET_CREATION_FEE, Math.max(0, CREATION_COST + boundedFee));
}

async function recalculateUserRates(userId: string): Promise<void> {
  const user = await User.findById(userId);
  if (!user) return;

  const wins = user.wins ?? user.betsCompleted ?? 0;
  const losses = user.losses ?? user.betsFailed ?? 0;
  const ducks = user.ducks ?? user.calloutsIgnored ?? 0;
  const calloutsReceived = user.calloutsReceived ?? 0;

  user.wins = wins;
  user.losses = losses;
  user.ducks = ducks;
  user.winRate = calculateWinRateValue(wins, losses);
  user.duckRate = calculateDuckRateValue(ducks, calloutsReceived);
  user.lastActiveDate = new Date();

  await user.save();
}

export interface EligibleBetTarget {
  id: string;
  firstName?: string;
  lastName?: string;
  profilePicture?: string;
}

async function getEligibleTargetUserIdsForChat(chatId: string, userId: string): Promise<string[]> {
  const [audienceGraph, chatMembers] = await Promise.all([
    getAudienceGraph({ userId }),
    ChatMember.find({
      chatId,
      userId: { $ne: userId },
    }).select('userId'),
  ]);

  const networkSet = new Set(
    audienceGraph.mergedUserIds
      .filter(id => id !== userId)
  );

  const eligible = new Set<string>();
  for (const member of chatMembers) {
    if (networkSet.has(member.userId)) {
      eligible.add(member.userId);
    }
  }

  return [...eligible];
}

export async function getEligibleBetTargets(params: { chatId: string; userId: string }): Promise<EligibleBetTarget[]> {
  const { chatId, userId } = params;

  await requireChatMembership(
    chatId,
    userId,
    'You must be a member of this chat to view eligible bet targets'
  );

  const eligibleUserIds = await getEligibleTargetUserIdsForChat(chatId, userId);
  if (eligibleUserIds.length === 0) {
    return [];
  }

  const users = await User.find({
    _id: { $in: eligibleUserIds },
  }).select('_id firstName lastName profilePicture');

  const userById = new Map<string, { firstName?: string; lastName?: string; profilePicture?: string }>();
  for (const user of users) {
    userById.set(String(user._id), {
      firstName: user.firstName,
      lastName: user.lastName,
      profilePicture: user.profilePicture,
    });
  }

  const resolvedTargets: EligibleBetTarget[] = [];
  for (const id of eligibleUserIds) {
    const user = userById.get(id);
    if (!user) continue;

    resolvedTargets.push({
      id,
      firstName: user.firstName,
      lastName: user.lastName,
      profilePicture: user.profilePicture,
    });
  }

  return resolvedTargets.sort((lhs, rhs) => {
    const lhsName = `${lhs.firstName ?? ''} ${lhs.lastName ?? ''}`.trim() || lhs.id;
    const rhsName = `${rhs.firstName ?? ''} ${rhs.lastName ?? ''}`.trim() || rhs.id;
    return lhsName.localeCompare(rhsName);
  });
}

export async function createBet(input: CreateBetInput): Promise<IBet> {
  const {
    chatId,
    creatorId,
    betType,
    description,
    deadline,
    initialStake,
    initialSide,
    targetUserId,
    participationThreshold,
    resolutionType,
    isAnonymous = false,
  } = input;

  // ── Validate description ────────────────────────────────────
  const trimmed = description.trim();
  if (trimmed.length === 0) {
    throw new Error('Description cannot be empty');
  }
  if (trimmed.length > MAX_DESCRIPTION_LENGTH) {
    throw new Error(`Description too long (max ${MAX_DESCRIPTION_LENGTH} characters)`);
  }

  // ── Validate deadline ───────────────────────────────────────
  const now = new Date();
  const minDeadline = new Date(now.getTime() + MIN_DEADLINE_HOURS * 60 * 60 * 1000);
  if (deadline <= minDeadline) {
    throw new Error(`Deadline must be in the future (at least ${MIN_DEADLINE_HOURS} hour from now)`);
  }

  // ── Verify creator is in chat ───────────────────────────────
  await requireChatMembership(chatId, creatorId, 'You must be a member of this chat to create bets');

  // ── Validate initial stake/side ─────────────────────────────
  if (!Number.isInteger(initialStake) || initialStake < MIN_STAKE) {
    throw new Error(`Initial stake must be an integer >= ${MIN_STAKE}`);
  }
  if (initialSide !== 'yes' && initialSide !== 'no') {
    throw new Error('Initial side must be "yes" or "no"');
  }

  if (participationThreshold !== undefined) {
    if (typeof participationThreshold !== 'number' || Number.isNaN(participationThreshold)) {
      throw new Error('participationThreshold must be a number between 0.1 and 1.0');
    }
    if (participationThreshold < 0.1 || participationThreshold > 1.0) {
      throw new Error('participationThreshold must be between 0.1 and 1.0');
    }
  }

  const resolvedResolutionType = resolveBetResolutionType({ betType, resolutionType });
  if (!['proof', 'observable', 'consensus'].includes(resolvedResolutionType)) {
    throw new Error('resolutionType must be proof, observable, or consensus');
  }

  // ── Verify creator has sufficient Aura ──────────────────────
  const creator = await User.findById(creatorId);
  if (!creator) {
    throw new Error('Creator not found');
  }

  // Bankruptcy check - cannot create bets with 0 or less Aura
  if ((creator.auraBalance ?? 0) <= 0) {
    throw new Error('You are bankrupt! Wait for daily bonus or accept a callout to earn Aura.');
  }

  const creationCost = calculateBetCreationCost({ deadline, now });
  const initialStakeFee = NEW_STAKE_FEE;
  const totalCost = creationCost + initialStake + initialStakeFee;
  if ((creator.auraBalance ?? 0) < totalCost) {
    if (initialStakeFee > 0 || creationCost > 0) {
      throw new Error(
        `Insufficient Aura. Need ${totalCost} (${creationCost} creation + ${initialStake} stake + ${initialStakeFee} fee), have ${creator.auraBalance ?? 0}`
      );
    }
    throw new Error(`Insufficient Aura. Need ${totalCost}, have ${creator.auraBalance ?? 0}`);
  }

  // ── Validate target for callout/dare ────────────────────────
  if (betType === 'callout' || betType === 'dare') {
    if (!targetUserId) {
      throw new Error(`${betType} bet requires a target user`);
    }
    if (targetUserId === creatorId) {
      throw new Error('Cannot target yourself in a callout or dare');
    }

    const target = await User.findById(targetUserId);
    if (!target) {
      throw new Error('Target user not found');
    }

    await requireChatMembership(chatId, targetUserId, 'Target user must be in this chat');

    const eligibleTargetIds = new Set(await getEligibleTargetUserIdsForChat(chatId, creatorId));
    if (!eligibleTargetIds.has(targetUserId)) {
      throw new Error('Target user must be in your Vibe network and this chat');
    }
  }

  // ── Create bet and creator's initial stake ──────────────────
  const betId = `bet_${Date.now()}_${uuidv4().substring(0, 6)}`;
  const nowForCreation = new Date();
  const status: BetStatus = participationThreshold !== undefined ? 'pending' : 'active';
  const thresholdMemberCount = participationThreshold !== undefined
    ? await ChatMember.countDocuments({ chatId })
    : undefined;
  const originalDeadlineDuration = Math.max(
    deadline.getTime() - nowForCreation.getTime(),
    MIN_DEADLINE_HOURS * 60 * 60 * 1000
  );

  const normalizedTargetUserId =
    betType === 'callout' || betType === 'dare'
      ? targetUserId
      : undefined;

  // Create bet
  const bet = await Bet.create({
    betId,
    chatId,
    creatorId,
    betType,
    description: trimmed,
    deadline,
    status,
    targetUserId: normalizedTargetUserId,
    creationCost,
    participationThreshold,
    resolutionType: resolvedResolutionType,
    thresholdMemberCount,
    activatedAt: status === 'active' ? nowForCreation : undefined,
    originalDeadlineDuration: participationThreshold !== undefined ? originalDeadlineDuration : undefined,
  });

  // Record creator as first participant so "create bet" has initial stake.
  const participantId = `participant_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
  await BetParticipant.create({
    participantId,
    betId,
    userId: creatorId,
    side: initialSide,
    amount: initialStake,
    isAnonymous,
  });

  if (bet.status === 'pending' && bet.participationThreshold) {
    const currentParticipants = await BetParticipant.countDocuments({ betId });
    const thresholdBaseCount = bet.thresholdMemberCount
      ?? await ChatMember.countDocuments({ chatId: bet.chatId });
    const requiredParticipants = Math.max(
      1,
      Math.ceil(thresholdBaseCount * bet.participationThreshold)
    );

    if (currentParticipants >= requiredParticipants) {
      const duration = bet.originalDeadlineDuration
        ?? Math.max(deadline.getTime() - Date.now(), MIN_DEADLINE_HOURS * 60 * 60 * 1000);

      bet.status = 'active';
      bet.activatedAt = new Date();
      bet.deadline = new Date(Date.now() + duration);
      await bet.save();
    }
  }

  // Deduct Aura
  const balanceAfterCreation = (creator.auraBalance ?? 0) - creationCost;
  const balanceAfterStake = balanceAfterCreation - initialStake;
  const finalBalance = balanceAfterStake - initialStakeFee;
  creator.auraBalance = finalBalance;
  creator.lifetimeAuraSpent = (creator.lifetimeAuraSpent ?? 0) + totalCost;
  creator.betsCreated = (creator.betsCreated ?? 0) + 1;
  creator.lastActiveDate = nowForCreation;
  await creator.save();

  // Record creation fee transaction only when non-zero.
  if (creationCost > 0) {
    await AuraTransaction.create({
      transactionId: `txn_${uuidv4()}`,
      userId: creatorId,
      amount: -creationCost,
      balanceAfter: balanceAfterCreation,
      transactionType: 'bet_creation',
      referenceId: betId,
      description: `Created ${betType} bet: ${trimmed.substring(0, 50)}...`,
    });
  }

  // Record initial stake transaction
  await AuraTransaction.create({
    transactionId: `txn_${uuidv4()}`,
    userId: creatorId,
    amount: -initialStake,
    balanceAfter: initialStakeFee > 0 ? balanceAfterStake : finalBalance,
    transactionType: 'bet_stake',
    referenceId: betId,
    description: `Initial ${initialSide.toUpperCase()} stake on bet: "${trimmed.substring(0, 50)}..."`,
  });

  if (initialStakeFee > 0) {
    await AuraTransaction.create({
      transactionId: `txn_${uuidv4()}`,
      userId: creatorId,
      amount: -initialStakeFee,
      balanceAfter: finalBalance,
      transactionType: 'bet_stake_fee',
      referenceId: betId,
      description: `New stake fee (${initialStakeFee} Aura) for bet: "${trimmed.substring(0, 50)}..."`,
    });
  }

  if (normalizedTargetUserId && (betType === 'callout' || betType === 'dare')) {
    await User.updateOne(
      { _id: normalizedTargetUserId },
      { $inc: { calloutsReceived: 1 } }
    );
    await recalculateUserRates(normalizedTargetUserId);
  }

  await recalculateUserRates(creatorId);

  return bet;
}

export async function getBetById(betId: string): Promise<IBet | null> {
  return await Bet.findOne({ betId });
}

export async function getBetsByChatId(
  chatId: string,
  status?: BetStatus,
  limit: number = 50
): Promise<IBet[]> {
  const query: any = { chatId };
  if (status) query.status = status;
  return await Bet.find(query).sort({ createdAt: -1 }).limit(limit);
}

export async function isUserInChat(userId: string, chatId: string): Promise<boolean> {
  try {
    await requireChatMembership(chatId, userId, 'not in chat');
    return true;
  } catch {
    return false;
  }
}

// ═══════════════════════════════════════════════════════════
// STAKING FUNCTIONS
// ═══════════════════════════════════════════════════════════

/**
 * Place stake on a bet.
 * Validates all business rules, deducts Aura (held in escrow),
 * creates participant record and transaction log.
 */
export async function placeBetStake(params: {
  betId: string;
  userId: string;
  side: 'yes' | 'no';
  amount: number;
  isAnonymous?: boolean;
}): Promise<{
  participant: IBetParticipant;
  chargedFee: number;
  totalDebited: number;
  isNewStake: boolean;
}> {
  const { betId, userId, side, amount, isAnonymous = false } = params;

  // ── Validate bet exists and can accept stakes ───────────────
  const bet = await Bet.findOne({ betId });
  if (!bet) throw new Error('Bet not found');
  if (bet.status !== 'active' && bet.status !== 'pending') {
    throw new Error(`Cannot stake on ${bet.status} bet`);
  }

  // Pending bets start their effective countdown only once threshold is met.
  if (bet.status === 'active' && bet.deadline <= new Date()) {
    throw new Error('Bet deadline has passed');
  }

  // ── Validate user and Aura balance ──────────────────────────
  const user = await User.findById(userId);
  if (!user) throw new Error('User not found');

  // Bankruptcy check - cannot bet with 0 or less Aura
  if ((user.auraBalance ?? 0) <= 0) {
    throw new Error('You are bankrupt! Wait for daily bonus or accept a callout to earn Aura.');
  }

  if (amount < MIN_STAKE) {
    throw new Error(`Minimum stake is ${MIN_STAKE} Aura`);
  }
  if (!Number.isInteger(amount)) {
    throw new Error(`Minimum stake is ${MIN_STAKE} Aura`);
  }

  // ── Validate user is in chat ────────────────────────────────
  await requireChatMembership(bet.chatId, userId, 'You must be in this chat to bet');

  // ── Prevent duplicate stakes (except creator top-up before others join) ──
  const existing = await BetParticipant.findOne({ betId, userId });
  const isNewStake = !existing;
  const stakeFee = isNewStake ? NEW_STAKE_FEE : 0;
  const totalDebit = amount + stakeFee;

  if ((user.auraBalance ?? 0) < totalDebit) {
    if (stakeFee > 0) {
      throw new Error(`Insufficient Aura. Need ${totalDebit} (${amount} stake + ${stakeFee} fee), have ${user.auraBalance ?? 0}`);
    }
    throw new Error(`Insufficient Aura. Need ${amount}, have ${user.auraBalance ?? 0}`);
  }

  let participant: IBetParticipant;
  let isCreatorTopUp = false;

  // ── Validate side ───────────────────────────────────────────
  if (side !== 'yes' && side !== 'no') {
    throw new Error('Side must be "yes" or "no"');
  }

  if (existing) {
    const otherParticipantCount = await BetParticipant.countDocuments({
      betId,
      userId: { $ne: userId }
    });

    const canTopUp = userId === bet.creatorId && otherParticipantCount === 0;
    if (!canTopUp) {
      throw new Error('You have already staked on this bet');
    }

    if (existing.side !== side) {
      throw new Error(`You can only add to your existing ${existing.side.toUpperCase()} stake`);
    }

    existing.amount += amount;
    participant = await existing.save();
    isCreatorTopUp = true;
  } else {
    // ── Execute transaction ─────────────────────────────────────
    const participantId = `participant_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;

    try {
      participant = await BetParticipant.create({
        participantId,
        betId,
        userId,
        side,
        amount,
        isAnonymous,
      });
    } catch (error) {
      if (isDuplicateKeyError(error)) {
        throw new Error('You have already staked on this bet');
      }
      throw error;
    }
  }

  // Deduct Aura (stake + optional new-stake fee).
  const previousBalance = user.auraBalance ?? 0;
  const newBalance = previousBalance - totalDebit;
  user.auraBalance = newBalance;
  user.lifetimeAuraSpent = (user.lifetimeAuraSpent ?? 0) + totalDebit;
  await user.save();

  // Record stake transaction (keeps stake activity history clean).
  const stakeBalanceAfter = previousBalance - amount;
  await AuraTransaction.create({
    transactionId: `txn_${uuidv4()}`,
    userId,
    amount: -amount,
    balanceAfter: stakeFee > 0 ? stakeBalanceAfter : newBalance,
    transactionType: 'bet_stake',
    referenceId: betId,
    description: isCreatorTopUp
      ? `Added ${amount} Aura to existing "${side}" stake for bet: "${bet.description.substring(0, 50)}..."`
      : `Staked ${amount} Aura on "${side}" for bet: "${bet.description.substring(0, 50)}..."`,
  });

  if (stakeFee > 0) {
    await AuraTransaction.create({
      transactionId: `txn_${uuidv4()}`,
      userId,
      amount: -stakeFee,
      balanceAfter: newBalance,
      transactionType: 'bet_stake_fee',
      referenceId: betId,
      description: `New stake fee (${stakeFee} Aura) for bet: "${bet.description.substring(0, 50)}..."`,
    });
  }

  if (bet.status === 'pending' && bet.participationThreshold) {
    const currentParticipants = await BetParticipant.countDocuments({ betId });
    const thresholdBaseCount = bet.thresholdMemberCount
      ?? await ChatMember.countDocuments({ chatId: bet.chatId });
    const requiredParticipants = Math.max(
      1,
      Math.ceil(thresholdBaseCount * bet.participationThreshold)
    );

    if (currentParticipants >= requiredParticipants) {
      const duration = bet.originalDeadlineDuration
        ?? Math.max(bet.deadline.getTime() - Date.now(), MIN_DEADLINE_HOURS * 60 * 60 * 1000);

      bet.status = 'active';
      bet.activatedAt = new Date();
      bet.deadline = new Date(Date.now() + duration);
      await bet.save();
    }
  }

  await recalculateUserRates(userId);

  return {
    participant,
    chargedFee: stakeFee,
    totalDebited: totalDebit,
    isNewStake,
  };
}

/**
 * Get total Aura staked on each side of a bet.
 */
export async function getBetTotals(betId: string): Promise<{
  totalYes: number;
  totalNo: number;
  totalPot: number;
  yesCount: number;
  noCount: number;
}> {
  const participants = await BetParticipant.find({ betId });

  const totalYes = participants
    .filter(p => p.side === 'yes')
    .reduce((sum, p) => sum + p.amount, 0);

  const totalNo = participants
    .filter(p => p.side === 'no')
    .reduce((sum, p) => sum + p.amount, 0);

  const yesCount = participants.filter(p => p.side === 'yes').length;
  const noCount = participants.filter(p => p.side === 'no').length;

  return {
    totalYes,
    totalNo,
    totalPot: totalYes + totalNo,
    yesCount,
    noCount,
  };
}

/**
 * Get all participants for a bet.
 */
export async function getBetParticipants(betId: string): Promise<IBetParticipant[]> {
  return await BetParticipant.find({ betId }).sort({ createdAt: 1 });
}

/**
 * Get a user's stake in a bet (if any).
 */
export async function getUserStake(betId: string, userId: string): Promise<IBetParticipant | null> {
  return await BetParticipant.findOne({ betId, userId });
}

/**
 * Get current user's stake transactions for a specific bet.
 * Includes both initial stake and any creator top-ups.
 */
export async function getUserBetStakeTransactions(params: {
  betId: string;
  userId: string;
  limit?: number;
}): Promise<IAuraTransaction[]> {
  const { betId, userId, limit = 50 } = params;
  const safeLimit = Math.max(1, Math.min(limit, 100));

  return await AuraTransaction.find({
    userId,
    referenceId: betId,
    transactionType: 'bet_stake',
  })
    .sort({ createdAt: 1 })
    .limit(safeLimit);
}

// ═══════════════════════════════════════════════════════════
// PROOF SUBMISSION FUNCTIONS
// ═══════════════════════════════════════════════════════════

/**
 * Submit Proof for Bet
 *
 * BUSINESS RULES:
 * 1. Bet must exist and be active/resolving
 * 2. Only authorized users can submit proof:
 *    - Self bets: Creator only
 *    - Callouts: Creator or target user
 *    - Dares: Creator or target user
 * 3. Media URL must be provided (from S3 upload)
 * 4. Deadline must not have passed (1 hour grace period)
 * 5. Can submit multiple proofs for same bet
 *
 * SIDE EFFECTS:
 * 1. Creates BetProof record
 * 2. Sets proof status to pending and opens dispute window
 * 3. Resolution happens separately in Phase 2.5
 */
export async function submitBetProof(params: {
  betId: string;
  userId: string;
  mediaType: 'photo' | 'video';
  mediaUrl: string;
  mediaKey: string;
  thumbnailUrl?: string;
  thumbnailKey?: string;
  caption?: string;
}): Promise<IBetProof> {

  const {
    betId,
    userId,
    mediaType,
    mediaUrl,
    mediaKey,
    thumbnailUrl,
    thumbnailKey,
    caption
  } = params;

  // ── Validate bet exists and is in a proof-accepting state ──
  const bet = await Bet.findOne({ betId });

  if (!bet) {
    throw new Error('Bet not found');
  }

  if (bet.status !== 'active' && bet.status !== 'resolving') {
    throw new Error(`Cannot submit proof for ${bet.status} bet`);
  }

  // ── Validate deadline with grace period for active bets ─
  const gracePeriod = 60 * 60 * 1000; // 1 hour
  const deadlineWithGrace = new Date(bet.deadline.getTime() + gracePeriod);

  if (bet.status === 'active' && new Date() > deadlineWithGrace) {
    throw new Error('Deadline has passed (including grace period)');
  }

  // ── Verify user is authorized to submit proof ───────────
  let isAuthorized = false;

  if (bet.betType === 'self') {
    // Self bets: Only creator can submit proof
    isAuthorized = (userId === bet.creatorId);

    if (!isAuthorized) {
      throw new Error('Only the bet creator can submit proof for self bets');
    }
  }

  if (bet.betType === 'callout' || bet.betType === 'dare') {
    // Callouts/dares: Creator or target can submit proof
    isAuthorized = userId === bet.creatorId || userId === bet.targetUserId;

    if (!isAuthorized) {
      throw new Error('Only the bet creator or target user can submit proof for callouts/dares');
    }
  }

  // ── Validate media type ─────────────────────────────────
  if (!['photo', 'video'].includes(mediaType)) {
    throw new Error('Media type must be "photo" or "video"');
  }

  // ── Validate media URL and key ──────────────────────────
  if (!mediaUrl || !mediaKey) {
    throw new Error('Media URL and key are required');
  }

  // Validate URL format
  try {
    new URL(mediaUrl);
  } catch {
    throw new Error('Invalid media URL format');
  }

  // ── Validate caption length if provided ─────────────────
  if (caption && caption.length > 500) {
    throw new Error('Caption too long (max 500 characters)');
  }

  // ── Create proof record ─────────────────────────────────
  const proofId = `proof_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
  const disputeDeadline = new Date(Date.now() + AURA_CONSTANTS.DISPUTE_WINDOW_MS);

  const proof = await BetProof.create({
    proofId,
    betId,
    userId,
    mediaType,
    mediaUrl,
    mediaKey,
    thumbnailUrl: thumbnailUrl || undefined,
    thumbnailKey: thumbnailKey || undefined,
    caption: caption?.trim() || undefined,
    status: 'pending',
    confirmations: 0,
    disputes: 0,
    disputeDeadline,
    isStory: true,
  });

  // Small reward for completing proof flow.
  const performer = await User.findById(userId);
  if (performer) {
    performer.auraBalance = (performer.auraBalance ?? 0) + AURA_CONSTANTS.PROOF_UPLOAD_BONUS;
    performer.lifetimeAuraEarned = (performer.lifetimeAuraEarned ?? 0) + AURA_CONSTANTS.PROOF_UPLOAD_BONUS;
    performer.lastActiveDate = new Date();
    await performer.save();

    await AuraTransaction.create({
      transactionId: `txn_${uuidv4()}`,
      userId,
      amount: AURA_CONSTANTS.PROOF_UPLOAD_BONUS,
      balanceAfter: performer.auraBalance,
      transactionType: 'proof_upload_bonus',
      referenceId: betId,
      description: `Uploaded proof for bet "${bet.description.substring(0, 50)}..."`,
    });
  }

  if (bet.status === 'active' && new Date() >= bet.deadline) {
    bet.status = 'resolving';
    await bet.save();
  }

  return proof;
}

/**
 * Get Proofs for Bet
 *
 * Retrieves all proof submissions for a bet.
 */
export async function getBetProofs(betId: string): Promise<IBetProof[]> {
  return await BetProof.find({ betId })
    .populate('userId', 'firstName lastName profilePicture')
    .sort({ createdAt: -1 });
}

/**
 * Get User's Proofs for Bet
 *
 * Checks if a specific user has submitted proof for a bet.
 */
export async function getUserProofs(
  betId: string,
  userId: string
): Promise<IBetProof[]> {
  return await BetProof.find({ betId, userId })
    .sort({ createdAt: -1 });
}

/**
 * Delete Proof
 *
 * Allows user to delete their own proof before bet is resolved.
 *
 * BUSINESS RULES:
 * 1. Proof must exist
 * 2. User must own the proof
 * 3. Bet must still be active (can't delete after resolution)
 */
export async function deleteBetProof(
  proofId: string,
  userId: string
): Promise<void> {

  const proof = await BetProof.findOne({ proofId });

  if (!proof) {
    throw new Error('Proof not found');
  }

  // Verify ownership
  if (proof.userId.toString() !== userId) {
    throw new Error('You can only delete your own proofs');
  }

  // Verify bet is still active
  const bet = await Bet.findOne({ betId: proof.betId });

  if (!bet) {
    throw new Error('Bet not found');
  }

  if (bet.status !== 'active') {
    throw new Error('Cannot delete proof from resolved bet');
  }

  // Delete proof
  await BetProof.deleteOne({ proofId });
}

// ═══════════════════════════════════════════════════════════
// RESOLUTION & PAYOUT FUNCTIONS
// ═══════════════════════════════════════════════════════════

/**
 * Resolve Bet
 *
 * Settles a bet, distributes Aura to winners, updates stats.
 *
 * BUSINESS RULES:
 * 1. Bet must exist and be active
 * 2. Only authorized users can resolve
 * 3. Outcome must be valid: 'yes', 'no', 'expired', 'ducked'
 * 4. Pari-mutuel payout must be exact
 * 5. All payouts must succeed atomically
 *
 * PAYOUT CALCULATION (Pari-Mutuel):
 * Winner payout = (Their stake / Total winning side) × Total pot
 * No house rake (0% fee)
 */
export async function resolveBet(params: {
  betId: string;
  resolvedBy: string;
  outcome: 'yes' | 'no' | 'expired' | 'ducked';
  notes?: string;
  allowedStatuses?: BetStatus[];
}): Promise<IBetResolution> {

  const {
    betId,
    resolvedBy,
    outcome,
    notes,
    allowedStatuses = ['active', 'resolving']
  } = params;

  const buildPariMutuelPayouts = (
    winningParticipants: IBetParticipant[],
    totalWinningStake: number,
    pot: number
  ): Array<{ userId: string; amount: number; type: string }> => {
    if (winningParticipants.length === 0 || totalWinningStake <= 0 || pot <= 0) return [];

    const payouts = winningParticipants.map(p => ({
      userId: p.userId.toString(),
      amount: Math.floor((p.amount / totalWinningStake) * pot),
      type: 'win',
    }));

    let distributed = payouts.reduce((sum, p) => sum + p.amount, 0);
    let remainder = pot - distributed;

    for (let i = 0; remainder > 0 && payouts.length > 0; i++) {
      const idx = i % payouts.length;
      payouts[idx].amount += 1;
      remainder -= 1;
      distributed += 1;
    }

    return payouts.filter(p => p.amount > 0);
  };

  // ── Validate bet exists and is active ───────────────────
  const bet = await Bet.findOne({ betId });

  if (!bet) {
    throw new Error('Bet not found');
  }

  if (!allowedStatuses.includes(bet.status)) {
    throw new Error(`Bet is already ${bet.status}`);
  }

  // ── Validate outcome ────────────────────────────────────
  const validOutcomes = ['yes', 'no', 'expired', 'ducked'];
  if (!validOutcomes.includes(outcome)) {
    throw new Error(`Invalid outcome. Must be one of: ${validOutcomes.join(', ')}`);
  }

  // ── Verify authorization ────────────────────────────────
  if (resolvedBy !== 'system' && resolvedBy !== 'consensus') {
    const isCreator = (resolvedBy === bet.creatorId);
    const isTarget = (bet.targetUserId && resolvedBy === bet.targetUserId);

    if (!isCreator && !isTarget) {
      throw new Error('Only the bet creator or target can resolve this bet');
    }
  }

  // ── Ducked outcome only valid for challenges (callout/dare) ──────────────
  if (outcome === 'ducked' && bet.betType !== 'callout' && bet.betType !== 'dare') {
    throw new Error('Only callouts or dares can be marked as ducked');
  }

  // ── Get all participants and calculate totals ───────────
  const participants = await BetParticipant.find({ betId });

  const totalYes = participants
    .filter(p => p.side === 'yes')
    .reduce((sum, p) => sum + p.amount, 0);

  const totalNo = participants
    .filter(p => p.side === 'no')
    .reduce((sum, p) => sum + p.amount, 0);

  const totalPot = totalYes + totalNo;

  // ── Calculate payouts based on outcome ──────────────────
  let payouts: Array<{ userId: string; amount: number; type: string }> = [];

  if (outcome === 'yes') {
    if (totalYes === 0) {
      // No winners - refund Team NO
      payouts = participants
        .filter(p => p.side === 'no')
        .map(p => ({
          userId: p.userId.toString(),
          amount: p.amount,
          type: 'refund'
        }));
    } else {
      // Pari-mutuel payout to Team YES
      payouts = buildPariMutuelPayouts(
        participants.filter(p => p.side === 'yes'),
        totalYes,
        totalPot
      );
    }
  }
  else if (outcome === 'no') {
    if (totalNo === 0) {
      // No winners - refund Team YES
      payouts = participants
        .filter(p => p.side === 'yes')
        .map(p => ({
          userId: p.userId.toString(),
          amount: p.amount,
          type: 'refund'
        }));
    } else {
      // Pari-mutuel payout to Team NO
      payouts = buildPariMutuelPayouts(
        participants.filter(p => p.side === 'no'),
        totalNo,
        totalPot
      );
    }
  }
  else if (outcome === 'expired' || outcome === 'ducked') {
    // Refund everyone
    payouts = participants.map(p => ({
      userId: p.userId.toString(),
      amount: p.amount,
      type: 'refund'
    }));
  }

  const winningSide = outcome === 'yes'
    ? 'yes'
    : outcome === 'no'
      ? 'no'
      : null;
  const hasWinningPool = winningSide === 'yes'
    ? totalYes > 0
    : winningSide === 'no'
      ? totalNo > 0
      : false;

  // ── Update bet status ───────────────────────────────────
  bet.status = outcome === 'yes' ? 'completed'
    : outcome === 'no' ? 'completed'
      : outcome === 'expired' ? 'expired' : 'ducked';
  await bet.save();

  // ── Create resolution record ────────────────────────────
  const resolutionId = `resolution_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;

  const resolution = await BetResolution.create({
    resolutionId,
    betId,
    outcome,
    resolvedBy,
    resolvedAt: new Date(),
    notes: notes?.trim() || undefined,
  });

  // ── Distribute payouts ──────────────────────────────────
  const payoutByUser = new Map<string, { amount: number; type: string }>();

  for (const payout of payouts) {
    const user = await User.findById(payout.userId);

    if (!user) {
      console.error(`User ${payout.userId} not found during payout`);
      continue;
    }

    user.auraBalance = (user.auraBalance ?? 0) + payout.amount;

    if (payout.type === 'win') {
      user.lifetimeAuraEarned = (user.lifetimeAuraEarned ?? 0) + payout.amount;
    }

    await user.save();

    // Record transaction
    await AuraTransaction.create({
      transactionId: `txn_${uuidv4()}`,
      userId: payout.userId,
      amount: payout.amount,
      balanceAfter: user.auraBalance,
      transactionType: payout.type === 'win' ? 'bet_win' : 'bet_refund',
      referenceId: betId,
      description: payout.type === 'win'
        ? `Won ${payout.amount} Aura from bet: "${bet.description.substring(0, 50)}"`
        : `Refunded ${payout.amount} Aura from ${outcome} bet`,
    });

    payoutByUser.set(payout.userId, { amount: payout.amount, type: payout.type });
  }

  for (const participant of participants) {
    const payoutRecord = payoutByUser.get(participant.userId.toString());
    const payoutAmount = payoutRecord?.amount ?? 0;

    const participantWon = winningSide !== null && hasWinningPool
      ? participant.side === winningSide
      : false;

    participant.payout = payoutAmount;
    participant.won = participantWon;
    await participant.save();
  }

  // ── Update user stats for all participants ───────────────
  for (const participant of participants) {
    const user = await User.findById(participant.userId);
    if (!user) continue;

    if (winningSide !== null && hasWinningPool) {
      if (participant.side === winningSide) {
        user.wins = (user.wins ?? user.betsCompleted ?? 0) + 1;
        user.betsCompleted = (user.betsCompleted ?? 0) + 1;
      } else {
        user.losses = (user.losses ?? user.betsFailed ?? 0) + 1;
        user.betsFailed = (user.betsFailed ?? 0) + 1;
      }
    }

    user.vibeScore = Math.max(
      0,
      100
      + ((user.betsCompleted ?? 0) * 10)
      - ((user.betsFailed ?? 0) * 20)
      - ((user.calloutsIgnored ?? 0) * 10)
    );
    user.lastActiveDate = new Date();
    await user.save();
  }

  // ── Performer bonus / duck penalty for callout + dare ─────
  if (bet.targetUserId && (bet.betType === 'callout' || bet.betType === 'dare')) {
    const target = await User.findById(bet.targetUserId);
    if (target) {
      if (outcome === 'yes') {
        const bonus = AURA_CONSTANTS.DARE_COMPLETION_BONUS;
        target.auraBalance = (target.auraBalance ?? 0) + bonus;
        target.lifetimeAuraEarned = (target.lifetimeAuraEarned ?? 0) + bonus;
        target.lastActiveDate = new Date();
        await target.save();

        await AuraTransaction.create({
          transactionId: `txn_${uuidv4()}`,
          userId: target._id,
          amount: bonus,
          balanceAfter: target.auraBalance ?? bonus,
          transactionType: 'dare_completion_bonus',
          referenceId: betId,
          description: `Completion bonus for ${bet.betType} bet`,
        });
      }

      if (outcome === 'no' || outcome === 'ducked') {
        const penalty = AURA_CONSTANTS.DUCK_PENALTY;
        const existingDucks = target.ducks ?? target.calloutsIgnored ?? 0;
        target.auraBalance = Math.max(0, (target.auraBalance ?? 0) - penalty);
        target.calloutsIgnored = (target.calloutsIgnored ?? 0) + 1;
        target.ducks = existingDucks + 1;
        target.lastActiveDate = new Date();
        await target.save();

        await AuraTransaction.create({
          transactionId: `txn_${uuidv4()}`,
          userId: target._id,
          amount: -penalty,
          balanceAfter: target.auraBalance ?? 0,
          transactionType: 'duck_penalty',
          referenceId: betId,
          description: `Duck penalty for ${bet.betType} bet`,
        });
      }
    }
  }

  const touchedUserIds = [...new Set(participants.map(p => p.userId.toString()))];
  if (bet.targetUserId) {
    touchedUserIds.push(bet.targetUserId);
  }
  for (const userId of new Set(touchedUserIds)) {
    await recalculateUserRates(userId);
  }

  return resolution;
}

/**
 * Get Resolution for Bet
 *
 * Retrieves the resolution record for a bet.
 */
export async function getBetResolution(betId: string): Promise<IBetResolution | null> {
  return await BetResolution.findOne({ betId });
}

export async function declareObservableOutcome(params: {
  betId: string;
  creatorId: string;
  outcome: 'yes' | 'no';
}): Promise<IBet> {
  const { betId, creatorId, outcome } = params;
  const bet = await Bet.findOne({ betId });

  if (!bet) {
    throw new Error('Bet not found');
  }

  if (bet.resolutionType !== 'observable') {
    throw new Error('Only observable bets can use creator declaration');
  }

  if (bet.status !== 'resolving') {
    throw new Error(`Observable declaration only allowed while resolving (current: ${bet.status})`);
  }

  if (bet.creatorId !== creatorId) {
    throw new Error('Only the bet creator can declare observable outcomes');
  }

  if (bet.observableDeclaredOutcome && bet.deadline > new Date()) {
    throw new Error('An observable declaration is already pending confirmation');
  }

  bet.observableDeclaredOutcome = outcome;
  bet.observableDeclaredBy = creatorId;
  bet.observableDeclaredAt = new Date();
  bet.deadline = new Date(Date.now() + AURA_CONSTANTS.OBSERVABLE_DISPUTE_WINDOW_MS);
  await bet.save();

  // Reset votes whenever a fresh declaration starts a new dispute window.
  await ConsensusVote.deleteMany({ betId });

  return bet;
}

export async function refundAllStakes(betId: string): Promise<void> {
  const participants = await BetParticipant.find({ betId });

  for (const participant of participants) {
    const user = await User.findById(participant.userId);
    if (!user) continue;

    user.auraBalance = (user.auraBalance ?? 0) + participant.amount;
    user.lastActiveDate = new Date();
    await user.save();

    await AuraTransaction.create({
      transactionId: `txn_${uuidv4()}`,
      userId: participant.userId.toString(),
      amount: participant.amount,
      balanceAfter: user.auraBalance ?? participant.amount,
      transactionType: 'refund',
      referenceId: betId,
      description: `Refunded ${participant.amount} Aura due to unresolved bet`,
    });

    participant.payout = participant.amount;
    participant.won = false;
    await participant.save();
  }
}

export async function applyDuckPenalty(userId: string, betId: string): Promise<void> {
  const user = await User.findById(userId);
  if (!user) return;

  const penalty = AURA_CONSTANTS.DUCK_PENALTY;
  const existingDucks = user.ducks ?? user.calloutsIgnored ?? 0;

  user.auraBalance = Math.max(0, (user.auraBalance ?? 0) - penalty);
  user.calloutsIgnored = (user.calloutsIgnored ?? 0) + 1;
  user.ducks = existingDucks + 1;
  user.lastActiveDate = new Date();
  await user.save();

  await AuraTransaction.create({
    transactionId: `txn_${uuidv4()}`,
    userId,
    amount: -penalty,
    balanceAfter: user.auraBalance ?? 0,
    transactionType: 'duck_penalty',
    referenceId: betId,
    description: 'Duck penalty applied',
  });

  await recalculateUserRates(userId);
}

export async function voteOnConsensus(params: {
  betId: string;
  userId: string;
  vote: 'yes' | 'no';
}): Promise<{ yesVotes: number; noVotes: number; totalVotes: number }> {
  const { betId, userId, vote } = params;
  const bet = await Bet.findOne({ betId });
  if (!bet) {
    throw new Error('Bet not found');
  }

  if (bet.status !== 'resolving') {
    throw new Error(`Bet must be resolving to vote. Current status: ${bet.status}`);
  }

  if (bet.resolutionType !== 'consensus' && bet.resolutionType !== 'observable') {
    throw new Error('Consensus voting is not available for this bet');
  }

  if (bet.resolutionType === 'consensus' && bet.deadline <= new Date()) {
    throw new Error('Consensus voting window has closed');
  }

  if (bet.resolutionType === 'observable') {
    if (!bet.observableDeclaredOutcome) {
      throw new Error('No observable declaration is currently open for dispute');
    }

    if (bet.deadline <= new Date()) {
      throw new Error('Observable dispute window has closed');
    }
  }

  const participant = await BetParticipant.findOne({ betId, userId });
  if (!participant) {
    throw new Error('Only stakers can vote on this bet');
  }

  const existingVote = await ConsensusVote.findOne({ betId, userId });
  if (existingVote) {
    throw new Error('You already voted on this bet');
  }

  await ConsensusVote.create({
    voteId: `vote_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    betId,
    userId,
    vote,
  });

  const [yesVotes, noVotes] = await Promise.all([
    ConsensusVote.countDocuments({ betId, vote: 'yes' }),
    ConsensusVote.countDocuments({ betId, vote: 'no' }),
  ]);

  return {
    yesVotes,
    noVotes,
    totalVotes: yesVotes + noVotes,
  };
}

export async function reactToProof(params: {
  betId: string;
  proofId: string;
  userId: string;
  reaction: 'confirm' | 'dispute';
}): Promise<{ proof: IBetProof; confirmations: number; disputes: number }> {
  const { betId, proofId, userId, reaction } = params;

  const bet = await Bet.findOne({ betId });
  if (!bet) {
    throw new Error('Bet not found');
  }

  if (bet.status !== 'resolving' && bet.status !== 'active') {
    throw new Error(`Cannot react to proof for ${bet.status} bet`);
  }

  const proof = await BetProof.findOne({ proofId, betId });
  if (!proof) {
    throw new Error('Proof not found');
  }

  if (proof.status !== 'pending') {
    throw new Error(`Cannot react to proof with status ${proof.status}`);
  }

  if (!proof.disputeDeadline || proof.disputeDeadline <= new Date()) {
    throw new Error('Dispute window has closed');
  }

  if (proof.userId.toString() === userId) {
    throw new Error('Proof uploader cannot react to their own proof');
  }

  const staker = await BetParticipant.findOne({ betId, userId });
  if (!staker) {
    throw new Error('Only stakers can react to proof');
  }

  const existingReaction = await ProofReaction.findOne({ proofId, userId });
  if (existingReaction) {
    throw new Error('You already reacted to this proof');
  }

  await ProofReaction.create({
    reactionId: `pr_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    proofId,
    userId,
    reaction,
  });

  if (reaction === 'confirm') {
    proof.confirmations = (proof.confirmations ?? 0) + 1;
  } else {
    proof.disputes = (proof.disputes ?? 0) + 1;
  }
  await proof.save();

  return {
    proof,
    confirmations: proof.confirmations ?? 0,
    disputes: proof.disputes ?? 0,
  };
}

export async function getBetResolutionPayload(betId: string): Promise<{
  betId: string;
  description: string;
  betType: BetType;
  outcome: 'yes' | 'no' | 'expired' | 'ducked';
  proof: {
    mediaUrl: string;
    thumbnailUrl?: string;
    mediaType: 'photo' | 'video';
  } | null;
  winners: Array<{
    userId: string | null;
    displayName: string;
    stakeAmount: number;
    payout: number;
    netGain: number;
  }>;
  losers: Array<{
    userId: string | null;
    displayName: string;
    stakeAmount: number;
    netLoss: number;
  }>;
  ducked: Array<{
    userId: string | null;
    displayName: string;
    penalty: number;
  }> | null;
  totalPot: number;
  participantCount: number;
}> {
  const bet = await Bet.findOne({ betId });
  if (!bet) {
    throw new Error('Bet not found');
  }

  const resolution = await BetResolution.findOne({ betId });
  if (!resolution) {
    throw new Error('Bet has not been resolved');
  }

  const participants = await BetParticipant.find({ betId }).sort({ createdAt: 1 });
  const userIds = participants.map(p => p.userId.toString());
  if (bet.targetUserId) userIds.push(bet.targetUserId);
  const users = await User.find({ _id: { $in: [...new Set(userIds)] } }).select('_id firstName lastName');
  const usersById = new Map(users.map(u => [u._id, u]));

  const totalPot = participants.reduce((sum, p) => sum + p.amount, 0);
  const participantCount = participants.length;

  const winners: Array<{
    userId: string | null;
    displayName: string;
    stakeAmount: number;
    payout: number;
    netGain: number;
  }> = [];

  const losers: Array<{
    userId: string | null;
    displayName: string;
    stakeAmount: number;
    netLoss: number;
  }> = [];

  for (const participant of participants) {
    const user = usersById.get(participant.userId.toString());
    const fullName = `${user?.firstName ?? ''} ${user?.lastName ?? ''}`.trim() || 'Anonymous';
    const isAnonymous = participant.isAnonymous === true;
    const displayName = isAnonymous ? 'Anonymous' : fullName;
    const publicUserId = isAnonymous ? null : participant.userId.toString();
    const payout = participant.payout ?? 0;
    const net = payout - participant.amount;

    if (participant.won || net > 0) {
      winners.push({
        userId: publicUserId,
        displayName,
        stakeAmount: participant.amount,
        payout,
        netGain: net,
      });
    } else if (net < 0) {
      losers.push({
        userId: publicUserId,
        displayName,
        stakeAmount: participant.amount,
        netLoss: net,
      });
    }
  }

  const proof = await BetProof.findOne({ betId }).sort({ createdAt: -1 });
  const proofPayload = proof
    ? {
      mediaUrl: proof.mediaUrl,
      thumbnailUrl: proof.thumbnailUrl,
      mediaType: proof.mediaType,
    }
    : null;

  let ducked: Array<{ userId: string | null; displayName: string; penalty: number; }> | null = null;
  if (resolution.outcome === 'ducked' && bet.targetUserId) {
    const target = usersById.get(bet.targetUserId);
    const fullName = `${target?.firstName ?? ''} ${target?.lastName ?? ''}`.trim() || 'Anonymous';
    ducked = [{
      userId: bet.targetUserId,
      displayName: fullName,
      penalty: AURA_CONSTANTS.DUCK_PENALTY,
    }];
  }

  return {
    betId: bet.betId,
    description: bet.description,
    betType: bet.betType,
    outcome: resolution.outcome,
    proof: proofPayload,
    winners,
    losers,
    ducked,
    totalPot,
    participantCount,
  };
}

function uniqueStrings(values: string[]): string[] {
  return [...new Set(values.filter(Boolean))];
}

function buildClaimReviewerIds(params: {
  bet: IBet;
  proposedBy: string;
  proposedOutcome: 'yes' | 'no' | 'ducked';
  participants: IBetParticipant[];
}): string[] {
  const { bet, proposedBy, proposedOutcome, participants } = params;

  if (bet.betType === 'self') {
    if (proposedOutcome !== 'yes' && proposedOutcome !== 'no') {
      return [];
    }

    const losingSide = proposedOutcome === 'yes' ? 'no' : 'yes';
    return uniqueStrings(
      participants
        .filter(p => p.side === losingSide)
        .map(p => p.userId.toString())
        .filter(userId => userId !== proposedBy)
    );
  }

  if ((bet.betType === 'callout' || bet.betType === 'dare') && bet.targetUserId) {
    return uniqueStrings([bet.targetUserId].filter(userId => userId !== proposedBy));
  }

  return [];
}

async function finalizeResolutionClaim(params: {
  claim: IResolutionClaim;
  finalStatus: 'confirmed' | 'auto_confirmed';
  finalNotes?: string;
}): Promise<{ claim: IResolutionClaim; resolution: IBetResolution }> {
  const { claim, finalStatus, finalNotes } = params;

  const resolution = await resolveBet({
    betId: claim.betId,
    resolvedBy: claim.proposedBy,
    outcome: claim.proposedOutcome as 'yes' | 'no' | 'ducked',
    notes: finalNotes ?? claim.notes,
    allowedStatuses: ['resolving'],
  });

  const updatedClaim = await ResolutionClaim.findOneAndUpdate(
    { claimId: claim.claimId, status: 'pending' },
    {
      $set: {
        status: finalStatus,
        finalizedAt: new Date(),
      }
    },
    { new: true }
  );

  if (!updatedClaim) {
    const fallbackClaim = await ResolutionClaim.findOne({ claimId: claim.claimId });
    if (!fallbackClaim) throw new Error('Resolution claim not found');
    return { claim: fallbackClaim, resolution };
  }

  return { claim: updatedClaim, resolution };
}

export async function getPendingResolutionClaim(betId: string): Promise<IResolutionClaim | null> {
  return await ResolutionClaim.findOne({
    betId,
    status: 'pending',
  }).sort({ createdAt: -1 });
}

/**
 * Claim Resolution With Proof
 *
 * Creates a pending resolution claim and transitions the bet to `resolving`.
 * Payouts only happen once this claim is confirmed (or auto-confirmed).
 */
export async function claimBetResolution(params: {
  betId: string;
  userId: string;
  outcome: 'yes' | 'no' | 'ducked';
  mediaType: 'photo' | 'video';
  mediaUrl: string;
  mediaKey: string;
  thumbnailUrl?: string;
  thumbnailKey?: string;
  caption?: string;
  notes?: string;
}): Promise<{ claim: IResolutionClaim; proof: IBetProof; resolution?: IBetResolution }> {
  const {
    betId,
    userId,
    outcome,
    mediaType,
    mediaUrl,
    mediaKey,
    thumbnailUrl,
    thumbnailKey,
    caption,
    notes,
  } = params;

  const bet = await Bet.findOne({ betId });
  if (!bet) {
    throw new Error('Bet not found');
  }

  if (bet.status !== 'active' && bet.status !== 'resolving') {
    throw new Error(`Cannot claim resolution for ${bet.status} bet`);
  }

  const isCreator = userId === bet.creatorId;
  const isTarget = (bet.betType === 'callout' || bet.betType === 'dare') && userId === bet.targetUserId;
  if (!isCreator && !isTarget) {
    throw new Error('Only the bet creator or called-out user can claim resolution');
  }

  if (outcome === 'ducked' && !isCreator) {
    throw new Error('Only the bet creator can mark a callout as ducked');
  }

  if (!['yes', 'no', 'ducked'].includes(outcome)) {
    throw new Error('Invalid outcome. Must be yes, no, or ducked');
  }

  if (outcome === 'ducked' && bet.betType !== 'callout' && bet.betType !== 'dare') {
    throw new Error('Only callouts or dares can be marked as ducked');
  }

  const existingPendingClaim = await getPendingResolutionClaim(betId);
  if (existingPendingClaim) {
    throw new Error('A pending resolution claim already exists for this bet');
  }

  const proof = await submitBetProof({
    betId,
    userId,
    mediaType,
    mediaUrl,
    mediaKey,
    thumbnailUrl,
    thumbnailKey,
    caption,
  });

  const participants = await getBetParticipants(betId);
  const reviewerIds = buildClaimReviewerIds({
    bet,
    proposedBy: userId,
    proposedOutcome: outcome,
    participants,
  });

  const autoConfirmAt = new Date(Date.now() + RESOLUTION_CLAIM_WINDOW_HOURS * 60 * 60 * 1000);
  const claimId = `claim_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;

  const claim = await ResolutionClaim.create({
    claimId,
    betId,
    proofId: proof.proofId,
    proposedOutcome: outcome,
    proposedBy: userId,
    reviewerIds,
    confirmedBy: [],
    disputedBy: [],
    status: 'pending',
    notes: notes?.trim() || undefined,
    autoConfirmAt,
  });

  bet.status = 'resolving';
  await bet.save();

  // If no reviewers are needed, finalize immediately.
  if (reviewerIds.length === 0) {
    const finalized = await finalizeResolutionClaim({
      claim,
      finalStatus: 'auto_confirmed',
      finalNotes: notes?.trim() || 'Auto-confirmed (no opposing stakers to review)',
    });
    return {
      claim: finalized.claim,
      proof,
      resolution: finalized.resolution,
    };
  }

  return {
    claim,
    proof,
  };
}

/**
 * Confirm a pending resolution claim.
 * When all reviewers confirm, payouts are finalized.
 */
export async function confirmBetResolution(params: {
  betId: string;
  userId: string;
}): Promise<{ claim: IResolutionClaim; resolution?: IBetResolution }> {
  const { betId, userId } = params;

  const claim = await getPendingResolutionClaim(betId);
  if (!claim) {
    throw new Error('No pending resolution claim found');
  }

  if (!claim.reviewerIds.includes(userId)) {
    throw new Error('You are not allowed to confirm this claim');
  }

  if (claim.disputedBy.includes(userId)) {
    throw new Error('You already disputed this claim');
  }

  if (claim.confirmedBy.includes(userId)) {
    throw new Error('You already confirmed this claim');
  }

  const updatedClaim = await ResolutionClaim.findOneAndUpdate(
    { claimId: claim.claimId, status: 'pending' },
    { $addToSet: { confirmedBy: userId } },
    { new: true }
  );

  if (!updatedClaim) {
    throw new Error('Resolution claim is no longer pending');
  }

  const allConfirmed = updatedClaim.reviewerIds.every(reviewerId =>
    updatedClaim.confirmedBy.includes(reviewerId)
  );

  if (!allConfirmed) {
    return { claim: updatedClaim };
  }

  const finalized = await finalizeResolutionClaim({
    claim: updatedClaim,
    finalStatus: 'confirmed',
    finalNotes: updatedClaim.notes?.trim() || 'Resolution confirmed by reviewers',
  });

  return {
    claim: finalized.claim,
    resolution: finalized.resolution,
  };
}

/**
 * Dispute a pending resolution claim.
 * Keeps bet in resolving so additional proof/votes can be submitted.
 */
export async function disputeBetResolution(params: {
  betId: string;
  userId: string;
  notes?: string;
}): Promise<IResolutionClaim> {
  const { betId, userId, notes } = params;

  const claim = await getPendingResolutionClaim(betId);
  if (!claim) {
    throw new Error('No pending resolution claim found');
  }

  if (!claim.reviewerIds.includes(userId)) {
    throw new Error('You are not allowed to dispute this claim');
  }

  if (claim.confirmedBy.includes(userId)) {
    throw new Error('You already confirmed this claim');
  }

  if (claim.disputedBy.includes(userId)) {
    throw new Error('You already disputed this claim');
  }

  const updatedClaim = await ResolutionClaim.findOneAndUpdate(
    { claimId: claim.claimId, status: 'pending' },
    {
      $addToSet: { disputedBy: userId },
      $set: {
        status: 'disputed',
        finalizedAt: new Date(),
        notes: notes?.trim() || claim.notes,
      }
    },
    { new: true }
  );

  if (!updatedClaim) {
    throw new Error('Resolution claim is no longer pending');
  }

  await Bet.updateOne(
    { betId, status: 'resolving' },
    { $set: { status: 'resolving' } }
  );

  return updatedClaim;
}

export async function autoConfirmPendingResolutionClaims(): Promise<number> {
  const now = new Date();
  const pendingClaims = await ResolutionClaim.find({
    status: 'pending',
    autoConfirmAt: { $lt: now }
  }).sort({ autoConfirmAt: 1 });

  let autoConfirmedCount = 0;

  for (const claim of pendingClaims) {
    try {
      await finalizeResolutionClaim({
        claim,
        finalStatus: 'auto_confirmed',
        finalNotes: claim.notes?.trim() || 'Auto-confirmed by system (claim window passed)',
      });
      autoConfirmedCount++;
    } catch (error) {
      console.error(`Failed to auto-confirm claim ${claim.claimId}:`, error);
    }
  }

  return autoConfirmedCount;
}

/**
 * Auto-Expire Bets + Auto-Confirm Claims
 *
 * System function to resolve expired bets and auto-confirm pending claims
 * whose review windows have elapsed.
 */
export async function autoExpireBets(): Promise<{ expiredCount: number; autoConfirmedCount: number }> {
  const now = new Date();

  const expiredBets = await Bet.find({
    status: 'active',
    deadline: { $lt: now }
  });

  let expiredCount = 0;

  for (const bet of expiredBets) {
    try {
      await resolveBet({
        betId: bet.betId,
        resolvedBy: 'system',
        outcome: 'expired',
        notes: 'Auto-expired by system (deadline passed)'
      });
      expiredCount++;
    } catch (error) {
      console.error(`Failed to expire bet ${bet.betId}:`, error);
    }
  }

  const autoConfirmedCount = await autoConfirmPendingResolutionClaims();

  return { expiredCount, autoConfirmedCount };
}
