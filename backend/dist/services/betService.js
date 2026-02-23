"use strict";
/**
 * Bet Service - Business Logic Layer
 *
 * Handles all bet creation validation and transactions.
 * Validates user permissions, Aura balance, description length, deadline.
 * Creates bet + deducts Aura atomically.
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getEligibleBetTargets = getEligibleBetTargets;
exports.createBet = createBet;
exports.getBetById = getBetById;
exports.getBetsByChatId = getBetsByChatId;
exports.isUserInChat = isUserInChat;
exports.placeBetStake = placeBetStake;
exports.getBetTotals = getBetTotals;
exports.getBetParticipants = getBetParticipants;
exports.getUserStake = getUserStake;
exports.getUserBetStakeTransactions = getUserBetStakeTransactions;
exports.submitBetProof = submitBetProof;
exports.getBetProofs = getBetProofs;
exports.getUserProofs = getUserProofs;
exports.deleteBetProof = deleteBetProof;
exports.resolveBet = resolveBet;
exports.getBetResolution = getBetResolution;
exports.refundAllStakes = refundAllStakes;
exports.applyDuckPenalty = applyDuckPenalty;
exports.voteOnConsensus = voteOnConsensus;
exports.reactToProof = reactToProof;
exports.getBetResolutionPayload = getBetResolutionPayload;
exports.getPendingResolutionClaim = getPendingResolutionClaim;
exports.claimBetResolution = claimBetResolution;
exports.confirmBetResolution = confirmBetResolution;
exports.disputeBetResolution = disputeBetResolution;
exports.autoConfirmPendingResolutionClaims = autoConfirmPendingResolutionClaims;
exports.autoExpireBets = autoExpireBets;
const uuid_1 = require("uuid");
const User_1 = __importDefault(require("../models/User"));
const Bet_1 = __importDefault(require("../models/Bet"));
const BetParticipant_1 = __importDefault(require("../models/BetParticipant"));
const BetProof_1 = __importDefault(require("../models/BetProof"));
const BetResolution_1 = __importDefault(require("../models/BetResolution"));
const ResolutionClaim_1 = __importDefault(require("../models/ResolutionClaim"));
const ConsensusVote_1 = __importDefault(require("../models/ConsensusVote"));
const ProofReaction_1 = __importDefault(require("../models/ProofReaction"));
const AuraTransaction_1 = __importDefault(require("../models/AuraTransaction"));
const ChatMember_1 = __importDefault(require("../models/ChatMember"));
const chatMembershipService_1 = require("./chatMembershipService");
const contactNetworkService_1 = require("./contactNetworkService");
const auraConstants_1 = require("../config/auraConstants");
const CREATION_COST = auraConstants_1.AURA_CONSTANTS.CREATION_COST;
const MAX_DESCRIPTION_LENGTH = 500;
const MIN_DEADLINE_HOURS = 1;
const MIN_STAKE = auraConstants_1.AURA_CONSTANTS.MIN_STAKE;
const RESOLUTION_CLAIM_WINDOW_HOURS = 6;
async function requireChatMembership(chatId, userId, errorMessage) {
    let membership = await ChatMember_1.default.findOne({ chatId, userId });
    if (!membership) {
        const repaired = await (0, chatMembershipService_1.ensureChatMembershipIfKnown)(chatId, userId);
        if (repaired) {
            membership = await ChatMember_1.default.findOne({ chatId, userId });
        }
    }
    if (!membership) {
        throw new Error(errorMessage);
    }
}
function isDuplicateKeyError(error) {
    return (typeof error === 'object' &&
        error !== null &&
        'code' in error &&
        error.code === 11000);
}
function resolveBetResolutionType(params) {
    const { betType, resolutionType } = params;
    if (resolutionType)
        return resolutionType;
    if (betType === 'prediction')
        return 'observable';
    return 'proof';
}
function calculateWinRateValue(wins, losses) {
    const total = wins + losses;
    if (total <= 0)
        return 0;
    return Math.round((wins / total) * 100);
}
function calculateDuckRateValue(ducks, calloutsReceived) {
    const total = ducks + calloutsReceived;
    if (total <= 0)
        return 0;
    return Math.round((ducks / total) * 100);
}
async function recalculateUserRates(userId) {
    const user = await User_1.default.findById(userId);
    if (!user)
        return;
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
async function getEligibleTargetUserIdsForChat(chatId, userId) {
    const [audienceGraph, chatMembers] = await Promise.all([
        (0, contactNetworkService_1.getAudienceGraph)({ userId }),
        ChatMember_1.default.find({
            chatId,
            userId: { $ne: userId },
        }).select('userId'),
    ]);
    const networkSet = new Set(audienceGraph.mergedUserIds
        .filter(id => id !== userId));
    const eligible = new Set();
    for (const member of chatMembers) {
        if (networkSet.has(member.userId)) {
            eligible.add(member.userId);
        }
    }
    return [...eligible];
}
async function getEligibleBetTargets(params) {
    const { chatId, userId } = params;
    await requireChatMembership(chatId, userId, 'You must be a member of this chat to view eligible bet targets');
    const eligibleUserIds = await getEligibleTargetUserIdsForChat(chatId, userId);
    if (eligibleUserIds.length === 0) {
        return [];
    }
    const users = await User_1.default.find({
        _id: { $in: eligibleUserIds },
    }).select('_id firstName lastName profilePicture');
    const userById = new Map();
    for (const user of users) {
        userById.set(String(user._id), {
            firstName: user.firstName,
            lastName: user.lastName,
            profilePicture: user.profilePicture,
        });
    }
    const resolvedTargets = [];
    for (const id of eligibleUserIds) {
        const user = userById.get(id);
        if (!user)
            continue;
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
async function createBet(input) {
    const { chatId, creatorId, betType, description, deadline, initialStake, initialSide, targetUserId, participationThreshold, resolutionType, isAnonymous = false, } = input;
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
    const creator = await User_1.default.findById(creatorId);
    if (!creator) {
        throw new Error('Creator not found');
    }
    // Bankruptcy check - cannot create bets with 0 or less Aura
    if ((creator.auraBalance ?? 0) <= 0) {
        throw new Error('You are bankrupt! Wait for daily bonus or accept a callout to earn Aura.');
    }
    const totalCost = CREATION_COST + initialStake;
    if ((creator.auraBalance ?? 0) < totalCost) {
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
        const target = await User_1.default.findById(targetUserId);
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
    const betId = `bet_${Date.now()}_${(0, uuid_1.v4)().substring(0, 6)}`;
    const nowForCreation = new Date();
    const status = participationThreshold !== undefined ? 'pending' : 'active';
    const thresholdMemberCount = participationThreshold !== undefined
        ? await ChatMember_1.default.countDocuments({ chatId })
        : undefined;
    const originalDeadlineDuration = Math.max(deadline.getTime() - nowForCreation.getTime(), MIN_DEADLINE_HOURS * 60 * 60 * 1000);
    const normalizedTargetUserId = betType === 'callout' || betType === 'dare'
        ? targetUserId
        : undefined;
    // Create bet
    const bet = await Bet_1.default.create({
        betId,
        chatId,
        creatorId,
        betType,
        description: trimmed,
        deadline,
        status,
        targetUserId: normalizedTargetUserId,
        creationCost: CREATION_COST,
        participationThreshold,
        resolutionType: resolvedResolutionType,
        thresholdMemberCount,
        activatedAt: status === 'active' ? nowForCreation : undefined,
        originalDeadlineDuration: participationThreshold !== undefined ? originalDeadlineDuration : undefined,
    });
    // Record creator as first participant so "create bet" has initial stake.
    const participantId = `participant_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    await BetParticipant_1.default.create({
        participantId,
        betId,
        userId: creatorId,
        side: initialSide,
        amount: initialStake,
        isAnonymous,
    });
    if (bet.status === 'pending' && bet.participationThreshold) {
        const currentParticipants = await BetParticipant_1.default.countDocuments({ betId });
        const thresholdBaseCount = bet.thresholdMemberCount
            ?? await ChatMember_1.default.countDocuments({ chatId: bet.chatId });
        const requiredParticipants = Math.max(1, Math.ceil(thresholdBaseCount * bet.participationThreshold));
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
    const balanceAfterCreation = (creator.auraBalance ?? 0) - CREATION_COST;
    const finalBalance = balanceAfterCreation - initialStake;
    creator.auraBalance = finalBalance;
    creator.lifetimeAuraSpent = (creator.lifetimeAuraSpent ?? 0) + totalCost;
    creator.betsCreated = (creator.betsCreated ?? 0) + 1;
    creator.lastActiveDate = nowForCreation;
    await creator.save();
    // Record creation fee transaction only when non-zero.
    if (CREATION_COST > 0) {
        await AuraTransaction_1.default.create({
            transactionId: `txn_${(0, uuid_1.v4)()}`,
            userId: creatorId,
            amount: -CREATION_COST,
            balanceAfter: balanceAfterCreation,
            transactionType: 'bet_creation',
            referenceId: betId,
            description: `Created ${betType} bet: ${trimmed.substring(0, 50)}...`,
        });
    }
    // Record initial stake transaction
    await AuraTransaction_1.default.create({
        transactionId: `txn_${(0, uuid_1.v4)()}`,
        userId: creatorId,
        amount: -initialStake,
        balanceAfter: finalBalance,
        transactionType: 'bet_stake',
        referenceId: betId,
        description: `Initial ${initialSide.toUpperCase()} stake on bet: "${trimmed.substring(0, 50)}..."`,
    });
    if (normalizedTargetUserId && (betType === 'callout' || betType === 'dare')) {
        await User_1.default.updateOne({ _id: normalizedTargetUserId }, { $inc: { calloutsReceived: 1 } });
        await recalculateUserRates(normalizedTargetUserId);
    }
    await recalculateUserRates(creatorId);
    return bet;
}
async function getBetById(betId) {
    return await Bet_1.default.findOne({ betId });
}
async function getBetsByChatId(chatId, status, limit = 50) {
    const query = { chatId };
    if (status)
        query.status = status;
    return await Bet_1.default.find(query).sort({ createdAt: -1 }).limit(limit);
}
async function isUserInChat(userId, chatId) {
    try {
        await requireChatMembership(chatId, userId, 'not in chat');
        return true;
    }
    catch {
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
async function placeBetStake(params) {
    const { betId, userId, side, amount, isAnonymous = false } = params;
    // ── Validate bet exists and can accept stakes ───────────────
    const bet = await Bet_1.default.findOne({ betId });
    if (!bet)
        throw new Error('Bet not found');
    if (bet.status !== 'active' && bet.status !== 'pending') {
        throw new Error(`Cannot stake on ${bet.status} bet`);
    }
    // Pending bets start their effective countdown only once threshold is met.
    if (bet.status === 'active' && bet.deadline <= new Date()) {
        throw new Error('Bet deadline has passed');
    }
    // ── Validate user and Aura balance ──────────────────────────
    const user = await User_1.default.findById(userId);
    if (!user)
        throw new Error('User not found');
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
    if ((user.auraBalance ?? 0) < amount) {
        throw new Error(`Insufficient Aura. Need ${amount}, have ${user.auraBalance ?? 0}`);
    }
    // ── Validate user is in chat ────────────────────────────────
    await requireChatMembership(bet.chatId, userId, 'You must be in this chat to bet');
    // ── Prevent duplicate stakes (except creator top-up before others join) ──
    const existing = await BetParticipant_1.default.findOne({ betId, userId });
    let participant;
    let isCreatorTopUp = false;
    // ── Validate side ───────────────────────────────────────────
    if (side !== 'yes' && side !== 'no') {
        throw new Error('Side must be "yes" or "no"');
    }
    if (existing) {
        const otherParticipantCount = await BetParticipant_1.default.countDocuments({
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
    }
    else {
        // ── Execute transaction ─────────────────────────────────────
        const participantId = `participant_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
        try {
            participant = await BetParticipant_1.default.create({
                participantId,
                betId,
                userId,
                side,
                amount,
                isAnonymous,
            });
        }
        catch (error) {
            if (isDuplicateKeyError(error)) {
                throw new Error('You have already staked on this bet');
            }
            throw error;
        }
    }
    // Deduct Aura (held in escrow)
    const newBalance = (user.auraBalance ?? 0) - amount;
    user.auraBalance = newBalance;
    user.lifetimeAuraSpent = (user.lifetimeAuraSpent ?? 0) + amount;
    await user.save();
    // Record transaction
    await AuraTransaction_1.default.create({
        transactionId: `txn_${(0, uuid_1.v4)()}`,
        userId,
        amount: -amount,
        balanceAfter: newBalance,
        transactionType: 'bet_stake',
        referenceId: betId,
        description: isCreatorTopUp
            ? `Added ${amount} Aura to existing "${side}" stake for bet: "${bet.description.substring(0, 50)}..."`
            : `Staked ${amount} Aura on "${side}" for bet: "${bet.description.substring(0, 50)}..."`,
    });
    if (bet.status === 'pending' && bet.participationThreshold) {
        const currentParticipants = await BetParticipant_1.default.countDocuments({ betId });
        const thresholdBaseCount = bet.thresholdMemberCount
            ?? await ChatMember_1.default.countDocuments({ chatId: bet.chatId });
        const requiredParticipants = Math.max(1, Math.ceil(thresholdBaseCount * bet.participationThreshold));
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
    return participant;
}
/**
 * Get total Aura staked on each side of a bet.
 */
async function getBetTotals(betId) {
    const participants = await BetParticipant_1.default.find({ betId });
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
async function getBetParticipants(betId) {
    return await BetParticipant_1.default.find({ betId }).sort({ createdAt: 1 });
}
/**
 * Get a user's stake in a bet (if any).
 */
async function getUserStake(betId, userId) {
    return await BetParticipant_1.default.findOne({ betId, userId });
}
/**
 * Get current user's stake transactions for a specific bet.
 * Includes both initial stake and any creator top-ups.
 */
async function getUserBetStakeTransactions(params) {
    const { betId, userId, limit = 50 } = params;
    const safeLimit = Math.max(1, Math.min(limit, 100));
    return await AuraTransaction_1.default.find({
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
async function submitBetProof(params) {
    const { betId, userId, mediaType, mediaUrl, mediaKey, thumbnailUrl, thumbnailKey, caption } = params;
    // ── Validate bet exists and is in a proof-accepting state ──
    const bet = await Bet_1.default.findOne({ betId });
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
    }
    catch {
        throw new Error('Invalid media URL format');
    }
    // ── Validate caption length if provided ─────────────────
    if (caption && caption.length > 500) {
        throw new Error('Caption too long (max 500 characters)');
    }
    // ── Create proof record ─────────────────────────────────
    const proofId = `proof_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    const disputeDeadline = new Date(Date.now() + auraConstants_1.AURA_CONSTANTS.DISPUTE_WINDOW_MS);
    const proof = await BetProof_1.default.create({
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
    const performer = await User_1.default.findById(userId);
    if (performer) {
        performer.auraBalance = (performer.auraBalance ?? 0) + auraConstants_1.AURA_CONSTANTS.PROOF_UPLOAD_BONUS;
        performer.lifetimeAuraEarned = (performer.lifetimeAuraEarned ?? 0) + auraConstants_1.AURA_CONSTANTS.PROOF_UPLOAD_BONUS;
        performer.lastActiveDate = new Date();
        await performer.save();
        await AuraTransaction_1.default.create({
            transactionId: `txn_${(0, uuid_1.v4)()}`,
            userId,
            amount: auraConstants_1.AURA_CONSTANTS.PROOF_UPLOAD_BONUS,
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
async function getBetProofs(betId) {
    return await BetProof_1.default.find({ betId })
        .populate('userId', 'firstName lastName profilePicture')
        .sort({ createdAt: -1 });
}
/**
 * Get User's Proofs for Bet
 *
 * Checks if a specific user has submitted proof for a bet.
 */
async function getUserProofs(betId, userId) {
    return await BetProof_1.default.find({ betId, userId })
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
async function deleteBetProof(proofId, userId) {
    const proof = await BetProof_1.default.findOne({ proofId });
    if (!proof) {
        throw new Error('Proof not found');
    }
    // Verify ownership
    if (proof.userId.toString() !== userId) {
        throw new Error('You can only delete your own proofs');
    }
    // Verify bet is still active
    const bet = await Bet_1.default.findOne({ betId: proof.betId });
    if (!bet) {
        throw new Error('Bet not found');
    }
    if (bet.status !== 'active') {
        throw new Error('Cannot delete proof from resolved bet');
    }
    // Delete proof
    await BetProof_1.default.deleteOne({ proofId });
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
async function resolveBet(params) {
    const { betId, resolvedBy, outcome, notes, allowedStatuses = ['active', 'resolving'] } = params;
    const buildPariMutuelPayouts = (winningParticipants, totalWinningStake, pot) => {
        if (winningParticipants.length === 0 || totalWinningStake <= 0 || pot <= 0)
            return [];
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
    const bet = await Bet_1.default.findOne({ betId });
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
    const participants = await BetParticipant_1.default.find({ betId });
    const totalYes = participants
        .filter(p => p.side === 'yes')
        .reduce((sum, p) => sum + p.amount, 0);
    const totalNo = participants
        .filter(p => p.side === 'no')
        .reduce((sum, p) => sum + p.amount, 0);
    const totalPot = totalYes + totalNo;
    // ── Calculate payouts based on outcome ──────────────────
    let payouts = [];
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
        }
        else {
            // Pari-mutuel payout to Team YES
            payouts = buildPariMutuelPayouts(participants.filter(p => p.side === 'yes'), totalYes, totalPot);
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
        }
        else {
            // Pari-mutuel payout to Team NO
            payouts = buildPariMutuelPayouts(participants.filter(p => p.side === 'no'), totalNo, totalPot);
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
    const resolution = await BetResolution_1.default.create({
        resolutionId,
        betId,
        outcome,
        resolvedBy,
        resolvedAt: new Date(),
        notes: notes?.trim() || undefined,
    });
    // ── Distribute payouts ──────────────────────────────────
    const payoutByUser = new Map();
    for (const payout of payouts) {
        const user = await User_1.default.findById(payout.userId);
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
        await AuraTransaction_1.default.create({
            transactionId: `txn_${(0, uuid_1.v4)()}`,
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
        const user = await User_1.default.findById(participant.userId);
        if (!user)
            continue;
        if (winningSide !== null && hasWinningPool) {
            if (participant.side === winningSide) {
                user.wins = (user.wins ?? user.betsCompleted ?? 0) + 1;
                user.betsCompleted = (user.betsCompleted ?? 0) + 1;
            }
            else {
                user.losses = (user.losses ?? user.betsFailed ?? 0) + 1;
                user.betsFailed = (user.betsFailed ?? 0) + 1;
            }
        }
        user.vibeScore = Math.max(0, 100
            + ((user.betsCompleted ?? 0) * 10)
            - ((user.betsFailed ?? 0) * 20)
            - ((user.calloutsIgnored ?? 0) * 10));
        user.lastActiveDate = new Date();
        await user.save();
    }
    // ── Performer bonus / duck penalty for callout + dare ─────
    if (bet.targetUserId && (bet.betType === 'callout' || bet.betType === 'dare')) {
        const target = await User_1.default.findById(bet.targetUserId);
        if (target) {
            if (outcome === 'yes') {
                const bonus = auraConstants_1.AURA_CONSTANTS.DARE_COMPLETION_BONUS;
                target.auraBalance = (target.auraBalance ?? 0) + bonus;
                target.lifetimeAuraEarned = (target.lifetimeAuraEarned ?? 0) + bonus;
                target.lastActiveDate = new Date();
                await target.save();
                await AuraTransaction_1.default.create({
                    transactionId: `txn_${(0, uuid_1.v4)()}`,
                    userId: target._id,
                    amount: bonus,
                    balanceAfter: target.auraBalance ?? bonus,
                    transactionType: 'dare_completion_bonus',
                    referenceId: betId,
                    description: `Completion bonus for ${bet.betType} bet`,
                });
            }
            if (outcome === 'no' || outcome === 'ducked') {
                const penalty = auraConstants_1.AURA_CONSTANTS.DUCK_PENALTY;
                const existingDucks = target.ducks ?? target.calloutsIgnored ?? 0;
                target.auraBalance = Math.max(0, (target.auraBalance ?? 0) - penalty);
                target.calloutsIgnored = (target.calloutsIgnored ?? 0) + 1;
                target.ducks = existingDucks + 1;
                target.lastActiveDate = new Date();
                await target.save();
                await AuraTransaction_1.default.create({
                    transactionId: `txn_${(0, uuid_1.v4)()}`,
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
async function getBetResolution(betId) {
    return await BetResolution_1.default.findOne({ betId });
}
async function refundAllStakes(betId) {
    const participants = await BetParticipant_1.default.find({ betId });
    for (const participant of participants) {
        const user = await User_1.default.findById(participant.userId);
        if (!user)
            continue;
        user.auraBalance = (user.auraBalance ?? 0) + participant.amount;
        user.lastActiveDate = new Date();
        await user.save();
        await AuraTransaction_1.default.create({
            transactionId: `txn_${(0, uuid_1.v4)()}`,
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
async function applyDuckPenalty(userId, betId) {
    const user = await User_1.default.findById(userId);
    if (!user)
        return;
    const penalty = auraConstants_1.AURA_CONSTANTS.DUCK_PENALTY;
    const existingDucks = user.ducks ?? user.calloutsIgnored ?? 0;
    user.auraBalance = Math.max(0, (user.auraBalance ?? 0) - penalty);
    user.calloutsIgnored = (user.calloutsIgnored ?? 0) + 1;
    user.ducks = existingDucks + 1;
    user.lastActiveDate = new Date();
    await user.save();
    await AuraTransaction_1.default.create({
        transactionId: `txn_${(0, uuid_1.v4)()}`,
        userId,
        amount: -penalty,
        balanceAfter: user.auraBalance ?? 0,
        transactionType: 'duck_penalty',
        referenceId: betId,
        description: 'Duck penalty applied',
    });
    await recalculateUserRates(userId);
}
async function voteOnConsensus(params) {
    const { betId, userId, vote } = params;
    const bet = await Bet_1.default.findOne({ betId });
    if (!bet) {
        throw new Error('Bet not found');
    }
    if (bet.status !== 'resolving') {
        throw new Error(`Bet must be resolving to vote. Current status: ${bet.status}`);
    }
    const isConsensusAllowed = bet.resolutionType === 'consensus' || bet.resolutionType === 'observable';
    if (!isConsensusAllowed) {
        throw new Error('Consensus voting is not available for this bet');
    }
    const participant = await BetParticipant_1.default.findOne({ betId, userId });
    if (!participant) {
        throw new Error('Only stakers can vote on this bet');
    }
    const existingVote = await ConsensusVote_1.default.findOne({ betId, userId });
    if (existingVote) {
        throw new Error('You already voted on this bet');
    }
    await ConsensusVote_1.default.create({
        voteId: `vote_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
        betId,
        userId,
        vote,
    });
    const [yesVotes, noVotes] = await Promise.all([
        ConsensusVote_1.default.countDocuments({ betId, vote: 'yes' }),
        ConsensusVote_1.default.countDocuments({ betId, vote: 'no' }),
    ]);
    return {
        yesVotes,
        noVotes,
        totalVotes: yesVotes + noVotes,
    };
}
async function reactToProof(params) {
    const { betId, proofId, userId, reaction } = params;
    const bet = await Bet_1.default.findOne({ betId });
    if (!bet) {
        throw new Error('Bet not found');
    }
    if (bet.status !== 'resolving' && bet.status !== 'active') {
        throw new Error(`Cannot react to proof for ${bet.status} bet`);
    }
    const proof = await BetProof_1.default.findOne({ proofId, betId });
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
    const staker = await BetParticipant_1.default.findOne({ betId, userId });
    if (!staker) {
        throw new Error('Only stakers can react to proof');
    }
    const existingReaction = await ProofReaction_1.default.findOne({ proofId, userId });
    if (existingReaction) {
        throw new Error('You already reacted to this proof');
    }
    await ProofReaction_1.default.create({
        reactionId: `pr_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
        proofId,
        userId,
        reaction,
    });
    if (reaction === 'confirm') {
        proof.confirmations = (proof.confirmations ?? 0) + 1;
    }
    else {
        proof.disputes = (proof.disputes ?? 0) + 1;
    }
    await proof.save();
    return {
        proof,
        confirmations: proof.confirmations ?? 0,
        disputes: proof.disputes ?? 0,
    };
}
async function getBetResolutionPayload(betId) {
    const bet = await Bet_1.default.findOne({ betId });
    if (!bet) {
        throw new Error('Bet not found');
    }
    const resolution = await BetResolution_1.default.findOne({ betId });
    if (!resolution) {
        throw new Error('Bet has not been resolved');
    }
    const participants = await BetParticipant_1.default.find({ betId }).sort({ createdAt: 1 });
    const userIds = participants.map(p => p.userId.toString());
    if (bet.targetUserId)
        userIds.push(bet.targetUserId);
    const users = await User_1.default.find({ _id: { $in: [...new Set(userIds)] } }).select('_id firstName lastName');
    const usersById = new Map(users.map(u => [u._id, u]));
    const totalPot = participants.reduce((sum, p) => sum + p.amount, 0);
    const participantCount = participants.length;
    const winners = [];
    const losers = [];
    for (const participant of participants) {
        const user = usersById.get(participant.userId.toString());
        const fullName = `${user?.firstName ?? ''} ${user?.lastName ?? ''}`.trim() || 'Anonymous';
        const isAnonymous = participant.isAnonymous === true;
        const displayName = isAnonymous ? 'Anonymous' : fullName;
        const publicUserId = isAnonymous ? null : participant.userId.toString();
        const payout = participant.payout ?? 0;
        const net = payout - participant.amount;
        if (participant.won) {
            winners.push({
                userId: publicUserId,
                displayName,
                stakeAmount: participant.amount,
                payout,
                netGain: net,
            });
        }
        else {
            losers.push({
                userId: publicUserId,
                displayName,
                stakeAmount: participant.amount,
                netLoss: -participant.amount,
            });
        }
    }
    const proof = await BetProof_1.default.findOne({ betId }).sort({ createdAt: -1 });
    const proofPayload = proof
        ? {
            mediaUrl: proof.mediaUrl,
            thumbnailUrl: proof.thumbnailUrl,
            mediaType: proof.mediaType,
        }
        : null;
    let ducked = null;
    if (resolution.outcome === 'ducked' && bet.targetUserId) {
        const target = usersById.get(bet.targetUserId);
        const fullName = `${target?.firstName ?? ''} ${target?.lastName ?? ''}`.trim() || 'Anonymous';
        ducked = [{
                userId: bet.targetUserId,
                displayName: fullName,
                penalty: auraConstants_1.AURA_CONSTANTS.DUCK_PENALTY,
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
function uniqueStrings(values) {
    return [...new Set(values.filter(Boolean))];
}
function buildClaimReviewerIds(params) {
    const { bet, proposedBy, proposedOutcome, participants } = params;
    if (bet.betType === 'self') {
        if (proposedOutcome !== 'yes' && proposedOutcome !== 'no') {
            return [];
        }
        const losingSide = proposedOutcome === 'yes' ? 'no' : 'yes';
        return uniqueStrings(participants
            .filter(p => p.side === losingSide)
            .map(p => p.userId.toString())
            .filter(userId => userId !== proposedBy));
    }
    if ((bet.betType === 'callout' || bet.betType === 'dare') && bet.targetUserId) {
        return uniqueStrings([bet.targetUserId].filter(userId => userId !== proposedBy));
    }
    return [];
}
async function finalizeResolutionClaim(params) {
    const { claim, finalStatus, finalNotes } = params;
    const resolution = await resolveBet({
        betId: claim.betId,
        resolvedBy: claim.proposedBy,
        outcome: claim.proposedOutcome,
        notes: finalNotes ?? claim.notes,
        allowedStatuses: ['resolving'],
    });
    const updatedClaim = await ResolutionClaim_1.default.findOneAndUpdate({ claimId: claim.claimId, status: 'pending' }, {
        $set: {
            status: finalStatus,
            finalizedAt: new Date(),
        }
    }, { new: true });
    if (!updatedClaim) {
        const fallbackClaim = await ResolutionClaim_1.default.findOne({ claimId: claim.claimId });
        if (!fallbackClaim)
            throw new Error('Resolution claim not found');
        return { claim: fallbackClaim, resolution };
    }
    return { claim: updatedClaim, resolution };
}
async function getPendingResolutionClaim(betId) {
    return await ResolutionClaim_1.default.findOne({
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
async function claimBetResolution(params) {
    const { betId, userId, outcome, mediaType, mediaUrl, mediaKey, thumbnailUrl, thumbnailKey, caption, notes, } = params;
    const bet = await Bet_1.default.findOne({ betId });
    if (!bet) {
        throw new Error('Bet not found');
    }
    if (bet.status !== 'active' && bet.status !== 'resolving') {
        throw new Error(`Cannot claim resolution for ${bet.status} bet`);
    }
    if (userId !== bet.creatorId) {
        throw new Error('Only the bet creator can claim resolution');
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
    const claim = await ResolutionClaim_1.default.create({
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
async function confirmBetResolution(params) {
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
    const updatedClaim = await ResolutionClaim_1.default.findOneAndUpdate({ claimId: claim.claimId, status: 'pending' }, { $addToSet: { confirmedBy: userId } }, { new: true });
    if (!updatedClaim) {
        throw new Error('Resolution claim is no longer pending');
    }
    const allConfirmed = updatedClaim.reviewerIds.every(reviewerId => updatedClaim.confirmedBy.includes(reviewerId));
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
async function disputeBetResolution(params) {
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
    const updatedClaim = await ResolutionClaim_1.default.findOneAndUpdate({ claimId: claim.claimId, status: 'pending' }, {
        $addToSet: { disputedBy: userId },
        $set: {
            status: 'disputed',
            finalizedAt: new Date(),
            notes: notes?.trim() || claim.notes,
        }
    }, { new: true });
    if (!updatedClaim) {
        throw new Error('Resolution claim is no longer pending');
    }
    await Bet_1.default.updateOne({ betId, status: 'resolving' }, { $set: { status: 'resolving' } });
    return updatedClaim;
}
async function autoConfirmPendingResolutionClaims() {
    const now = new Date();
    const pendingClaims = await ResolutionClaim_1.default.find({
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
        }
        catch (error) {
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
async function autoExpireBets() {
    const now = new Date();
    const expiredBets = await Bet_1.default.find({
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
        }
        catch (error) {
            console.error(`Failed to expire bet ${bet.betId}:`, error);
        }
    }
    const autoConfirmedCount = await autoConfirmPendingResolutionClaims();
    return { expiredCount, autoConfirmedCount };
}
//# sourceMappingURL=betService.js.map