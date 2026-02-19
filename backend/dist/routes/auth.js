"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const apple_signin_auth_1 = __importDefault(require("apple-signin-auth"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const User_1 = __importDefault(require("../models/User"));
const auraService_1 = require("../services/auraService");
const contactNetworkService_1 = require("../services/contactNetworkService");
const router = express_1.default.Router();
const DEFAULT_APPLE_AUDIENCES = [
    'nickmilien.com.vibes.MessagesExtension',
    'nickmilien.com.vibes',
];
function parseAllowedAppleAudiences() {
    const fromEnv = (process.env.APPLE_ALLOWED_AUDIENCES || '')
        .split(',')
        .map(v => v.trim())
        .filter(Boolean);
    return Array.from(new Set([...fromEnv, ...DEFAULT_APPLE_AUDIENCES]));
}
function decodeAppleTokenPayload(identityToken) {
    const parts = identityToken.split('.');
    if (parts.length < 2)
        return null;
    const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64 + '='.repeat((4 - (base64.length % 4)) % 4);
    try {
        const raw = Buffer.from(padded, 'base64').toString('utf8');
        return JSON.parse(raw);
    }
    catch {
        return null;
    }
}
function normalizeAudienceClaim(aud) {
    if (!aud)
        return [];
    if (Array.isArray(aud))
        return aud.filter(Boolean);
    return [aud];
}
function classifyVerifyError(err) {
    const raw = err instanceof Error ? err.message : String(err || 'unknown');
    const message = raw.toLowerCase();
    if (message.includes('expired')) {
        return { status: 401, code: 'apple_token_expired', message: 'Apple identity token expired' };
    }
    if (message.includes('network') ||
        message.includes('timeout') ||
        message.includes('econnreset') ||
        message.includes('enotfound') ||
        message.includes('fetch')) {
        return {
            status: 503,
            code: 'apple_verification_unavailable',
            message: 'Apple verification service unavailable',
        };
    }
    return { status: 401, code: 'apple_token_invalid', message: 'Invalid identity token' };
}
async function verifyAppleIdentityToken(identityToken, allowedAudiences) {
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
    let lastError = null;
    for (const audience of candidateAudiences) {
        try {
            const verified = await apple_signin_auth_1.default.verifyIdToken(identityToken, {
                audience,
                ignoreExpiration: false,
            });
            return { ok: true, payload, verified };
        }
        catch (err) {
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
router.post('/apple', async (req, res) => {
    const { identityToken, userIdentifier, firstName, lastName, email } = req.body;
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
    const { sub: appleId, email: appleEmail } = verification.verified;
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
        let user = await User_1.default.findOne({ appleId });
        if (!user) {
            user = await User_1.default.findById(appleId);
        }
        let isNewUser = false;
        if (!user) {
            user = new User_1.default({
                _id: appleId,
                appleId,
                email: email || appleEmail,
                firstName,
                lastName,
            });
            await user.save();
            isNewUser = true;
            console.log(`New user created: ${user._id}`);
        }
        else {
            let shouldSave = false;
            if (!user.appleId) {
                user.appleId = appleId;
                shouldSave = true;
            }
            if (!user.email && (email || appleEmail)) {
                user.email = email || appleEmail;
                shouldSave = true;
            }
            if (!user.firstName && firstName) {
                user.firstName = firstName;
                shouldSave = true;
            }
            if (!user.lastName && lastName) {
                user.lastName = lastName;
                shouldSave = true;
            }
            if (shouldSave) {
                await user.save();
            }
        }
        if (user.contactDiscoveryEnabled) {
            try {
                await (0, contactNetworkService_1.registerVerifiedEmailIdentifier)({
                    userId: user._id,
                    email: user.email || appleEmail || email,
                });
            }
            catch (identifierError) {
                console.error('Auth identifier registration warning:', identifierError);
            }
        }
        const { auraBalance, vibeScore, dailyBonusClaimed } = await (0, auraService_1.processLoginUpdates)(user._id);
        if (dailyBonusClaimed) {
            console.log(`Daily bonus (+50 Aura) awarded to ${user._id}`);
        }
        const token = jsonwebtoken_1.default.sign({ userId: user._id, appleId: user.appleId }, jwtSecret, { expiresIn: '7d' });
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
    }
    catch (err) {
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
router.post('/dev-login', async (req, res) => {
    // Only allow in development
    if (process.env.NODE_ENV === 'production') {
        return res.status(404).json({ error: 'Not found' });
    }
    const { userId } = req.body;
    if (!userId) {
        return res.status(400).json({ error: 'userId is required' });
    }
    try {
        let user = await User_1.default.findById(userId);
        let isNewUser = false;
        if (!user) {
            user = new User_1.default({
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
                await (0, contactNetworkService_1.registerVerifiedEmailIdentifier)({
                    userId: user._id,
                    email: user.email,
                });
            }
            catch (identifierError) {
                console.error('Dev auth identifier registration warning:', identifierError);
            }
        }
        const { auraBalance, vibeScore, dailyBonusClaimed } = await (0, auraService_1.processLoginUpdates)(user._id);
        if (dailyBonusClaimed) {
            console.log(`Daily bonus (+50 Aura) awarded to ${user._id}`);
        }
        const token = jsonwebtoken_1.default.sign({ userId: user._id }, process.env.JWT_SECRET, { expiresIn: '30d' });
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
    }
    catch (err) {
        console.error('Dev login error:', err);
        res.status(500).json({ error: 'Dev login failed' });
    }
});
/**
 * @route PUT /api/auth/birthday
 * @desc Save user's birthday (month + day)
 * @access Private
 */
router.put('/birthday', async (req, res) => {
    const { userId, month, day } = req.body;
    if (!userId || !month || !day) {
        return res.status(400).json({ error: 'userId, month, and day are required' });
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
        return res.status(400).json({ error: 'Invalid month or day' });
    }
    try {
        const user = await User_1.default.findById(userId);
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }
        user.birthday = { month, day };
        await user.save();
        res.json({ success: true });
    }
    catch (err) {
        console.error('Birthday save error:', err);
        res.status(500).json({ error: 'Failed to save birthday' });
    }
});
exports.default = router;
//# sourceMappingURL=auth.js.map