"use strict";
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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildConnectionGraph = buildConnectionGraph;
require("dotenv/config");
const mongoose_1 = __importDefault(require("mongoose"));
const uuid_1 = require("uuid");
const ChatMember_1 = __importDefault(require("../models/ChatMember"));
const UserConnection_1 = __importDefault(require("../models/UserConnection"));
async function buildConnectionGraph() {
    console.log('Building connection graph...');
    const memberships = await ChatMember_1.default.find({});
    // Group user IDs by chatId
    const chatGroups = new Map();
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
                    await UserConnection_1.default.create({
                        connectionId: `conn_${(0, uuid_1.v4)()}`,
                        userId1,
                        userId2,
                        sourceChatId: chatId,
                        establishedAt: new Date(),
                        lastInteraction: new Date(),
                    });
                    created++;
                }
                catch (error) {
                    if (error.code !== 11000)
                        throw error;
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
        await mongoose_1.default.connect(mongoUri);
        console.log('Connected to MongoDB');
        await buildConnectionGraph();
        await mongoose_1.default.disconnect();
    })().catch((err) => {
        console.error('Migration failed:', err);
        process.exit(1);
    });
}
//# sourceMappingURL=build-connection-graph.js.map