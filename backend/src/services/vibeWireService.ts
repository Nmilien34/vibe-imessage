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
    }

    console.log(`[Vibe Wire] Saved ${savedItems.length} valid articles for ${batch} batch.`);
    return savedItems;
};

export const getVibeWireFeed = async () => {
    // Return sorted by batch priority (Evening > Noon > Morning) then Score
    // Or just simple createdAt desc
    return await NewsItem.find().sort({ createdAt: -1 }).limit(20);
};
