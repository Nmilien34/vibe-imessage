/**
 * Migration: Add Aura Economy + Reputation fields to all existing users
 *
 * Idempotent — safe to run multiple times. Only touches users missing the fields.
 * New users created after the schema change get defaults automatically via Mongoose.
 *
 * Run: npx ts-node src/scripts/migrate-add-aura.ts
 */
import 'dotenv/config';
export declare function migrateUsersToAura(): Promise<void>;
//# sourceMappingURL=migrate-add-aura.d.ts.map