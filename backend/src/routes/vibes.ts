import express, { Request, Response, Router } from 'express';
import Vibe, { FEED_EXPIRATION_DAYS, HISTORY_RETENTION_DAYS } from '../models/Vibe';
import Streak from '../models/Streak';
import User from '../models/User';
import Chat from '../models/Chat';
import { VibeType, IVibe, ISongData, IMood, IParlay } from '../types';

const router: Router = express.Router();

interface VibeQueryParams {
  conversationId: string;
}

interface CreateVibeRequest {
  userId: string;
  chatId?: string;
  conversationId?: string;
  type: VibeType;
  mediaUrl?: string;
  mediaKey?: string;
  thumbnailUrl?: string;
  thumbnailKey?: string;
  songData?: ISongData;
  batteryLevel?: number;
  mood?: IMood;
  poll?: {
    question: string;
    options: string[];
    votes?: { userId: string; optionIndex: number }[];
  };
  parlay?: IParlay;
  textStatus?: string;
  styleName?: string;
  etaStatus?: string;
  oderId?: string;
  isLocked?: boolean;
}

interface ReactRequest {
  userId: string;
  emoji: string;
}

interface ViewRequest {
  userId: string;
}

interface VoteRequest {
  userId: string;
  optionIndex: number;
}

// Helper to extract S3 key from URL
function extractS3Key(url?: string): string | null {
  if (!url) return null;
  try {
    const urlObj = new URL(url);
    return urlObj.pathname.substring(1);
  } catch {
    return null;
  }
}

// Helper: Update streak when someone posts
async function updateStreak(conversationId: string, userId: string): Promise<void> {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  let streak = await Streak.findOne({ conversationId });

  if (!streak) {
    streak = new Streak({ conversationId });
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
}

/**
 * @route   GET /api/vibes/:conversationId
 * @desc    Get all vibes for a conversation (non-expired - main feed)
 */
router.get('/:conversationId', async (req: Request<VibeQueryParams>, res: Response) => {
  try {
    const { conversationId } = req.params;
    const userId = req.query.userId as string;

    const vibes = await Vibe.find({
      conversationId,
      expiresAt: { $gt: new Date() },
    }).sort({ createdAt: -1 });

    const userHasPosted = vibes.some(v => v.userId === userId);

    const processedVibes = vibes.map(vibe => {
      const vibeObj = vibe.toObject() as IVibe & { isBlurred?: boolean };

      if (vibe.isLocked && !userHasPosted && vibe.userId !== userId) {
        vibeObj.isBlurred = true;
        delete (vibeObj as any).mediaUrl;
        delete (vibeObj as any).songData;
        delete (vibeObj as any).mood;
      } else {
        vibeObj.isBlurred = false;
      }

      return vibeObj;
    });

    res.json(processedVibes);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   GET /api/vibes/:conversationId/history
 * @desc    Get vibe history for a user (up to 15 days)
 */
router.get('/:conversationId/history', async (req: Request<VibeQueryParams>, res: Response) => {
  try {
    const { conversationId } = req.params;
    const userId = req.query.userId as string;
    const limit = parseInt(req.query.limit as string) || 50;

    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    const vibes = await Vibe.find({
      conversationId,
      userId,
      permanentDeleteAt: { $gt: new Date() },
    })
      .sort({ createdAt: -1 })
      .limit(limit);

    const processedVibes = vibes.map(vibe => {
      const vibeObj = vibe.toObject() as IVibe & { isExpiredFromFeed?: boolean };
      vibeObj.isExpiredFromFeed = vibe.expiresAt < new Date();
      return vibeObj;
    });

    res.json(processedVibes);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   POST /api/vibes
 * @desc    Create a new vibe
 */
router.post('/', async (req: Request<{}, {}, CreateVibeRequest>, res: Response) => {
  try {
    const {
      userId,
      chatId,
      conversationId,
      type,
      mediaUrl,
      mediaKey,
      thumbnailUrl,
      thumbnailKey,
      songData,
      batteryLevel,
      mood,
      poll,
      parlay,
      textStatus,
      styleName,
      etaStatus,
      oderId,
      isLocked,
    } = req.body;

    const effectiveChatId = chatId || conversationId;

    if (!effectiveChatId) {
      return res.status(400).json({ error: 'chatId or conversationId is required' });
    }

    const now = new Date();
    const expiresAt = new Date(now.getTime() + FEED_EXPIRATION_DAYS * 24 * 60 * 60 * 1000);
    const permanentDeleteAt = new Date(now.getTime() + HISTORY_RETENTION_DAYS * 24 * 60 * 60 * 1000);

    const vibe = new Vibe({
      userId,
      chatId: effectiveChatId,
      conversationId,
      type,
      mediaUrl,
      mediaKey: mediaKey || extractS3Key(mediaUrl),
      thumbnailUrl,
      thumbnailKey: thumbnailKey || extractS3Key(thumbnailUrl),
      songData,
      batteryLevel,
      mood,
      poll,
      parlay,
      textStatus,
      styleName,
      etaStatus,
      oderId,
      isLocked: isLocked || false,
      expiresAt,
      permanentDeleteAt,
    });

    await vibe.save();

    // Ensure user is in this chat
    const user = await User.findById(userId);
    if (user) {
      await user.joinChat(effectiveChatId);
    }

    // Update the chat's lastVibeId
    const chat = await Chat.findById(effectiveChatId);
    if (chat) {
      await chat.touch(vibe._id.toString());
    }

    // Update streak
    await updateStreak(effectiveChatId, userId);

    res.status(201).json(vibe);
  } catch (error) {
    console.error('Create vibe error:', error);
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   POST /api/vibes/:vibeId/react
 * @desc    Add reaction to a vibe
 */
router.post('/:vibeId/react', async (req: Request<{ vibeId: string }, {}, ReactRequest>, res: Response) => {
  try {
    const { vibeId } = req.params;
    const { userId, emoji } = req.body;

    const vibe = await Vibe.findById(vibeId);
    if (!vibe) {
      return res.status(404).json({ error: 'Vibe not found' });
    }

    vibe.reactions = vibe.reactions.filter(r => r.userId !== userId);
    vibe.reactions.push({ userId, emoji });
    await vibe.save();

    res.json(vibe);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   POST /api/vibes/:vibeId/view
 * @desc    Mark vibe as viewed
 */
router.post('/:vibeId/view', async (req: Request<{ vibeId: string }, {}, ViewRequest>, res: Response) => {
  try {
    const { vibeId } = req.params;
    const { userId } = req.body;

    await Vibe.findByIdAndUpdate(vibeId, {
      $addToSet: { viewedBy: userId },
    });

    res.json({ success: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   POST /api/vibes/:vibeId/vote
 * @desc    Vote on a poll
 */
router.post('/:vibeId/vote', async (req: Request<{ vibeId: string }, {}, VoteRequest>, res: Response) => {
  try {
    const { vibeId } = req.params;
    const { userId, optionIndex } = req.body;

    const vibe = await Vibe.findById(vibeId);
    if (!vibe || vibe.type !== 'poll') {
      return res.status(404).json({ error: 'Poll not found' });
    }

    if (vibe.poll) {
      if (!vibe.poll.votes) {
        vibe.poll.votes = [];
      }
      vibe.poll.votes = vibe.poll.votes.filter(v => v.userId !== userId);
      vibe.poll.votes.push({ userId, optionIndex });
      await vibe.save();
    }

    res.json(vibe);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   GET /api/vibes/:conversationId/streak
 * @desc    Get streak for a conversation
 */
router.get('/:conversationId/streak', async (req: Request<{ conversationId: string }>, res: Response) => {
  try {
    const { conversationId } = req.params;

    let streak = await Streak.findOne({ conversationId });
    if (!streak) {
      return res.json({ currentStreak: 0, longestStreak: 0 });
    }

    res.json(streak);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   POST /api/vibes/:vibeId/parlay/respond
 * @desc    Accept or decline a parlay bet
 */
router.post('/:vibeId/parlay/respond', async (req: Request<{ vibeId: string }>, res: Response) => {
  try {
    const { vibeId } = req.params;
    const { userId, status } = req.body;

    if (!['accepted', 'declined'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status. Must be accepted or declined.' });
    }

    const vibe = await Vibe.findById(vibeId);
    if (!vibe || vibe.type !== 'parlay') {
      return res.status(404).json({ error: 'Parlay not found' });
    }

    if (vibe.parlay) {
      vibe.parlay.status = status;
      vibe.parlay.opponentId = userId;
      // If accepted, we could also update the opponentName if we had it, but for now we just track the ID
      await vibe.save();
    }

    res.json(vibe);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

export default router;
