const express = require('express');
const router = express.Router();
const Vibe = require('../models/Vibe');
const Streak = require('../models/Streak');

// Get all vibes for a conversation (non-expired)
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

// Create a new vibe
router.post('/', async (req, res) => {
  try {
    const {
      userId,
      conversationId,
      type,
      mediaUrl,
      thumbnailUrl,
      songData,
      batteryLevel,
      mood,
      poll,
      isLocked,
    } = req.body;

    // Set expiration to 24 hours from now
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

    const vibe = new Vibe({
      userId,
      conversationId,
      type,
      mediaUrl,
      thumbnailUrl,
      songData,
      batteryLevel,
      mood,
      poll,
      isLocked: isLocked || false,
      expiresAt,
    });

    await vibe.save();

    // Update streak
    await updateStreak(conversationId, userId);

    res.status(201).json(vibe);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

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
