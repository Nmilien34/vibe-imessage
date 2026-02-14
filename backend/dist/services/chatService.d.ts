/**
 * Chat Service - Join Request Logic
 *
 * Handles join requests and voting for virtual chat membership.
 */
import { IJoinRequest } from '../types';
/**
 * Create a join request for a chat
 */
export declare function createJoinRequest(params: {
    chatId: string;
    userId: string;
    reason?: string;
    betId?: string;
}): Promise<IJoinRequest>;
/**
 * Vote on a join request
 */
export declare function voteOnJoinRequest(params: {
    requestId: string;
    voterId: string;
    vote: 'approve' | 'deny';
}): Promise<{
    vote: any;
    request: IJoinRequest;
    resolved: boolean;
    outcome?: 'approved' | 'denied';
}>;
/**
 * Get pending join requests for a chat
 */
export declare function getPendingRequests(chatId: string): Promise<any[]>;
/**
 * Get a user's join request for a specific chat
 */
export declare function getUserRequest(chatId: string, userId: string): Promise<IJoinRequest | null>;
/**
 * Cancel a pending join request
 */
export declare function cancelJoinRequest(requestId: string, userId: string): Promise<void>;
/**
 * Check if user has voted on a request
 */
export declare function hasUserVoted(requestId: string, userId: string): Promise<boolean>;
//# sourceMappingURL=chatService.d.ts.map