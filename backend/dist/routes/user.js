"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const auth_1 = require("../middleware/auth");
const User_1 = __importDefault(require("../models/User"));
const router = express_1.default.Router();
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
exports.default = router;
//# sourceMappingURL=user.js.map