const express = require('express');
const router = express.Router();
const multer = require('multer');
const Vibe = require('../models/Vibe');
const { uploadToS3 } = require('../utils/s3Upload');

// Configure multer for memory storage
const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 50 * 1024 * 1024, // 50MB limit
    },
});

// Retention periods (in days)
const FEED_EXPIRATION_DAYS = 1;      // 24 hours - visible in feed
const HISTORY_RETENTION_DAYS = 15;   // 15 days - viewable in history

/**
 * @route   POST /api/vibe/upload
 * @desc    Upload a video vibe (Multipart)
 * @params  video (file), userId, chatId, isLocked
 * @returns videoId, videoUrl, videoKey
 */
router.post('/upload', upload.single('video'), async (req, res) => {
    try {
        const { userId, chatId, isLocked } = req.body;
        const file = req.file;

        if (!file) {
            return res.status(400).json({ error: 'No video file provided' });
        }

        if (!userId || !chatId) {
            return res.status(400).json({ error: 'userId and chatId are required' });
        }

        // Determine file extension
        const extension = file.originalname.split('.').pop() || 'mp4';

        // Upload to S3
        const { publicUrl, key } = await uploadToS3(file.buffer, extension, 'vibes');

        // Create Vibe record with proper retention dates
        const now = new Date();
        const expiresAt = new Date(now.getTime() + FEED_EXPIRATION_DAYS * 24 * 60 * 60 * 1000);
        const permanentDeleteAt = new Date(now.getTime() + HISTORY_RETENTION_DAYS * 24 * 60 * 60 * 1000);

        const vibe = new Vibe({
            userId,
            conversationId: chatId,
            type: 'video',
            mediaUrl: publicUrl,
            mediaKey: key,
            isLocked: isLocked === 'true' || isLocked === true,
            expiresAt,
            permanentDeleteAt
        });

        await vibe.save();

        res.status(201).json({
            videoId: vibe._id,
            videoUrl: publicUrl,
            videoKey: key
        });
    } catch (error) {
        console.error('Upload error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * @route   GET /api/vibe/:videoId
 * @desc    Returns story metadata and checks lock status
 */
router.get('/:videoId', async (req, res) => {
    try {
        const { videoId } = req.params;
        const { userId } = req.query;

        const vibe = await Vibe.findById(videoId);
        if (!vibe) {
            return res.status(404).json({ error: 'Story not found' });
        }

        const vibeObj = vibe.toObject();

        // Check if user has posted something in this conversation to unlock
        const userHasPosted = await Vibe.exists({
            conversationId: vibe.conversationId,
            userId: userId,
            expiresAt: { $gt: new Date() }
        });

        if (vibe.isLocked && !userHasPosted && vibe.userId !== userId) {
            vibeObj.isLocked = true;
            delete vibeObj.mediaUrl;
            delete vibeObj.songData;
            delete vibeObj.mood;
        } else {
            vibeObj.isLocked = false;
        }

        res.json(vibeObj);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

/**
 * @route   POST /api/vibe/:videoId/unlock
 * @desc    Marks story as unlocked for a user
 */
router.post('/:videoId/unlock', async (req, res) => {
    try {
        const { videoId } = req.params;
        const { userId } = req.body;

        const vibe = await Vibe.findByIdAndUpdate(
            videoId,
            { $addToSet: { unlockedBy: userId } },
            { new: true }
        );

        if (!vibe) {
            return res.status(404).json({ error: 'Story not found' });
        }

        res.json({ success: true, vibe });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

/**
 * @route   GET /api/vibe/feed/:chatId
 * @desc    Returns all active stories for a group
 */
router.get('/feed/:chatId', async (req, res) => {
    try {
        const { chatId } = req.params;

        const vibes = await Vibe.find({
            conversationId: chatId,
            expiresAt: { $gt: new Date() }
        }).sort({ createdAt: -1 });

        res.json(vibes);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;
