"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ensureChatMembership = ensureChatMembership;
exports.ensureChatMembershipIfKnown = ensureChatMembershipIfKnown;
const uuid_1 = require("uuid");
const Chat_1 = __importDefault(require("../models/Chat"));
const ChatMember_1 = __importDefault(require("../models/ChatMember"));
const User_1 = __importDefault(require("../models/User"));
function deriveRole(chatCreatedBy, userId, explicitRole) {
    if (explicitRole)
        return explicitRole;
    return chatCreatedBy === userId ? 'admin' : 'member';
}
function isDuplicateKeyError(error) {
    return (typeof error === 'object' &&
        error !== null &&
        'code' in error &&
        error.code === 11000);
}
/**
 * Guarantees ChatMember + Chat.members + User.joinedChatIds are in sync.
 * Idempotent and safe to call repeatedly.
 */
async function ensureChatMembership(params) {
    const { chatId, userId, membershipType = 'full', role } = params;
    const [chat, user] = await Promise.all([
        Chat_1.default.findById(chatId),
        User_1.default.findById(userId),
    ]);
    if (!chat || !user) {
        return false;
    }
    let chatChanged = false;
    if (!chat.members.includes(userId)) {
        chat.members.push(userId);
        chatChanged = true;
    }
    let userChanged = false;
    if (!user.joinedChatIds.includes(chatId)) {
        user.joinedChatIds.push(chatId);
        userChanged = true;
    }
    const desiredRole = deriveRole(chat.createdBy, userId, role);
    let membership = await ChatMember_1.default.findOne({ chatId, userId });
    if (!membership) {
        try {
            await ChatMember_1.default.create({
                memberId: `member_${(0, uuid_1.v4)()}`,
                chatId,
                userId,
                membershipType,
                role: desiredRole,
                joinedAt: new Date(),
            });
        }
        catch (error) {
            // Concurrent join/resolve can race on unique(chatId,userId).
            if (!isDuplicateKeyError(error)) {
                throw error;
            }
        }
        membership = await ChatMember_1.default.findOne({ chatId, userId });
    }
    else {
        let membershipChanged = false;
        // Only upgrade, never downgrade (full > virtual, admin > member)
        if (membershipType === 'full' && membership.membershipType !== 'full') {
            membership.membershipType = 'full';
            membershipChanged = true;
        }
        if (desiredRole === 'admin' && membership.role !== 'admin') {
            membership.role = 'admin';
            membershipChanged = true;
        }
        if (membershipChanged) {
            await membership.save();
        }
    }
    await Promise.all([
        chatChanged ? chat.save() : Promise.resolve(),
        userChanged ? user.save() : Promise.resolve(),
    ]);
    return true;
}
/**
 * Repairs membership only when existing data indicates the user already belongs
 * to the chat (via Chat.members or User.joinedChatIds). Returns false if not.
 */
async function ensureChatMembershipIfKnown(chatId, userId) {
    const existing = await ChatMember_1.default.findOne({ chatId, userId });
    if (existing) {
        return true;
    }
    const [chat, user] = await Promise.all([
        Chat_1.default.findById(chatId).select('members createdBy'),
        User_1.default.findById(userId).select('joinedChatIds'),
    ]);
    if (!chat || !user) {
        return false;
    }
    const hasSignal = chat.members.includes(userId) || user.joinedChatIds.includes(chatId);
    if (!hasSignal) {
        return false;
    }
    return ensureChatMembership({ chatId, userId, membershipType: 'full' });
}
//# sourceMappingURL=chatMembershipService.js.map