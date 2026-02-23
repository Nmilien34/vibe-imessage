/**
 * Feed Service - Discovery & Feed Generation
 *
 * Generates personalized feeds based on:
 * 1. Bets from chats user is IN (full access)
 * 2. Bets from past connections (view-only)
 * 3. Bets from approved contacts (view-only)
 */
interface FeedBet {
    bet: any;
    accessLevel: 'full' | 'view_only';
    source: 'chat_member' | 'past_connection' | 'contact';
    canBet: boolean;
    totals: any;
    participantCount: number;
}
/**
 * Generate personalized feed for a user
 */
export declare function generateFeed(params: {
    userId: string;
    limit?: number;
    offset?: number;
    status?: 'pending' | 'active' | 'completed' | 'expired' | 'ducked' | 'resolving' | 'cancelled';
}): Promise<{
    bets: FeedBet[];
    total: number;
    hasMore: boolean;
}>;
/**
 * Get visibility settings for a user
 */
export declare function getVisibilitySettings(userId: string): Promise<{
    pastConnections: Array<{
        userId: string;
        chatId: string;
        visible: boolean;
    }>;
    contacts: Array<{
        userId: string;
        visible: boolean;
    }>;
}>;
/**
 * Grant visibility to a user
 */
export declare function grantVisibility(params: {
    userId: string;
    visibleToUserId: string;
    source: 'past_connection' | 'contact';
}): Promise<void>;
/**
 * Revoke visibility from a user
 */
export declare function revokeVisibility(params: {
    userId: string;
    visibleToUserId: string;
}): Promise<void>;
/**
 * Create user connection from shared chat
 */
export declare function createConnection(params: {
    userId1: string;
    userId2: string;
    sourceChatId: string;
}): Promise<void>;
export {};
//# sourceMappingURL=feedService.d.ts.map