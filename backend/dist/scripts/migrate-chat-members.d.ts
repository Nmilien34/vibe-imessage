/**
 * Migration: Backfill ChatMember documents from user.joinedChatIds
 *
 * Source of truth is user → chats (joinedChatIds), not chat → users (members).
 * Chat.createdBy is loaded to assign 'admin' role to the creator.
 * Idempotent — compound index (chatId, userId) skips duplicates.
 *
 * Run: npx ts-node src/scripts/migrate-chat-members.ts
 */
import 'dotenv/config';
export declare function migrateChatMembers(): Promise<void>;
//# sourceMappingURL=migrate-chat-members.d.ts.map