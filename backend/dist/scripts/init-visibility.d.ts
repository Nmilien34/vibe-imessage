/**
 * Migration: Seed bidirectional VisibilityPermission from existing UserConnections
 *
 * Every connection A↔B produces two permissions: A can see B, B can see A.
 * Idempotent — compound unique index (userId, visibleToUserId) skips existing entries.
 *
 * Run AFTER build-connection-graph.ts
 * Run: npx ts-node src/scripts/init-visibility.ts
 */
import 'dotenv/config';
export declare function initializeVisibility(): Promise<void>;
//# sourceMappingURL=init-visibility.d.ts.map