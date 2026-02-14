/**
 * Cleanup: remove pure identity-split orphans and their downstream references.
 *
 * A "pure orphan" is a User doc with no appleId, no firstName, no email, and
 * no appleUUID — created by a chat route before the owner ever signed in via
 * Apple. It has no recoverable identity data. The real user will get a proper
 * doc (with _id = appleId) the next time they sign in.
 *
 * Seed users (test_user_*) are explicitly skipped — they are intentional test
 * data and will never have appleId.
 *
 * Downstream cleanup for each deleted orphan:
 *   - ChatMember docs where userId = orphan._id
 *   - UserConnection docs where userId1 or userId2 = orphan._id
 *   - VisibilityPermission docs where userId or visibleToUserId = orphan._id
 *   - Chat.members arrays: pull orphan._id out
 *
 * Idempotent: safe to run repeatedly. Logs everything before and after.
 *
 * Run: npx ts-node src/scripts/cleanup-orphans.ts
 * Dry run: npx ts-node src/scripts/cleanup-orphans.ts --dry-run
 */
import 'dotenv/config';
//# sourceMappingURL=cleanup-orphans.d.ts.map