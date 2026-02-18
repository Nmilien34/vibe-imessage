"use strict";
/**
 * Migration: Seed bidirectional VisibilityPermission from existing UserConnections
 *
 * Every connection A↔B produces two permissions: A can see B, B can see A.
 * Idempotent — compound unique index (userId, visibleToUserId) skips existing entries.
 *
 * Run AFTER build-connection-graph.ts
 * Run: npx ts-node src/scripts/init-visibility.ts
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.initializeVisibility = initializeVisibility;
require("dotenv/config");
const mongoose_1 = __importDefault(require("mongoose"));
const uuid_1 = require("uuid");
const UserConnection_1 = __importDefault(require("../models/UserConnection"));
const VisibilityPermission_1 = __importDefault(require("../models/VisibilityPermission"));
async function initializeVisibility() {
    console.log('Initializing visibility permissions...');
    const connections = await UserConnection_1.default.find({});
    let created = 0;
    for (const conn of connections) {
        // Bidirectional: each user can see the other's vibes
        const pairs = [
            [conn.userId1, conn.userId2],
            [conn.userId2, conn.userId1],
        ];
        for (const [owner, viewer] of pairs) {
            try {
                await VisibilityPermission_1.default.create({
                    permissionId: `perm_${(0, uuid_1.v4)()}`,
                    userId: owner,
                    visibleToUserId: viewer,
                    source: 'past_connection',
                    grantedAt: conn.establishedAt,
                });
                created++;
            }
            catch (error) {
                if (error.code !== 11000)
                    throw error;
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
        await mongoose_1.default.connect(mongoUri);
        console.log('Connected to MongoDB');
        await initializeVisibility();
        await mongoose_1.default.disconnect();
    })().catch((err) => {
        console.error('Migration failed:', err);
        process.exit(1);
    });
}
//# sourceMappingURL=init-visibility.js.map