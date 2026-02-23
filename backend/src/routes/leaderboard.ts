import express, { Request, Response, Router } from 'express';
import { authMiddleware } from '../middleware/auth';
import ChatMember from '../models/ChatMember';
import User from '../models/User';

const router: Router = express.Router();

function calculateWinRate(wins: number, losses: number): number {
  const total = wins + losses;
  if (total <= 0) return 0;
  return Math.round((wins / total) * 100);
}

/**
 * @route   GET /api/leaderboard
 * @desc    Aura leaderboard scoped to a chat or all chats the user is in
 * @access  Private (JWT required)
 */
router.get('/', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const chatId = typeof req.query.chatId === 'string' ? req.query.chatId : undefined;

    let scopedUserIds: string[] = [];

    if (chatId) {
      const requesterMembership = await ChatMember.findOne({ chatId, userId });
      if (!requesterMembership) {
        return res.status(403).json({ error: 'You are not a member of this chat' });
      }

      const chatMembers = await ChatMember.find({ chatId }).select('userId');
      scopedUserIds = chatMembers.map(member => member.userId);
    } else {
      const memberships = await ChatMember.find({ userId }).select('chatId');
      const chatIds = [...new Set(memberships.map(member => member.chatId))];

      if (chatIds.length === 0) {
        return res.json({ leaderboard: [], count: 0 });
      }

      const allMembers = await ChatMember.find({ chatId: { $in: chatIds } }).select('userId');
      scopedUserIds = allMembers.map(member => member.userId);
    }

    const uniqueUserIds = [...new Set(scopedUserIds)];
    if (uniqueUserIds.length === 0) {
      return res.json({ leaderboard: [], count: 0 });
    }

    const users = await User.find({ _id: { $in: uniqueUserIds } })
      .select('_id firstName lastName auraBalance wins losses ducks betsCompleted betsFailed calloutsIgnored winRate vibeScore')
      .sort({ auraBalance: -1 })
      .limit(50);

    const leaderboard = users
      .map((user) => {
        const wins = user.wins ?? user.betsCompleted ?? 0;
        const losses = user.losses ?? user.betsFailed ?? 0;
        const ducks = user.ducks ?? user.calloutsIgnored ?? 0;
        const displayName = `${user.firstName ?? ''} ${user.lastName ?? ''}`.trim() || 'Unknown';

        return {
          userId: user._id,
          displayName,
          auraBalance: user.auraBalance ?? 0,
          wins,
          losses,
          ducks,
          winRate: user.winRate ?? calculateWinRate(wins, losses),
          vibeScore: user.vibeScore ?? 100,
        };
      })
      .sort((lhs, rhs) => {
        if (rhs.auraBalance !== lhs.auraBalance) {
          return rhs.auraBalance - lhs.auraBalance;
        }
        if (rhs.wins !== lhs.wins) {
          return rhs.wins - lhs.wins;
        }
        return lhs.displayName.localeCompare(rhs.displayName);
      })
      .slice(0, 50)
      .map((entry, index) => ({
        rank: index + 1,
        ...entry,
      }));

    res.json({
      leaderboard,
      count: leaderboard.length,
    });
  } catch (error: any) {
    console.error('Leaderboard error:', error);
    res.status(500).json({
      error: 'Failed to fetch leaderboard',
      message: error.message,
    });
  }
});

export default router;
