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
const multer_1 = __importDefault(require("multer"));
const Vibe_1 = __importStar(require("../models/Vibe"));
const s3Upload_1 = require("../utils/s3Upload");
const router = express_1.default.Router();
// Configure multer for memory storage
const upload = (0, multer_1.default)({
    storage: multer_1.default.memoryStorage(),
    limits: {
        fileSize: 50 * 1024 * 1024, // 50MB limit
    },
});
/**
 * @route   POST /api/vibe/upload
 * @desc    Upload a video vibe (Multipart)
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
        const extension = file.originalname.split('.').pop() || 'mp4';
        const { publicUrl, key } = await (0, s3Upload_1.uploadToS3)(file.buffer, extension, 'vibes');
        const now = new Date();
        const expiresAt = new Date(now.getTime() + Vibe_1.FEED_EXPIRATION_DAYS * 24 * 60 * 60 * 1000);
        const permanentDeleteAt = new Date(now.getTime() + Vibe_1.HISTORY_RETENTION_DAYS * 24 * 60 * 60 * 1000);
        const vibe = new Vibe_1.default({
            userId,
            conversationId: chatId,
            type: 'video',
            mediaUrl: publicUrl,
            mediaKey: key,
            isLocked: isLocked === 'true' || isLocked === true,
            expiresAt,
            permanentDeleteAt,
        });
        await vibe.save();
        res.status(201).json({
            videoId: vibe._id,
            videoUrl: publicUrl,
            videoKey: key,
        });
    }
    catch (error) {
        console.error('Upload error:', error);
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
/**
 * @route   GET /api/vibe/:videoId
 * @desc    Returns story metadata and checks lock status
 */
router.get('/:videoId', async (req, res) => {
    try {
        const { videoId } = req.params;
        const userId = req.query.userId;
        const vibe = await Vibe_1.default.findById(videoId);
        if (!vibe) {
            return res.status(404).json({ error: 'Story not found' });
        }
        const vibeObj = vibe.toObject();
        const userHasPosted = await Vibe_1.default.exists({
            conversationId: vibe.conversationId,
            userId: userId,
            expiresAt: { $gt: new Date() },
        });
        if (vibe.isLocked && !userHasPosted && vibe.userId !== userId) {
            vibeObj.isLocked = true;
            delete vibeObj.mediaUrl;
            delete vibeObj.songData;
            delete vibeObj.mood;
        }
        else {
            vibeObj.isLocked = false;
        }
        res.json(vibeObj);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
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
        const vibe = await Vibe_1.default.findByIdAndUpdate(videoId, { $addToSet: { unlockedBy: userId } }, { new: true });
        if (!vibe) {
            return res.status(404).json({ error: 'Story not found' });
        }
        res.json({ success: true, vibe });
    }
    catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
/**
 * @route   GET /api/vibe/feed/:chatId
 * @desc    Returns all active stories for a group
 */
router.get('/feed/:chatId', async (req, res) => {
    try {
        const { chatId } = req.params;
        const vibes = await Vibe_1.default.find({
            conversationId: chatId,
            expiresAt: { $gt: new Date() },
        }).sort({ createdAt: -1 });
        res.json(vibes);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
exports.default = router;
//# sourceMappingURL=vibe.js.map