import express, { Request, Response, Router } from 'express';
import Streak from '../models/Streak';

const router: Router = express.Router();

interface StreakParams {
  chatId: string;
}

interface StreakUpdateRequest {
  userId: string;
}

/**
 * @route   GET /api/group/:chatId/streak
 * @desc    Returns the current streak for a group
 */
router.get('/:chatId/streak', async (req: Request<StreakParams>, res: Response) => {
  try {
    const { chatId } = req.params;
    let streak = await Streak.findOne({ conversationId: chatId });

    if (!streak) {
      return res.json({
        conversationId: chatId,
        currentStreak: 0,
        longestStreak: 0,
        lastPostDate: null,
        todayPosters: [],
      });
    }

    res.json(streak);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   POST /api/group/:chatId/streak
 * @desc    Manually increments/updates the streak for a group
 */
router.post('/:chatId/streak', async (req: Request<StreakParams, {}, StreakUpdateRequest>, res: Response) => {
  try {
    const { chatId } = req.params;
    const { userId } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    let streak = await Streak.findOne({ conversationId: chatId });

    if (!streak) {
      streak = new Streak({ conversationId: chatId });
    }

    const lastPost = streak.lastPostDate ? new Date(streak.lastPostDate) : null;
    if (lastPost) {
      lastPost.setHours(0, 0, 0, 0);
    }

    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    if (!lastPost || lastPost.getTime() < today.getTime()) {
      if (lastPost && lastPost.getTime() === yesterday.getTime()) {
        streak.currentStreak += 1;
      } else if (!lastPost || lastPost.getTime() < yesterday.getTime()) {
        streak.currentStreak = 1;
      }

      streak.lastPostDate = new Date();
      streak.todayPosters = [userId];

      if (streak.currentStreak > streak.longestStreak) {
        streak.longestStreak = streak.currentStreak;
      }
    } else {
      if (!streak.todayPosters.includes(userId)) {
        streak.todayPosters.push(userId);
      }
    }

    await streak.save();
    res.json(streak);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

export default router;
