"use strict";
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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
require("dotenv/config");
const mongoose_1 = __importDefault(require("mongoose"));
const models_1 = require("../models");
const DRY_RUN = process.argv.includes('--dry-run');
async function cleanupOrphans() {
    const mongoUri = process.env.MONGODB_URI;
    if (!mongoUri) {
        console.error('MONGODB_URI not set');
        process.exit(1);
    }
    await mongoose_1.default.connect(mongoUri);
    console.log('Connected to MongoDB');
    if (DRY_RUN)
        console.log('DRY RUN — no writes will be made\n');
    else
        console.log('');
    // Find pure orphans: no appleId, no firstName, no email, no appleUUID
    const orphans = await models_1.User.find({
        appleId: { $exists: false },
        firstName: { $exists: false },
        email: { $exists: false },
        appleUUID: { $exists: false },
    }).select('_id joinedChatIds');
    if (orphans.length === 0) {
        console.log('No pure orphans found. Nothing to do.');
        await mongoose_1.default.disconnect();
        return;
    }
    console.log(`Found ${orphans.length} pure orphan(s):\n`);
    for (const orphan of orphans) {
        const id = orphan._id;
        console.log(`Orphan: ${id} (${orphan.joinedChatIds?.length || 0} chat(s))`);
        // --- ChatMember ---
        const chatMemberCount = await models_1.ChatMember.countDocuments({ userId: id });
        console.log(`  ChatMember refs:            ${chatMemberCount}`);
        if (!DRY_RUN && chatMemberCount > 0) {
            await models_1.ChatMember.deleteMany({ userId: id });
        }
        // --- UserConnection ---
        const connCount = await models_1.UserConnection.countDocuments({
            $or: [{ userId1: id }, { userId2: id }],
        });
        console.log(`  UserConnection refs:        ${connCount}`);
        if (!DRY_RUN && connCount > 0) {
            await models_1.UserConnection.deleteMany({
                $or: [{ userId1: id }, { userId2: id }],
            });
        }
        // --- VisibilityPermission ---
        const visCount = await models_1.VisibilityPermission.countDocuments({
            $or: [{ userId: id }, { visibleToUserId: id }],
        });
        console.log(`  VisibilityPermission refs:  ${visCount}`);
        if (!DRY_RUN && visCount > 0) {
            await models_1.VisibilityPermission.deleteMany({
                $or: [{ userId: id }, { visibleToUserId: id }],
            });
        }
        // --- Chat.members array ---
        const chatsTouched = await models_1.Chat.countDocuments({ members: id });
        console.log(`  Chat.members refs:          ${chatsTouched}`);
        if (!DRY_RUN && chatsTouched > 0) {
            await models_1.Chat.updateMany({ members: id }, { $pull: { members: id } });
        }
        // --- Delete the orphan ---
        console.log(`  Deleting user doc...`);
        if (!DRY_RUN) {
            await models_1.User.deleteOne({ _id: id });
        }
        console.log('');
    }
    // --- Post-cleanup verification ---
    console.log('─'.repeat(50));
    console.log('POST-CLEANUP STATE');
    console.log(`  Total users:                ${await models_1.User.countDocuments()}`);
    console.log(`  Users with appleId:         ${await models_1.User.countDocuments({ appleId: { $exists: true, $ne: null } })}`);
    console.log(`  ChatMember docs:            ${await models_1.ChatMember.countDocuments()}`);
    console.log(`  UserConnection docs:        ${await models_1.UserConnection.countDocuments()}`);
    console.log(`  VisibilityPermission docs:  ${await models_1.VisibilityPermission.countDocuments()}`);
    await mongoose_1.default.disconnect();
    console.log('\nDisconnected from MongoDB');
}
cleanupOrphans().catch((err) => {
    console.error('Cleanup failed:', err);
    process.exit(1);
});
//# sourceMappingURL=cleanup-orphans.js.map