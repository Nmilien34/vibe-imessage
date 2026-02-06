import mongoose from 'mongoose';
import dotenv from 'dotenv';
import { User } from '../models';

dotenv.config();

async function diagnoseOrphans() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGODB_URI!);
    console.log('Connected\n');

    // Count users by identity completeness
    const totalUsers = await User.countDocuments();
    const usersWithAppleId = await User.countDocuments({ appleId: { $exists: true, $ne: null } });
    const usersWithoutAppleId = await User.countDocuments({ appleId: { $exists: false } });
    const usersWithNullAppleId = await User.countDocuments({ appleId: null });

    console.log('USER IDENTITY BREAKDOWN');
    console.log('─'.repeat(50));
    console.log(`Total users:              ${totalUsers}`);
    console.log(`  With appleId:           ${usersWithAppleId}`);
    console.log(`  Without appleId:        ${usersWithoutAppleId}`);
    console.log(`  With null appleId:      ${usersWithNullAppleId}`);
    console.log('');

    // Identify orphans (users created by chat routes, not auth)
    const orphans = await User.find({
      $or: [
        { appleId: { $exists: false } },
        { appleId: null }
      ]
    }).select('_id firstName lastName email appleId appleUUID joinedChatIds auraBalance vibeScore createdAt');

    if (orphans.length === 0) {
      console.log('No orphans found. All users have Apple IDs.\n');
      await mongoose.disconnect();
      return;
    }

    console.log(`FOUND ${orphans.length} ORPHAN USER(S)\n`);

    orphans.forEach((orphan, index) => {
      console.log(`Orphan #${index + 1}:`);
      console.log('─'.repeat(50));
      console.log(`  _id:           ${orphan._id}`);
      console.log(`  firstName:     ${orphan.firstName || '(none)'}`);
      console.log(`  lastName:      ${orphan.lastName || '(none)'}`);
      console.log(`  email:         ${orphan.email || '(none)'}`);
      console.log(`  appleId:       ${orphan.appleId || '(none)'}`);
      console.log(`  appleUUID:     ${orphan.appleUUID || '(none)'}`);
      console.log(`  joinedChatIds: ${orphan.joinedChatIds?.length || 0} chats`);
      console.log(`  auraBalance:   ${orphan.auraBalance}`);
      console.log(`  vibeScore:     ${orphan.vibeScore}`);
      console.log(`  createdAt:     ${orphan.createdAt}`);
      console.log('');
    });

    // Check for potential duplicates (same person, two docs)
    console.log('CHECKING FOR POTENTIAL DUPLICATES\n');

    let duplicatesFound = 0;
    for (const orphan of orphans) {
      if (orphan.firstName) {
        const possibleDuplicate = await User.findOne({
          _id: { $ne: orphan._id },
          firstName: orphan.firstName,
          lastName: orphan.lastName,
          appleId: { $exists: true, $ne: null }
        });

        if (possibleDuplicate) {
          duplicatesFound++;
          console.log(`POSSIBLE DUPLICATE DETECTED:`);
          console.log(`   Orphan: ${orphan._id} (${orphan.firstName} ${orphan.lastName})`);
          console.log(`   Full:   ${possibleDuplicate._id} (${possibleDuplicate.firstName} ${possibleDuplicate.lastName})`);
          console.log('');
        }
      }
    }

    if (duplicatesFound === 0) {
      console.log('No name-based duplicates found.\n');
    }

    // Also check: orphans that have appleUUID — can we match to a full user?
    console.log('CHECKING appleUUID MATCHES\n');
    let uuidMatches = 0;
    for (const orphan of orphans) {
      if (orphan.appleUUID) {
        const match = await User.findOne({
          _id: { $ne: orphan._id },
          appleUUID: orphan.appleUUID,
          appleId: { $exists: true, $ne: null }
        });
        if (match) {
          uuidMatches++;
          console.log(`appleUUID MATCH:`);
          console.log(`   Orphan: ${orphan._id} (appleUUID: ${orphan.appleUUID})`);
          console.log(`   Full:   ${match._id} (appleId: ${match.appleId})`);
          console.log('');
        }
      }
    }
    if (uuidMatches === 0) {
      console.log('No appleUUID matches found.\n');
    }

    // Summary classification
    console.log('SUMMARY');
    console.log('─'.repeat(50));
    const pureOrphans = orphans.filter(o => !o.firstName && !o.email && !o.appleUUID);
    const partialOrphans = orphans.filter(o => (o.firstName || o.email) && !o.appleId);
    console.log(`  Pure orphans (no identity data):  ${pureOrphans.length} → candidates for deletion`);
    console.log(`  Partial orphans (have name/email): ${partialOrphans.length} → keep, will merge on next login`);
    console.log(`  Duplicate pairs detected:          ${duplicatesFound}`);
    console.log(`  appleUUID matches:                 ${uuidMatches}`);

    await mongoose.disconnect();
    console.log('\nDisconnected from MongoDB');

  } catch (error) {
    console.error('Diagnostic failed:', error);
    process.exit(1);
  }
}

diagnoseOrphans();
