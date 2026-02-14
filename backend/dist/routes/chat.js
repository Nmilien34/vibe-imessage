"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const uuid_1 = require("uuid");
const Chat_1 = __importDefault(require("../models/Chat"));
const User_1 = __importDefault(require("../models/User"));
const ChatMember_1 = __importDefault(require("../models/ChatMember"));
const auth_1 = require("../middleware/auth");
const chatService_1 = require("../services/chatService");
const router = express_1.default.Router();
/**
 * @route   POST /api/chat/resolve
 * @desc    Resolve or create a chat - The "Trojan Horse" endpoint
 *          This is the main endpoint the iOS ConversationManager uses.
 *
 *          Logic:
 *          1. If chatId is provided (from URL params), join that chat
 *          2. If only appleUUID is provided, look up if we've seen this user before
 *             and return their most recent chat, or create a new one
 *          3. Always ensures user is a member of the returned chat
 */
router.post('/resolve', async (req, res) => {
    try {
        const { userId, chatId, appleUUID, title } = req.body;
        if (!userId) {
            return res.status(400).json({ error: 'userId is required' });
        }
        let isNew = false;
        let isNewMember = false;
        let chat;
        // CASE 1: chatId provided (user tapped a message bubble with ?chat_id=XYZ)
        if (chatId) {
            chat = await Chat_1.default.findById(chatId);
            if (!chat) {
                // Chat doesn't exist yet, create it
                chat = new Chat_1.default({
                    _id: chatId,
                    title: title || null,
                    members: [userId],
                    lastActivityAt: new Date(),
                });
                await chat.save();
                isNew = true;
                isNewMember = true;
            }
            else {
                // Chat exists, check if user is already a member
                if (!chat.members.includes(userId)) {
                    await chat.addMember(userId);
                    isNewMember = true;
                }
            }
        }
        // CASE 2: No chatId - need to create a new chat
        else {
            const newChatId = `chat_${(0, uuid_1.v4)()}`;
            chat = new Chat_1.default({
                _id: newChatId,
                title: title || null,
                members: [userId],
                createdBy: userId,
                lastActivityAt: new Date(),
            });
            await chat.save();
            isNew = true;
            isNewMember = true;
        }
        // Ensure user exists and has this chat in their joinedChatIds.
        // Fallback chain prevents identity split: client sends appleId as userId,
        // but an older doc may have been created with a different _id.
        let user = await User_1.default.findById(userId);
        if (!user) {
            user = await User_1.default.findOne({ appleId: userId });
        }
        if (!user && appleUUID) {
            user = await User_1.default.findOne({ appleUUID });
        }
        if (!user) {
            user = new User_1.default({
                _id: userId,
                appleUUID: appleUUID || undefined,
                joinedChatIds: [chat._id],
            });
            await user.save();
        }
        else {
            if (appleUUID && user.appleUUID !== appleUUID) {
                user.appleUUID = appleUUID;
            }
            await user.joinChat(chat._id);
        }
        const response = {
            chatId: chat._id,
            chat: chat.toObject(),
            isNew,
            isNewMember,
        };
        res.json(response);
    }
    catch (error) {
        console.error('Resolve chat error:', error);
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
/**
 * @route   POST /api/chat/create
 * @desc    Create a new virtual chat room
 */
router.post('/create', auth_1.authMiddleware, async (req, res) => {
    try {
        const { userId, title, type = 'group' } = req.body;
        if (!userId) {
            return res.status(400).json({ error: 'userId is required' });
        }
        const chatId = `chat_${(0, uuid_1.v4)()}`;
        const chat = new Chat_1.default({
            _id: chatId,
            title: title || null,
            members: [userId],
            type,
            createdBy: userId,
            lastActivityAt: new Date(),
        });
        await chat.save();
        let user = await User_1.default.findById(userId);
        if (!user) {
            user = await User_1.default.findOne({ appleId: userId });
        }
        if (!user) {
            user = new User_1.default({
                _id: userId,
                joinedChatIds: [chatId],
            });
            await user.save();
        }
        else {
            await user.joinChat(chatId);
        }
        const response = {
            chatId,
            chat: chat.toObject(),
            isNew: true,
        };
        res.status(201).json(response);
    }
    catch (error) {
        console.error('Create chat error:', error);
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
/**
 * @route   POST /api/chat/join
 * @desc    Join an existing chat
 */
router.post('/join', auth_1.authMiddleware, async (req, res) => {
    try {
        const { userId, chatId } = req.body;
        if (!userId || !chatId) {
            return res.status(400).json({ error: 'userId and chatId are required' });
        }
        let chat = await Chat_1.default.findById(chatId);
        if (!chat) {
            chat = new Chat_1.default({
                _id: chatId,
                members: [userId],
                lastActivityAt: new Date(),
            });
            await chat.save();
        }
        else {
            await chat.addMember(userId);
        }
        let user = await User_1.default.findById(userId);
        if (!user) {
            user = await User_1.default.findOne({ appleId: userId });
        }
        if (!user) {
            user = new User_1.default({
                _id: userId,
                joinedChatIds: [chatId],
            });
            await user.save();
        }
        else {
            await user.joinChat(chatId);
        }
        const response = {
            success: true,
            chat: chat.toObject(),
            isNewMember: !chat.members.includes(userId), // Note: This will be false since we just added them
        };
        res.json(response);
    }
    catch (error) {
        console.error('Join chat error:', error);
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
/**
 * @route   GET /api/chat/:chatId
 * @desc    Get chat details
 */
router.get('/:chatId', async (req, res) => {
    try {
        const { chatId } = req.params;
        const chat = await Chat_1.default.findById(chatId);
        if (!chat) {
            return res.status(404).json({ error: 'Chat not found' });
        }
        res.json(chat);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
/**
 * @route   GET /api/chat/:chatId/members
 * @desc    Get chat members
 */
router.get('/:chatId/members', async (req, res) => {
    try {
        const { chatId } = req.params;
        const chat = await Chat_1.default.findById(chatId);
        if (!chat) {
            return res.status(404).json({ error: 'Chat not found' });
        }
        const members = await User_1.default.find({ _id: { $in: chat.members } });
        const response = {
            members: members.map(m => m.toObject()),
        };
        res.json(response);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
/**
 * @route   GET /api/chat/user/:userId/chats
 * @desc    Get all chats for a user
 */
router.get('/user/:userId/chats', async (req, res) => {
    try {
        const { userId } = req.params;
        const user = await User_1.default.findById(userId);
        if (!user) {
            const emptyResponse = { chats: [] };
            return res.json(emptyResponse);
        }
        const chats = await Chat_1.default.find({ _id: { $in: user.joinedChatIds } }).sort({ lastActivityAt: -1 });
        const response = {
            chats: chats.map(c => c.toObject()),
        };
        res.json(response);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
// ═══════════════════════════════════════════════════════════
// JOIN REQUEST ROUTES
// ═══════════════════════════════════════════════════════════
/**
 * @route   POST /api/chat/:chatId/request
 * @desc    Request to join a chat
 * @access  Private (JWT required)
 */
router.post('/:chatId/request', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { chatId } = req.params;
        const { reason, betId } = req.body;
        const request = await (0, chatService_1.createJoinRequest)({
            chatId,
            userId,
            reason,
            betId
        });
        res.status(201).json({
            success: true,
            request: {
                requestId: request.requestId,
                chatId: request.chatId,
                userId: request.userId,
                reason: request.reason,
                betId: request.contextBetId,
                status: request.status,
                createdAt: request.createdAt
            },
            message: 'Join request submitted. Waiting for member approval.'
        });
    }
    catch (error) {
        console.error('Join request error:', error);
        if (error.message === 'Chat not found') {
            return res.status(404).json({ error: error.message });
        }
        if (error.message?.includes('already a member') ||
            error.message?.includes('already have a pending request')) {
            return res.status(409).json({ error: error.message });
        }
        res.status(500).json({
            error: 'Failed to create join request',
            message: error.message
        });
    }
});
/**
 * @route   GET /api/chat/:chatId/requests
 * @desc    Get pending join requests for a chat
 * @access  Private (JWT required, must be member)
 */
router.get('/:chatId/requests', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { chatId } = req.params;
        // Verify user is a member
        const member = await ChatMember_1.default.findOne({ chatId, userId });
        if (!member) {
            return res.status(403).json({
                error: 'Only chat members can view join requests'
            });
        }
        const requests = await (0, chatService_1.getPendingRequests)(chatId);
        res.json({
            requests,
            count: requests.length
        });
    }
    catch (error) {
        console.error('Get requests error:', error);
        res.status(500).json({
            error: 'Failed to get join requests',
            message: error.message
        });
    }
});
/**
 * @route   POST /api/chat/requests/:requestId/vote
 * @desc    Vote on a join request
 * @access  Private (JWT required, must be member)
 */
router.post('/requests/:requestId/vote', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { requestId } = req.params;
        const { vote } = req.body;
        // Validate vote
        if (!vote || !['approve', 'deny'].includes(vote)) {
            return res.status(400).json({
                error: 'Invalid vote',
                allowed: ['approve', 'deny']
            });
        }
        const result = await (0, chatService_1.voteOnJoinRequest)({
            requestId,
            voterId: userId,
            vote
        });
        res.json({
            success: true,
            vote: {
                voteId: result.vote.voteId,
                vote: result.vote.vote
            },
            request: {
                requestId: result.request.requestId,
                status: result.request.status
            },
            resolved: result.resolved,
            outcome: result.outcome,
            message: result.resolved
                ? `Request ${result.outcome}!`
                : 'Vote recorded. Waiting for more votes.'
        });
    }
    catch (error) {
        console.error('Vote error:', error);
        if (error.message === 'Join request not found') {
            return res.status(404).json({ error: error.message });
        }
        if (error.message?.includes('already voted') ||
            error.message?.includes('already approved') ||
            error.message?.includes('already denied')) {
            return res.status(409).json({ error: error.message });
        }
        if (error.message?.includes('Only chat members')) {
            return res.status(403).json({ error: error.message });
        }
        res.status(500).json({
            error: 'Failed to vote',
            message: error.message
        });
    }
});
/**
 * @route   DELETE /api/chat/requests/:requestId
 * @desc    Cancel a pending join request
 * @access  Private (JWT required, must be requester)
 */
router.delete('/requests/:requestId', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { requestId } = req.params;
        await (0, chatService_1.cancelJoinRequest)(requestId, userId);
        res.json({
            success: true,
            message: 'Join request cancelled'
        });
    }
    catch (error) {
        console.error('Cancel request error:', error);
        if (error.message === 'Join request not found') {
            return res.status(404).json({ error: error.message });
        }
        if (error.message?.includes('only cancel your own')) {
            return res.status(403).json({ error: error.message });
        }
        res.status(500).json({
            error: 'Failed to cancel request',
            message: error.message
        });
    }
});
/**
 * @route   GET /api/chat/:chatId/my-request
 * @desc    Get current user's pending request for a chat
 * @access  Private (JWT required)
 */
router.get('/:chatId/my-request', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { chatId } = req.params;
        const request = await (0, chatService_1.getUserRequest)(chatId, userId);
        if (!request) {
            return res.json({
                hasRequest: false,
                request: null
            });
        }
        res.json({
            hasRequest: true,
            request: {
                requestId: request.requestId,
                status: request.status,
                reason: request.reason,
                createdAt: request.createdAt
            }
        });
    }
    catch (error) {
        console.error('Get my request error:', error);
        res.status(500).json({
            error: 'Failed to get request',
            message: error.message
        });
    }
});
exports.default = router;
//# sourceMappingURL=chat.js.map