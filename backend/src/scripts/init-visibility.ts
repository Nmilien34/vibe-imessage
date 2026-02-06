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
import mongoose from 'mongoose';
import { v4 as uuidv4 } from 'uuid';
import UserConnection from '../models/UserConnection';
import VisibilityPermission from '../models/VisibilityPermission';

export async function initializeVisibility() {
  console.log('Initializing visibility permissions...');

  const connections = await UserConnection.find({});
  let created = 0;

  for (const conn of connections) {
    // Bidirectional: each user can see the other's vibes
    const pairs: [string, string][] = [
      [conn.userId1, conn.userId2],
      [conn.userId2, conn.userId1],
    ];

    for (const [owner, viewer] of pairs) {
      try {
        await VisibilityPermission.create({
          permissionId: `perm_${uuidv4()}`,
          userId: owner,
          visibleToUserId: viewer,
          source: 'past_chat',
          grantedAt: conn.establishedAt,
        });
        created++;
      } catch (error: any) {
        if (error.code !== 11000) throw error;
      }
    }
  }

  console.log(`Created ${created} visibility permissions from ${connections.length} connections`);
}

if (require.main === module) {
  (async () => {
    const mongoUri = process.env.MONGODB_URI;
    if (!mongoUri) {
      console.error('MONGODB_URI not set');
      process.exit(1);
    }
    await mongoose.connect(mongoUri);
    console.log('Connected to MongoDB');
    await initializeVisibility();
    await mongoose.disconnect();
  })().catch((err) => {
    console.error('Migration failed:', err);
    process.exit(1);
  });
}
