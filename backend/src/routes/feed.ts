import express, { Request, Response, Router } from 'express';
import Vibe from '../models/Vibe';
import User from '../models/User';
import {
  IVibe,
  IVibeWithBlur,
  IVibeWithExpiry,
  FeedResponse,
  FeedStatsResponse,
  IUserStory,
  StoriesFeedResponse,
  StoriesByChatResponse,
  IUserDocument
} from '../types';

const router: Router = express.Router();

interface FeedQuery {
  userId?: string;
  limit?: string;
  offset?: string;
}

interface StoriesQuery {
  userId?: string;
  chatIds?: string; // Comma-separated chat IDs
  limit?: string;
}

interface ChatParams {
  chatId: string;
}

/**
 * Helper: Process vibe for blur status
 */
async function processVibeForBlur(
  vibe: any,
  requestingUserId: string,
  userHasPostedInChat?: boolean
): Promise<IVibeWithBlur> {
  const vibeObj = vibe.toObject() as IVibeWithBlur;

  if (vibe.isLocked && vibe.userId !== requestingUserId) {
    // Check if user has posted (use cached value if provided)
    const hasPosted = userHasPostedInChat ?? await Vibe.exists({
      chatId: vibe.chatId,
      userId: requestingUserId,
      expiresAt: { $gt: new Date() },
    });

    if (!hasPosted && !vibe.unlockedBy.includes(requestingUserId)) {
      vibeObj.isBlurred = true;
      delete (vibeObj as any).mediaUrl;
      delete (vibeObj as any).songData;
      delete (vibeObj as any).mood;
    } else {
      vibeObj.isBlurred = false;
    }
  } else {
    vibeObj.isBlurred = false;
  }

  return vibeObj;
}

/**
 * Helper: Group vibes into user stories
 */
async function groupVibesIntoStories(
  vibes: any[],
  requestingUserId: string
): Promise<IUserStory[]> {
  // Group vibes by userId
  const vibesByUser = new Map<string, any[]>();

  for (const vibe of vibes) {
    const existing = vibesByUser.get(vibe.userId) || [];
    existing.push(vibe);
    vibesByUser.set(vibe.userId, existing);
  }

  // Get all unique user IDs
  const userIds = Array.from(vibesByUser.keys());

  // Fetch user info for all users
  const users = await User.find({ _id: { $in: userIds } });
  const userMap = new Map<string, IUserDocument>();
  for (const user of users) {
    userMap.set(user._id, user);
  }

  // Build stories array
  const stories: IUserStory[] = await Promise.all(
    userIds.map(async (oderId) => {
      const userVibes = vibesByUser.get(oderId) || [];
      const user = userMap.get(oderId);

      // Process each vibe for blur status
      const processedVibes = await Promise.all(
        userVibes.map(vibe => processVibeForBlur(vibe, requestingUserId))
      );

      // Sort vibes by createdAt descending
      processedVibes.sort((a, b) =>
        new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
      );

      // Check if any vibes are unviewed
      const hasUnviewed = userVibes.some(
        vibe => vibe.userId !== requestingUserId && !vibe.viewedBy.includes(requestingUserId)
      );

      return {
        userId: oderId,
        userName: user ? `${user.firstName || ''} ${user.lastName || ''}`.trim() || undefined : undefined,
        profilePicture: user?.profilePicture,
        vibes: processedVibes,
        latestVibeAt: new Date(userVibes[0].createdAt),
        hasUnviewed,
      };
    })
  );

  // Sort stories: unviewed first, then by latest vibe time
  stories.sort((a, b) => {
    if (a.hasUnviewed && !b.hasUnviewed) return -1;
    if (!a.hasUnviewed && b.hasUnviewed) return 1;
    return b.latestVibeAt.getTime() - a.latestVibeAt.getTime();
  });

  return stories;
}

/**
 * Feed Routes - The Unified View
 *
 * These endpoints power the "see all vibes from everyone" feed.
 * Instead of showing vibes from one conversation, we aggregate
 * vibes from ALL chats the user is a member of.
 */

/**
 * @route   GET /api/feed/my-feed
 * @query   { userId, limit?, offset? }
 * @desc    Get unified feed - all vibes from all chats user belongs to
 */
router.get('/my-feed', async (req: Request<{}, {}, {}, FeedQuery>, res: Response) => {
  try {
    const { userId, limit = '50', offset = '0' } = req.query;

    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    const user = await User.findById(userId);
    if (!user || !user.joinedChatIds || user.joinedChatIds.length === 0) {
      return res.json({ vibes: [], hasMore: false });
    }

    const chatIds = user.joinedChatIds;
    const limitNum = parseInt(limit);
    const offsetNum = parseInt(offset);

    const vibes = await Vibe.find({
      chatId: { $in: chatIds },
      expiresAt: { $gt: new Date() },
    })
      .sort({ createdAt: -1 })
      .skip(offsetNum)
      .limit(limitNum + 1);

    const hasMore = vibes.length > limitNum;
    const resultVibes = hasMore ? vibes.slice(0, -1) : vibes;

    const processedVibes: IVibeWithBlur[] = await Promise.all(
      resultVibes.map(vibe => processVibeForBlur(vibe, userId))
    );

    const response: FeedResponse = {
      vibes: processedVibes,
      hasMore,
    };

    res.json(response);
  } catch (error) {
    console.error('My feed error:', error);
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   GET /api/feed/chat/:chatId
 * @desc    Get vibes for a specific chat
 */
router.get('/chat/:chatId', async (req: Request<ChatParams, {}, {}, { userId?: string }>, res: Response) => {
  try {
    const { chatId } = req.params;
    const { userId } = req.query;

    const vibes = await Vibe.find({
      chatId,
      expiresAt: { $gt: new Date() },
    }).sort({ createdAt: -1 });

    // Check if requesting user has posted in this chat (for unlock logic)
    const userHasPosted = userId ? vibes.some(v => v.userId === userId) : false;

    const processedVibes: IVibeWithBlur[] = await Promise.all(
      vibes.map(vibe => processVibeForBlur(vibe, userId || '', userHasPosted))
    );

    res.json(processedVibes);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   GET /api/feed/history
 * @query   { userId, limit? }
 * @desc    Get user's vibe history across all chats (up to 15 days)
 */
router.get('/history', async (req: Request<{}, {}, {}, FeedQuery>, res: Response) => {
  try {
    const { userId, limit = '50' } = req.query;

    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    const vibes = await Vibe.find({
      userId,
      permanentDeleteAt: { $gt: new Date() },
    })
      .sort({ createdAt: -1 })
      .limit(parseInt(limit));

    const processedVibes: IVibeWithExpiry[] = vibes.map((vibe) => {
      const vibeObj = vibe.toObject() as IVibeWithExpiry;
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
 * @route   GET /api/feed/stats
 * @query   { userId }
 * @desc    Get feed stats for a user
 */
router.get('/stats', async (req: Request<{}, {}, {}, { userId?: string }>, res: Response) => {
  try {
    const { userId } = req.query;

    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.json({ totalChats: 0, totalVibes: 0, unviewedCount: 0 });
    }

    const totalChats = user.joinedChatIds.length;

    const totalVibes = await Vibe.countDocuments({
      chatId: { $in: user.joinedChatIds },
      expiresAt: { $gt: new Date() },
    });

    const unviewedCount = await Vibe.countDocuments({
      chatId: { $in: user.joinedChatIds },
      expiresAt: { $gt: new Date() },
      userId: { $ne: userId },
      viewedBy: { $ne: userId },
    });

    const stats: FeedStatsResponse = {
      totalChats,
      totalVibes,
      unviewedCount,
    };

    res.json(stats);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   GET /api/feed/stories
 * @query   { userId, chatIds?, limit? }
 * @desc    Get vibes grouped by user as stories (for story ring UI)
 *          chatIds can be comma-separated list to filter specific chats
 */
router.get('/stories', async (req: Request<{}, {}, {}, StoriesQuery>, res: Response) => {
  try {
    const { userId, chatIds, limit = '50' } = req.query;

    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    let targetChatIds: string[];

    if (chatIds) {
      // Use provided chat IDs (comma-separated)
      targetChatIds = chatIds.split(',').map(id => id.trim()).filter(Boolean);
    } else {
      // Get all user's joined chats
      const user = await User.findById(userId);
      if (!user || !user.joinedChatIds || user.joinedChatIds.length === 0) {
        const emptyResponse: StoriesFeedResponse = { stories: [], hasMore: false };
        return res.json(emptyResponse);
      }
      targetChatIds = user.joinedChatIds;
    }

    const limitNum = parseInt(limit);

    // Fetch all non-expired vibes from target chats
    const vibes = await Vibe.find({
      chatId: { $in: targetChatIds },
      expiresAt: { $gt: new Date() },
    })
      .sort({ createdAt: -1 })
      .limit(limitNum);

    // Group into stories
    const stories = await groupVibesIntoStories(vibes, userId);

    const response: StoriesFeedResponse = {
      stories,
      hasMore: vibes.length >= limitNum,
    };

    res.json(response);
  } catch (error) {
    console.error('Stories feed error:', error);
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   GET /api/feed/stories/:chatId
 * @query   { userId }
 * @desc    Get stories for a specific chat, grouped by user
 */
router.get('/stories/:chatId', async (req: Request<ChatParams, {}, {}, { userId?: string }>, res: Response) => {
  try {
    const { chatId } = req.params;
    const { userId } = req.query;

    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    // Fetch all non-expired vibes from this chat
    const vibes = await Vibe.find({
      chatId,
      expiresAt: { $gt: new Date() },
    }).sort({ createdAt: -1 });

    // Group into stories
    const stories = await groupVibesIntoStories(vibes, userId);

    const response: StoriesByChatResponse = {
      chatId,
      stories,
    };

    res.json(response);
  } catch (error) {
    console.error('Stories by chat error:', error);
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   GET /api/feed/user/:oderId/vibes
 * @query   { userId, chatId? }
 * @desc    Get all vibes from a specific user (for viewing their story)
 */
router.get('/user/:oderId/vibes', async (req: Request<{ oderId: string }, {}, {}, { userId?: string; chatId?: string }>, res: Response) => {
  try {
    const { oderId } = req.params;
    const { userId, chatId } = req.query;

    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    // Build query
    const query: any = {
      userId: oderId,
      expiresAt: { $gt: new Date() },
    };

    // Optionally filter by chat
    if (chatId) {
      query.chatId = chatId;
    }

    const vibes = await Vibe.find(query).sort({ createdAt: -1 });

    // Process for blur status
    const processedVibes: IVibeWithBlur[] = await Promise.all(
      vibes.map(vibe => processVibeForBlur(vibe, userId))
    );

    // Get user info
    const vibeOwner = await User.findById(oderId);

    res.json({
      userId: oderId,
      userName: vibeOwner ? `${vibeOwner.firstName || ''} ${vibeOwner.lastName || ''}`.trim() || undefined : undefined,
      profilePicture: vibeOwner?.profilePicture,
      vibes: processedVibes,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

export default router;
