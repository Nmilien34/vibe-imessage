"use strict";
/**
 * Feed Service - Discovery & Feed Generation
 *
 * Generates personalized feeds based on:
 * 1. Bets from chats user is IN (full access)
 * 2. Bets from past connections (view-only)
 * 3. Bets from approved contacts (view-only)
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateFeed = generateFeed;
exports.getVisibilitySettings = getVisibilitySettings;
exports.grantVisibility = grantVisibility;
exports.revokeVisibility = revokeVisibility;
exports.createConnection = createConnection;
const Bet_1 = __importDefault(require("../models/Bet"));
const User_1 = __importDefault(require("../models/User"));
const ChatMember_1 = __importDefault(require("../models/ChatMember"));
const UserConnection_1 = __importDefault(require("../models/UserConnection"));
const VisibilityPermission_1 = __importDefault(require("../models/VisibilityPermission"));
const betService_1 = require("./betService");
const chatMembershipService_1 = require("./chatMembershipService");
/**
 * Generate personalized feed for a user
 */
async function generateFeed(params) {
    const { userId, limit = 20, offset = 0, status = 'active' } = params;
    const user = await User_1.default.findById(userId).select('joinedChatIds');
    // Get all chat IDs where user is a member (full access)
    let memberships = await ChatMember_1.default.find({ userId });
    // Repair legacy data where only User.joinedChatIds was populated.
    if (memberships.length === 0 && user?.joinedChatIds?.length) {
        await Promise.all(user.joinedChatIds.map(chatId => (0, chatMembershipService_1.ensureChatMembership)({
            chatId,
            userId,
            membershipType: 'full',
        })));
        memberships = await ChatMember_1.default.find({ userId });
    }
    const memberChatIds = memberships.length > 0
        ? memberships.map(m => m.chatId)
        : (user?.joinedChatIds || []);
    // Get past connections (users who shared chats with this user)
    const connections = await UserConnection_1.default.find({
        $or: [{ userId1: userId }, { userId2: userId }]
    });
    const connectedUserIds = connections.map(c => c.userId1 === userId ? c.userId2 : c.userId1);
    // Get contacts who user has granted visibility to (and vice versa)
    const visibilityGrants = await VisibilityPermission_1.default.find({
        $or: [
            { userId: userId, revokedAt: null },
            { visibleToUserId: userId, revokedAt: null }
        ]
    });
    // Build set of users who can see this user's bets
    const contactUserIds = [];
    for (const grant of visibilityGrants) {
        if (grant.userId === userId) {
            // User granted visibility to someone
            contactUserIds.push(grant.visibleToUserId);
        }
        else {
            // Someone granted visibility to user
            contactUserIds.push(grant.userId);
        }
    }
    // Deduplicate
    const allVisibleUserIds = [...new Set([...connectedUserIds, ...contactUserIds])];
    // Query 1: Bets from chats user is in (full access)
    const memberBets = await Bet_1.default.find({
        chatId: { $in: memberChatIds },
        status
    }).sort({ createdAt: -1 });
    // Query 2: Bets from connected/contact users (view only)
    // Only include bets NOT already in member chats
    const viewOnlyBets = await Bet_1.default.find({
        creatorId: { $in: allVisibleUserIds },
        chatId: { $nin: memberChatIds },
        status
    }).sort({ createdAt: -1 });
    const formatBet = (bet) => ({
        betId: bet.betId,
        chatId: bet.chatId,
        creatorId: bet.creatorId,
        betType: bet.betType,
        description: bet.description,
        deadline: bet.deadline,
        targetUserId: bet.targetUserId,
        creationCost: bet.creationCost,
        status: bet.status,
        createdAt: bet.createdAt
    });
    // Hydrate all cards concurrently to avoid O(n) serialized DB latency.
    const memberFeedBets = await Promise.all(memberBets.map(async (bet) => {
        const [totals, participants] = await Promise.all([
            (0, betService_1.getBetTotals)(bet.betId),
            (0, betService_1.getBetParticipants)(bet.betId),
        ]);
        return {
            bet: formatBet(bet),
            accessLevel: 'full',
            source: 'chat_member',
            canBet: true,
            totals,
            participantCount: participants.length
        };
    }));
    const viewOnlyFeedBets = await Promise.all(viewOnlyBets.map(async (bet) => {
        const [totals, participants] = await Promise.all([
            (0, betService_1.getBetTotals)(bet.betId),
            (0, betService_1.getBetParticipants)(bet.betId),
        ]);
        const source = connectedUserIds.includes(bet.creatorId)
            ? 'past_connection'
            : 'contact';
        return {
            bet: formatBet(bet),
            accessLevel: 'view_only',
            source,
            canBet: false,
            totals,
            participantCount: participants.length
        };
    }));
    // Combine and sort by urgency/freshness
    const allBets = [...memberFeedBets, ...viewOnlyFeedBets];
    // Sort by:
    // 1. Urgency (bets ending soon first for active bets)
    // 2. Stakes (high Aura pots)
    // 3. Freshness (recent first)
    allBets.sort((a, b) => {
        // Active bets: sort by deadline (soonest first)
        if (status === 'active') {
            const aDeadline = new Date(a.bet.deadline).getTime();
            const bDeadline = new Date(b.bet.deadline).getTime();
            // Prioritize bets ending within 24 hours
            const now = Date.now();
            const aUrgent = aDeadline - now < 24 * 60 * 60 * 1000;
            const bUrgent = bDeadline - now < 24 * 60 * 60 * 1000;
            if (aUrgent && !bUrgent)
                return -1;
            if (!aUrgent && bUrgent)
                return 1;
            // Then by pot size
            if (a.totals.totalPot !== b.totals.totalPot) {
                return b.totals.totalPot - a.totals.totalPot;
            }
            // Then by deadline
            return aDeadline - bDeadline;
        }
        // Completed/expired: sort by creation date (newest first)
        return new Date(b.bet.createdAt).getTime() - new Date(a.bet.createdAt).getTime();
    });
    // Apply pagination
    const total = allBets.length;
    const paginatedBets = allBets.slice(offset, offset + limit);
    const hasMore = offset + limit < total;
    return {
        bets: paginatedBets,
        total,
        hasMore
    };
}
/**
 * Get visibility settings for a user
 */
async function getVisibilitySettings(userId) {
    // Get past connections
    const connections = await UserConnection_1.default.find({
        $or: [{ userId1: userId }, { userId2: userId }]
    });
    const pastConnectionSettings = await Promise.all(connections.map(async (conn) => {
        const connectedUserId = conn.userId1 === userId ? conn.userId2 : conn.userId1;
        // Check if visibility is granted
        const permission = await VisibilityPermission_1.default.findOne({
            userId: userId,
            visibleToUserId: connectedUserId,
            source: 'past_connection',
            revokedAt: null
        });
        return {
            userId: connectedUserId,
            chatId: conn.sourceChatId,
            visible: !!permission
        };
    }));
    // Get contact-based permissions
    const contactPermissions = await VisibilityPermission_1.default.find({
        userId: userId,
        source: 'contact',
        revokedAt: null
    });
    const contactSettings = contactPermissions.map(p => ({
        userId: p.visibleToUserId,
        visible: true
    }));
    return {
        pastConnections: pastConnectionSettings,
        contacts: contactSettings
    };
}
/**
 * Grant visibility to a user
 */
async function grantVisibility(params) {
    const { userId, visibleToUserId, source } = params;
    // Check if already granted
    const existing = await VisibilityPermission_1.default.findOne({
        userId,
        visibleToUserId,
        revokedAt: null
    });
    if (existing) {
        // Already granted
        return;
    }
    // Check if was previously revoked
    const revoked = await VisibilityPermission_1.default.findOne({
        userId,
        visibleToUserId,
        revokedAt: { $ne: null }
    });
    if (revoked) {
        // Re-grant
        revoked.revokedAt = undefined;
        revoked.grantedAt = new Date();
        await revoked.save();
        return;
    }
    // Create new permission
    const permissionId = `perm_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    await VisibilityPermission_1.default.create({
        permissionId,
        userId,
        visibleToUserId,
        source
    });
}
/**
 * Revoke visibility from a user
 */
async function revokeVisibility(params) {
    const { userId, visibleToUserId } = params;
    await VisibilityPermission_1.default.updateOne({ userId, visibleToUserId, revokedAt: null }, { $set: { revokedAt: new Date() } });
}
/**
 * Create user connection from shared chat
 */
async function createConnection(params) {
    const { userId1, userId2, sourceChatId } = params;
    // Normalize order
    const [user1, user2] = [userId1, userId2].sort();
    // Check if exists
    const existing = await UserConnection_1.default.findOne({
        userId1: user1,
        userId2: user2
    });
    if (existing) {
        // Update last interaction
        existing.lastInteraction = new Date();
        await existing.save();
        return;
    }
    // Create new connection
    const connectionId = `conn_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    await UserConnection_1.default.create({
        connectionId,
        userId1: user1,
        userId2: user2,
        sourceChatId
    });
    // Auto-grant visibility for past connections
    await grantVisibility({
        userId: user1,
        visibleToUserId: user2,
        source: 'past_connection'
    });
    await grantVisibility({
        userId: user2,
        visibleToUserId: user1,
        source: 'past_connection'
    });
}
//# sourceMappingURL=feedService.js.map