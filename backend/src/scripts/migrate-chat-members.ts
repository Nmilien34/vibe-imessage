/**
 * Migration: Backfill ChatMember documents from user.joinedChatIds
 *
 * Source of truth is user → chats (joinedChatIds), not chat → users (members).
 * Chat.createdBy is loaded to assign 'admin' role to the creator.
 * Idempotent — compound index (chatId, userId) skips duplicates.
 *
 * Run: npx ts-node src/scripts/migrate-chat-members.ts
 */

import 'dotenv/config';
import mongoose from 'mongoose';
import { v4 as uuidv4 } from 'uuid';
import User from '../models/User';
import Chat from '../models/Chat';
import ChatMember from '../models/ChatMember';

export async function migrateChatMembers() {
  console.log('Migrating chat members...');

  const users = await User.find({});
  console.log(`Found ${users.length} users`);

  // Build chatId → creatorId lookup so we can assign admin role
  const chats = await Chat.find({});
  const creatorMap = new Map<string, string>();
  for (const chat of chats) {
    if (chat.createdBy) {
      creatorMap.set(chat._id as string, chat.createdBy as string);
    }
  }
  console.log(`Found ${chats.length} chats`);

  let created = 0;

  for (const user of users) {
    for (const chatId of user.joinedChatIds) {
      try {
        await ChatMember.create({
          memberId: `member_${uuidv4()}`,
          chatId,
          userId: user._id as string,
          membershipType: 'full',
          role: creatorMap.get(chatId) === (user._id as string) ? 'admin' : 'member',
          joinedAt: new Date(),
        });
        created++;
      } catch (error: any) {
        if (error.code !== 11000) throw error;
      }
    }
  }

  console.log(`Migrated ${users.length} users, created ${created} memberships`);
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
    await migrateChatMembers();
    await mongoose.disconnect();
  })().catch((err) => {
    console.error('Migration failed:', err);
    process.exit(1);
  });
}
