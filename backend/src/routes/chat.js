const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const Chat = require('../models/Chat');
const User = require('../models/User');
const Vibe = require('../models/Vibe');

/**
 * Chat Routes - The "Virtual Room" System
 *
 * These endpoints manage our distributed chat ID system that works around
 * iMessage's lack of persistent conversation identifiers.
 */

/**
 * @route   POST /api/chat/create
 * @desc    Create a new virtual chat room
 * @body    { userId, title?, type? }
 * @returns { chatId, chat }
 */
router.post('/create', async (req, res) => {
  try {
    const { userId, title, type = 'group' } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    // Generate a unique chat ID
    const chatId = `chat_${uuidv4()}`;

    // Create the chat
    const chat = new Chat({
      _id: chatId,
      title: title || null,
      members: [userId],
      type,
      createdBy: userId,
      lastActivityAt: new Date(),
    });

    await chat.save();

    // Add this chat to the user's joinedChatIds
    let user = await User.findById(userId);
    if (!user) {
      // Create user if doesn't exist
      user = new User({
        _id: userId,
        joinedChatIds: [chatId],
      });
      await user.save();
    } else {
      await user.joinChat(chatId);
    }

    res.status(201).json({
      chatId,
      chat,
    });
  } catch (error) {
    console.error('Create chat error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * @route   POST /api/chat/join
 * @desc    Join an existing chat (called when receiving a Vibe message)
 * @body    { userId, chatId }
 * @returns { success, chat }
 */
router.post('/join', async (req, res) => {
  try {
    const { userId, chatId } = req.body;

    if (!userId || !chatId) {
      return res.status(400).json({ error: 'userId and chatId are required' });
    }

    // Find or create the chat
    let chat = await Chat.findById(chatId);
    if (!chat) {
      // Chat doesn't exist yet (edge case - create it)
      chat = new Chat({
        _id: chatId,
        members: [userId],
        lastActivityAt: new Date(),
      });
      await chat.save();
    } else {
      // Add user to chat members
      await chat.addMember(userId);
    }

    // Find or create the user
    let user = await User.findById(userId);
    if (!user) {
      user = new User({
        _id: userId,
        joinedChatIds: [chatId],
      });
      await user.save();
    } else {
      await user.joinChat(chatId);
    }

    res.json({
      success: true,
      chat,
    });
  } catch (error) {
    console.error('Join chat error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * @route   GET /api/chat/:chatId
 * @desc    Get chat details
 * @returns { chat }
 */
router.get('/:chatId', async (req, res) => {
  try {
    const { chatId } = req.params;

    const chat = await Chat.findById(chatId);
    if (!chat) {
      return res.status(404).json({ error: 'Chat not found' });
    }

    res.json(chat);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * @route   GET /api/chat/:chatId/members
 * @desc    Get chat members
 * @returns { members: User[] }
 */
router.get('/:chatId/members', async (req, res) => {
  try {
    const { chatId } = req.params;

    const chat = await Chat.findById(chatId);
    if (!chat) {
      return res.status(404).json({ error: 'Chat not found' });
    }

    const members = await User.find({ _id: { $in: chat.members } });

    res.json({ members });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * @route   GET /api/chat/user/:userId/chats
 * @desc    Get all chats for a user
 * @returns { chats: Chat[] }
 */
router.get('/user/:userId/chats', async (req, res) => {
  try {
    const { userId } = req.params;

    const user = await User.findById(userId);
    if (!user) {
      return res.json({ chats: [] });
    }

    const chats = await Chat.find({ _id: { $in: user.joinedChatIds } })
      .sort({ lastActivityAt: -1 });

    res.json({ chats });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
