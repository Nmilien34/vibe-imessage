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
const router = express_1.default.Router();
/**
 * @route POST /api/auth/apple
 * @desc Authenticate with Apple ID
 * @access Public
 */
router.post('/apple', async (req, res) => {
    const { identityToken, firstName, lastName, email } = req.body;
    if (!identityToken) {
        return res.status(400).json({ error: 'Identity token is required' });
    }
    try {
        const appleData = await apple_signin_auth_1.default.verifyIdToken(identityToken, {
            audience: ['nickmilien.com.vibes.MessagesExtension', 'nickmilien.com.vibes'],
            ignoreExpiration: false,
        });
        const { sub: appleId, email: appleEmail } = appleData;
        let user = await User_1.default.findOne({ appleId });
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
        const { auraBalance, vibeScore, dailyBonusClaimed } = await (0, auraService_1.processLoginUpdates)(user._id);
        if (dailyBonusClaimed) {
            console.log(`Daily bonus (+50 Aura) awarded to ${user._id}`);
        }
        const token = jsonwebtoken_1.default.sign({ userId: user._id, appleId: user.appleId }, process.env.JWT_SECRET, { expiresIn: '7d' });
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
        console.error('Apple Auth Error:', err);
        res.status(401).json({ error: 'Invalid identity token' });
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