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
import 'dotenv/config';
interface CleanupResults {
    totalProcessed: number;
    totalArchived: number;
    totalS3Deleted: number;
    totalVibesDeleted: number;
    errors?: number;
}
declare function cleanupVibes(): Promise<CleanupResults>;
export { cleanupVibes };
//# sourceMappingURL=cleanupVibes.d.ts.map