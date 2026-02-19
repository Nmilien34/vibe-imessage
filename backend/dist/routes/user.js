"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const auth_1 = require("../middleware/auth");
const User_1 = __importDefault(require("../models/User"));
const router = express_1.default.Router();
const isValidHttpUrl = (value) => {
    try {
        const url = new URL(value);
        return url.protocol === 'http:' || url.protocol === 'https:';
    }
    catch {
        return false;
    }
};
/**
 * @route   GET /api/user/me
 * @desc    Current user's profile + economy snapshot
 * @access  Private (JWT required)
 */
router.get('/me', auth_1.authMiddleware, async (req, res) => {
    try {
        const user = await User_1.default.findById(req.userId).select('firstName lastName email profilePicture auraBalance vibeScore betsCreated betsCompleted betsFailed');
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }
        res.json({
            user: {
                id: user._id,
                firstName: user.firstName,
                lastName: user.lastName,
                email: user.email,
                profilePicture: user.profilePicture,
                auraBalance: user.auraBalance,
                vibeScore: user.vibeScore,
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
    }
    catch (err) {
        console.error('GET /user/me error:', err);
        res.status(500).json({ error: 'Failed to fetch user' });
    }
});
/**
 * @route   PUT /api/user/profile-picture
 * @desc    Update current user's profile picture URL
 * @access  Private (JWT required)
 */
router.put('/profile-picture', auth_1.authMiddleware, async (req, res) => {
    try {
        const rawProfilePicture = req.body?.profilePicture;
        const profilePicture = typeof rawProfilePicture === 'string' ? rawProfilePicture.trim() : '';
        if (!profilePicture) {
            return res.status(400).json({ error: 'profilePicture is required' });
        }
        if (!isValidHttpUrl(profilePicture)) {
            return res.status(400).json({ error: 'profilePicture must be a valid http/https URL' });
        }
        const user = await User_1.default.findByIdAndUpdate(req.userId, { profilePicture }, { new: true, runValidators: true }).select('_id firstName profilePicture');
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
    }
    catch (err) {
        console.error('PUT /user/profile-picture error:', err);
        res.status(500).json({ error: 'Failed to update profile picture' });
    }
});
/**
 * @route   POST /api/user/batch
 * @desc    Batch lookup user profiles by IDs (max 100)
 * @access  Private (JWT required)
 */
router.post('/batch', auth_1.authMiddleware, async (req, res) => {
    try {
        const { userIds } = req.body;
        if (!Array.isArray(userIds) || userIds.length === 0) {
            return res.status(400).json({ error: 'userIds must be a non-empty array' });
        }
        if (userIds.length > 100) {
            return res.status(400).json({ error: 'Maximum 100 userIds per request' });
        }
        const users = await User_1.default.find({ _id: { $in: userIds } })
            .select('_id firstName lastName profilePicture');
        res.json({
            users: users.map(u => ({
                id: u._id,
                firstName: u.firstName || null,
                lastName: u.lastName || null,
                profilePicture: u.profilePicture || null,
            })),
        });
    }
    catch (err) {
        console.error('POST /user/batch error:', err);
        res.status(500).json({ error: 'Failed to fetch users' });
    }
});
exports.default = router;
//# sourceMappingURL=user.js.map