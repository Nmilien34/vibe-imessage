import express, { Request, Response, Router } from 'express';
import { getUploadUrl } from '../utils/s3Upload';

const router: Router = express.Router();

interface PresignedUrlRequest {
  fileType: string;
  folder?: string;
}

const validTypes = ['mp4', 'mov', 'jpg', 'jpeg', 'png', 'gif'];

router.post('/presigned-url', async (req: Request<{}, {}, PresignedUrlRequest>, res: Response) => {
  try {
    const { fileType, folder } = req.body;

    if (!fileType) {
      return res.status(400).json({ error: 'fileType is required' });
    }

    if (!validTypes.includes(fileType.toLowerCase())) {
      return res.status(400).json({ error: 'Invalid file type' });
    }

    const { uploadUrl, publicUrl, key } = await getUploadUrl(fileType, folder || 'vibes');

    res.json({ uploadUrl, publicUrl, key });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

export default router;
