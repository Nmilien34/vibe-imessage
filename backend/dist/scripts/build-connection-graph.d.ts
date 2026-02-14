/**
 * Migration: Build UserConnection graph from existing ChatMember data
 *
 * Every pair of users who share a chat gets a connection record.
 * userId1 is always the lexicographically smaller ID (enforces uniqueness).
 * Idempotent — compound unique index (userId1, userId2) skips existing pairs.
 *
 * Run AFTER migrate-chat-members.ts
 * Run: npx ts-node src/scripts/build-connection-graph.ts
 */
import 'dotenv/config';
export declare function buildConnectionGraph(): Promise<void>;
//# sourceMappingURL=build-connection-graph.d.ts.map