"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.initScheduler = void 0;
const node_cron_1 = __importDefault(require("node-cron"));
const vibeWireService_1 = require("../services/vibeWireService");
const teaService_1 = require("../services/teaService");
// Initialize Scheduled Jobs
const initScheduler = () => {
    console.log('[Scheduler] Initializing Vibe Wire Daily Cycle...');
    // Tea settlement tick
    // Bet settlement runs in backgroundJobs (every 60s).
    node_cron_1.default.schedule('*/15 * * * *', async () => {
        try {
            const expiredTeas = await (0, teaService_1.autoExpireTeaSpills)();
            if (expiredTeas > 0) {
                console.log(`[Scheduler] Settlement tick - expired teas: ${expiredTeas}`);
            }
        }
        catch (error) {
            console.error('[Scheduler] Settlement tick failed:', error);
        }
    });
    // 6:00 AM (The Reset)
    // Clears old news, fetches fresh morning batch
    node_cron_1.default.schedule('0 6 * * *', async () => {
        console.log('[Scheduler] 6:00 AM - Running Morning Reset');
        await (0, vibeWireService_1.fetchVibeNews)('morning');
    });
    // 12:00 PM (Noon Update)
    // Appends noon news
    node_cron_1.default.schedule('0 12 * * *', async () => {
        console.log('[Scheduler] 12:00 PM - Running Noon Update');
        await (0, vibeWireService_1.fetchVibeNews)('noon');
    });
    // 6:00 PM (Evening Update)
    // Appends evening news
    node_cron_1.default.schedule('0 18 * * *', async () => {
        console.log('[Scheduler] 6:00 PM - Running Evening Update');
        await (0, vibeWireService_1.fetchVibeNews)('evening');
    });
    console.log('[Scheduler] Jobs scheduled: every 15m tea settlement + 6am, 12pm, 6pm vibe wire');
};
exports.initScheduler = initScheduler;
//# sourceMappingURL=scheduler.js.map