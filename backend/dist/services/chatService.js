"use strict";
/**
 * Chat Service - Join Request Logic
 *
 * Handles join requests and voting for virtual chat membership.
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.createJoinRequest = createJoinRequest;
exports.voteOnJoinRequest = voteOnJoinRequest;
exports.getPendingRequests = getPendingRequests;
exports.getUserRequest = getUserRequest;
exports.cancelJoinRequest = cancelJoinRequest;
exports.hasUserVoted = hasUserVoted;
const JoinRequest_1 = __importDefault(require("../models/JoinRequest"));
const JoinRequestVote_1 = __importDefault(require("../models/JoinRequestVote"));
const ChatMember_1 = __importDefault(require("../models/ChatMember"));
const Chat_1 = __importDefault(require("../models/Chat"));
const User_1 = __importDefault(require("../models/User"));
/**
 * Create a join request for a chat
 */
async function createJoinRequest(params) {
    const { chatId, userId, reason, betId } = params;
    // Check if chat exists
    const chat = await Chat_1.default.findById(chatId);
    if (!chat) {
        throw new Error('Chat not found');
    }
    // Check if user exists
    const user = await User_1.default.findById(userId);
    if (!user) {
        throw new Error('User not found');
    }
    // Check if already a member
    const existingMember = await ChatMember_1.default.findOne({ chatId, userId });
    if (existingMember) {
        throw new Error('You are already a member of this chat');
    }
    // Check if pending request already exists
    const existingRequest = await JoinRequest_1.default.findOne({
        chatId,
        userId,
        status: 'pending'
    });
    if (existingRequest) {
        throw new Error('You already have a pending request for this chat');
    }
    // Create request
    const requestId = `req_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    const request = await JoinRequest_1.default.create({
        requestId,
        chatId,
        userId,
        reason: reason?.trim() || undefined,
        contextBetId: betId || undefined,
        status: 'pending'
    });
    return request;
}
/**
 * Vote on a join request
 */
async function voteOnJoinRequest(params) {
    const { requestId, voterId, vote } = params;
    // Get request
    const request = await JoinRequest_1.default.findOne({ requestId });
    if (!request) {
        throw new Error('Join request not found');
    }
    if (request.status !== 'pending') {
        throw new Error(`Request is already ${request.status}`);
    }
    // Verify voter is a member of the chat
    const voterMember = await ChatMember_1.default.findOne({
        chatId: request.chatId,
        userId: voterId
    });
    if (!voterMember) {
        throw new Error('Only chat members can vote on join requests');
    }
    // Check if already voted
    const existingVote = await JoinRequestVote_1.default.findOne({
        requestId,
        voterId
    });
    if (existingVote) {
        throw new Error('You have already voted on this request');
    }
    // Record vote
    const voteId = `vote_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    const voteRecord = await JoinRequestVote_1.default.create({
        voteId,
        requestId,
        voterId,
        decision: vote
    });
    // Count votes
    const totalMembers = await ChatMember_1.default.countDocuments({ chatId: request.chatId });
    const approvals = await JoinRequestVote_1.default.countDocuments({
        requestId,
        decision: 'approve'
    });
    const denials = await JoinRequestVote_1.default.countDocuments({
        requestId,
        decision: 'deny'
    });
    // Simple majority needed (> 50%)
    const majorityNeeded = Math.floor(totalMembers / 2) + 1;
    let resolved = false;
    let outcome;
    // Check if majority reached
    if (approvals >= majorityNeeded) {
        // Approved! Add as virtual member
        request.status = 'approved';
        request.resolvedAt = new Date();
        await request.save();
        // Add to chat_members as virtual member
        await ChatMember_1.default.create({
            chatId: request.chatId,
            userId: request.userId,
            membershipType: 'virtual',
            role: 'member'
        });
        resolved = true;
        outcome = 'approved';
    }
    else if (denials >= majorityNeeded) {
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
async function getPendingRequests(chatId) {
    const requests = await JoinRequest_1.default.find({
        chatId,
        status: 'pending'
    }).sort({ createdAt: -1 });
    // Enrich with user data and vote counts
    const enrichedRequests = await Promise.all(requests.map(async (req) => {
        const user = await User_1.default.findById(req.userId).select('firstName lastName profilePicture vibeScore betsCreated betsCompleted betsFailed calloutsIgnored');
        const votes = await JoinRequestVote_1.default.find({ requestId: req.requestId });
        const approvals = votes.filter(v => v.decision === 'approve').length;
        const denials = votes.filter(v => v.decision === 'deny').length;
        const totalMembers = await ChatMember_1.default.countDocuments({ chatId });
        return {
            requestId: req.requestId,
            chatId: req.chatId,
            reason: req.reason,
            betId: req.contextBetId,
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
                duckRate: user.calloutsReceived
                    ? Math.round(((user.calloutsIgnored ?? 0) / user.calloutsReceived) * 100)
                    : 0
            } : null,
            votes: {
                approvals,
                denials,
                total: votes.length,
                needed: Math.floor(totalMembers / 2) + 1
            }
        };
    }));
    return enrichedRequests;
}
/**
 * Get a user's join request for a specific chat
 */
async function getUserRequest(chatId, userId) {
    return await JoinRequest_1.default.findOne({
        chatId,
        userId,
        status: 'pending'
    });
}
/**
 * Cancel a pending join request
 */
async function cancelJoinRequest(requestId, userId) {
    const request = await JoinRequest_1.default.findOne({ requestId });
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
    await JoinRequestVote_1.default.deleteMany({ requestId });
    await JoinRequest_1.default.deleteOne({ requestId });
}
/**
 * Check if user has voted on a request
 */
async function hasUserVoted(requestId, userId) {
    const vote = await JoinRequestVote_1.default.findOne({ requestId, voterId: userId });
    return !!vote;
}
//# sourceMappingURL=chatService.js.map