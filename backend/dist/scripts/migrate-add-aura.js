"use strict";
/**
 * Migration: Add Aura Economy + Reputation fields to all existing users
 *
 * Idempotent — safe to run multiple times. Only touches users missing the fields.
 * New users created after the schema change get defaults automatically via Mongoose.
 *
 * Run: npx ts-node src/scripts/migrate-add-aura.ts
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.migrateUsersToAura = migrateUsersToAura;
require("dotenv/config");
const mongoose_1 = __importDefault(require("mongoose"));
const User_1 = __importDefault(require("../models/User"));
const DEFAULT_AURA_BALANCE = 1000;
const DEFAULT_VIBE_SCORE = 100;
async function migrateUsersToAura() {
    console.log('Starting Aura migration...');
    const result = await User_1.default.updateMany({ auraBalance: { $exists: false } }, {
        $set: {
            auraBalance: DEFAULT_AURA_BALANCE,
            lifetimeAuraEarned: 0,
            lifetimeAuraSpent: 0,
            lastDailyBonus: null,
            vibeScore: DEFAULT_VIBE_SCORE,
            betsCreated: 0,
            betsCompleted: 0,
            betsFailed: 0,
            calloutsReceived: 0,
            calloutsIgnored: 0,
        },
    });
    console.log(`Migrated ${result.modifiedCount} users (${result.matchedCount} matched, ${result.modifiedCount} updated)`);
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
        await migrateUsersToAura();
        await mongoose_1.default.disconnect();
    })().catch((err) => {
        console.error('Migration failed:', err);
        process.exit(1);
    });
}
//# sourceMappingURL=migrate-add-aura.js.map