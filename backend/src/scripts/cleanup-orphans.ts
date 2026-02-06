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
import mongoose from 'mongoose';
import { User, Chat, ChatMember, UserConnection, VisibilityPermission } from '../models';

const DRY_RUN = process.argv.includes('--dry-run');

async function cleanupOrphans() {
  const mongoUri = process.env.MONGODB_URI;
  if (!mongoUri) {
    console.error('MONGODB_URI not set');
    process.exit(1);
  }

  await mongoose.connect(mongoUri);
  console.log('Connected to MongoDB');
  if (DRY_RUN) console.log('DRY RUN — no writes will be made\n');
  else console.log('');

  // Find pure orphans: no appleId, no firstName, no email, no appleUUID
  const orphans = await User.find({
    appleId: { $exists: false },
    firstName: { $exists: false },
    email: { $exists: false },
    appleUUID: { $exists: false },
  }).select('_id joinedChatIds');

  if (orphans.length === 0) {
    console.log('No pure orphans found. Nothing to do.');
    await mongoose.disconnect();
    return;
  }

  console.log(`Found ${orphans.length} pure orphan(s):\n`);

  for (const orphan of orphans) {
    const id = orphan._id as string;
    console.log(`Orphan: ${id} (${orphan.joinedChatIds?.length || 0} chat(s))`);

    // --- ChatMember ---
    const chatMemberCount = await ChatMember.countDocuments({ userId: id });
    console.log(`  ChatMember refs:            ${chatMemberCount}`);
    if (!DRY_RUN && chatMemberCount > 0) {
      await ChatMember.deleteMany({ userId: id });
    }

    // --- UserConnection ---
    const connCount = await UserConnection.countDocuments({
      $or: [{ userId1: id }, { userId2: id }],
    });
    console.log(`  UserConnection refs:        ${connCount}`);
    if (!DRY_RUN && connCount > 0) {
      await UserConnection.deleteMany({
        $or: [{ userId1: id }, { userId2: id }],
      });
    }

    // --- VisibilityPermission ---
    const visCount = await VisibilityPermission.countDocuments({
      $or: [{ userId: id }, { visibleToUserId: id }],
    });
    console.log(`  VisibilityPermission refs:  ${visCount}`);
    if (!DRY_RUN && visCount > 0) {
      await VisibilityPermission.deleteMany({
        $or: [{ userId: id }, { visibleToUserId: id }],
      });
    }

    // --- Chat.members array ---
    const chatsTouched = await Chat.countDocuments({ members: id });
    console.log(`  Chat.members refs:          ${chatsTouched}`);
    if (!DRY_RUN && chatsTouched > 0) {
      await Chat.updateMany({ members: id }, { $pull: { members: id } });
    }

    // --- Delete the orphan ---
    console.log(`  Deleting user doc...`);
    if (!DRY_RUN) {
      await User.deleteOne({ _id: id });
    }
    console.log('');
  }

  // --- Post-cleanup verification ---
  console.log('─'.repeat(50));
  console.log('POST-CLEANUP STATE');
  console.log(`  Total users:                ${await User.countDocuments()}`);
  console.log(`  Users with appleId:         ${await User.countDocuments({ appleId: { $exists: true, $ne: null } })}`);
  console.log(`  ChatMember docs:            ${await ChatMember.countDocuments()}`);
  console.log(`  UserConnection docs:        ${await UserConnection.countDocuments()}`);
  console.log(`  VisibilityPermission docs:  ${await VisibilityPermission.countDocuments()}`);

  await mongoose.disconnect();
  console.log('\nDisconnected from MongoDB');
}

cleanupOrphans().catch((err) => {
  console.error('Cleanup failed:', err);
  process.exit(1);
});
