/**
 * Vibe Cleanup Job
 *
 * This job should run periodically (e.g., every hour via cron) to:
 * 1. Find vibes past their permanentDeleteAt date
 * 2. Delete associated S3 media files
 * 3. Archive minimal metadata for analytics
 * 4. Delete the vibe documents
 *
 * Run manually: node src/jobs/cleanupVibes.js
 * Or schedule via cron: 0 * * * * cd /path/to/backend && node src/jobs/cleanupVibes.js
 */

const mongoose = require('mongoose');
const Vibe = require('../models/Vibe');
const ArchivedVibe = require('../models/ArchivedVibe');
const { deleteFile } = require('../utils/s3Upload');
require('dotenv').config();

// Configuration
const BATCH_SIZE = 100; // Process in batches to avoid memory issues
const DRY_RUN = process.env.CLEANUP_DRY_RUN === 'true'; // Set to true to test without deleting

async function connectDB() {
  if (mongoose.connection.readyState === 0) {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB');
  }
}

async function deleteS3Media(vibe) {
  const deletedKeys = [];

  try {
    // Delete main media
    if (vibe.mediaKey) {
      await deleteFile(vibe.mediaKey);
      deletedKeys.push(vibe.mediaKey);
    } else if (vibe.mediaUrl) {
      // Extract key from URL if mediaKey not stored
      const key = extractS3Key(vibe.mediaUrl);
      if (key) {
        await deleteFile(key);
        deletedKeys.push(key);
      }
    }

    // Delete thumbnail
    if (vibe.thumbnailKey) {
      await deleteFile(vibe.thumbnailKey);
      deletedKeys.push(vibe.thumbnailKey);
    } else if (vibe.thumbnailUrl && vibe.thumbnailUrl !== vibe.mediaUrl) {
      const key = extractS3Key(vibe.thumbnailUrl);
      if (key) {
        await deleteFile(key);
        deletedKeys.push(key);
      }
    }
  } catch (error) {
    console.error(`Error deleting S3 files for vibe ${vibe._id}:`, error.message);
    // Continue with cleanup even if S3 delete fails
    // The S3 lifecycle policy will catch orphaned files
  }

  return deletedKeys;
}

function extractS3Key(url) {
  if (!url) return null;

  try {
    // URL format: https://bucket.s3.region.amazonaws.com/folder/file.ext
    const urlObj = new URL(url);
    // Remove leading slash
    return urlObj.pathname.substring(1);
  } catch {
    return null;
  }
}

async function archiveVibe(vibe) {
  try {
    const archived = new ArchivedVibe({
      originalVibeId: vibe._id.toString(),
      userId: vibe.userId,
      conversationId: vibe.conversationId,
      type: vibe.type,
      wasLocked: vibe.isLocked || false,
      metrics: {
        viewCount: vibe.viewedBy?.length || 0,
        reactionCount: vibe.reactions?.length || 0,
        unlockCount: vibe.unlockedBy?.length || 0,
      },
      originalCreatedAt: vibe.createdAt,
    });

    await archived.save();
    return true;
  } catch (error) {
    // Duplicate key error is fine (already archived)
    if (error.code === 11000) {
      return true;
    }
    console.error(`Error archiving vibe ${vibe._id}:`, error.message);
    return false;
  }
}

async function cleanupVibes() {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`Vibe Cleanup Job Started: ${new Date().toISOString()}`);
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN (no actual deletions)' : 'LIVE'}`);
  console.log(`${'='.repeat(60)}\n`);

  await connectDB();

  const now = new Date();
  let totalProcessed = 0;
  let totalArchived = 0;
  let totalS3Deleted = 0;
  let totalVibesDeleted = 0;
  let errors = 0;

  // Find vibes that should be permanently deleted
  const query = {
    permanentDeleteAt: { $lte: now },
  };

  const totalCount = await Vibe.countDocuments(query);
  console.log(`Found ${totalCount} vibes to clean up\n`);

  if (totalCount === 0) {
    console.log('No vibes to clean up. Exiting.');
    return { totalProcessed: 0, totalArchived: 0, totalS3Deleted: 0, totalVibesDeleted: 0 };
  }

  // Process in batches
  let hasMore = true;
  while (hasMore) {
    const vibes = await Vibe.find(query).limit(BATCH_SIZE);

    if (vibes.length === 0) {
      hasMore = false;
      break;
    }

    console.log(`Processing batch of ${vibes.length} vibes...`);

    for (const vibe of vibes) {
      totalProcessed++;

      try {
        // 1. Delete S3 media
        if (!DRY_RUN) {
          const deletedKeys = await deleteS3Media(vibe);
          totalS3Deleted += deletedKeys.length;
          if (deletedKeys.length > 0) {
            console.log(`  Deleted S3: ${deletedKeys.join(', ')}`);
          }
        } else {
          console.log(`  [DRY RUN] Would delete S3: ${vibe.mediaKey || vibe.mediaUrl || 'none'}`);
        }

        // 2. Archive metadata
        if (!DRY_RUN) {
          const archived = await archiveVibe(vibe);
          if (archived) totalArchived++;
        } else {
          console.log(`  [DRY RUN] Would archive vibe: ${vibe._id}`);
          totalArchived++;
        }

        // 3. Delete vibe document
        if (!DRY_RUN) {
          await Vibe.deleteOne({ _id: vibe._id });
          totalVibesDeleted++;
          console.log(`  Deleted vibe: ${vibe._id} (${vibe.type})`);
        } else {
          console.log(`  [DRY RUN] Would delete vibe: ${vibe._id}`);
          totalVibesDeleted++;
        }
      } catch (error) {
        errors++;
        console.error(`  Error processing vibe ${vibe._id}:`, error.message);
      }
    }

    // Small delay between batches to avoid overwhelming the system
    await new Promise(resolve => setTimeout(resolve, 100));
  }

  // Summary
  console.log(`\n${'='.repeat(60)}`);
  console.log('Cleanup Summary:');
  console.log(`  Total Processed: ${totalProcessed}`);
  console.log(`  Vibes Deleted: ${totalVibesDeleted}`);
  console.log(`  S3 Files Deleted: ${totalS3Deleted}`);
  console.log(`  Metadata Archived: ${totalArchived}`);
  console.log(`  Errors: ${errors}`);
  console.log(`${'='.repeat(60)}\n`);

  return { totalProcessed, totalArchived, totalS3Deleted, totalVibesDeleted, errors };
}

// Run if called directly
if (require.main === module) {
  cleanupVibes()
    .then((results) => {
      console.log('Cleanup completed:', results);
      process.exit(0);
    })
    .catch((error) => {
      console.error('Cleanup failed:', error);
      process.exit(1);
    });
}

module.exports = { cleanupVibes };
