import { EventRegistry, QueryArticlesIter, ReturnInfo, ArticleInfoFlags } from 'eventregistry';
import { NewsItem } from '../models/NewsItem';

// Lazy-load EventRegistry to ensure env vars are loaded
let er: EventRegistry | null = null;
const getEventRegistry = () => {
    if (!er) {
        const apiKey = process.env.EVENT_REGISTRY_API_KEY;
        console.log(`[Vibe Wire] Initializing EventRegistry with API key: ${apiKey ? 'present' : 'MISSING'}`);
        er = new EventRegistry({ apiKey });
    }
    return er;
};

export const fetchVibeNews = async (batch: 'morning' | 'noon' | 'evening') => {
    console.log(`[Vibe Wire] Fetching ${batch} news...`);

    const q = new QueryArticlesIter(getEventRegistry(), {
        keywords: ['pop culture', 'technology', 'viral', 'music', 'entertainment'],
        lang: 'eng',
        sortBy: 'socialScore', // Get viral stuff
        maxItems: 10, // Top 10 viral stories
        isDuplicateFilter: 'skipDuplicates',
    });

    const articles: any[] = [];

    // Fetch articles
    await new Promise<void>((resolve) => {
        q.execQuery((item) => {
            articles.push(item);
        }, () => {
            resolve();
        });
    });

    console.log(`[Vibe Wire] Found ${articles.length} articles.`);

    // Clear old news if it's the morning reset
    if (batch === 'morning') {
        await NewsItem.deleteMany({});
        console.log('[Vibe Wire] Cleared previous day\'s news.');
    }

    // Save new items
    const savedItems = [];
    for (const article of articles) {
        if (!article.image) continue; // Skip if no image (it's visual!)

        try {
            const newsItem = new NewsItem({
                headline: article.title,
                imageUrl: article.image,
                source: article.source.title,
                url: article.url,
                publishedAt: new Date(article.dateTime),
                vibeScore: article.socialScore || 0,
                batch: batch
            });

            await newsItem.save();
            savedItems.push(newsItem);
        } catch (error) {
            console.error(`[Vibe Wire] Failed to save article: ${article.title}`, error);
            // Continue with other articles
        }
    }

    console.log(`[Vibe Wire] Saved ${savedItems.length} valid articles for ${batch} batch.`);
    return savedItems;
};

export const getVibeWireFeed = async () => {
    const news = await NewsItem.find().sort({ createdAt: -1 }).limit(20);

    // Auto-fetch if empty or very stale
    if (news.length === 0) {
        console.log('[Vibe Wire] Feed is empty, triggering background fetch...');
        // Fire and forget fetch (don't await to avoid blocking the response)
        fetchVibeNews('morning').catch(err => {
            console.error('[Vibe Wire] Background fetch failed:', err);
        });
    } else {
        // Check if the latest news is older than 12 hours
        const latest = news[0];
        const ageHours = (Date.now() - latest.createdAt.getTime()) / (1000 * 60 * 60);
        if (ageHours > 12) {
            console.log(`[Vibe Wire] News is stale (${Math.round(ageHours)}h old), refreshing...`);
            fetchVibeNews('morning').catch(err => {
                console.error('[Vibe Wire] Background refresh failed:', err);
            });
        }
    }

    return news;
};
