"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const Vibe_1 = __importStar(require("../models/Vibe"));
const Streak_1 = __importDefault(require("../models/Streak"));
const User_1 = __importDefault(require("../models/User"));
const Chat_1 = __importDefault(require("../models/Chat"));
const router = express_1.default.Router();
// Helper to extract S3 key from URL
function extractS3Key(url) {
    if (!url)
        return null;
    try {
        const urlObj = new URL(url);
        return urlObj.pathname.substring(1);
    }
    catch {
        return null;
    }
}
// Helper: Update streak when someone posts
async function updateStreak(conversationId, userId) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    let streak = await Streak_1.default.findOne({ conversationId });
    if (!streak) {
        streak = new Streak_1.default({ conversationId });
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
        }
        else if (!lastPost || lastPost.getTime() < yesterday.getTime()) {
            streak.currentStreak = 1;
        }
        streak.lastPostDate = new Date();
        streak.todayPosters = [userId];
        if (streak.currentStreak > streak.longestStreak) {
            streak.longestStreak = streak.currentStreak;
        }
    }
    else {
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
router.get('/:conversationId', async (req, res) => {
    try {
        const { conversationId } = req.params;
        const userId = req.query.userId;
        const vibes = await Vibe_1.default.find({
            conversationId,
            expiresAt: { $gt: new Date() },
        }).sort({ createdAt: -1 });
        const userHasPosted = vibes.some(v => v.userId === userId);
        const processedVibes = vibes.map(vibe => {
            const vibeObj = vibe.toObject();
            if (vibe.isLocked && !userHasPosted && vibe.userId !== userId) {
                vibeObj.isBlurred = true;
                delete vibeObj.mediaUrl;
                delete vibeObj.songData;
                delete vibeObj.mood;
            }
            else {
                vibeObj.isBlurred = false;
            }
            return vibeObj;
        });
        res.json(processedVibes);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
/**
 * @route   GET /api/vibes/:conversationId/history
 * @desc    Get vibe history for a user (up to 15 days)
 */
router.get('/:conversationId/history', async (req, res) => {
    try {
        const { conversationId } = req.params;
        const userId = req.query.userId;
        const limit = parseInt(req.query.limit) || 50;
        if (!userId) {
            return res.status(400).json({ error: 'userId is required' });
        }
        const vibes = await Vibe_1.default.find({
            conversationId,
            userId,
            permanentDeleteAt: { $gt: new Date() },
        })
            .sort({ createdAt: -1 })
            .limit(limit);
        const processedVibes = vibes.map(vibe => {
            const vibeObj = vibe.toObject();
            vibeObj.isExpiredFromFeed = vibe.expiresAt < new Date();
            return vibeObj;
        });
        res.json(processedVibes);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
/**
 * @route   POST /api/vibes
 * @desc    Create a new vibe
 */
router.post('/', async (req, res) => {
    try {
        const { userId, chatId, conversationId, type, mediaUrl, mediaKey, thumbnailUrl, thumbnailKey, songData, batteryLevel, mood, poll, parlay, textStatus, styleName, etaStatus, oderId, isLocked, } = req.body;
        const effectiveChatId = chatId || conversationId;
        if (!effectiveChatId) {
            return res.status(400).json({ error: 'chatId or conversationId is required' });
        }
        const now = new Date();
        const expiresAt = new Date(now.getTime() + Vibe_1.FEED_EXPIRATION_DAYS * 24 * 60 * 60 * 1000);
        const permanentDeleteAt = new Date(now.getTime() + Vibe_1.HISTORY_RETENTION_DAYS * 24 * 60 * 60 * 1000);
        const vibe = new Vibe_1.default({
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
        const user = await User_1.default.findById(userId);
        if (user) {
            await user.joinChat(effectiveChatId);
        }
        // Update the chat's lastVibeId
        const chat = await Chat_1.default.findById(effectiveChatId);
        if (chat) {
            await chat.touch(vibe._id.toString());
        }
        // Update streak
        await updateStreak(effectiveChatId, userId);
        res.status(201).json(vibe);
    }
    catch (error) {
        console.error('Create vibe error:', error);
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
/**
 * @route   POST /api/vibes/:vibeId/react
 * @desc    Add reaction to a vibe
 */
router.post('/:vibeId/react', async (req, res) => {
    try {
        const { vibeId } = req.params;
        const { userId, emoji } = req.body;
        const vibe = await Vibe_1.default.findById(vibeId);
        if (!vibe) {
            return res.status(404).json({ error: 'Vibe not found' });
        }
        vibe.reactions = vibe.reactions.filter(r => r.userId !== userId);
        vibe.reactions.push({ userId, emoji });
        await vibe.save();
        res.json(vibe);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
/**
 * @route   POST /api/vibes/:vibeId/view
 * @desc    Mark vibe as viewed
 */
router.post('/:vibeId/view', async (req, res) => {
    try {
        const { vibeId } = req.params;
        const { userId } = req.body;
        await Vibe_1.default.findByIdAndUpdate(vibeId, {
            $addToSet: { viewedBy: userId },
        });
        res.json({ success: true });
    }
    catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
/**
 * @route   POST /api/vibes/:vibeId/vote
 * @desc    Vote on a poll
 */
router.post('/:vibeId/vote', async (req, res) => {
    try {
        const { vibeId } = req.params;
        const { userId, optionIndex } = req.body;
        const vibe = await Vibe_1.default.findById(vibeId);
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
    }
    catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
/**
 * @route   GET /api/vibes/:conversationId/streak
 * @desc    Get streak for a conversation
 */
router.get('/:conversationId/streak', async (req, res) => {
    try {
        const { conversationId } = req.params;
        let streak = await Streak_1.default.findOne({ conversationId });
        if (!streak) {
            return res.json({ currentStreak: 0, longestStreak: 0 });
        }
        res.json(streak);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
exports.default = router;
//# sourceMappingURL=vibes.js.map