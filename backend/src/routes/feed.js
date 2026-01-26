const express = require('express');
const router = express.Router();
const Vibe = require('../models/Vibe');
const User = require('../models/User');
const Chat = require('../models/Chat');

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
 * @returns { vibes: Vibe[], hasMore: boolean }
 */
router.get('/my-feed', async (req, res) => {
  try {
    const { userId, limit = 50, offset = 0 } = req.query;

    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    // Get user's joined chat IDs
    const user = await User.findById(userId);
    if (!user || !user.joinedChatIds || user.joinedChatIds.length === 0) {
      return res.json({ vibes: [], hasMore: false });
    }

    const chatIds = user.joinedChatIds;

    // Query vibes from all joined chats that haven't expired from feed
    const vibes = await Vibe.find({
      chatId: { $in: chatIds },
      expiresAt: { $gt: new Date() },
    })
      .sort({ createdAt: -1 })
      .skip(parseInt(offset))
      .limit(parseInt(limit) + 1); // +1 to check if there are more

    const hasMore = vibes.length > parseInt(limit);
    const resultVibes = hasMore ? vibes.slice(0, -1) : vibes;

    // Process vibes for lock status
    const processedVibes = await Promise.all(resultVibes.map(async (vibe) => {
      const vibeObj = vibe.toObject();

      // Check if user has posted in this chat (for unlock logic)
      if (vibe.isLocked && vibe.userId !== userId) {
        const userHasPosted = await Vibe.exists({
          chatId: vibe.chatId,
          userId: userId,
          expiresAt: { $gt: new Date() },
        });

        if (!userHasPosted && !vibe.unlockedBy.includes(userId)) {
          vibeObj.isBlurred = true;
          delete vibeObj.mediaUrl;
          delete vibeObj.songData;
          delete vibeObj.mood;
        } else {
          vibeObj.isBlurred = false;
        }
      } else {
        vibeObj.isBlurred = false;
      }

      return vibeObj;
    }));

    res.json({
      vibes: processedVibes,
      hasMore,
    });
  } catch (error) {
    console.error('My feed error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * @route   GET /api/feed/chat/:chatId
 * @desc    Get vibes for a specific chat
 * @returns { vibes: Vibe[] }
 */
router.get('/chat/:chatId', async (req, res) => {
  try {
    const { chatId } = req.params;
    const { userId } = req.query;

    const vibes = await Vibe.find({
      chatId,
      expiresAt: { $gt: new Date() },
    }).sort({ createdAt: -1 });

    // Process for lock status
    const processedVibes = vibes.map((vibe) => {
      const vibeObj = vibe.toObject();

      if (vibe.isLocked && vibe.userId !== userId) {
        const userHasPosted = vibes.some(v => v.userId === userId);
        if (!userHasPosted && !vibe.unlockedBy.includes(userId)) {
          vibeObj.isBlurred = true;
          delete vibeObj.mediaUrl;
          delete vibeObj.songData;
          delete vibeObj.mood;
        }
      }

      return vibeObj;
    });

    res.json(processedVibes);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * @route   GET /api/feed/history
 * @query   { userId, limit? }
 * @desc    Get user's vibe history across all chats (up to 15 days)
 * @returns { vibes: Vibe[] }
 */
router.get('/history', async (req, res) => {
  try {
    const { userId, limit = 50 } = req.query;

    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    // Get vibes created by this user that haven't been permanently deleted
    const vibes = await Vibe.find({
      userId,
      permanentDeleteAt: { $gt: new Date() },
    })
      .sort({ createdAt: -1 })
      .limit(parseInt(limit));

    // Mark which ones are expired from feed but still in history
    const processedVibes = vibes.map((vibe) => {
      const vibeObj = vibe.toObject();
      vibeObj.isExpiredFromFeed = vibe.expiresAt < new Date();
      return vibeObj;
    });

    res.json(processedVibes);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * @route   GET /api/feed/stats
 * @query   { userId }
 * @desc    Get feed stats for a user
 * @returns { totalChats, totalVibes, unviewedCount }
 */
router.get('/stats', async (req, res) => {
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

    // Count active vibes in user's chats
    const totalVibes = await Vibe.countDocuments({
      chatId: { $in: user.joinedChatIds },
      expiresAt: { $gt: new Date() },
    });

    // Count unviewed vibes
    const unviewedCount = await Vibe.countDocuments({
      chatId: { $in: user.joinedChatIds },
      expiresAt: { $gt: new Date() },
      userId: { $ne: userId },
      viewedBy: { $ne: userId },
    });

    res.json({
      totalChats,
      totalVibes,
      unviewedCount,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
