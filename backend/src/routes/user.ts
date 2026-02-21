import express, { Request, Response, Router } from 'express';
import { authMiddleware } from '../middleware/auth';
import User from '../models/User';

const router: Router = express.Router();

interface UpdateProfilePictureRequest {
  profilePicture: string;
}

const isValidHttpUrl = (value: string): boolean => {
  try {
    const url = new URL(value);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch {
    return false;
  }
};

const deriveFirstName = (firstName?: string | null, email?: string | null): string | null => {
  const trimmed = firstName?.trim();
  if (trimmed) {
    const normalized = trimmed.toLowerCase();
    if (normalized !== 'user' && normalized !== 'vibe user') {
      return trimmed;
    }
  }

  const localPart = email?.split('@')[0]?.trim();
  if (!localPart) return null;

  const cleaned = localPart.replace(/[._-]+/g, ' ').trim();
  if (!cleaned) return null;

  return cleaned
    .split(/\s+/)
    .filter(Boolean)
    .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(' ');
};

/**
 * @route   GET /api/user/me
 * @desc    Current user's profile + economy snapshot
 * @access  Private (JWT required)
 */
router.get('/me', authMiddleware, async (req: Request, res: Response) => {
  try {
    const user = await User.findById(req.userId!).select(
      'firstName lastName email profilePicture auraBalance vibeScore betsCreated betsCompleted betsFailed contactDiscoveryEnabled'
    );

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({
      user: {
        id: user._id,
        firstName: deriveFirstName(user.firstName, user.email),
        lastName: user.lastName,
        email: user.email,
        profilePicture: user.profilePicture,
        auraBalance: user.auraBalance,
        vibeScore: user.vibeScore,
        contactDiscoveryEnabled: user.contactDiscoveryEnabled ?? false,
        stats: {
          betsCreated: user.betsCreated ?? 0,
          betsCompleted: user.betsCompleted ?? 0,
          betsFailed: user.betsFailed ?? 0,
          winRate: (user.betsCreated ?? 0) > 0
            ? (((user.betsCompleted ?? 0) / (user.betsCreated ?? 0)) * 100).toFixed(1) + '%'
            : '0%',
        },
      },
    });
  } catch (err) {
    console.error('GET /user/me error:', err);
    res.status(500).json({ error: 'Failed to fetch user' });
  }
});

/**
 * @route   PUT /api/user/profile-picture
 * @desc    Update current user's profile picture URL
 * @access  Private (JWT required)
 */
router.put(
  '/profile-picture',
  authMiddleware,
  async (req: Request<{}, {}, UpdateProfilePictureRequest>, res: Response) => {
    try {
      const rawProfilePicture = req.body?.profilePicture;
      const profilePicture = typeof rawProfilePicture === 'string' ? rawProfilePicture.trim() : '';

      if (!profilePicture) {
        return res.status(400).json({ error: 'profilePicture is required' });
      }

      if (!isValidHttpUrl(profilePicture)) {
        return res.status(400).json({ error: 'profilePicture must be a valid http/https URL' });
      }

      const user = await User.findByIdAndUpdate(
        req.userId!,
        { profilePicture },
        { new: true, runValidators: true }
      ).select('_id firstName profilePicture');

      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      res.json({
        success: true,
        user: {
          id: user._id,
          firstName: user.firstName,
          profilePicture: user.profilePicture,
        },
      });
    } catch (err) {
      console.error('PUT /user/profile-picture error:', err);
      res.status(500).json({ error: 'Failed to update profile picture' });
    }
  }
);

/**
 * @route   POST /api/user/batch
 * @desc    Batch lookup user profiles by IDs (max 100)
 * @access  Private (JWT required)
 */
router.post('/batch', authMiddleware, async (req: Request<{}, {}, { userIds: string[] }>, res: Response) => {
  try {
    const { userIds } = req.body;

    if (!Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({ error: 'userIds must be a non-empty array' });
    }

    if (userIds.length > 100) {
      return res.status(400).json({ error: 'Maximum 100 userIds per request' });
    }

    const users = await User.find({ _id: { $in: userIds } })
      .select('_id firstName lastName profilePicture');

    res.json({
      users: users.map(u => ({
        id: u._id,
        firstName: u.firstName || null,
        lastName: u.lastName || null,
        profilePicture: u.profilePicture || null,
      })),
    });
  } catch (err) {
    console.error('POST /user/batch error:', err);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

export default router;
