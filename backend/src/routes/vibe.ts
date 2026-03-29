import express, { Request, Response, Router } from 'express';
import multer from 'multer';
import Vibe, { FEED_EXPIRATION_DAYS, HISTORY_RETENTION_DAYS } from '../models/Vibe';
import { uploadToS3 } from '../utils/s3Upload';
import { IVibe } from '../types';
import { authMiddleware, optionalAuth } from '../middleware/auth';

const router: Router = express.Router();

const ALLOWED_EXTENSIONS = new Set(['mp4', 'mov', 'jpg', 'jpeg', 'png', 'gif']);

// Configure multer for memory storage
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 50 * 1024 * 1024, // 50MB limit
  },
});

interface UploadRequestBody {
  userId?: string;
  chatId: string;
  isLocked: string | boolean;
}

interface VideoParams {
  videoId: string;
}

interface UnlockRequest {
  userId?: string;
}

interface ChatParams {
  chatId: string;
}

function normalizedNonEmpty(value?: string | null): string | null {
  const trimmed = value?.trim();
  return trimmed ? trimmed : null;
}

function buildChatLookup(chatKey?: string | null) {
  const normalizedChatKey = normalizedNonEmpty(chatKey);
  if (!normalizedChatKey) {
    return {};
  }

  return {
    $or: [
      { chatId: normalizedChatKey },
      { conversationId: normalizedChatKey },
    ],
  };
}

/**
 * @route   POST /api/vibe/upload
 * @desc    Upload vibe media (Multipart)
 */
router.post('/upload', authMiddleware, upload.single('video'), async (req: Request<{}, {}, UploadRequestBody>, res: Response) => {
  try {
    const authenticatedUserId = req.userId!;
    const { userId: requestedUserId, chatId, isLocked } = req.body;
    const userId = authenticatedUserId;
    const file = req.file;

    if (!file) {
      return res.status(400).json({ error: 'No media file provided' });
    }

    if (requestedUserId && requestedUserId !== authenticatedUserId) {
      return res.status(403).json({ error: 'Cannot upload as another user' });
    }

    if (!userId || !chatId) {
      return res.status(400).json({ error: 'userId and chatId are required' });
    }

    const extension = (file.originalname.split('.').pop() || '').toLowerCase();
    if (!ALLOWED_EXTENSIONS.has(extension)) {
      return res.status(400).json({ error: 'Invalid file type' });
    }
    const { publicUrl, key } = await uploadToS3(file.buffer, extension, 'vibes');

    // RETURN ONLY S3 INFO - LET THE CLIENT CREATE THE VIBE WITH METADATA
    res.status(201).json({
      videoId: "temp_upload_success", // Backwards compatibility for client parser
      videoUrl: publicUrl,
      videoKey: key,
    });
  } catch (error) {
    console.error('Upload error:', error);
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   GET /api/vibe/:videoId
 * @desc    Returns story metadata and checks lock status
 */
router.get('/:videoId', optionalAuth, async (req: Request<any>, res: Response) => {
  try {
    const videoId = req.params.videoId as string;
    const userId = req.userId || (req.query.userId as string | undefined) || '';

    const vibe = await Vibe.findById(videoId);
    if (!vibe) {
      return res.status(404).json({ error: 'Story not found' });
    }

    const vibeObj = vibe.toObject() as IVibe & { isLocked: boolean };
    const vibeChatKey = normalizedNonEmpty(vibe.chatId) || normalizedNonEmpty(vibe.conversationId);

    const userHasPosted = vibeChatKey
      ? await Vibe.exists({
          ...buildChatLookup(vibeChatKey),
          userId: userId,
          expiresAt: { $gt: new Date() },
        })
      : null;

    if (vibe.isLocked && !userHasPosted && vibe.userId !== userId) {
      vibeObj.isLocked = true;
      delete (vibeObj as any).mediaUrl;
      delete (vibeObj as any).songData;
      delete (vibeObj as any).mood;
    } else {
      vibeObj.isLocked = false;
    }

    res.json(vibeObj);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   POST /api/vibe/:videoId/unlock
 * @desc    Marks story as unlocked for a user
 */
router.post('/:videoId/unlock', authMiddleware, async (req: Request, res: Response) => {
  try {
    const authenticatedUserId = req.userId!;
    const { videoId } = req.params;
    const { userId: requestedUserId } = req.body as UnlockRequest;
    const userId = authenticatedUserId;

    if (requestedUserId && requestedUserId !== authenticatedUserId) {
      return res.status(403).json({ error: 'Cannot unlock as another user' });
    }

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
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   GET /api/vibe/feed/:chatId
 * @desc    Returns all active stories for a group
 */
router.get('/feed/:chatId', authMiddleware, async (req: Request<any>, res: Response) => {
  try {
    const chatId = req.params.chatId as string;

    const vibes = await Vibe.find({
      ...buildChatLookup(chatId),
      expiresAt: { $gt: new Date() },
    }).sort({ createdAt: -1 });

    res.json(vibes);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

export default router;
