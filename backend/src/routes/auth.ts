import express, { Request, Response, Router } from 'express';
import appleSignin from 'apple-signin-auth';
import jwt from 'jsonwebtoken';
import User from '../models/User';
import { processLoginUpdates } from '../services/auraService';
import { registerVerifiedEmailIdentifier } from '../services/contactNetworkService';

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

interface AppleTokenPayload {
  iss?: string;
  aud?: string | string[];
  sub?: string;
  email?: string;
  exp?: number;
  iat?: number;
}

interface AppleVerifySuccess {
  ok: true;
  payload: AppleTokenPayload;
  verified: any;
}

interface AppleVerifyFailure {
  ok: false;
  status: number;
  code: string;
  message: string;
  details?: Record<string, unknown>;
}

const DEFAULT_APPLE_AUDIENCES = [
  'nickmilien.com.vibes.MessagesExtension',
  'nickmilien.com.vibes',
];

function parseAllowedAppleAudiences(): string[] {
  const fromEnv = (process.env.APPLE_ALLOWED_AUDIENCES || '')
    .split(',')
    .map(v => v.trim())
    .filter(Boolean);

  return Array.from(new Set([...fromEnv, ...DEFAULT_APPLE_AUDIENCES]));
}

function normalizeOptionalString(value?: string): string | undefined {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function isPlaceholderFirstName(value?: string): boolean {
  if (!value) return true;
  const normalized = value.trim().toLowerCase();
  return (
    normalized.length === 0 ||
    normalized === 'user' ||
    normalized === 'vibe user' ||
    normalized === 'unknown' ||
    normalized === 'unknown user' ||
    normalized === 'anonymous' ||
    normalized === 'anon'
  );
}

function deriveFirstName(
  providedFirstName: string | undefined,
  emailCandidates: Array<string | undefined>
): string | undefined {
  if (!isPlaceholderFirstName(providedFirstName)) return providedFirstName;

  for (const email of emailCandidates) {
    if (!email) continue;
    const localPart = email.split('@')[0];
    if (!localPart) continue;

    const cleaned = localPart
      .replace(/[._-]+/g, ' ')
      .trim();
    if (!cleaned) continue;

    return cleaned
      .split(/\s+/)
      .filter(Boolean)
      .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
      .join(' ');
  }

  return undefined;
}

function decodeAppleTokenPayload(identityToken: string): AppleTokenPayload | null {
  const parts = identityToken.split('.');
  if (parts.length < 2) return null;

  const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64 + '='.repeat((4 - (base64.length % 4)) % 4);

  try {
    const raw = Buffer.from(padded, 'base64').toString('utf8');
    return JSON.parse(raw) as AppleTokenPayload;
  } catch {
    return null;
  }
}

function normalizeAudienceClaim(aud?: string | string[]): string[] {
  if (!aud) return [];
  if (Array.isArray(aud)) return aud.filter(Boolean);
  return [aud];
}

function classifyVerifyError(err: unknown): { status: number; code: string; message: string } {
  const raw = err instanceof Error ? err.message : String(err || 'unknown');
  const message = raw.toLowerCase();

  if (message.includes('expired')) {
    return { status: 401, code: 'apple_token_expired', message: 'Apple identity token expired' };
  }

  if (
    message.includes('network') ||
    message.includes('timeout') ||
    message.includes('econnreset') ||
    message.includes('enotfound') ||
    message.includes('fetch')
  ) {
    return {
      status: 503,
      code: 'apple_verification_unavailable',
      message: 'Apple verification service unavailable',
    };
  }

  return { status: 401, code: 'apple_token_invalid', message: 'Invalid identity token' };
}

async function verifyAppleIdentityToken(
  identityToken: string,
  allowedAudiences: string[]
): Promise<AppleVerifySuccess | AppleVerifyFailure> {
  const payload = decodeAppleTokenPayload(identityToken);
  if (!payload) {
    return {
      ok: false,
      status: 401,
      code: 'apple_token_malformed',
      message: 'Malformed identity token',
    };
  }

  if (payload.iss && payload.iss !== 'https://appleid.apple.com') {
    return {
      ok: false,
      status: 401,
      code: 'apple_issuer_invalid',
      message: 'Invalid Apple token issuer',
      details: { iss: payload.iss },
    };
  }

  const tokenAudiences = normalizeAudienceClaim(payload.aud);
  const candidateAudiences = tokenAudiences.filter(aud => allowedAudiences.includes(aud));

  if (candidateAudiences.length === 0) {
    return {
      ok: false,
      status: 401,
      code: 'apple_audience_mismatch',
      message: 'Token audience not allowed',
      details: { tokenAudiences, allowedAudiences },
    };
  }

  let lastError: unknown = null;
  for (const audience of candidateAudiences) {
    try {
      const verified = await appleSignin.verifyIdToken(identityToken, {
        audience,
        ignoreExpiration: false,
      });

      return { ok: true, payload, verified };
    } catch (err) {
      lastError = err;
    }
  }

  const classified = classifyVerifyError(lastError);
  return {
    ok: false,
    status: classified.status,
    code: classified.code,
    message: classified.message,
    details: {
      tokenAudiences,
      allowedAudiences,
      verifyError: lastError instanceof Error ? lastError.message : String(lastError),
    },
  };
}

/**
 * @route POST /api/auth/apple
 * @desc Authenticate with Apple ID
 * @access Public
 */
router.post('/apple', async (req: Request<{}, {}, AppleAuthRequest>, res: Response) => {
  const { identityToken, userIdentifier, firstName, lastName, email } = req.body;
  const normalizedFirstName = normalizeOptionalString(firstName);
  const normalizedLastName = normalizeOptionalString(lastName);
  const normalizedEmail = normalizeOptionalString(email)?.toLowerCase();

  if (!identityToken || typeof identityToken !== 'string' || !identityToken.trim()) {
    return res.status(400).json({ error: 'Identity token is required' });
  }

  const jwtSecret = process.env.JWT_SECRET;
  if (!jwtSecret) {
    console.error('Auth Error: JWT_SECRET is missing');
    return res.status(500).json({
      error: 'Server authentication misconfiguration',
      code: 'auth_server_misconfigured',
    });
  }

  const normalizedToken = identityToken.trim();
  const allowedAudiences = parseAllowedAppleAudiences();

  const verification = await verifyAppleIdentityToken(normalizedToken, allowedAudiences);
  if (!verification.ok) {
    console.error('Apple Auth Verification Failed:', {
      code: verification.code,
      details: verification.details,
    });
    return res.status(verification.status).json({
      error: verification.message,
      code: verification.code,
    });
  }

  const { sub: appleId, email: appleEmail } = verification.verified as { sub?: string; email?: string };
  const normalizedAppleEmail = normalizeOptionalString(appleEmail)?.toLowerCase();
  if (!appleId) {
    return res.status(401).json({
      error: 'Missing Apple subject claim',
      code: 'apple_subject_missing',
    });
  }

  if (userIdentifier && userIdentifier !== appleId) {
    console.warn('Apple Auth Warning: userIdentifier mismatch', {
      userIdentifier,
      appleId,
    });
  }

  try {
    let user = await User.findOne({ appleId });
    if (!user) {
      user = await User.findById(appleId);
    }
    let isNewUser = false;

    if (!user) {
      const derivedFirstName = deriveFirstName(normalizedFirstName, [normalizedEmail, normalizedAppleEmail]);
      user = new User({
        _id: appleId,
        appleId,
        email: normalizedEmail || normalizedAppleEmail,
        firstName: derivedFirstName,
        lastName: normalizedLastName,
      });
      await user.save();
      isNewUser = true;
      console.log(`New user created: ${user._id}`);
    } else {
      let shouldSave = false;

      if (!user.appleId) {
        user.appleId = appleId;
        shouldSave = true;
      }
      if (!user.email && (normalizedEmail || normalizedAppleEmail)) {
        user.email = normalizedEmail || normalizedAppleEmail;
        shouldSave = true;
      }
      const derivedFirstName = deriveFirstName(normalizedFirstName, [user.email, normalizedEmail, normalizedAppleEmail]);
      if (isPlaceholderFirstName(user.firstName) && derivedFirstName) {
        user.firstName = derivedFirstName;
        shouldSave = true;
      }
      if (!user.lastName && normalizedLastName) {
        user.lastName = normalizedLastName;
        shouldSave = true;
      }

      if (shouldSave) {
        await user.save();
      }
    }

    if (user.contactDiscoveryEnabled) {
      try {
        await registerVerifiedEmailIdentifier({
          userId: user._id,
          email: user.email || normalizedAppleEmail || normalizedEmail,
        });
      } catch (identifierError) {
        console.error('Auth identifier registration warning:', identifierError);
      }
    }

    const { auraBalance, vibeScore, dailyBonusClaimed } = await processLoginUpdates(user._id, {
      awardDailyBonus: false,
    });
    if (dailyBonusClaimed) {
      console.log(`Daily bonus (+50 Aura) awarded to ${user._id}`);
    }

    const token = jwt.sign(
      { userId: user._id, appleId: user.appleId },
      jwtSecret,
      { expiresIn: '7d' }
    );

    const responseFirstName = deriveFirstName(user.firstName, [user.email, normalizedAppleEmail, normalizedEmail]);

    res.json({
      token,
      isNewUser,
      dailyBonusClaimed,
      user: {
        id: user._id,
        firstName: responseFirstName,
        lastName: user.lastName,
        email: user.email,
        profilePicture: user.profilePicture,
        auraBalance,
        vibeScore,
      },
    });
  } catch (err) {
    console.error('Apple Auth Error (post-verification):', err);
    res.status(500).json({
      error: 'Authentication failed due to server error',
      code: 'auth_server_error',
    });
  }
});

/**
 * @route POST /api/auth/dev-login
 * @desc Development-only login for simulator testing (bypasses Apple Sign In)
 * @access Public (only available in non-production)
 */
router.post('/dev-login', async (req: Request<{}, {}, { userId: string }>, res: Response) => {
  // Only allow in development
  if (process.env.NODE_ENV === 'production') {
    return res.status(404).json({ error: 'Not found' });
  }

  const { userId } = req.body;

  if (!userId) {
    return res.status(400).json({ error: 'userId is required' });
  }

  try {
    let user = await User.findById(userId);
    let isNewUser = false;

    if (!user) {
      user = new User({
        _id: userId,
        firstName: 'Test',
        lastName: 'User',
        email: 'test@vibe.app',
      });
      await user.save();
      isNewUser = true;
      console.log(`Dev login: Created new test user ${userId}`);
    }

    if (user.contactDiscoveryEnabled) {
      try {
        await registerVerifiedEmailIdentifier({
          userId: user._id,
          email: user.email,
        });
      } catch (identifierError) {
        console.error('Dev auth identifier registration warning:', identifierError);
      }
    }

    const { auraBalance, vibeScore, dailyBonusClaimed } = await processLoginUpdates(user._id, {
      awardDailyBonus: false,
    });
    if (dailyBonusClaimed) {
      console.log(`Daily bonus (+50 Aura) awarded to ${user._id}`);
    }

    const token = jwt.sign(
      { userId: user._id },
      process.env.JWT_SECRET!,
      { expiresIn: '30d' }
    );

    console.log(`Dev login: User ${userId} authenticated`);

    res.json({
      token,
      isNewUser,
      dailyBonusClaimed,
      user: {
        id: user._id,
        firstName: user.firstName,
        lastName: user.lastName,
        email: user.email,
        profilePicture: user.profilePicture,
        auraBalance,
        vibeScore,
      },
    });
  } catch (err) {
    console.error('Dev login error:', err);
    res.status(500).json({ error: 'Dev login failed' });
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
