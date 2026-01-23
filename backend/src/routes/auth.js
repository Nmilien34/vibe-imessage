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

module.exports = router;
