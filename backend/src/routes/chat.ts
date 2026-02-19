import express, { Request, Response, Router } from 'express';
import { v4 as uuidv4 } from 'uuid';
import Chat from '../models/Chat';
import User from '../models/User';
import ChatMember from '../models/ChatMember';
import {
  ChatType,
  CreateChatResponse,
  JoinChatResponse,
  ResolveChatRequest,
  ResolveChatResponse,
  UserChatsResponse,
  ChatMembersResponse,
} from '../types';
import { authMiddleware } from '../middleware/auth';
import {
  createJoinRequest,
  voteOnJoinRequest,
  getPendingRequests,
  getUserRequest,
  cancelJoinRequest
} from '../services/chatService';
import {
  ensureChatMembership,
  ensureChatMembershipIfKnown,
} from '../services/chatMembershipService';

const router: Router = express.Router();

interface CreateChatRequest {
  userId: string;
  title?: string;
  type?: ChatType;
}

interface JoinChatRequest {
  userId: string;
  chatId: string;
}

function isLikelyBackendChatId(chatId: string): boolean {
  return chatId.startsWith('chat_') && chatId.length > 'chat_'.length + 8;
}

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
router.post('/resolve', authMiddleware, async (req: Request<{}, {}, ResolveChatRequest>, res: Response) => {
  try {
    const authenticatedUserId = req.userId!;
    const { userId: requestedUserId, chatId, appleUUID, title } = req.body;
    const normalizedUserId = requestedUserId || authenticatedUserId;

    if (requestedUserId && requestedUserId !== authenticatedUserId) {
      return res.status(403).json({ error: 'Cannot resolve chat for another user' });
    }

    if (chatId && !isLikelyBackendChatId(chatId)) {
      return res.status(400).json({ error: 'Invalid chatId format' });
    }

    // Resolve canonical user first so all downstream membership writes
    // (Chat.members, User.joinedChatIds, ChatMember.userId) stay aligned.
    let user = await User.findById(normalizedUserId);
    if (!user) {
      user = await User.findOne({ appleId: normalizedUserId });
    }
    if (!user && appleUUID) {
      user = await User.findOne({ appleUUID });
    }
    if (!user) {
      user = new User({
        _id: normalizedUserId,
        appleId: normalizedUserId,
        appleUUID: appleUUID || undefined,
        joinedChatIds: [],
      });
      await user.save();
    } else {
      let userChanged = false;
      if (appleUUID && user.appleUUID !== appleUUID) {
        user.appleUUID = appleUUID;
        userChanged = true;
      }
      if (!user.appleId && normalizedUserId !== user._id) {
        user.appleId = normalizedUserId;
        userChanged = true;
      }
      if (userChanged) {
        await user.save();
      }
    }
    const userId = user._id.toString();

    let isNew = false;
    let isNewMember = false;
    let chat;

    // CASE 1: chatId provided (user tapped a message bubble with ?chat_id=XYZ)
    if (chatId) {
      chat = await Chat.findById(chatId);

      if (!chat) {
        // Chat doesn't exist yet, create it
        chat = new Chat({
          _id: chatId,
          title: title || null,
          members: [userId],
          createdBy: userId,
          lastActivityAt: new Date(),
        });
        await chat.save();
        isNew = true;
        isNewMember = true;
      } else {
        // Chat exists, check if user is already a member
        if (!chat.members.includes(userId)) {
          await chat.addMember(userId);
          isNewMember = true;
        }
      }
    }
    // CASE 2: No chatId - need to create a new chat
    else {
      const newChatId = `chat_${uuidv4()}`;
      chat = new Chat({
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

    await user.joinChat(chat._id.toString());

    await ensureChatMembership({
      chatId: chat._id.toString(),
      userId,
      membershipType: 'full',
    });

    const response: ResolveChatResponse = {
      chatId: chat._id,
      chat: chat.toObject(),
      isNew,
      isNewMember,
    };

    res.json(response);
  } catch (error) {
    console.error('Resolve chat error:', error);
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   POST /api/chat/create
 * @desc    Create a new virtual chat room
 */
router.post('/create', authMiddleware, async (req: Request<{}, {}, CreateChatRequest>, res: Response) => {
  try {
    const authenticatedUserId = req.userId!;
    const { userId: requestedUserId, title, type = 'group' } = req.body;
    const userId = authenticatedUserId;

    if (requestedUserId && requestedUserId !== authenticatedUserId) {
      return res.status(403).json({ error: 'Cannot create chat for another user' });
    }

    const chatId = `chat_${uuidv4()}`;

    const chat = new Chat({
      _id: chatId,
      title: title || null,
      members: [userId],
      type,
      createdBy: userId,
      lastActivityAt: new Date(),
    });

    await chat.save();

    let user = await User.findById(userId);
    if (!user) {
      user = await User.findOne({ appleId: userId });
    }
    if (!user) {
      user = new User({
        _id: userId,
        joinedChatIds: [chatId],
      });
      await user.save();
    } else {
      await user.joinChat(chatId);
    }

    await ensureChatMembership({
      chatId,
      userId,
      membershipType: 'full',
      role: 'admin',
    });

    const response: CreateChatResponse = {
      chatId,
      chat: chat.toObject(),
      isNew: true,
    };

    res.status(201).json(response);
  } catch (error) {
    console.error('Create chat error:', error);
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   POST /api/chat/join
 * @desc    Join an existing chat
 */
router.post('/join', authMiddleware, async (req: Request<{}, {}, JoinChatRequest>, res: Response) => {
  try {
    const authenticatedUserId = req.userId!;
    const { userId: requestedUserId, chatId } = req.body;
    const userId = authenticatedUserId;

    if (!chatId) {
      return res.status(400).json({ error: 'chatId is required' });
    }

    if (requestedUserId && requestedUserId !== authenticatedUserId) {
      return res.status(403).json({ error: 'Cannot join chat for another user' });
    }

    let chat = await Chat.findById(chatId);
    const wasMember = !!chat?.members.includes(userId);

    if (!chat) {
      chat = new Chat({
        _id: chatId,
        members: [userId],
        createdBy: userId,
        lastActivityAt: new Date(),
      });
      await chat.save();
    } else if (!wasMember) {
      await chat.addMember(userId);
    }

    let user = await User.findById(userId);
    if (!user) {
      user = await User.findOne({ appleId: userId });
    }
    if (!user) {
      user = new User({
        _id: userId,
        joinedChatIds: [chatId],
      });
      await user.save();
    } else {
      await user.joinChat(chatId);
    }

    await ensureChatMembership({
      chatId,
      userId,
      membershipType: 'full',
    });

    const response: JoinChatResponse = {
      success: true,
      chat: chat.toObject(),
      isNewMember: !wasMember,
    };

    res.json(response);
  } catch (error) {
    console.error('Join chat error:', error);
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   GET /api/chat/:chatId
 * @desc    Get chat details
 */
router.get('/:chatId', async (req: Request<{ chatId: string }>, res: Response) => {
  try {
    const { chatId } = req.params;

    const chat = await Chat.findById(chatId);
    if (!chat) {
      return res.status(404).json({ error: 'Chat not found' });
    }

    res.json(chat);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   GET /api/chat/:chatId/members
 * @desc    Get chat members
 */
router.get('/:chatId/members', async (req: Request<{ chatId: string }>, res: Response) => {
  try {
    const { chatId } = req.params;

    const chat = await Chat.findById(chatId);
    if (!chat) {
      return res.status(404).json({ error: 'Chat not found' });
    }

    const members = await User.find({ _id: { $in: chat.members } });

    const response: ChatMembersResponse = {
      members: members.map(m => m.toObject()),
    };

    res.json(response);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

/**
 * @route   GET /api/chat/user/:userId/chats
 * @desc    Get all chats for a user
 */
router.get('/user/:userId/chats', async (req: Request<{ userId: string }>, res: Response) => {
  try {
    const { userId } = req.params;

    const user = await User.findById(userId);
    if (!user) {
      const emptyResponse: UserChatsResponse = { chats: [] };
      return res.json(emptyResponse);
    }

    const chats = await Chat.find({ _id: { $in: user.joinedChatIds } }).sort({ lastActivityAt: -1 });

    const response: UserChatsResponse = {
      chats: chats.map(c => c.toObject()),
    };

    res.json(response);
  } catch (error) {
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
router.post('/:chatId/request', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { chatId } = req.params;
    const { reason, betId } = req.body;

    const request = await createJoinRequest({
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

  } catch (error: any) {
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
router.get('/:chatId/requests', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { chatId } = req.params;

    // Verify user is a member
    let member = await ChatMember.findOne({ chatId, userId });
    if (!member) {
      const repaired = await ensureChatMembershipIfKnown(chatId, userId);
      if (repaired) {
        member = await ChatMember.findOne({ chatId, userId });
      }
    }
    if (!member) {
      return res.status(403).json({
        error: 'Only chat members can view join requests'
      });
    }

    const requests = await getPendingRequests(chatId);

    res.json({
      requests,
      count: requests.length
    });

  } catch (error: any) {
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
router.post('/requests/:requestId/vote', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { requestId } = req.params;
    const { vote } = req.body;

    // Validate vote
    if (!vote || !['approve', 'deny'].includes(vote)) {
      return res.status(400).json({
        error: 'Invalid vote',
        allowed: ['approve', 'deny']
      });
    }

    const result = await voteOnJoinRequest({
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

  } catch (error: any) {
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
router.delete('/requests/:requestId', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { requestId } = req.params;

    await cancelJoinRequest(requestId, userId);

    res.json({
      success: true,
      message: 'Join request cancelled'
    });

  } catch (error: any) {
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
router.get('/:chatId/my-request', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { chatId } = req.params;

    const request = await getUserRequest(chatId, userId);

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

  } catch (error: any) {
    console.error('Get my request error:', error);
    res.status(500).json({
      error: 'Failed to get request',
      message: error.message
    });
  }
});

export default router;
