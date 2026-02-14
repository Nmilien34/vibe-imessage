"use strict";
/**
 * Migration: Backfill ChatMember documents from user.joinedChatIds
 *
 * Source of truth is user → chats (joinedChatIds), not chat → users (members).
 * Chat.createdBy is loaded to assign 'admin' role to the creator.
 * Idempotent — compound index (chatId, userId) skips duplicates.
 *
 * Run: npx ts-node src/scripts/migrate-chat-members.ts
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.migrateChatMembers = migrateChatMembers;
require("dotenv/config");
const mongoose_1 = __importDefault(require("mongoose"));
const uuid_1 = require("uuid");
const User_1 = __importDefault(require("../models/User"));
const Chat_1 = __importDefault(require("../models/Chat"));
const ChatMember_1 = __importDefault(require("../models/ChatMember"));
async function migrateChatMembers() {
    console.log('Migrating chat members...');
    const users = await User_1.default.find({});
    console.log(`Found ${users.length} users`);
    // Build chatId → creatorId lookup so we can assign admin role
    const chats = await Chat_1.default.find({});
    const creatorMap = new Map();
    for (const chat of chats) {
        if (chat.createdBy) {
            creatorMap.set(chat._id, chat.createdBy);
        }
    }
    console.log(`Found ${chats.length} chats`);
    let created = 0;
    for (const user of users) {
        for (const chatId of user.joinedChatIds) {
            try {
                await ChatMember_1.default.create({
                    memberId: `member_${(0, uuid_1.v4)()}`,
                    chatId,
                    userId: user._id,
                    membershipType: 'full',
                    role: creatorMap.get(chatId) === user._id ? 'admin' : 'member',
                    joinedAt: new Date(),
                });
                created++;
            }
            catch (error) {
                if (error.code !== 11000)
                    throw error;
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
        await mongoose_1.default.connect(mongoUri);
        console.log('Connected to MongoDB');
        await migrateChatMembers();
        await mongoose_1.default.disconnect();
    })().catch((err) => {
        console.error('Migration failed:', err);
        process.exit(1);
    });
}
//# sourceMappingURL=migrate-chat-members.js.map