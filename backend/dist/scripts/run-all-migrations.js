"use strict";
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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
require("dotenv/config");
const mongoose_1 = __importDefault(require("mongoose"));
const migrate_add_aura_1 = require("./migrate-add-aura");
const migrate_chat_members_1 = require("./migrate-chat-members");
const build_connection_graph_1 = require("./build-connection-graph");
const init_visibility_1 = require("./init-visibility");
async function runAllMigrations() {
    const mongoUri = process.env.MONGODB_URI;
    if (!mongoUri) {
        console.error('MONGODB_URI not set');
        process.exit(1);
    }
    await mongoose_1.default.connect(mongoUri);
    console.log('Connected to MongoDB\n');
    console.log('=== PHASE 1: USER MIGRATION ===');
    await (0, migrate_add_aura_1.migrateUsersToAura)();
    console.log('\n=== PHASE 2: CHAT MEMBER MIGRATION ===');
    await (0, migrate_chat_members_1.migrateChatMembers)();
    console.log('\n=== PHASE 3: CONNECTION GRAPH ===');
    await (0, build_connection_graph_1.buildConnectionGraph)();
    console.log('\n=== PHASE 4: VISIBILITY PERMISSIONS ===');
    await (0, init_visibility_1.initializeVisibility)();
    console.log('\nAll migrations complete');
    await mongoose_1.default.disconnect();
}
runAllMigrations().catch((err) => {
    console.error('Migration failed:', err);
    process.exit(1);
});
//# sourceMappingURL=run-all-migrations.js.map