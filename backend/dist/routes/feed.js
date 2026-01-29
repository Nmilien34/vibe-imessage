"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const Vibe_1 = __importDefault(require("../models/Vibe"));
const User_1 = __importDefault(require("../models/User"));
const router = express_1.default.Router();
/**
 * Helper: Process vibe for blur status
 */
async function processVibeForBlur(vibe, requestingUserId, userHasPostedInChat) {
    const vibeObj = vibe.toObject();
    if (vibe.isLocked && vibe.userId !== requestingUserId) {
        // Check if user has posted (use cached value if provided)
        const hasPosted = userHasPostedInChat ?? await Vibe_1.default.exists({
            chatId: vibe.chatId,
            userId: requestingUserId,
            expiresAt: { $gt: new Date() },
        });
        if (!hasPosted && !vibe.unlockedBy.includes(requestingUserId)) {
            vibeObj.isBlurred = true;
            delete vibeObj.mediaUrl;
            delete vibeObj.songData;
            delete vibeObj.mood;
        }
        else {
            vibeObj.isBlurred = false;
        }
    }
    else {
        vibeObj.isBlurred = false;
    }
    return vibeObj;
}
/**
 * Helper: Group vibes into user stories
 */
async function groupVibesIntoStories(vibes, requestingUserId) {
    // Group vibes by userId
    const vibesByUser = new Map();
    for (const vibe of vibes) {
        const existing = vibesByUser.get(vibe.userId) || [];
        existing.push(vibe);
        vibesByUser.set(vibe.userId, existing);
    }
    // Get all unique user IDs
    const userIds = Array.from(vibesByUser.keys());
    // Fetch user info for all users
    const users = await User_1.default.find({ _id: { $in: userIds } });
    const userMap = new Map();
    for (const user of users) {
        userMap.set(user._id, user);
    }
    // Build stories array
    const stories = await Promise.all(userIds.map(async (oderId) => {
        const userVibes = vibesByUser.get(oderId) || [];
        const user = userMap.get(oderId);
        // Process each vibe for blur status
        const processedVibes = await Promise.all(userVibes.map(vibe => processVibeForBlur(vibe, requestingUserId)));
        // Sort vibes by createdAt descending
        processedVibes.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
        // Check if any vibes are unviewed
        const hasUnviewed = userVibes.some(vibe => vibe.userId !== requestingUserId && !vibe.viewedBy.includes(requestingUserId));
        return {
            userId: oderId,
            userName: user ? `${user.firstName || ''} ${user.lastName || ''}`.trim() || undefined : undefined,
            profilePicture: user?.profilePicture,
            vibes: processedVibes,
            latestVibeAt: new Date(userVibes[0].createdAt),
            hasUnviewed,
        };
    }));
    // Sort stories: unviewed first, then by latest vibe time
    stories.sort((a, b) => {
        if (a.hasUnviewed && !b.hasUnviewed)
            return -1;
        if (!a.hasUnviewed && b.hasUnviewed)
            return 1;
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
router.get('/my-feed', async (req, res) => {
    try {
        const { userId, limit = '50', offset = '0' } = req.query;
        if (!userId) {
            return res.status(400).json({ error: 'userId is required' });
        }
        const user = await User_1.default.findById(userId);
        if (!user || !user.joinedChatIds || user.joinedChatIds.length === 0) {
            return res.json({ vibes: [], hasMore: false });
        }
        const chatIds = user.joinedChatIds;
        const limitNum = parseInt(limit);
        const offsetNum = parseInt(offset);
        const vibes = await Vibe_1.default.find({
            chatId: { $in: chatIds },
            expiresAt: { $gt: new Date() },
        })
            .sort({ createdAt: -1 })
            .skip(offsetNum)
            .limit(limitNum + 1);
        const hasMore = vibes.length > limitNum;
        const resultVibes = hasMore ? vibes.slice(0, -1) : vibes;
        const processedVibes = await Promise.all(resultVibes.map(vibe => processVibeForBlur(vibe, userId)));
        const response = {
            vibes: processedVibes,
            hasMore,
        };
        res.json(response);
    }
    catch (error) {
        console.error('My feed error:', error);
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
/**
 * @route   GET /api/feed/chat/:chatId
 * @desc    Get vibes for a specific chat
 */
router.get('/chat/:chatId', async (req, res) => {
    try {
        const { chatId } = req.params;
        const { userId } = req.query;
        const vibes = await Vibe_1.default.find({
            chatId,
            expiresAt: { $gt: new Date() },
        }).sort({ createdAt: -1 });
        // Check if requesting user has posted in this chat (for unlock logic)
        const userHasPosted = userId ? vibes.some(v => v.userId === userId) : false;
        const processedVibes = await Promise.all(vibes.map(vibe => processVibeForBlur(vibe, userId || '', userHasPosted)));
        res.json(processedVibes);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
/**
 * @route   GET /api/feed/history
 * @query   { userId, limit? }
 * @desc    Get user's vibe history across all chats (up to 15 days)
 */
router.get('/history', async (req, res) => {
    try {
        const { userId, limit = '50' } = req.query;
        if (!userId) {
            return res.status(400).json({ error: 'userId is required' });
        }
        const vibes = await Vibe_1.default.find({
            userId,
            permanentDeleteAt: { $gt: new Date() },
        })
            .sort({ createdAt: -1 })
            .limit(parseInt(limit));
        const processedVibes = vibes.map((vibe) => {
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
 * @route   GET /api/feed/stats
 * @query   { userId }
 * @desc    Get feed stats for a user
 */
router.get('/stats', async (req, res) => {
    try {
        const { userId } = req.query;
        if (!userId) {
            return res.status(400).json({ error: 'userId is required' });
        }
        const user = await User_1.default.findById(userId);
        if (!user) {
            return res.json({ totalChats: 0, totalVibes: 0, unviewedCount: 0 });
        }
        const totalChats = user.joinedChatIds.length;
        const totalVibes = await Vibe_1.default.countDocuments({
            chatId: { $in: user.joinedChatIds },
            expiresAt: { $gt: new Date() },
        });
        const unviewedCount = await Vibe_1.default.countDocuments({
            chatId: { $in: user.joinedChatIds },
            expiresAt: { $gt: new Date() },
            userId: { $ne: userId },
            viewedBy: { $ne: userId },
        });
        const stats = {
            totalChats,
            totalVibes,
            unviewedCount,
        };
        res.json(stats);
    }
    catch (error) {
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
router.get('/stories', async (req, res) => {
    try {
        const { userId, chatIds, limit = '50' } = req.query;
        if (!userId) {
            return res.status(400).json({ error: 'userId is required' });
        }
        let targetChatIds;
        if (chatIds) {
            // Use provided chat IDs (comma-separated)
            targetChatIds = chatIds.split(',').map(id => id.trim()).filter(Boolean);
        }
        else {
            // Get all user's joined chats
            const user = await User_1.default.findById(userId);
            if (!user || !user.joinedChatIds || user.joinedChatIds.length === 0) {
                const emptyResponse = { stories: [], hasMore: false };
                return res.json(emptyResponse);
            }
            targetChatIds = user.joinedChatIds;
        }
        const limitNum = parseInt(limit);
        // Fetch all non-expired vibes from target chats
        const vibes = await Vibe_1.default.find({
            chatId: { $in: targetChatIds },
            expiresAt: { $gt: new Date() },
        })
            .sort({ createdAt: -1 })
            .limit(limitNum);
        // Group into stories
        const stories = await groupVibesIntoStories(vibes, userId);
        const response = {
            stories,
            hasMore: vibes.length >= limitNum,
        };
        res.json(response);
    }
    catch (error) {
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
router.get('/stories/:chatId', async (req, res) => {
    try {
        const { chatId } = req.params;
        const { userId } = req.query;
        if (!userId) {
            return res.status(400).json({ error: 'userId is required' });
        }
        // Fetch all non-expired vibes from this chat
        const vibes = await Vibe_1.default.find({
            chatId,
            expiresAt: { $gt: new Date() },
        }).sort({ createdAt: -1 });
        // Group into stories
        const stories = await groupVibesIntoStories(vibes, userId);
        const response = {
            chatId,
            stories,
        };
        res.json(response);
    }
    catch (error) {
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
router.get('/user/:oderId/vibes', async (req, res) => {
    try {
        const { oderId } = req.params;
        const { userId, chatId } = req.query;
        if (!userId) {
            return res.status(400).json({ error: 'userId is required' });
        }
        // Build query
        const query = {
            userId: oderId,
            expiresAt: { $gt: new Date() },
        };
        // Optionally filter by chat
        if (chatId) {
            query.chatId = chatId;
        }
        const vibes = await Vibe_1.default.find(query).sort({ createdAt: -1 });
        // Process for blur status
        const processedVibes = await Promise.all(vibes.map(vibe => processVibeForBlur(vibe, userId)));
        // Get user info
        const vibeOwner = await User_1.default.findById(oderId);
        res.json({
            userId: oderId,
            userName: vibeOwner ? `${vibeOwner.firstName || ''} ${vibeOwner.lastName || ''}`.trim() || undefined : undefined,
            profilePicture: vibeOwner?.profilePicture,
            vibes: processedVibes,
        });
    }
    catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
exports.default = router;
//# sourceMappingURL=feed.js.map