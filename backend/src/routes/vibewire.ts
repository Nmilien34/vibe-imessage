import express from 'express';
import { getVibeWireFeed, fetchVibeNews } from '../services/vibeWireService';

const router = express.Router();

// GET /api/vibewire - Fetch current news feed
router.get('/', async (_req, res) => {
    try {
        const feed = await getVibeWireFeed();
        res.json(feed);
    } catch (error) {
        console.error('Error fetching Vibe Wire feed:', error);
        res.status(500).json({ error: 'Failed to fetch news feed' });
    }
});

// POST /api/vibewire/refresh - Manual trigger (for testing)
router.post('/refresh', async (req, res) => {
    try {
        const { batch } = req.body;
        if (!batch || !['morning', 'noon', 'evening'].includes(batch)) {
            return res.status(400).json({ error: 'Invalid batch. Use: morning, noon, or evening' });
        }

        const items = await fetchVibeNews(batch);
        res.json({ message: `Fetched ${items.length} items for ${batch}`, items });
    } catch (error) {
        console.error('Error refreshing Vibe Wire:', error);
        res.status(500).json({ error: 'Failed to refresh news' });
    }
});

export default router;
