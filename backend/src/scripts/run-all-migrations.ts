/**
 * Master migration runner — executes all migrations in dependency order
 * against a single MongoDB connection.
 *
 * Each individual script is also runnable standalone:
 *   npx ts-node src/scripts/migrate-add-aura.ts
 *
 * Or run everything at once:
 *   npx ts-node src/scripts/run-all-migrations.ts
 */

import 'dotenv/config';
import mongoose from 'mongoose';
import { migrateUsersToAura } from './migrate-add-aura';
import { migrateChatMembers } from './migrate-chat-members';
import { buildConnectionGraph } from './build-connection-graph';
import { initializeVisibility } from './init-visibility';

async function runAllMigrations() {
  const mongoUri = process.env.MONGODB_URI;
  if (!mongoUri) {
    console.error('MONGODB_URI not set');
    process.exit(1);
  }

  await mongoose.connect(mongoUri);
  console.log('Connected to MongoDB\n');

  console.log('=== PHASE 1: USER MIGRATION ===');
  await migrateUsersToAura();

  console.log('\n=== PHASE 2: CHAT MEMBER MIGRATION ===');
  await migrateChatMembers();

  console.log('\n=== PHASE 3: CONNECTION GRAPH ===');
  await buildConnectionGraph();

  console.log('\n=== PHASE 4: VISIBILITY PERMISSIONS ===');
  await initializeVisibility();

  console.log('\nAll migrations complete');
  await mongoose.disconnect();
}

runAllMigrations().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
