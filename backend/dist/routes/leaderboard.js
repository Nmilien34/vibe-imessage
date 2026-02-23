"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const auth_1 = require("../middleware/auth");
const ChatMember_1 = __importDefault(require("../models/ChatMember"));
const User_1 = __importDefault(require("../models/User"));
const router = express_1.default.Router();
function calculateWinRate(wins, losses) {
    const total = wins + losses;
    if (total <= 0)
        return 0;
    return Math.round((wins / total) * 100);
}
/**
 * @route   GET /api/leaderboard
 * @desc    Aura leaderboard scoped to a chat or all chats the user is in
 * @access  Private (JWT required)
 */
router.get('/', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const chatId = typeof req.query.chatId === 'string' ? req.query.chatId : undefined;
        let scopedUserIds = [];
        if (chatId) {
            const requesterMembership = await ChatMember_1.default.findOne({ chatId, userId });
            if (!requesterMembership) {
                return res.status(403).json({ error: 'You are not a member of this chat' });
            }
            const chatMembers = await ChatMember_1.default.find({ chatId }).select('userId');
            scopedUserIds = chatMembers.map(member => member.userId);
        }
        else {
            const memberships = await ChatMember_1.default.find({ userId }).select('chatId');
            const chatIds = [...new Set(memberships.map(member => member.chatId))];
            if (chatIds.length === 0) {
                return res.json({ leaderboard: [], count: 0 });
            }
            const allMembers = await ChatMember_1.default.find({ chatId: { $in: chatIds } }).select('userId');
            scopedUserIds = allMembers.map(member => member.userId);
        }
        const uniqueUserIds = [...new Set(scopedUserIds)];
        if (uniqueUserIds.length === 0) {
            return res.json({ leaderboard: [], count: 0 });
        }
        const users = await User_1.default.find({ _id: { $in: uniqueUserIds } })
            .select('_id firstName lastName auraBalance wins losses ducks betsCompleted betsFailed calloutsIgnored winRate vibeScore')
            .sort({ auraBalance: -1 })
            .limit(50);
        const leaderboard = users
            .map((user) => {
            const wins = user.wins ?? user.betsCompleted ?? 0;
            const losses = user.losses ?? user.betsFailed ?? 0;
            const ducks = user.ducks ?? user.calloutsIgnored ?? 0;
            const displayName = `${user.firstName ?? ''} ${user.lastName ?? ''}`.trim() || 'Unknown';
            return {
                userId: user._id,
                displayName,
                auraBalance: user.auraBalance ?? 0,
                wins,
                losses,
                ducks,
                winRate: user.winRate ?? calculateWinRate(wins, losses),
                vibeScore: user.vibeScore ?? 100,
            };
        })
            .sort((lhs, rhs) => {
            if (rhs.auraBalance !== lhs.auraBalance) {
                return rhs.auraBalance - lhs.auraBalance;
            }
            if (rhs.wins !== lhs.wins) {
                return rhs.wins - lhs.wins;
            }
            return lhs.displayName.localeCompare(rhs.displayName);
        })
            .slice(0, 50)
            .map((entry, index) => ({
            rank: index + 1,
            ...entry,
        }));
        res.json({
            leaderboard,
            count: leaderboard.length,
        });
    }
    catch (error) {
        console.error('Leaderboard error:', error);
        res.status(500).json({
            error: 'Failed to fetch leaderboard',
            message: error.message,
        });
    }
});
exports.default = router;
//# sourceMappingURL=leaderboard.js.map