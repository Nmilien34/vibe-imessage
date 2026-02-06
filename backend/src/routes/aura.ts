import express, { Request, Response, Router } from 'express';
import { authMiddleware } from '../middleware/auth';
import {
  getAuraStats,
  getTransactionHistory,
  processLoginUpdates,
  calculateWinRate,
  calculateDuckRate
} from '../services/auraService';
import User from '../models/User';

const router: Router = express.Router();

/**
 * @route   GET /api/aura/stats
 * @desc    Get user's Aura stats
 * @access  Private (JWT required)
 */
router.get('/stats', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const stats = await getAuraStats(userId);

    res.json({
      success: true,
      stats
    });

  } catch (error: any) {
    console.error('Aura stats error:', error);

    if (error.message === 'User not found') {
      return res.status(404).json({ error: error.message });
    }

    res.status(500).json({
      error: 'Failed to get Aura stats',
      message: error.message
    });
  }
});

/**
 * @route   GET /api/aura/transactions
 * @desc    Get user's transaction history
 * @access  Private (JWT required)
 */
router.get('/transactions', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { limit } = req.query;

    let parsedLimit = 20;
    if (limit) {
      parsedLimit = parseInt(limit as string, 10);
      if (isNaN(parsedLimit) || parsedLimit < 1) parsedLimit = 20;
      if (parsedLimit > 100) parsedLimit = 100;
    }

    const transactions = await getTransactionHistory(userId, parsedLimit);

    res.json({
      transactions: transactions.map(t => ({
        transactionId: t.transactionId,
        amount: t.amount,
        balanceAfter: t.balanceAfter,
        type: t.transactionType,
        description: t.description,
        referenceId: t.referenceId,
        createdAt: t.createdAt
      })),
      count: transactions.length
    });

  } catch (error: any) {
    console.error('Transaction history error:', error);
    res.status(500).json({
      error: 'Failed to get transaction history',
      message: error.message
    });
  }
});

/**
 * @route   POST /api/aura/claim-daily
 * @desc    Claim daily bonus (also happens on login)
 * @access  Private (JWT required)
 */
router.post('/claim-daily', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const result = await processLoginUpdates(userId);

    if (result.dailyBonusClaimed) {
      res.json({
        success: true,
        claimed: true,
        amount: 50,
        newBalance: result.auraBalance,
        message: 'Daily bonus claimed! +50 Aura'
      });
    } else {
      res.json({
        success: true,
        claimed: false,
        amount: 0,
        currentBalance: result.auraBalance,
        message: 'Daily bonus already claimed. Come back tomorrow!'
      });
    }

  } catch (error: any) {
    console.error('Daily bonus claim error:', error);
    res.status(500).json({
      error: 'Failed to claim daily bonus',
      message: error.message
    });
  }
});

/**
 * @route   GET /api/aura/leaderboard
 * @desc    Get Aura leaderboard
 * @access  Private (JWT required)
 */
router.get('/leaderboard', authMiddleware, async (req: Request, res: Response) => {
  try {
    const { limit, sortBy } = req.query;

    let parsedLimit = 20;
    if (limit) {
      parsedLimit = parseInt(limit as string, 10);
      if (isNaN(parsedLimit) || parsedLimit < 1) parsedLimit = 20;
      if (parsedLimit > 100) parsedLimit = 100;
    }

    // Determine sort field
    let sortField: any = { auraBalance: -1 };
    if (sortBy === 'vibeScore') {
      sortField = { vibeScore: -1 };
    } else if (sortBy === 'lifetimeEarned') {
      sortField = { lifetimeAuraEarned: -1 };
    }

    const users = await User.find({})
      .select('firstName lastName profilePicture auraBalance vibeScore betsCreated betsCompleted betsFailed calloutsIgnored')
      .sort(sortField)
      .limit(parsedLimit);

    const leaderboard = users.map((u, index) => ({
      rank: index + 1,
      id: u._id,
      name: `${u.firstName || ''} ${u.lastName || ''}`.trim() || 'Anonymous',
      profilePicture: u.profilePicture,
      auraBalance: u.auraBalance ?? 0,
      vibeScore: u.vibeScore ?? 100,
      winRate: calculateWinRate(u.betsCompleted ?? 0, u.betsCreated ?? 0),
      duckRate: calculateDuckRate(u.calloutsIgnored ?? 0, (u as any).calloutsReceived ?? 0)
    }));

    res.json({
      leaderboard,
      count: leaderboard.length
    });

  } catch (error: any) {
    console.error('Leaderboard error:', error);
    res.status(500).json({
      error: 'Failed to get leaderboard',
      message: error.message
    });
  }
});

export default router;
