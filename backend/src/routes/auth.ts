import express, { Request, Response, Router } from 'express';
import appleSignin from 'apple-signin-auth';
import jwt from 'jsonwebtoken';
import User from '../models/User';

const router: Router = express.Router();

interface AppleAuthRequest {
  identityToken: string;
  userIdentifier?: string;
  firstName?: string;
  lastName?: string;
  email?: string;
}

interface BirthdayRequest {
  userId: string;
  month: number;
  day: number;
}

/**
 * @route POST /api/auth/apple
 * @desc Authenticate with Apple ID
 * @access Public
 */
router.post('/apple', async (req: Request<{}, {}, AppleAuthRequest>, res: Response) => {
  const { identityToken, firstName, lastName, email } = req.body;

  if (!identityToken) {
    return res.status(400).json({ error: 'Identity token is required' });
  }

  try {
    const appleData = await appleSignin.verifyIdToken(identityToken, {
      audience: 'nickmilien.com.vibes.MessagesExtension',
      ignoreExpiration: false,
    });

    const { sub: appleId, email: appleEmail } = appleData;

    let user = await User.findOne({ appleId });

    if (!user) {
      user = new User({
        appleId,
        email: email || appleEmail,
        firstName,
        lastName,
      });
      await user.save();
    }

    const token = jwt.sign(
      { userId: user._id, appleId: user.appleId },
      process.env.JWT_SECRET || 'your_fallback_secret',
      { expiresIn: '7d' }
    );

    res.json({
      token,
      user: {
        id: user._id,
        firstName: user.firstName,
        lastName: user.lastName,
        email: user.email,
      },
    });
  } catch (err) {
    console.error('Apple Auth Error:', err);
    res.status(401).json({ error: 'Invalid identity token' });
  }
});

/**
 * @route PUT /api/auth/birthday
 * @desc Save user's birthday (month + day)
 * @access Private
 */
router.put('/birthday', async (req: Request<{}, {}, BirthdayRequest>, res: Response) => {
  const { userId, month, day } = req.body;

  if (!userId || !month || !day) {
    return res.status(400).json({ error: 'userId, month, and day are required' });
  }

  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return res.status(400).json({ error: 'Invalid month or day' });
  }

  try {
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    user.birthday = { month, day };
    await user.save();

    res.json({ success: true });
  } catch (err) {
    console.error('Birthday save error:', err);
    res.status(500).json({ error: 'Failed to save birthday' });
  }
});

export default router;
