"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const uuid_1 = require("uuid");
const Chat_1 = __importDefault(require("../models/Chat"));
const User_1 = __importDefault(require("../models/User"));
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
        // Ensure user exists and has this chat in their joinedChatIds
        let user = await User_1.default.findById(userId);
        if (!user) {
            user = new User_1.default({
                _id: userId,
                appleUUID: appleUUID || undefined,
                joinedChatIds: [chat._id],
            });
            await user.save();
        }
        else {
            // Update appleUUID if provided (it can change per device)
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
router.post('/create', async (req, res) => {
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
router.post('/join', async (req, res) => {
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
exports.default = router;
//# sourceMappingURL=chat.js.map