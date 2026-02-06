/**
 * Chat Service - Join Request Logic
 *
 * Handles join requests and voting for virtual chat membership.
 */

import JoinRequest from '../models/JoinRequest';
import JoinRequestVote from '../models/JoinRequestVote';
import ChatMember from '../models/ChatMember';
import Chat from '../models/Chat';
import User from '../models/User';
import { IJoinRequest } from '../types';

/**
 * Create a join request for a chat
 */
export async function createJoinRequest(params: {
  chatId: string;
  userId: string;
  reason?: string;
  betId?: string;
}): Promise<IJoinRequest> {
  const { chatId, userId, reason, betId } = params;

  // Check if chat exists
  const chat = await Chat.findById(chatId);
  if (!chat) {
    throw new Error('Chat not found');
  }

  // Check if user exists
  const user = await User.findById(userId);
  if (!user) {
    throw new Error('User not found');
  }

  // Check if already a member
  const existingMember = await ChatMember.findOne({ chatId, userId });
  if (existingMember) {
    throw new Error('You are already a member of this chat');
  }

  // Check if pending request already exists
  const existingRequest = await JoinRequest.findOne({
    chatId,
    userId,
    status: 'pending'
  });
  if (existingRequest) {
    throw new Error('You already have a pending request for this chat');
  }

  // Create request
  const requestId = `req_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;

  const request = await JoinRequest.create({
    requestId,
    chatId,
    userId,
    reason: reason?.trim() || undefined,
    betId: betId || undefined,
    status: 'pending'
  });

  return request;
}

/**
 * Vote on a join request
 */
export async function voteOnJoinRequest(params: {
  requestId: string;
  voterId: string;
  vote: 'approve' | 'deny';
}): Promise<{
  vote: any;
  request: IJoinRequest;
  resolved: boolean;
  outcome?: 'approved' | 'denied';
}> {
  const { requestId, voterId, vote } = params;

  // Get request
  const request = await JoinRequest.findOne({ requestId });
  if (!request) {
    throw new Error('Join request not found');
  }

  if (request.status !== 'pending') {
    throw new Error(`Request is already ${request.status}`);
  }

  // Verify voter is a member of the chat
  const voterMember = await ChatMember.findOne({
    chatId: request.chatId,
    userId: voterId
  });
  if (!voterMember) {
    throw new Error('Only chat members can vote on join requests');
  }

  // Check if already voted
  const existingVote = await JoinRequestVote.findOne({
    requestId,
    voterId
  });
  if (existingVote) {
    throw new Error('You have already voted on this request');
  }

  // Record vote
  const voteId = `vote_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;

  const voteRecord = await JoinRequestVote.create({
    voteId,
    requestId,
    voterId,
    vote
  });

  // Count votes
  const totalMembers = await ChatMember.countDocuments({ chatId: request.chatId });
  const approvals = await JoinRequestVote.countDocuments({
    requestId,
    vote: 'approve'
  });
  const denials = await JoinRequestVote.countDocuments({
    requestId,
    vote: 'deny'
  });

  // Simple majority needed (> 50%)
  const majorityNeeded = Math.floor(totalMembers / 2) + 1;

  let resolved = false;
  let outcome: 'approved' | 'denied' | undefined;

  // Check if majority reached
  if (approvals >= majorityNeeded) {
    // Approved! Add as virtual member
    request.status = 'approved';
    request.resolvedAt = new Date();
    await request.save();

    // Add to chat_members as virtual member
    await ChatMember.create({
      chatId: request.chatId,
      userId: request.userId,
      membershipType: 'virtual',
      role: 'member'
    });

    resolved = true;
    outcome = 'approved';
  } else if (denials >= majorityNeeded) {
    // Denied
    request.status = 'denied';
    request.resolvedAt = new Date();
    await request.save();

    resolved = true;
    outcome = 'denied';
  }

  return {
    vote: voteRecord,
    request,
    resolved,
    outcome
  };
}

/**
 * Get pending join requests for a chat
 */
export async function getPendingRequests(chatId: string): Promise<any[]> {
  const requests = await JoinRequest.find({
    chatId,
    status: 'pending'
  }).sort({ createdAt: -1 });

  // Enrich with user data and vote counts
  const enrichedRequests = await Promise.all(
    requests.map(async (req) => {
      const user = await User.findById(req.userId).select(
        'firstName lastName profilePicture vibeScore betsCreated betsCompleted betsFailed calloutsIgnored'
      );

      const votes = await JoinRequestVote.find({ requestId: req.requestId });
      const approvals = votes.filter(v => v.vote === 'approve').length;
      const denials = votes.filter(v => v.vote === 'deny').length;

      const totalMembers = await ChatMember.countDocuments({ chatId });

      return {
        requestId: req.requestId,
        chatId: req.chatId,
        reason: req.reason,
        betId: req.betId,
        status: req.status,
        createdAt: req.createdAt,
        user: user ? {
          id: user._id,
          name: `${user.firstName || ''} ${user.lastName || ''}`.trim() || 'Anonymous',
          profilePicture: user.profilePicture,
          vibeScore: user.vibeScore ?? 100,
          winRate: user.betsCreated
            ? Math.round(((user.betsCompleted ?? 0) / user.betsCreated) * 100)
            : 0,
          duckRate: (user as any).calloutsReceived
            ? Math.round(((user.calloutsIgnored ?? 0) / (user as any).calloutsReceived) * 100)
            : 0
        } : null,
        votes: {
          approvals,
          denials,
          total: votes.length,
          needed: Math.floor(totalMembers / 2) + 1
        }
      };
    })
  );

  return enrichedRequests;
}

/**
 * Get a user's join request for a specific chat
 */
export async function getUserRequest(
  chatId: string,
  userId: string
): Promise<IJoinRequest | null> {
  return await JoinRequest.findOne({
    chatId,
    userId,
    status: 'pending'
  });
}

/**
 * Cancel a pending join request
 */
export async function cancelJoinRequest(
  requestId: string,
  userId: string
): Promise<void> {
  const request = await JoinRequest.findOne({ requestId });

  if (!request) {
    throw new Error('Join request not found');
  }

  if (request.userId !== userId) {
    throw new Error('You can only cancel your own requests');
  }

  if (request.status !== 'pending') {
    throw new Error(`Cannot cancel ${request.status} request`);
  }

  // Delete the request and all votes
  await JoinRequestVote.deleteMany({ requestId });
  await JoinRequest.deleteOne({ requestId });
}

/**
 * Check if user has voted on a request
 */
export async function hasUserVoted(
  requestId: string,
  userId: string
): Promise<boolean> {
  const vote = await JoinRequestVote.findOne({ requestId, voterId: userId });
  return !!vote;
}
