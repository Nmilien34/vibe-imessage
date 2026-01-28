const express = require('express');
const router = express.Router();
const appleSignin = require('apple-signin-auth');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

/**
 * @route POST /api/auth/apple
 * @desc Authenticate with Apple ID
 * @access Public
 */
router.post('/apple', async (req, res) => {
    const { identityToken, userIdentifier, firstName, lastName, email } = req.body;

    if (!identityToken) {
        return res.status(400).json({ error: 'Identity token is required' });
    }

    try {
        // 1. Verify the identity token with Apple
        // NOTE: In production, you should verify the 'aud' matches your App Bundle ID
        const appleData = await appleSignin.verifyIdToken(identityToken, {
            // audience is optional but recommended
            // audience: 'com.your.bundle.id', 
            ignoreExpiration: false,
        });

        const { sub: appleId, email: appleEmail } = appleData;

        // 2. Find or create the user
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

        // 3. Generate a JWT for our application
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
router.put('/birthday', async (req, res) => {
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

module.exports = router;
