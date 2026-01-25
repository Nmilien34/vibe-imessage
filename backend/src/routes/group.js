const express = require('express');
const router = express.Router();
const Streak = require('../models/Streak');

/**
 * @route   GET /api/group/:chatId/streak
 * @desc    Returns the current streak for a group
 */
router.get('/:chatId/streak', async (req, res) => {
    try {
        const { chatId } = req.params;
        let streak = await Streak.findOne({ conversationId: chatId });

        if (!streak) {
            streak = { conversationId: chatId, currentStreak: 0, longestStreak: 0, lastPostDate: null, todayPosters: [] };
        }

        res.json(streak);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

/**
 * @route   POST /api/group/:chatId/streak
 * @desc    Manually increments/updates the streak for a group
 * @params  userId (in body)
 */
router.post('/:chatId/streak', async (req, res) => {
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
        res.json(streak);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;
