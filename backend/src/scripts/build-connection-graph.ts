/**
 * Migration: Build UserConnection graph from existing ChatMember data
 *
 * Every pair of users who share a chat gets a connection record.
 * userId1 is always the lexicographically smaller ID (enforces uniqueness).
 * Idempotent — compound unique index (userId1, userId2) skips existing pairs.
 *
 * Run AFTER migrate-chat-members.ts
 * Run: npx ts-node src/scripts/build-connection-graph.ts
 */

import 'dotenv/config';
import mongoose from 'mongoose';
import { v4 as uuidv4 } from 'uuid';
import ChatMember from '../models/ChatMember';
import UserConnection from '../models/UserConnection';

export async function buildConnectionGraph() {
  console.log('Building connection graph...');

  const memberships = await ChatMember.find({});

  // Group user IDs by chatId
  const chatGroups = new Map<string, string[]>();
  for (const m of memberships) {
    const existing = chatGroups.get(m.chatId) || [];
    existing.push(m.userId);
    chatGroups.set(m.chatId, existing);
  }

  let created = 0;

  for (const [chatId, users] of chatGroups) {
    for (let i = 0; i < users.length; i++) {
      for (let j = i + 1; j < users.length; j++) {
        // Smaller ID first for consistent uniqueness
        const [userId1, userId2] = users[i] < users[j] ? [users[i], users[j]] : [users[j], users[i]];

        try {
          await UserConnection.create({
            connectionId: `conn_${uuidv4()}`,
            userId1,
            userId2,
            sourceChatId: chatId,
            establishedAt: new Date(),
            lastInteraction: new Date(),
          });
          created++;
        } catch (error: any) {
          if (error.code !== 11000) throw error;
        }
      }
    }
  }

  console.log(`Created ${created} connections from ${chatGroups.size} chats`);
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
    await buildConnectionGraph();
    await mongoose.disconnect();
  })().catch((err) => {
    console.error('Migration failed:', err);
    process.exit(1);
  });
}
