import { MemberRole, MembershipType } from '../types';
interface EnsureChatMembershipParams {
    chatId: string;
    userId: string;
    membershipType?: MembershipType;
    role?: MemberRole;
}
/**
 * Guarantees ChatMember + Chat.members + User.joinedChatIds are in sync.
 * Idempotent and safe to call repeatedly.
 */
export declare function ensureChatMembership(params: EnsureChatMembershipParams): Promise<boolean>;
/**
 * Repairs membership only when existing data indicates the user already belongs
 * to the chat (via Chat.members or User.joinedChatIds). Returns false if not.
 */
export declare function ensureChatMembershipIfKnown(chatId: string, userId: string): Promise<boolean>;
export {};
//# sourceMappingURL=chatMembershipService.d.ts.map