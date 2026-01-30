
import cron from 'node-cron';
import { fetchVibeNews } from '../services/vibeWireService';

// Initialize Scheduled Jobs
export const initScheduler = () => {
    console.log('[Scheduler] Initializing Vibe Wire Daily Cycle...');

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

    console.log('[Scheduler] Jobs scheduled: 6am, 12pm, 6pm');
};
