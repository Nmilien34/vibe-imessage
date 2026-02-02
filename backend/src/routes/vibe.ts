import express, { Request, Response, Router } from 'express';
import multer from 'multer';
import Vibe, { FEED_EXPIRATION_DAYS, HISTORY_RETENTION_DAYS } from '../models/Vibe';
import { uploadToS3 } from '../utils/s3Upload';
import { IVibe } from '../types';

const router: Router = express.Router();

// Configure multer for memory storage
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 50 * 1024 * 1024, // 50MB limit
  },
});

interface UploadRequestBody {
  userId: string;
  chatId: string;
  isLocked: string | boolean;
}

interface VideoParams {
  videoId: string;
}

interface UnlockRequest {
  userId: string;
}

interface ChatParams {
  chatId: string;
}

/**
 * @route   POST /api/vibe/upload
 * @desc    Upload a video vibe (Multipart)
 */
router.post('/upload', upload.single('video'), async (req: Request<{}, {}, UploadRequestBody>, res: Response) => {
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
router.get('/:videoId', async (req: Request<VideoParams>, res: Response) => {
  try {
    const { videoId } = req.params;
    const userId = req.query.userId as string;

    const vibe = await Vibe.findById(videoId);
    if (!vibe) {
      return res.status(404).json({ error: 'Story not found' });
    }

    const vibeObj = vibe.toObject() as IVibe & { isLocked: boolean };

    const userHasPosted = await Vibe.exists({
      conversationId: vibe.conversationId,
      userId: userId,
      expiresAt: { $gt: new Date() },
    });

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
router.post('/:videoId/unlock', async (req: Request<VideoParams, {}, UnlockRequest>, res: Response) => {
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
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   GET /api/vibe/feed/:chatId
 * @desc    Returns all active stories for a group
 */
router.get('/feed/:chatId', async (req: Request<ChatParams>, res: Response) => {
  try {
    const { chatId } = req.params;

    const vibes = await Vibe.find({
      conversationId: chatId,
      expiresAt: { $gt: new Date() },
    }).sort({ createdAt: -1 });

    res.json(vibes);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

export default router;
