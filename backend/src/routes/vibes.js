const express = require('express');
const router = express.Router();
const Vibe = require('../models/Vibe');
const Streak = require('../models/Streak');

// Retention periods (in days)
const FEED_EXPIRATION_DAYS = 1;      // 24 hours - visible in feed
const HISTORY_RETENTION_DAYS = 15;   // 15 days - viewable in history

// Get all vibes for a conversation (non-expired - main feed)
router.get('/:conversationId', async (req, res) => {
  try {
    const { conversationId } = req.params;
    const { userId } = req.query;

    const vibes = await Vibe.find({
      conversationId,
      expiresAt: { $gt: new Date() },
    }).sort({ createdAt: -1 });

    // Process vibes - blur locked ones if user hasn't posted
    const userHasPosted = vibes.some(v => v.userId === userId);

    const processedVibes = vibes.map(vibe => {
      const vibeObj = vibe.toObject();

      // If locked and user hasn't posted (and isn't the author)
      if (vibe.isLocked && !userHasPosted && vibe.userId !== userId) {
        vibeObj.isBlurred = true;
        // Hide sensitive content
        delete vibeObj.mediaUrl;
        delete vibeObj.songData;
        delete vibeObj.mood;
      } else {
        vibeObj.isBlurred = false;
      }

      return vibeObj;
    });

    res.json(processedVibes);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get vibe history for a user (up to 15 days)
router.get('/:conversationId/history', async (req, res) => {
  try {
    const { conversationId } = req.params;
    const { userId, limit = 50 } = req.query;

    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    // Get vibes that haven't been permanently deleted yet (up to 15 days old)
    const vibes = await Vibe.find({
      conversationId,
      userId,
      permanentDeleteAt: { $gt: new Date() },
    })
      .sort({ createdAt: -1 })
      .limit(parseInt(limit));

    // Mark expired vibes (past 24h) but still in history
    const processedVibes = vibes.map(vibe => {
      const vibeObj = vibe.toObject();
      vibeObj.isExpiredFromFeed = vibe.expiresAt < new Date();
      return vibeObj;
    });

    res.json(processedVibes);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Create a new vibe
router.post('/', async (req, res) => {
  try {
    const {
      userId,
      chatId,         // New: Our virtual chat ID
      conversationId, // Legacy: iMessage conversation ID
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

    // Use chatId if provided, fall back to conversationId for legacy support
    const effectiveChatId = chatId || conversationId;

    if (!effectiveChatId) {
      return res.status(400).json({ error: 'chatId or conversationId is required' });
    }

    const now = new Date();
    // Feed expiration: 24 hours
    const expiresAt = new Date(now.getTime() + FEED_EXPIRATION_DAYS * 24 * 60 * 60 * 1000);
    // Permanent deletion: 15 days
    const permanentDeleteAt = new Date(now.getTime() + HISTORY_RETENTION_DAYS * 24 * 60 * 60 * 1000);

    const vibe = new Vibe({
      userId,
      chatId: effectiveChatId,
      conversationId, // Keep for backwards compatibility
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

    // Ensure user is in this chat (for unified feed)
    const User = require('../models/User');
    let user = await User.findById(userId);
    if (user) {
      await user.joinChat(effectiveChatId);
    }

    // Update the chat's lastVibeId
    const Chat = require('../models/Chat');
    const chat = await Chat.findById(effectiveChatId);
    if (chat) {
      await chat.touch(vibe._id.toString());
    }

    // Update streak
    await updateStreak(effectiveChatId, userId);

    res.status(201).json(vibe);
  } catch (error) {
    console.error('Create vibe error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Helper to extract S3 key from URL
function extractS3Key(url) {
  if (!url) return null;
  try {
    const urlObj = new URL(url);
    return urlObj.pathname.substring(1); // Remove leading slash
  } catch {
    return null;
  }
}

// Add reaction to a vibe
router.post('/:vibeId/react', async (req, res) => {
  try {
    const { vibeId } = req.params;
    const { userId, emoji } = req.body;

    const vibe = await Vibe.findById(vibeId);
    if (!vibe) {
      return res.status(404).json({ error: 'Vibe not found' });
    }

    // Remove existing reaction from this user
    vibe.reactions = vibe.reactions.filter(r => r.userId !== userId);

    // Add new reaction
    vibe.reactions.push({ userId, emoji });
    await vibe.save();

    res.json(vibe);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Mark vibe as viewed
router.post('/:vibeId/view', async (req, res) => {
  try {
    const { vibeId } = req.params;
    const { userId } = req.body;

    await Vibe.findByIdAndUpdate(vibeId, {
      $addToSet: { viewedBy: userId },
    });

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Vote on a poll
router.post('/:vibeId/vote', async (req, res) => {
  try {
    const { vibeId } = req.params;
    const { userId, optionIndex } = req.body;

    const vibe = await Vibe.findById(vibeId);
    if (!vibe || vibe.type !== 'poll') {
      return res.status(404).json({ error: 'Poll not found' });
    }

    // Remove existing vote from this user
    vibe.poll.votes = vibe.poll.votes.filter(v => v.userId !== userId);

    // Add new vote
    vibe.poll.votes.push({ userId, optionIndex });
    await vibe.save();

    res.json(vibe);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get streak for a conversation
router.get('/:conversationId/streak', async (req, res) => {
  try {
    const { conversationId } = req.params;

    let streak = await Streak.findOne({ conversationId });
    if (!streak) {
      streak = { currentStreak: 0, longestStreak: 0 };
    }

    res.json(streak);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Helper: Update streak when someone posts
async function updateStreak(conversationId, userId) {
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

  // Check if this is a new day
  if (!lastPost || lastPost.getTime() < today.getTime()) {
    // If last post was yesterday, continue streak
    if (lastPost && lastPost.getTime() === yesterday.getTime()) {
      streak.currentStreak += 1;
    } else if (!lastPost || lastPost.getTime() < yesterday.getTime()) {
      // Streak broken, reset to 1
      streak.currentStreak = 1;
    }

    streak.lastPostDate = new Date();
    streak.todayPosters = [userId];

    if (streak.currentStreak > streak.longestStreak) {
      streak.longestStreak = streak.currentStreak;
    }
  } else {
    // Same day, just add user to today's posters
    if (!streak.todayPosters.includes(userId)) {
      streak.todayPosters.push(userId);
    }
  }

  await streak.save();
}

module.exports = router;
