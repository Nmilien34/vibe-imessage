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

const isPlaceholderFirstName = (value?: string | null): boolean => {
  const normalized = value?.trim().toLowerCase();
  return (
    !normalized ||
    normalized === 'user' ||
    normalized === 'vibe user' ||
    normalized === 'unknown' ||
    normalized === 'unknown user' ||
    normalized === 'anonymous' ||
    normalized === 'anon'
  );
};

const deriveFirstName = (firstName?: string | null, email?: string | null): string | null => {
  if (!isPlaceholderFirstName(firstName)) {
    return firstName!.trim();
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
      'firstName lastName email profilePicture auraBalance vibeScore betsCreated betsCompleted betsFailed wins losses ducks calloutsReceived calloutsIgnored streak lastActiveDate winRate duckRate contactDiscoveryEnabled'
    );

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const wins = user.wins ?? user.betsCompleted ?? 0;
    const losses = user.losses ?? user.betsFailed ?? 0;
    const ducks = user.ducks ?? user.calloutsIgnored ?? 0;
    const totalDecisions = wins + losses;
    const computedWinRate = totalDecisions > 0 ? Math.round((wins / totalDecisions) * 100) : 0;
    const totalDuckOpportunities = ducks + (user.calloutsReceived ?? 0);
    const computedDuckRate = totalDuckOpportunities > 0
      ? Math.round((ducks / totalDuckOpportunities) * 100)
      : 0;

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
          wins,
          losses,
          ducks,
          winRate: user.winRate ?? computedWinRate,
          duckRate: user.duckRate ?? computedDuckRate,
          streak: user.streak ?? 0,
          lastActiveDate: user.lastActiveDate ?? null,
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
      .select('_id firstName lastName email profilePicture');

    res.json({
      users: users.map(u => ({
        id: u._id,
        firstName: deriveFirstName(u.firstName, u.email),
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
