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
exports.createBet = createBet;
exports.getBetById = getBetById;
exports.getBetsByChatId = getBetsByChatId;
exports.isUserInChat = isUserInChat;
exports.placeBetStake = placeBetStake;
exports.getBetTotals = getBetTotals;
exports.getBetParticipants = getBetParticipants;
exports.getUserStake = getUserStake;
exports.submitBetProof = submitBetProof;
exports.getBetProofs = getBetProofs;
exports.getUserProofs = getUserProofs;
exports.deleteBetProof = deleteBetProof;
exports.resolveBet = resolveBet;
exports.autoExpireBets = autoExpireBets;
exports.getBetResolution = getBetResolution;
const uuid_1 = require("uuid");
const User_1 = __importDefault(require("../models/User"));
const Bet_1 = __importDefault(require("../models/Bet"));
const BetParticipant_1 = __importDefault(require("../models/BetParticipant"));
const BetProof_1 = __importDefault(require("../models/BetProof"));
const BetResolution_1 = __importDefault(require("../models/BetResolution"));
const AuraTransaction_1 = __importDefault(require("../models/AuraTransaction"));
const ChatMember_1 = __importDefault(require("../models/ChatMember"));
const CREATION_COST = 10;
const MAX_DESCRIPTION_LENGTH = 500;
const MIN_DEADLINE_HOURS = 1;
const MIN_STAKE = 10;
async function createBet(input) {
    const { chatId, creatorId, betType, description, deadline, initialStake, initialSide, targetUserId, } = input;
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
    const creatorInChat = await ChatMember_1.default.findOne({ chatId, userId: creatorId });
    if (!creatorInChat) {
        throw new Error('You must be a member of this chat to create bets');
    }
    // ── Validate initial stake/side ─────────────────────────────
    if (!Number.isInteger(initialStake) || initialStake < MIN_STAKE) {
        throw new Error(`Initial stake must be an integer >= ${MIN_STAKE}`);
    }
    if (initialSide !== 'yes' && initialSide !== 'no') {
        throw new Error('Initial side must be "yes" or "no"');
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
        const targetInChat = await ChatMember_1.default.findOne({ chatId, userId: targetUserId });
        if (!targetInChat) {
            throw new Error('Target user must be in this chat');
        }
    }
    // ── Create bet and creator's initial stake ──────────────────
    const betId = `bet_${Date.now()}_${(0, uuid_1.v4)().substring(0, 6)}`;
    // Create bet
    const bet = await Bet_1.default.create({
        betId,
        chatId,
        creatorId,
        betType,
        description: trimmed,
        deadline,
        status: 'active',
        targetUserId,
        creationCost: CREATION_COST,
    });
    // Record creator as first participant so "create bet" costs fee + stake.
    const participantId = `participant_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    await BetParticipant_1.default.create({
        participantId,
        betId,
        userId: creatorId,
        side: initialSide,
        amount: initialStake,
    });
    // Deduct Aura
    const balanceAfterCreation = (creator.auraBalance ?? 0) - CREATION_COST;
    const finalBalance = balanceAfterCreation - initialStake;
    creator.auraBalance = finalBalance;
    creator.lifetimeAuraSpent = (creator.lifetimeAuraSpent ?? 0) + totalCost;
    creator.betsCreated = (creator.betsCreated ?? 0) + 1;
    await creator.save();
    // Record creation fee transaction
    await AuraTransaction_1.default.create({
        transactionId: `txn_${(0, uuid_1.v4)()}`,
        userId: creatorId,
        amount: -CREATION_COST,
        balanceAfter: balanceAfterCreation,
        transactionType: 'bet_creation',
        referenceId: betId,
        description: `Created ${betType} bet: ${trimmed.substring(0, 50)}...`,
    });
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
    const membership = await ChatMember_1.default.findOne({ chatId, userId });
    return !!membership;
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
    const { betId, userId, side, amount } = params;
    // ── Validate bet exists and is active ───────────────────────
    const bet = await Bet_1.default.findOne({ betId });
    if (!bet)
        throw new Error('Bet not found');
    if (bet.status !== 'active')
        throw new Error(`Cannot stake on ${bet.status} bet`);
    // ── Validate deadline not passed ────────────────────────────
    if (bet.deadline <= new Date()) {
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
    if ((user.auraBalance ?? 0) < amount) {
        throw new Error(`Insufficient Aura. Need ${amount}, have ${user.auraBalance ?? 0}`);
    }
    // ── Validate user is in chat ────────────────────────────────
    const membership = await ChatMember_1.default.findOne({ chatId: bet.chatId, userId });
    if (!membership) {
        throw new Error('You must be in this chat to bet');
    }
    // ── Prevent duplicate stakes ────────────────────────────────
    const existing = await BetParticipant_1.default.findOne({ betId, userId });
    if (existing) {
        throw new Error('You have already staked on this bet');
    }
    // ── Validate side ───────────────────────────────────────────
    if (side !== 'yes' && side !== 'no') {
        throw new Error('Side must be "yes" or "no"');
    }
    // ── Execute transaction ─────────────────────────────────────
    const participantId = `participant_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    const participant = await BetParticipant_1.default.create({
        participantId,
        betId,
        userId,
        side,
        amount,
    });
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
        description: `Staked ${amount} Aura on "${side}" for bet: "${bet.description.substring(0, 50)}..."`,
    });
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
// ═══════════════════════════════════════════════════════════
// PROOF SUBMISSION FUNCTIONS
// ═══════════════════════════════════════════════════════════
/**
 * Submit Proof for Bet
 *
 * BUSINESS RULES:
 * 1. Bet must exist and be active
 * 2. Only authorized users can submit proof:
 *    - Self bets: Creator only
 *    - Callouts: Target user only
 *    - Dares: Target user only
 * 3. Media URL must be provided (from S3 upload)
 * 4. Deadline must not have passed (1 hour grace period)
 * 5. Can submit multiple proofs for same bet
 *
 * SIDE EFFECTS:
 * 1. Creates BetProof record
 * 2. Does NOT change bet status (remains 'active')
 * 3. Resolution happens separately in Phase 2.5
 */
async function submitBetProof(params) {
    const { betId, userId, mediaType, mediaUrl, mediaKey, thumbnailUrl, thumbnailKey, caption } = params;
    // ── Validate bet exists and is active ───────────────────
    const bet = await Bet_1.default.findOne({ betId });
    if (!bet) {
        throw new Error('Bet not found');
    }
    if (bet.status !== 'active') {
        throw new Error(`Cannot submit proof for ${bet.status} bet`);
    }
    // ── Validate deadline with grace period ─────────────────
    const gracePeriod = 60 * 60 * 1000; // 1 hour
    const deadlineWithGrace = new Date(bet.deadline.getTime() + gracePeriod);
    if (new Date() > deadlineWithGrace) {
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
        // Callouts/dares: Only target user can submit proof
        isAuthorized = (userId === bet.targetUserId);
        if (!isAuthorized) {
            throw new Error('Only the target user can submit proof for callouts/dares');
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
    });
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
    const { betId, resolvedBy, outcome, notes } = params;
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
    if (bet.status !== 'active') {
        throw new Error(`Bet is already ${bet.status}`);
    }
    // ── Validate outcome ────────────────────────────────────
    const validOutcomes = ['yes', 'no', 'expired', 'ducked'];
    if (!validOutcomes.includes(outcome)) {
        throw new Error(`Invalid outcome. Must be one of: ${validOutcomes.join(', ')}`);
    }
    // ── Verify authorization ────────────────────────────────
    if (resolvedBy !== 'system') {
        const isCreator = (resolvedBy === bet.creatorId);
        const isTarget = (bet.targetUserId && resolvedBy === bet.targetUserId);
        if (!isCreator && !isTarget) {
            throw new Error('Only the bet creator or target can resolve this bet');
        }
    }
    // ── Ducked outcome only valid for callouts ──────────────
    if (outcome === 'ducked' && bet.betType !== 'callout') {
        throw new Error('Only callouts can be marked as ducked');
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
    // ── Update bet status ───────────────────────────────────
    bet.status = outcome === 'yes' ? 'completed' :
        outcome === 'no' ? 'completed' :
            outcome === 'expired' ? 'expired' : 'ducked';
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
    }
    // ── Update creator stats ────────────────────────────────
    const creator = await User_1.default.findById(bet.creatorId);
    if (creator) {
        if (outcome === 'yes') {
            creator.betsCompleted = (creator.betsCompleted ?? 0) + 1;
        }
        else if (outcome === 'no') {
            creator.betsFailed = (creator.betsFailed ?? 0) + 1;
        }
        else if (outcome === 'expired') {
            creator.betsFailed = (creator.betsFailed ?? 0) + 1;
        }
        // Recalculate vibeScore
        creator.vibeScore = 100
            + ((creator.betsCompleted ?? 0) * 10)
            - ((creator.betsFailed ?? 0) * 20)
            - ((creator.calloutsIgnored ?? 0) * 10);
        if (creator.vibeScore < 0) {
            creator.vibeScore = 0;
        }
        await creator.save();
    }
    // ── Update target stats (callouts/dares) ────────────────
    if (bet.targetUserId && (bet.betType === 'callout' || bet.betType === 'dare')) {
        const target = await User_1.default.findById(bet.targetUserId);
        if (target) {
            if (outcome === 'yes') {
                target.betsCompleted = (target.betsCompleted ?? 0) + 1;
            }
            else if (outcome === 'no') {
                target.betsFailed = (target.betsFailed ?? 0) + 1;
            }
            else if (outcome === 'ducked') {
                target.calloutsIgnored = (target.calloutsIgnored ?? 0) + 1;
            }
            target.vibeScore = 100
                + ((target.betsCompleted ?? 0) * 10)
                - ((target.betsFailed ?? 0) * 20)
                - ((target.calloutsIgnored ?? 0) * 10);
            if (target.vibeScore < 0) {
                target.vibeScore = 0;
            }
            await target.save();
        }
    }
    return resolution;
}
/**
 * Auto-Expire Bets
 *
 * System function to resolve expired bets.
 * Called by cron job or background worker.
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
    return expiredCount;
}
/**
 * Get Resolution for Bet
 *
 * Retrieves the resolution record for a bet.
 */
async function getBetResolution(betId) {
    return await BetResolution_1.default.findOne({ betId });
}
//# sourceMappingURL=betService.js.map