import cron from 'node-cron';
import { fetchVibeNews } from '../services/vibeWireService';
import { autoExpireBets } from '../services/betService';
import { autoExpireTeaSpills } from '../services/teaService';

// Initialize Scheduled Jobs
export const initScheduler = () => {
    console.log('[Scheduler] Initializing Vibe Wire Daily Cycle...');

    // Bet + tea settlement tick
    // Runs every 15 minutes so pending resolution claims auto-confirm
    // after their 6-hour review window without manual intervention.
    cron.schedule('*/15 * * * *', async () => {
        try {
            const [{ expiredCount, autoConfirmedCount }, expiredTeas] = await Promise.all([
                autoExpireBets(),
                autoExpireTeaSpills(),
            ]);

            if (expiredCount > 0 || autoConfirmedCount > 0 || expiredTeas > 0) {
                console.log(
                    `[Scheduler] Settlement tick - expired bets: ${expiredCount}, auto-confirmed claims: ${autoConfirmedCount}, expired teas: ${expiredTeas}`
                );
            }
        } catch (error) {
            console.error('[Scheduler] Settlement tick failed:', error);
        }
    });

    // 6:00 AM (The Reset)
    // Clears old news, fetches fresh morning batch
    cron.schedule('0 6 * * *', async () => {
        console.log('[Scheduler] 6:00 AM - Running Morning Reset');
        await fetchVibeNews('morning');
    });

    // 12:00 PM (Noon Update)
    // Appends noon news
    cron.schedule('0 12 * * *', async () => {
        console.log('[Scheduler] 12:00 PM - Running Noon Update');
        await fetchVibeNews('noon');
    });

    // 6:00 PM (Evening Update)
    // Appends evening news
    cron.schedule('0 18 * * *', async () => {
        console.log('[Scheduler] 6:00 PM - Running Evening Update');
        await fetchVibeNews('evening');
    });

    console.log('[Scheduler] Jobs scheduled: every 15m settlement + 6am, 12pm, 6pm vibe wire');
};
