"use strict";
/**
 * Vibe Cleanup Job
 *
 * This job should run periodically (e.g., every hour via cron) to:
 * 1. Find vibes past their permanentDeleteAt date
 * 2. Delete associated S3 media files
 * 3. Archive minimal metadata for analytics
 * 4. Delete the vibe documents
 *
 * Run manually: npx ts-node src/jobs/cleanupVibes.ts
 * Or schedule via cron: 0 * * * * cd /path/to/backend && npx ts-node src/jobs/cleanupVibes.ts
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanupVibes = cleanupVibes;
require("dotenv/config");
const mongoose_1 = __importDefault(require("mongoose"));
const Vibe_1 = __importDefault(require("../models/Vibe"));
const ArchivedVibe_1 = __importDefault(require("../models/ArchivedVibe"));
const s3Upload_1 = require("../utils/s3Upload");
// Configuration
const BATCH_SIZE = 100;
const DRY_RUN = process.env.CLEANUP_DRY_RUN === 'true';
async function connectDB() {
    if (mongoose_1.default.connection.readyState === 0) {
        const mongoUri = process.env.MONGODB_URI;
        if (!mongoUri) {
            throw new Error('MONGODB_URI environment variable is not set');
        }
        await mongoose_1.default.connect(mongoUri);
        console.log('Connected to MongoDB');
    }
}
function extractS3Key(url) {
    if (!url)
        return null;
    try {
        const urlObj = new URL(url);
        return urlObj.pathname.substring(1);
    }
    catch {
        return null;
    }
}
async function deleteS3Media(vibe) {
    const deletedKeys = [];
    try {
        if (vibe.mediaKey) {
            await (0, s3Upload_1.deleteFile)(vibe.mediaKey);
            deletedKeys.push(vibe.mediaKey);
        }
        else if (vibe.mediaUrl) {
            const key = extractS3Key(vibe.mediaUrl);
            if (key) {
                await (0, s3Upload_1.deleteFile)(key);
                deletedKeys.push(key);
            }
        }
        if (vibe.thumbnailKey) {
            await (0, s3Upload_1.deleteFile)(vibe.thumbnailKey);
            deletedKeys.push(vibe.thumbnailKey);
        }
        else if (vibe.thumbnailUrl && vibe.thumbnailUrl !== vibe.mediaUrl) {
            const key = extractS3Key(vibe.thumbnailUrl);
            if (key) {
                await (0, s3Upload_1.deleteFile)(key);
                deletedKeys.push(key);
            }
        }
    }
    catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        console.error(`Error deleting S3 files for vibe ${vibe._id}:`, message);
    }
    return deletedKeys;
}
async function archiveVibe(vibe) {
    try {
        const archived = new ArchivedVibe_1.default({
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
    }
    catch (error) {
        if (error.code === 11000) {
            return true;
        }
        const message = error instanceof Error ? error.message : 'Unknown error';
        console.error(`Error archiving vibe ${vibe._id}:`, message);
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
    const query = {
        permanentDeleteAt: { $lte: now },
    };
    const totalCount = await Vibe_1.default.countDocuments(query);
    console.log(`Found ${totalCount} vibes to clean up\n`);
    if (totalCount === 0) {
        console.log('No vibes to clean up. Exiting.');
        return { totalProcessed: 0, totalArchived: 0, totalS3Deleted: 0, totalVibesDeleted: 0 };
    }
    let hasMore = true;
    while (hasMore) {
        const vibes = await Vibe_1.default.find(query).limit(BATCH_SIZE);
        if (vibes.length === 0) {
            hasMore = false;
            break;
        }
        console.log(`Processing batch of ${vibes.length} vibes...`);
        for (const vibe of vibes) {
            totalProcessed++;
            try {
                if (!DRY_RUN) {
                    const deletedKeys = await deleteS3Media(vibe);
                    totalS3Deleted += deletedKeys.length;
                    if (deletedKeys.length > 0) {
                        console.log(`  Deleted S3: ${deletedKeys.join(', ')}`);
                    }
                }
                else {
                    console.log(`  [DRY RUN] Would delete S3: ${vibe.mediaKey || vibe.mediaUrl || 'none'}`);
                }
                if (!DRY_RUN) {
                    const archived = await archiveVibe(vibe);
                    if (archived)
                        totalArchived++;
                }
                else {
                    console.log(`  [DRY RUN] Would archive vibe: ${vibe._id}`);
                    totalArchived++;
                }
                if (!DRY_RUN) {
                    await Vibe_1.default.deleteOne({ _id: vibe._id });
                    totalVibesDeleted++;
                    console.log(`  Deleted vibe: ${vibe._id} (${vibe.type})`);
                }
                else {
                    console.log(`  [DRY RUN] Would delete vibe: ${vibe._id}`);
                    totalVibesDeleted++;
                }
            }
            catch (error) {
                errors++;
                const message = error instanceof Error ? error.message : 'Unknown error';
                console.error(`  Error processing vibe ${vibe._id}:`, message);
            }
        }
        await new Promise(resolve => setTimeout(resolve, 100));
    }
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
//# sourceMappingURL=cleanupVibes.js.map