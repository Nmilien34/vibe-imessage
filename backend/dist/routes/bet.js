"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const auth_1 = require("../middleware/auth");
const betService_1 = require("../services/betService");
const feedService_1 = require("../services/feedService");
const router = express_1.default.Router();
/**
 * @route   POST /api/bets/create
 * @desc    Create a new bet
 * @access  Private (JWT required)
 */
router.post('/create', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { chatId, betType, description, deadline, targetUserId, side, amount, initialStake, initialSide, participationThreshold, resolutionType, isAnonymous, } = req.body;
        const normalizedInitialStake = amount ?? initialStake;
        const normalizedInitialSide = side ?? initialSide;
        // Validate required fields
        if (!chatId || !betType || !description || !deadline || normalizedInitialStake === undefined || !normalizedInitialSide) {
            return res.status(400).json({
                error: 'Missing required fields',
                required: ['chatId', 'betType', 'description', 'deadline', 'side', 'amount']
            });
        }
        // Validate betType enum
        const validBetTypes = ['self', 'callout', 'dare', 'prediction'];
        if (!validBetTypes.includes(betType)) {
            return res.status(400).json({
                error: 'Invalid betType',
                allowed: validBetTypes
            });
        }
        // Parse and validate deadline
        const deadlineDate = new Date(deadline);
        if (isNaN(deadlineDate.getTime())) {
            return res.status(400).json({
                error: 'Invalid deadline format',
                hint: 'Use ISO 8601 format'
            });
        }
        // Validate initial stake and side
        if (typeof normalizedInitialStake !== 'number' || !Number.isInteger(normalizedInitialStake) || normalizedInitialStake < 10) {
            return res.status(400).json({
                error: 'amount must be an integer >= 10'
            });
        }
        if (normalizedInitialSide !== 'yes' && normalizedInitialSide !== 'no') {
            return res.status(400).json({
                error: 'side must be "yes" or "no"'
            });
        }
        if (participationThreshold !== undefined &&
            (typeof participationThreshold !== 'number'
                || Number.isNaN(participationThreshold)
                || participationThreshold < 0.1
                || participationThreshold > 1.0)) {
            return res.status(400).json({
                error: 'participationThreshold must be a number between 0.1 and 1.0'
            });
        }
        if (resolutionType !== undefined
            && !['proof', 'observable', 'consensus'].includes(resolutionType)) {
            return res.status(400).json({
                error: 'Invalid resolutionType',
                allowed: ['proof', 'observable', 'consensus']
            });
        }
        // Call service layer
        const bet = await (0, betService_1.createBet)({
            chatId,
            creatorId: userId,
            betType,
            description,
            deadline: deadlineDate,
            initialStake: normalizedInitialStake,
            initialSide: normalizedInitialSide,
            targetUserId,
            participationThreshold,
            resolutionType,
            isAnonymous,
        });
        if ((betType === 'callout' || betType === 'dare')
            && targetUserId
            && typeof targetUserId === 'string'
            && targetUserId !== userId) {
            try {
                await (0, feedService_1.createConnection)({
                    userId1: userId,
                    userId2: targetUserId,
                    sourceChatId: chatId,
                });
            }
            catch (connectionError) {
                // Connection hydration should not block bet creation.
                console.error('Bet creation network connection warning:', connectionError);
            }
        }
        res.status(201).json({
            success: true,
            bet: {
                betId: bet.betId,
                chatId: bet.chatId,
                creatorId: bet.creatorId,
                betType: bet.betType,
                description: bet.description,
                deadline: bet.deadline,
                targetUserId: bet.targetUserId,
                creationCost: bet.creationCost,
                participationThreshold: bet.participationThreshold,
                resolutionType: bet.resolutionType,
                thresholdMemberCount: bet.thresholdMemberCount,
                activatedAt: bet.activatedAt,
                originalDeadlineDuration: bet.originalDeadlineDuration,
                observableDeclaredOutcome: bet.observableDeclaredOutcome ?? null,
                observableDeclaredBy: bet.observableDeclaredBy ?? null,
                observableDeclaredAt: bet.observableDeclaredAt ?? null,
                status: bet.status,
                createdAt: bet.createdAt,
            }
        });
    }
    catch (error) {
        console.error('Bet creation error:', error);
        // Map business logic errors to HTTP status codes
        const userErrors = [
            'Insufficient Aura',
            'must be a member',
            'Target user not found',
            'Target user must be in this chat',
            'Vibe network',
            'Cannot target yourself',
            'requires a target user',
            'Initial stake',
            'Initial side',
            'participationThreshold',
            'resolutionType',
            'Deadline must be',
            'Description',
        ];
        const isUserError = userErrors.some(msg => error.message?.includes(msg));
        if (isUserError) {
            return res.status(400).json({ error: error.message });
        }
        res.status(500).json({
            error: 'Failed to create bet',
            message: error.message
        });
    }
});
/**
 * @route   GET /api/bets/chat/:chatId/eligible-targets
 * @desc    Get target users eligible for callout/dare (network ∩ current chat)
 * @access  Private (JWT required)
 */
router.get('/chat/:chatId/eligible-targets', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { chatId } = req.params;
        const targets = await (0, betService_1.getEligibleBetTargets)({ chatId, userId });
        res.json({
            chatId,
            targets: targets.map(target => ({
                id: target.id,
                firstName: target.firstName ?? null,
                lastName: target.lastName ?? null,
                profilePicture: target.profilePicture ?? null,
            })),
        });
    }
    catch (error) {
        console.error('Eligible target fetch error:', error);
        if (error.message?.includes('must be a member')) {
            return res.status(403).json({ error: error.message });
        }
        res.status(500).json({
            error: 'Failed to fetch eligible targets',
            message: error.message
        });
    }
});
/**
 * @route   POST /api/bets/:betId/stake
 * @desc    Place a stake on a bet
 * @access  Private (JWT required)
 */
router.post('/:betId/stake', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { betId } = req.params;
        const { side, amount, isAnonymous } = req.body;
        // Validate required fields
        if (!side || amount === undefined) {
            return res.status(400).json({
                error: 'Missing required fields',
                required: ['side', 'amount']
            });
        }
        // Validate side
        if (side !== 'yes' && side !== 'no') {
            return res.status(400).json({
                error: 'Invalid side',
                allowed: ['yes', 'no']
            });
        }
        // Validate minimum stake amount
        if (typeof amount !== 'number' || amount < 10 || !Number.isInteger(amount)) {
            return res.status(400).json({
                error: 'Amount must be an integer >= 10'
            });
        }
        const betBeforeStake = await (0, betService_1.getBetById)(betId);
        // Call service layer
        const participant = await (0, betService_1.placeBetStake)({
            betId,
            userId,
            side,
            amount,
            isAnonymous,
        });
        const betAfterStake = await (0, betService_1.getBetById)(betId);
        const thresholdActivated = betBeforeStake?.status === 'pending' && betAfterStake?.status === 'active';
        res.status(201).json({
            success: true,
            participant: {
                participantId: participant.participantId,
                betId: participant.betId,
                userId: participant.userId,
                side: participant.side,
                amount: participant.amount,
                isAnonymous: participant.isAnonymous ?? false,
                payout: participant.payout ?? null,
                won: participant.won ?? null,
                createdAt: participant.createdAt
            },
            thresholdActivated,
            betStatus: betAfterStake?.status ?? null,
        });
    }
    catch (error) {
        console.error('Stake placement error:', error);
        // Map business logic errors to HTTP status codes
        const userErrors = [
            'Bet not found',
            'Cannot stake on',
            'deadline has passed',
            'Insufficient Aura',
            'Minimum stake',
            'must be in this chat',
            'already staked',
            'only add to your existing'
        ];
        const isUserError = userErrors.some(msg => error.message?.includes(msg));
        if (error.message === 'Bet not found') {
            return res.status(404).json({ error: error.message });
        }
        if (error.message?.includes('already staked')) {
            return res.status(409).json({ error: error.message });
        }
        if (isUserError) {
            return res.status(400).json({ error: error.message });
        }
        res.status(500).json({
            error: 'Failed to place stake',
            message: error.message
        });
    }
});
/**
 * @route   GET /api/bets/:betId/participants
 * @desc    Get all participants and totals for a bet
 * @access  Private (JWT required)
 */
router.get('/:betId/participants', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { betId } = req.params;
        // Verify bet exists
        const bet = await (0, betService_1.getBetById)(betId);
        if (!bet) {
            return res.status(404).json({ error: 'Bet not found' });
        }
        // Verify user has access to this bet
        const canAccess = await (0, betService_1.isUserInChat)(userId, bet.chatId);
        if (!canAccess) {
            return res.status(403).json({
                error: 'You do not have access to this bet'
            });
        }
        // Get participants and totals
        const participants = await (0, betService_1.getBetParticipants)(betId);
        const totals = await (0, betService_1.getBetTotals)(betId);
        res.json({
            participants: participants.map(p => ({
                participantId: p.participantId,
                userId: p.userId,
                side: p.side,
                amount: p.amount,
                isAnonymous: p.isAnonymous ?? false,
                payout: p.payout ?? null,
                won: p.won ?? null,
                createdAt: p.createdAt
            })),
            totals: {
                totalYes: totals.totalYes,
                totalNo: totals.totalNo,
                totalPot: totals.totalPot,
                yesCount: totals.yesCount,
                noCount: totals.noCount
            }
        });
    }
    catch (error) {
        console.error('Participants fetch error:', error);
        res.status(500).json({
            error: 'Failed to fetch participants',
            message: error.message
        });
    }
});
/**
 * @route   GET /api/bets/:betId/my-stake
 * @desc    Get current user's stake in a bet
 * @access  Private (JWT required)
 */
router.get('/:betId/my-stake', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { betId } = req.params;
        // Verify bet exists
        const bet = await (0, betService_1.getBetById)(betId);
        if (!bet) {
            return res.status(404).json({ error: 'Bet not found' });
        }
        // Verify user has access
        const canAccess = await (0, betService_1.isUserInChat)(userId, bet.chatId);
        if (!canAccess) {
            return res.status(403).json({
                error: 'You do not have access to this bet'
            });
        }
        // Get user's stake
        const stake = await (0, betService_1.getUserStake)(betId, userId);
        if (!stake) {
            return res.json({
                hasStake: false,
                stake: null
            });
        }
        res.json({
            hasStake: true,
            stake: {
                participantId: stake.participantId,
                side: stake.side,
                amount: stake.amount,
                isAnonymous: stake.isAnonymous ?? false,
                payout: stake.payout ?? null,
                won: stake.won ?? null,
                createdAt: stake.createdAt
            }
        });
    }
    catch (error) {
        console.error('User stake fetch error:', error);
        res.status(500).json({
            error: 'Failed to fetch user stake',
            message: error.message
        });
    }
});
/**
 * @route   GET /api/bets/:betId/my-stake-transactions
 * @desc    Get current user's stake transaction history for this bet
 * @access  Private (JWT required)
 */
router.get('/:betId/my-stake-transactions', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { betId } = req.params;
        const { limit } = req.query;
        let parsedLimit = 50;
        if (limit) {
            parsedLimit = parseInt(limit, 10);
            if (isNaN(parsedLimit) || parsedLimit < 1)
                parsedLimit = 50;
            if (parsedLimit > 100)
                parsedLimit = 100;
        }
        const bet = await (0, betService_1.getBetById)(betId);
        if (!bet) {
            return res.status(404).json({ error: 'Bet not found' });
        }
        const canAccess = await (0, betService_1.isUserInChat)(userId, bet.chatId);
        if (!canAccess) {
            return res.status(403).json({
                error: 'You do not have access to this bet'
            });
        }
        const transactions = await (0, betService_1.getUserBetStakeTransactions)({
            betId,
            userId,
            limit: parsedLimit
        });
        res.json({
            transactions: transactions.map(t => ({
                transactionId: t.transactionId,
                amount: t.amount,
                balanceAfter: t.balanceAfter,
                description: t.description,
                referenceId: t.referenceId,
                createdAt: t.createdAt
            })),
            totalStaked: transactions.reduce((sum, t) => sum + Math.abs(t.amount), 0),
            count: transactions.length
        });
    }
    catch (error) {
        console.error('Stake transaction history error:', error);
        res.status(500).json({
            error: 'Failed to fetch stake transaction history',
            message: error.message
        });
    }
});
/**
 * @route   GET /api/bets/:betId
 * @desc    Get bet by ID with participants, totals, and user's stake
 * @access  Private (JWT required)
 */
router.get('/:betId', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { betId } = req.params;
        const bet = await (0, betService_1.getBetById)(betId);
        if (!bet) {
            return res.status(404).json({ error: 'Bet not found' });
        }
        // Verify user is in the chat
        const canAccess = await (0, betService_1.isUserInChat)(userId, bet.chatId);
        if (!canAccess) {
            return res.status(403).json({
                error: 'You do not have access to this bet'
            });
        }
        // Get participants, totals, and user's stake
        const participants = await (0, betService_1.getBetParticipants)(betId);
        const totals = await (0, betService_1.getBetTotals)(betId);
        const userStake = await (0, betService_1.getUserStake)(betId, userId);
        res.json({
            bet: {
                betId: bet.betId,
                chatId: bet.chatId,
                creatorId: bet.creatorId,
                betType: bet.betType,
                description: bet.description,
                deadline: bet.deadline,
                targetUserId: bet.targetUserId,
                creationCost: bet.creationCost,
                participationThreshold: bet.participationThreshold,
                resolutionType: bet.resolutionType,
                thresholdMemberCount: bet.thresholdMemberCount,
                activatedAt: bet.activatedAt,
                originalDeadlineDuration: bet.originalDeadlineDuration,
                observableDeclaredOutcome: bet.observableDeclaredOutcome ?? null,
                observableDeclaredBy: bet.observableDeclaredBy ?? null,
                observableDeclaredAt: bet.observableDeclaredAt ?? null,
                status: bet.status,
                createdAt: bet.createdAt,
                updatedAt: bet.updatedAt,
            },
            participants: participants.map(p => ({
                participantId: p.participantId,
                userId: p.userId,
                side: p.side,
                amount: p.amount,
                isAnonymous: p.isAnonymous ?? false,
                payout: p.payout ?? null,
                won: p.won ?? null,
                createdAt: p.createdAt
            })),
            totals: {
                totalYes: totals.totalYes,
                totalNo: totals.totalNo,
                totalPot: totals.totalPot,
                yesCount: totals.yesCount,
                noCount: totals.noCount
            },
            userStake: userStake ? {
                participantId: userStake.participantId,
                side: userStake.side,
                amount: userStake.amount,
                isAnonymous: userStake.isAnonymous ?? false,
                payout: userStake.payout ?? null,
                won: userStake.won ?? null,
                createdAt: userStake.createdAt
            } : null
        });
    }
    catch (error) {
        console.error('Bet fetch error:', error);
        res.status(500).json({
            error: 'Failed to fetch bet',
            message: error.message
        });
    }
});
/**
 * @route   GET /api/bets/chat/:chatId
 * @desc    Get all bets in a chat
 * @access  Private (JWT required)
 */
router.get('/chat/:chatId', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { chatId } = req.params;
        const { status, limit } = req.query;
        // Verify user is in chat
        const canAccess = await (0, betService_1.isUserInChat)(userId, chatId);
        if (!canAccess) {
            return res.status(403).json({ error: 'You are not in this chat' });
        }
        // Parse limit
        let parsedLimit = 50;
        if (limit) {
            parsedLimit = parseInt(limit, 10);
            if (isNaN(parsedLimit) || parsedLimit < 1)
                parsedLimit = 50;
            if (parsedLimit > 100)
                parsedLimit = 100;
        }
        // Validate status
        if (status && !['pending', 'active', 'completed', 'expired', 'ducked', 'resolving', 'cancelled'].includes(status)) {
            return res.status(400).json({
                error: 'Invalid status',
                allowed: ['pending', 'active', 'completed', 'expired', 'ducked', 'resolving', 'cancelled']
            });
        }
        const bets = await (0, betService_1.getBetsByChatId)(chatId, status, parsedLimit);
        res.json({
            bets: bets.map(bet => ({
                betId: bet.betId,
                chatId: bet.chatId,
                creatorId: bet.creatorId,
                betType: bet.betType,
                description: bet.description,
                deadline: bet.deadline,
                targetUserId: bet.targetUserId,
                creationCost: bet.creationCost,
                participationThreshold: bet.participationThreshold,
                resolutionType: bet.resolutionType,
                thresholdMemberCount: bet.thresholdMemberCount,
                activatedAt: bet.activatedAt,
                originalDeadlineDuration: bet.originalDeadlineDuration,
                observableDeclaredOutcome: bet.observableDeclaredOutcome ?? null,
                observableDeclaredBy: bet.observableDeclaredBy ?? null,
                observableDeclaredAt: bet.observableDeclaredAt ?? null,
                status: bet.status,
                createdAt: bet.createdAt,
            })),
            count: bets.length
        });
    }
    catch (error) {
        console.error('Chat bets fetch error:', error);
        res.status(500).json({
            error: 'Failed to fetch bets',
            message: error.message
        });
    }
});
/**
 * @route   POST /api/bets/:betId/proof
 * @desc    Submit proof for a bet
 * @access  Private (JWT required)
 */
router.post('/:betId/proof', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { betId } = req.params;
        const { mediaType, mediaUrl, mediaKey, thumbnailUrl, thumbnailKey, caption } = req.body;
        // Validate required fields
        if (!mediaType || !mediaUrl || !mediaKey) {
            return res.status(400).json({
                error: 'Missing required fields',
                required: ['mediaType', 'mediaUrl', 'mediaKey']
            });
        }
        // Validate mediaType
        if (!['photo', 'video'].includes(mediaType)) {
            return res.status(400).json({
                error: 'Invalid mediaType',
                allowed: ['photo', 'video']
            });
        }
        // Call service layer
        const proof = await (0, betService_1.submitBetProof)({
            betId,
            userId,
            mediaType,
            mediaUrl,
            mediaKey,
            thumbnailUrl,
            thumbnailKey,
            caption
        });
        res.status(201).json({
            success: true,
            proof: {
                proofId: proof.proofId,
                betId: proof.betId,
                userId: proof.userId,
                mediaType: proof.mediaType,
                mediaUrl: proof.mediaUrl,
                thumbnailUrl: proof.thumbnailUrl,
                caption: proof.caption,
                createdAt: proof.createdAt
            }
        });
    }
    catch (error) {
        console.error('Proof submission error:', error);
        // Map business logic errors to HTTP status codes
        const userErrors = [
            'Bet not found',
            'Cannot submit proof',
            'Deadline has passed',
            'Only the bet creator',
            'Only the target user',
            'Only the bet creator or target user',
            'Media type must be',
            'Media URL and key',
            'Invalid media URL',
            'Caption too long'
        ];
        const isUserError = userErrors.some(msg => error.message?.includes(msg));
        if (error.message === 'Bet not found') {
            return res.status(404).json({ error: error.message });
        }
        if (isUserError) {
            return res.status(400).json({ error: error.message });
        }
        res.status(500).json({
            error: 'Failed to submit proof',
            message: error.message
        });
    }
});
/**
 * @route   POST /api/bets/:betId/vote
 * @desc    Cast consensus vote for a resolving bet
 * @access  Private (JWT required)
 */
router.post('/:betId/vote', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { betId } = req.params;
        const { vote } = req.body;
        if (!vote || !['yes', 'no'].includes(vote)) {
            return res.status(400).json({
                error: 'vote must be "yes" or "no"'
            });
        }
        const counts = await (0, betService_1.voteOnConsensus)({ betId, userId, vote });
        res.status(201).json({
            success: true,
            counts
        });
    }
    catch (error) {
        console.error('Consensus vote error:', error);
        if (error.message === 'Bet not found') {
            return res.status(404).json({ error: error.message });
        }
        if (error.message?.includes('already voted')
            || error.message?.includes('not available')
            || error.message?.includes('Only stakers')
            || error.message?.includes('must be resolving')
            || error.message?.includes('No observable declaration')
            || error.message?.includes('dispute window has closed')
            || error.message?.includes('voting window has closed')) {
            return res.status(400).json({ error: error.message });
        }
        res.status(500).json({
            error: 'Failed to cast vote',
            message: error.message
        });
    }
});
/**
 * @route   POST /api/bets/:betId/proof/:proofId/confirm
 * @desc    Confirm pending proof during dispute window
 * @access  Private (JWT required)
 */
router.post('/:betId/proof/:proofId/confirm', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { betId, proofId } = req.params;
        const result = await (0, betService_1.reactToProof)({
            betId,
            proofId,
            userId,
            reaction: 'confirm',
        });
        res.status(201).json({
            success: true,
            proof: {
                proofId: result.proof.proofId,
                status: result.proof.status,
                confirmations: result.confirmations,
                disputes: result.disputes,
                disputeDeadline: result.proof.disputeDeadline ?? null,
            }
        });
    }
    catch (error) {
        console.error('Proof confirm error:', error);
        if (error.message?.includes('Bet not found')
            || error.message?.includes('Proof not found')) {
            return res.status(404).json({ error: error.message });
        }
        if (error.message?.includes('Cannot react to proof')
            || error.message?.includes('Dispute window')
            || error.message?.includes('Only stakers')
            || error.message?.includes('cannot react to their own proof')
            || error.message?.includes('already reacted')
            || error.message?.includes('status')) {
            return res.status(400).json({ error: error.message });
        }
        res.status(500).json({
            error: 'Failed to confirm proof',
            message: error.message
        });
    }
});
/**
 * @route   POST /api/bets/:betId/proof/:proofId/dispute
 * @desc    Dispute pending proof during dispute window
 * @access  Private (JWT required)
 */
router.post('/:betId/proof/:proofId/dispute', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { betId, proofId } = req.params;
        const result = await (0, betService_1.reactToProof)({
            betId,
            proofId,
            userId,
            reaction: 'dispute',
        });
        res.status(201).json({
            success: true,
            proof: {
                proofId: result.proof.proofId,
                status: result.proof.status,
                confirmations: result.confirmations,
                disputes: result.disputes,
                disputeDeadline: result.proof.disputeDeadline ?? null,
            }
        });
    }
    catch (error) {
        console.error('Proof dispute error:', error);
        if (error.message?.includes('Bet not found')
            || error.message?.includes('Proof not found')) {
            return res.status(404).json({ error: error.message });
        }
        if (error.message?.includes('Cannot react to proof')
            || error.message?.includes('Dispute window')
            || error.message?.includes('Only stakers')
            || error.message?.includes('cannot react to their own proof')
            || error.message?.includes('already reacted')
            || error.message?.includes('status')) {
            return res.status(400).json({ error: error.message });
        }
        res.status(500).json({
            error: 'Failed to dispute proof',
            message: error.message
        });
    }
});
/**
 * @route   GET /api/bets/:betId/proofs
 * @desc    Get all proofs for a bet
 * @access  Private (JWT required)
 */
router.get('/:betId/proofs', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { betId } = req.params;
        // Verify bet exists
        const bet = await (0, betService_1.getBetById)(betId);
        if (!bet) {
            return res.status(404).json({ error: 'Bet not found' });
        }
        // Verify user has access to this bet
        const canAccess = await (0, betService_1.isUserInChat)(userId, bet.chatId);
        if (!canAccess) {
            return res.status(403).json({
                error: 'You do not have access to this bet'
            });
        }
        // Get all proofs
        const proofs = await (0, betService_1.getBetProofs)(betId);
        res.json({
            proofs: proofs.map(p => ({
                proofId: p.proofId,
                betId: p.betId,
                userId: p.userId,
                user: p.userId, // Populated user data
                mediaType: p.mediaType,
                mediaUrl: p.mediaUrl,
                thumbnailUrl: p.thumbnailUrl,
                caption: p.caption,
                status: p.status ?? null,
                confirmations: p.confirmations ?? 0,
                disputes: p.disputes ?? 0,
                disputeDeadline: p.disputeDeadline ?? null,
                createdAt: p.createdAt
            })),
            count: proofs.length
        });
    }
    catch (error) {
        console.error('Proofs fetch error:', error);
        res.status(500).json({
            error: 'Failed to fetch proofs',
            message: error.message
        });
    }
});
/**
 * @route   DELETE /api/bets/proofs/:proofId
 * @desc    Delete a proof submission
 * @access  Private (JWT required)
 */
router.delete('/proofs/:proofId', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { proofId } = req.params;
        // Call service layer
        await (0, betService_1.deleteBetProof)(proofId, userId);
        res.json({
            success: true,
            message: 'Proof deleted successfully'
        });
    }
    catch (error) {
        console.error('Proof deletion error:', error);
        // Map business logic errors to HTTP status codes
        if (error.message === 'Proof not found') {
            return res.status(404).json({ error: error.message });
        }
        if (error.message?.includes('You can only delete your own')) {
            return res.status(403).json({ error: error.message });
        }
        if (error.message?.includes('Cannot delete proof from resolved bet')) {
            return res.status(400).json({ error: error.message });
        }
        res.status(500).json({
            error: 'Failed to delete proof',
            message: error.message
        });
    }
});
/**
 * @route   GET /api/bets/:betId/resolution-claim
 * @desc    Get pending resolution claim details for a bet
 * @access  Private (JWT required)
 */
router.get('/:betId/resolution-claim', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { betId } = req.params;
        const bet = await (0, betService_1.getBetById)(betId);
        if (!bet) {
            return res.status(404).json({ error: 'Bet not found' });
        }
        const canAccess = await (0, betService_1.isUserInChat)(userId, bet.chatId);
        if (!canAccess) {
            return res.status(403).json({
                error: 'You do not have access to this bet'
            });
        }
        const claim = await (0, betService_1.getPendingResolutionClaim)(betId);
        if (!claim) {
            return res.json({ claim: null });
        }
        const canReview = claim.reviewerIds.includes(userId);
        const hasActed = claim.confirmedBy.includes(userId) || claim.disputedBy.includes(userId);
        res.json({
            claim: {
                claimId: claim.claimId,
                betId: claim.betId,
                proofId: claim.proofId,
                proposedOutcome: claim.proposedOutcome,
                proposedBy: claim.proposedBy,
                reviewerIds: claim.reviewerIds,
                confirmedBy: claim.confirmedBy,
                disputedBy: claim.disputedBy,
                status: claim.status,
                notes: claim.notes,
                autoConfirmAt: claim.autoConfirmAt,
                finalizedAt: claim.finalizedAt,
                createdAt: claim.createdAt,
                updatedAt: claim.updatedAt,
            },
            viewer: {
                canReview,
                hasActed,
            }
        });
    }
    catch (error) {
        console.error('Resolution claim fetch error:', error);
        res.status(500).json({
            error: 'Failed to fetch resolution claim',
            message: error.message
        });
    }
});
/**
 * @route   POST /api/bets/:betId/claim-resolution
 * @desc    Submit proof + claim a pending resolution outcome
 * @access  Private (JWT required)
 */
router.post('/:betId/claim-resolution', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { betId } = req.params;
        const { outcome, mediaType, mediaUrl, mediaKey, thumbnailUrl, thumbnailKey, caption, notes } = req.body;
        if (!outcome || !mediaType || !mediaUrl || !mediaKey) {
            return res.status(400).json({
                error: 'Missing required fields',
                required: ['outcome', 'mediaType', 'mediaUrl', 'mediaKey']
            });
        }
        const validOutcomes = ['yes', 'no', 'ducked'];
        if (!validOutcomes.includes(outcome)) {
            return res.status(400).json({
                error: 'Invalid outcome',
                allowed: validOutcomes
            });
        }
        if (!['photo', 'video'].includes(mediaType)) {
            return res.status(400).json({
                error: 'Invalid mediaType',
                allowed: ['photo', 'video']
            });
        }
        const result = await (0, betService_1.claimBetResolution)({
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
        });
        res.status(201).json({
            success: true,
            claim: {
                claimId: result.claim.claimId,
                betId: result.claim.betId,
                proofId: result.claim.proofId,
                proposedOutcome: result.claim.proposedOutcome,
                proposedBy: result.claim.proposedBy,
                reviewerIds: result.claim.reviewerIds,
                confirmedBy: result.claim.confirmedBy,
                disputedBy: result.claim.disputedBy,
                status: result.claim.status,
                notes: result.claim.notes,
                autoConfirmAt: result.claim.autoConfirmAt,
                finalizedAt: result.claim.finalizedAt,
                createdAt: result.claim.createdAt,
                updatedAt: result.claim.updatedAt,
            },
            proof: {
                proofId: result.proof.proofId,
                betId: result.proof.betId,
                userId: result.proof.userId,
                mediaType: result.proof.mediaType,
                mediaUrl: result.proof.mediaUrl,
                thumbnailUrl: result.proof.thumbnailUrl,
                caption: result.proof.caption,
                createdAt: result.proof.createdAt,
            },
            resolution: result.resolution ? {
                resolutionId: result.resolution.resolutionId,
                betId: result.resolution.betId,
                outcome: result.resolution.outcome,
                resolvedBy: result.resolution.resolvedBy,
                resolvedAt: result.resolution.resolvedAt,
                notes: result.resolution.notes,
            } : null,
            message: result.resolution
                ? 'Claim auto-confirmed. Bet resolved immediately.'
                : 'Resolution claim submitted. Waiting for confirm/dispute window.'
        });
    }
    catch (error) {
        console.error('Claim resolution error:', error);
        if (error.message === 'Bet not found') {
            return res.status(404).json({ error: error.message });
        }
        if (error.message?.includes('Only the bet creator can claim resolution') ||
            error.message?.includes('not allowed to')) {
            return res.status(403).json({ error: error.message });
        }
        if (error.message?.includes('pending resolution claim already exists')
            || error.message?.includes('already confirmed')
            || error.message?.includes('already disputed')) {
            return res.status(409).json({ error: error.message });
        }
        const userErrors = [
            'Cannot claim resolution for',
            'Invalid outcome',
            'Only callouts or dares can be marked as ducked',
            'Cannot submit proof',
            'Deadline has passed',
            'Media URL and key',
            'Invalid media URL',
            'Caption too long'
        ];
        const isUserError = userErrors.some(msg => error.message?.includes(msg));
        if (isUserError) {
            return res.status(400).json({ error: error.message });
        }
        res.status(500).json({
            error: 'Failed to claim resolution',
            message: error.message
        });
    }
});
/**
 * @route   POST /api/bets/:betId/confirm-resolution
 * @desc    Confirm pending resolution claim
 * @access  Private (JWT required)
 */
router.post('/:betId/confirm-resolution', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { betId } = req.params;
        const result = await (0, betService_1.confirmBetResolution)({ betId, userId });
        res.json({
            success: true,
            claim: {
                claimId: result.claim.claimId,
                betId: result.claim.betId,
                proofId: result.claim.proofId,
                proposedOutcome: result.claim.proposedOutcome,
                proposedBy: result.claim.proposedBy,
                reviewerIds: result.claim.reviewerIds,
                confirmedBy: result.claim.confirmedBy,
                disputedBy: result.claim.disputedBy,
                status: result.claim.status,
                notes: result.claim.notes,
                autoConfirmAt: result.claim.autoConfirmAt,
                finalizedAt: result.claim.finalizedAt,
                createdAt: result.claim.createdAt,
                updatedAt: result.claim.updatedAt,
            },
            resolution: result.resolution ? {
                resolutionId: result.resolution.resolutionId,
                betId: result.resolution.betId,
                outcome: result.resolution.outcome,
                resolvedBy: result.resolution.resolvedBy,
                resolvedAt: result.resolution.resolvedAt,
                notes: result.resolution.notes,
            } : null,
            message: result.resolution
                ? 'All reviewers confirmed. Bet resolved successfully.'
                : 'Confirmation recorded. Waiting on remaining reviewers.'
        });
    }
    catch (error) {
        console.error('Confirm resolution error:', error);
        if (error.message?.includes('No pending resolution claim found')) {
            return res.status(404).json({ error: error.message });
        }
        if (error.message?.includes('not allowed to confirm')) {
            return res.status(403).json({ error: error.message });
        }
        if (error.message?.includes('already confirmed')
            || error.message?.includes('already disputed')
            || error.message?.includes('no longer pending')) {
            return res.status(409).json({ error: error.message });
        }
        res.status(500).json({
            error: 'Failed to confirm resolution claim',
            message: error.message
        });
    }
});
/**
 * @route   POST /api/bets/:betId/dispute-resolution
 * @desc    Dispute pending resolution claim and reopen bet
 * @access  Private (JWT required)
 */
router.post('/:betId/dispute-resolution', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { betId } = req.params;
        const { notes } = req.body;
        const claim = await (0, betService_1.disputeBetResolution)({ betId, userId, notes });
        res.json({
            success: true,
            claim: {
                claimId: claim.claimId,
                betId: claim.betId,
                proofId: claim.proofId,
                proposedOutcome: claim.proposedOutcome,
                proposedBy: claim.proposedBy,
                reviewerIds: claim.reviewerIds,
                confirmedBy: claim.confirmedBy,
                disputedBy: claim.disputedBy,
                status: claim.status,
                notes: claim.notes,
                autoConfirmAt: claim.autoConfirmAt,
                finalizedAt: claim.finalizedAt,
                createdAt: claim.createdAt,
                updatedAt: claim.updatedAt,
            },
            message: 'Resolution claim disputed. Bet has been reopened.'
        });
    }
    catch (error) {
        console.error('Dispute resolution error:', error);
        if (error.message?.includes('No pending resolution claim found')) {
            return res.status(404).json({ error: error.message });
        }
        if (error.message?.includes('not allowed to dispute')) {
            return res.status(403).json({ error: error.message });
        }
        if (error.message?.includes('already confirmed')
            || error.message?.includes('already disputed')
            || error.message?.includes('no longer pending')) {
            return res.status(409).json({ error: error.message });
        }
        res.status(500).json({
            error: 'Failed to dispute resolution claim',
            message: error.message
        });
    }
});
/**
 * @route   POST /api/bets/:betId/resolve
 * @desc    Resolve a bet and distribute payouts
 * @access  Private (JWT required)
 */
router.post('/:betId/resolve', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { betId } = req.params;
        const { outcome, notes } = req.body;
        const bet = await (0, betService_1.getBetById)(betId);
        if (!bet) {
            return res.status(404).json({ error: 'Bet not found' });
        }
        // Validate required fields
        if (!outcome) {
            return res.status(400).json({
                error: 'Missing required field: outcome',
                allowed: ['yes', 'no', 'expired', 'ducked']
            });
        }
        // Validate outcome enum
        const validOutcomes = ['yes', 'no', 'expired', 'ducked'];
        if (!validOutcomes.includes(outcome)) {
            return res.status(400).json({
                error: 'Invalid outcome',
                allowed: validOutcomes,
                received: outcome
            });
        }
        if (bet.resolutionType === 'proof') {
            return res.status(400).json({
                error: 'Proof-based bets resolve through proof validation, not manual declaration'
            });
        }
        if (bet.resolutionType === 'consensus') {
            return res.status(400).json({
                error: 'Consensus bets must be resolved via voting',
                endpoint: `POST /api/bets/${betId}/vote`
            });
        }
        if (bet.resolutionType === 'observable') {
            if (userId !== bet.creatorId) {
                return res.status(403).json({
                    error: 'Only the bet creator can declare observable outcomes'
                });
            }
            if (outcome !== 'yes' && outcome !== 'no') {
                return res.status(400).json({
                    error: 'Observable bets must resolve to yes or no'
                });
            }
            const updatedBet = await (0, betService_1.declareObservableOutcome)({
                betId,
                creatorId: userId,
                outcome,
            });
            return res.status(202).json({
                success: true,
                bet: {
                    betId: updatedBet.betId,
                    status: updatedBet.status,
                    resolutionType: updatedBet.resolutionType,
                    disputeDeadline: updatedBet.deadline,
                    declaredOutcome: updatedBet.observableDeclaredOutcome,
                    declaredAt: updatedBet.observableDeclaredAt,
                },
                message: 'Observable outcome declared. Stakers can dispute for 30 minutes.'
            });
        }
        // Resolve bet
        const resolution = await (0, betService_1.resolveBet)({
            betId,
            resolvedBy: userId,
            outcome,
            notes,
            allowedStatuses: ['active', 'resolving'],
        });
        // Get final bet state
        const updatedBet = await (0, betService_1.getBetById)(betId);
        const totals = await (0, betService_1.getBetTotals)(betId);
        res.json({
            success: true,
            resolution: {
                resolutionId: resolution.resolutionId,
                betId: resolution.betId,
                outcome: resolution.outcome,
                resolvedBy: resolution.resolvedBy,
                resolvedAt: resolution.resolvedAt,
                notes: resolution.notes,
            },
            bet: {
                status: updatedBet?.status,
                finalPot: totals.totalPot,
            },
            message: outcome === 'yes' ? 'Bet completed successfully! Winners have been paid.' :
                outcome === 'no' ? 'Bet failed. Losers have been charged.' :
                    outcome === 'expired' ? 'Bet expired. All participants refunded.' :
                        'Callout ducked. All participants refunded.'
        });
    }
    catch (error) {
        console.error('Bet resolution error:', error);
        if (error.message === 'Bet not found') {
            return res.status(404).json({ error: error.message });
        }
        if (error.message?.includes('Only the bet creator or target')) {
            return res.status(403).json({ error: error.message });
        }
        const userErrors = [
            'already',
            'Invalid outcome',
            'Only callouts or dares can be marked as ducked',
            'Consensus bets must be resolved via voting',
            'Observable bets must resolve to yes or no',
            'Proof-based bets resolve through proof validation',
            'Only observable bets can use creator declaration',
            'Observable declaration only allowed while resolving',
            'already pending confirmation',
        ];
        const isUserError = userErrors.some(msg => error.message?.includes(msg));
        if (isUserError) {
            return res.status(400).json({ error: error.message });
        }
        res.status(500).json({
            error: 'Failed to resolve bet',
            message: error.message
        });
    }
});
/**
 * @route   GET /api/bets/:betId/resolution
 * @desc    Get rich resolution payload for iMessage result bubble
 * @access  Optional auth
 */
router.get('/:betId/resolution', async (req, res) => {
    try {
        const { betId } = req.params;
        const resolution = await (0, betService_1.getBetResolutionPayload)(betId);
        res.json(resolution);
    }
    catch (error) {
        console.error('Resolution fetch error:', error);
        if (error.message === 'Bet not found') {
            return res.status(404).json({ error: error.message });
        }
        if (error.message?.includes('has not been resolved')) {
            return res.status(409).json({ error: error.message });
        }
        res.status(500).json({
            error: 'Failed to fetch resolution',
            message: error.message
        });
    }
});
/**
 * @route   POST /api/bets/auto-expire
 * @desc    System endpoint to auto-expire old bets
 * @access  Private (JWT required)
 */
router.post('/auto-expire', auth_1.authMiddleware, async (req, res) => {
    try {
        const { expiredCount, autoConfirmedCount } = await (0, betService_1.autoExpireBets)();
        res.json({
            success: true,
            expiredCount,
            autoConfirmedCount,
            message: `Auto-expired ${expiredCount} bet(s) and auto-confirmed ${autoConfirmedCount} claim(s)`
        });
    }
    catch (error) {
        console.error('Auto-expire error:', error);
        res.status(500).json({
            error: 'Failed to auto-expire bets',
            message: error.message
        });
    }
});
exports.default = router;
//# sourceMappingURL=bet.js.map