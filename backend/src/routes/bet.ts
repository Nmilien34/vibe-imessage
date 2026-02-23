import express, { Request, Response, Router } from 'express';
import { authMiddleware } from '../middleware/auth';
import {
  createBet,
  getBetById,
  getBetsByChatId,
  isUserInChat,
  placeBetStake,
  getBetTotals,
  getBetParticipants,
  getUserStake,
  getUserBetStakeTransactions,
  submitBetProof,
  getBetProofs,
  deleteBetProof,
  claimBetResolution,
  getPendingResolutionClaim,
  confirmBetResolution,
  disputeBetResolution,
  resolveBet,
  getBetResolution,
  autoExpireBets,
  getEligibleBetTargets
} from '../services/betService';
import { createConnection } from '../services/feedService';

const router: Router = express.Router();

/**
 * @route   POST /api/bets/create
 * @desc    Create a new bet
 * @access  Private (JWT required)
 */
router.post('/create', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { chatId, betType, description, deadline, targetUserId, initialStake, initialSide } = req.body;

    // Validate required fields
    if (!chatId || !betType || !description || !deadline || initialStake === undefined || !initialSide) {
      return res.status(400).json({
        error: 'Missing required fields',
        required: ['chatId', 'betType', 'description', 'deadline', 'initialStake', 'initialSide']
      });
    }

    // Validate betType enum
    const validBetTypes = ['self', 'callout', 'dare'];
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
    if (typeof initialStake !== 'number' || !Number.isInteger(initialStake) || initialStake < 10) {
      return res.status(400).json({
        error: 'initialStake must be an integer >= 10'
      });
    }

    if (initialSide !== 'yes' && initialSide !== 'no') {
      return res.status(400).json({
        error: 'initialSide must be "yes" or "no"'
      });
    }

    // Call service layer
    const bet = await createBet({
      chatId,
      creatorId: userId,
      betType,
      description,
      deadline: deadlineDate,
      initialStake,
      initialSide,
      targetUserId,
    });

    if ((betType === 'callout' || betType === 'dare')
      && targetUserId
      && typeof targetUserId === 'string'
      && targetUserId !== userId) {
      try {
        await createConnection({
          userId1: userId,
          userId2: targetUserId,
          sourceChatId: chatId,
        });
      } catch (connectionError) {
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
        status: bet.status,
        createdAt: bet.createdAt,
      }
    });

  } catch (error: any) {
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
router.get('/chat/:chatId/eligible-targets', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { chatId } = req.params;

    const targets = await getEligibleBetTargets({ chatId, userId });

    res.json({
      chatId,
      targets: targets.map(target => ({
        id: target.id,
        firstName: target.firstName ?? null,
        lastName: target.lastName ?? null,
        profilePicture: target.profilePicture ?? null,
      })),
    });
  } catch (error: any) {
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
router.post('/:betId/stake', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { betId } = req.params;
    const { side, amount } = req.body;

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

    // Call service layer
    const participant = await placeBetStake({
      betId,
      userId,
      side,
      amount
    });

    res.status(201).json({
      success: true,
      participant: {
        participantId: participant.participantId,
        betId: participant.betId,
        userId: participant.userId,
        side: participant.side,
        amount: participant.amount,
        createdAt: participant.createdAt
      }
    });

  } catch (error: any) {
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
router.get('/:betId/participants', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { betId } = req.params;

    // Verify bet exists
    const bet = await getBetById(betId);
    if (!bet) {
      return res.status(404).json({ error: 'Bet not found' });
    }

    // Verify user has access to this bet
    const canAccess = await isUserInChat(userId, bet.chatId);
    if (!canAccess) {
      return res.status(403).json({
        error: 'You do not have access to this bet'
      });
    }

    // Get participants and totals
    const participants = await getBetParticipants(betId);
    const totals = await getBetTotals(betId);

    res.json({
      participants: participants.map(p => ({
        participantId: p.participantId,
        userId: p.userId,
        side: p.side,
        amount: p.amount,
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

  } catch (error: any) {
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
router.get('/:betId/my-stake', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { betId } = req.params;

    // Verify bet exists
    const bet = await getBetById(betId);
    if (!bet) {
      return res.status(404).json({ error: 'Bet not found' });
    }

    // Verify user has access
    const canAccess = await isUserInChat(userId, bet.chatId);
    if (!canAccess) {
      return res.status(403).json({
        error: 'You do not have access to this bet'
      });
    }

    // Get user's stake
    const stake = await getUserStake(betId, userId);

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
        createdAt: stake.createdAt
      }
    });

  } catch (error: any) {
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
router.get('/:betId/my-stake-transactions', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { betId } = req.params;
    const { limit } = req.query;

    let parsedLimit = 50;
    if (limit) {
      parsedLimit = parseInt(limit as string, 10);
      if (isNaN(parsedLimit) || parsedLimit < 1) parsedLimit = 50;
      if (parsedLimit > 100) parsedLimit = 100;
    }

    const bet = await getBetById(betId);
    if (!bet) {
      return res.status(404).json({ error: 'Bet not found' });
    }

    const canAccess = await isUserInChat(userId, bet.chatId);
    if (!canAccess) {
      return res.status(403).json({
        error: 'You do not have access to this bet'
      });
    }

    const transactions = await getUserBetStakeTransactions({
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

  } catch (error: any) {
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
router.get('/:betId', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { betId } = req.params;

    const bet = await getBetById(betId);

    if (!bet) {
      return res.status(404).json({ error: 'Bet not found' });
    }

    // Verify user is in the chat
    const canAccess = await isUserInChat(userId, bet.chatId);

    if (!canAccess) {
      return res.status(403).json({
        error: 'You do not have access to this bet'
      });
    }

    // Get participants, totals, and user's stake
    const participants = await getBetParticipants(betId);
    const totals = await getBetTotals(betId);
    const userStake = await getUserStake(betId, userId);

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
        status: bet.status,
        createdAt: bet.createdAt,
        updatedAt: bet.updatedAt,
      },
      participants: participants.map(p => ({
        participantId: p.participantId,
        userId: p.userId,
        side: p.side,
        amount: p.amount,
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
        createdAt: userStake.createdAt
      } : null
    });

  } catch (error: any) {
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
router.get('/chat/:chatId', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { chatId } = req.params;
    const { status, limit } = req.query;

    // Verify user is in chat
    const canAccess = await isUserInChat(userId, chatId);

    if (!canAccess) {
      return res.status(403).json({ error: 'You are not in this chat' });
    }

    // Parse limit
    let parsedLimit = 50;
    if (limit) {
      parsedLimit = parseInt(limit as string, 10);
      if (isNaN(parsedLimit) || parsedLimit < 1) parsedLimit = 50;
      if (parsedLimit > 100) parsedLimit = 100;
    }

    // Validate status
    if (status && !['active', 'pending_resolution', 'completed', 'expired', 'ducked'].includes(status as string)) {
      return res.status(400).json({
        error: 'Invalid status',
        allowed: ['active', 'pending_resolution', 'completed', 'expired', 'ducked']
      });
    }

    const bets = await getBetsByChatId(chatId, status as any, parsedLimit);

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
        status: bet.status,
        createdAt: bet.createdAt,
      })),
      count: bets.length
    });

  } catch (error: any) {
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
router.post('/:betId/proof', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
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
    const proof = await submitBetProof({
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

  } catch (error: any) {
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
 * @route   GET /api/bets/:betId/proofs
 * @desc    Get all proofs for a bet
 * @access  Private (JWT required)
 */
router.get('/:betId/proofs', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { betId } = req.params;

    // Verify bet exists
    const bet = await getBetById(betId);
    if (!bet) {
      return res.status(404).json({ error: 'Bet not found' });
    }

    // Verify user has access to this bet
    const canAccess = await isUserInChat(userId, bet.chatId);
    if (!canAccess) {
      return res.status(403).json({
        error: 'You do not have access to this bet'
      });
    }

    // Get all proofs
    const proofs = await getBetProofs(betId);

    res.json({
      proofs: proofs.map(p => ({
        proofId: p.proofId,
        betId: p.betId,
        userId: p.userId,
        user: (p as any).userId, // Populated user data
        mediaType: p.mediaType,
        mediaUrl: p.mediaUrl,
        thumbnailUrl: p.thumbnailUrl,
        caption: p.caption,
        createdAt: p.createdAt
      })),
      count: proofs.length
    });

  } catch (error: any) {
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
router.delete('/proofs/:proofId', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { proofId } = req.params;

    // Call service layer
    await deleteBetProof(proofId, userId);

    res.json({
      success: true,
      message: 'Proof deleted successfully'
    });

  } catch (error: any) {
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
router.get('/:betId/resolution-claim', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { betId } = req.params;

    const bet = await getBetById(betId);
    if (!bet) {
      return res.status(404).json({ error: 'Bet not found' });
    }

    const canAccess = await isUserInChat(userId, bet.chatId);
    if (!canAccess) {
      return res.status(403).json({
        error: 'You do not have access to this bet'
      });
    }

    const claim = await getPendingResolutionClaim(betId);

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
  } catch (error: any) {
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
router.post('/:betId/claim-resolution', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
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

    const result = await claimBetResolution({
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
  } catch (error: any) {
    console.error('Claim resolution error:', error);

    if (error.message === 'Bet not found') {
      return res.status(404).json({ error: error.message });
    }

    if (
      error.message?.includes('Only the bet creator can claim resolution') ||
      error.message?.includes('not allowed to')
    ) {
      return res.status(403).json({ error: error.message });
    }

    if (
      error.message?.includes('pending resolution claim already exists')
      || error.message?.includes('already confirmed')
      || error.message?.includes('already disputed')
    ) {
      return res.status(409).json({ error: error.message });
    }

    const userErrors = [
      'Cannot claim resolution for',
      'Invalid outcome',
      'Only callouts can be marked as ducked',
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
router.post('/:betId/confirm-resolution', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { betId } = req.params;

    const result = await confirmBetResolution({ betId, userId });

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
  } catch (error: any) {
    console.error('Confirm resolution error:', error);

    if (error.message?.includes('No pending resolution claim found')) {
      return res.status(404).json({ error: error.message });
    }

    if (error.message?.includes('not allowed to confirm')) {
      return res.status(403).json({ error: error.message });
    }

    if (
      error.message?.includes('already confirmed')
      || error.message?.includes('already disputed')
      || error.message?.includes('no longer pending')
    ) {
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
router.post('/:betId/dispute-resolution', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { betId } = req.params;
    const { notes } = req.body;

    const claim = await disputeBetResolution({ betId, userId, notes });

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
  } catch (error: any) {
    console.error('Dispute resolution error:', error);

    if (error.message?.includes('No pending resolution claim found')) {
      return res.status(404).json({ error: error.message });
    }

    if (error.message?.includes('not allowed to dispute')) {
      return res.status(403).json({ error: error.message });
    }

    if (
      error.message?.includes('already confirmed')
      || error.message?.includes('already disputed')
      || error.message?.includes('no longer pending')
    ) {
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
router.post('/:betId/resolve', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { betId } = req.params;
    const { outcome, notes } = req.body;

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

    // Resolve bet
    const resolution = await resolveBet({
      betId,
      resolvedBy: userId,
      outcome,
      notes,
    });

    // Get final bet state
    const bet = await getBetById(betId);
    const totals = await getBetTotals(betId);

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
        status: bet?.status,
        finalPot: totals.totalPot,
      },
      message: outcome === 'yes' ? 'Bet completed successfully! Winners have been paid.' :
               outcome === 'no' ? 'Bet failed. Losers have been charged.' :
               outcome === 'expired' ? 'Bet expired. All participants refunded.' :
               'Callout ducked. All participants refunded.'
    });

  } catch (error: any) {
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
      'Only callouts can be marked as ducked',
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
 * @desc    Get resolution details for a bet
 * @access  Private (JWT required)
 */
router.get('/:betId/resolution', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { betId } = req.params;

    // Get bet to check chat membership
    const bet = await getBetById(betId);

    if (!bet) {
      return res.status(404).json({ error: 'Bet not found' });
    }

    // Verify user is in chat
    const canAccess = await isUserInChat(userId, bet.chatId);

    if (!canAccess) {
      return res.status(403).json({
        error: 'You do not have access to this bet'
      });
    }

    // Get resolution (may be null if not resolved yet)
    const resolution = await getBetResolution(betId);

    if (!resolution) {
      return res.json({
        resolution: null,
        message: 'Bet has not been resolved yet'
      });
    }

    res.json({
      resolution: {
        resolutionId: resolution.resolutionId,
        betId: resolution.betId,
        outcome: resolution.outcome,
        resolvedBy: resolution.resolvedBy,
        resolvedAt: resolution.resolvedAt,
        notes: resolution.notes,
      }
    });

  } catch (error: any) {
    console.error('Resolution fetch error:', error);
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
router.post('/auto-expire', authMiddleware, async (req: Request, res: Response) => {
  try {
    const { expiredCount, autoConfirmedCount } = await autoExpireBets();

    res.json({
      success: true,
      expiredCount,
      autoConfirmedCount,
      message: `Auto-expired ${expiredCount} bet(s) and auto-confirmed ${autoConfirmedCount} claim(s)`
    });

  } catch (error: any) {
    console.error('Auto-expire error:', error);
    res.status(500).json({
      error: 'Failed to auto-expire bets',
      message: error.message
    });
  }
});

export default router;
