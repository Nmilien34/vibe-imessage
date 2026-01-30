import mongoose, { Schema, Document } from 'mongoose';

export interface INewsItem extends Document {
    headline: string;
    imageUrl?: string;
    source: string;
    url: string;
    publishedAt: Date;
    vibeScore: number;
    batch: 'morning' | 'noon' | 'evening';
    createdAt: Date;
}

const newsItemSchema = new Schema<INewsItem>(
    {
        headline: { type: String, required: true },
        imageUrl: { type: String },
        source: { type: String, required: true },
        url: { type: String, required: true },
        publishedAt: { type: Date, required: true },
        vibeScore: { type: Number, default: 0 },
        batch: {
            type: String,
            enum: ['morning', 'noon', 'evening'],
            required: true
        },
        createdAt: { type: Date, default: Date.now, expires: '24h' } // Auto-delete after 24h
    },
    { timestamps: true }
);

// Index for efficient sorting
newsItemSchema.index({ createdAt: -1 });

export const NewsItem = mongoose.model<INewsItem>('NewsItem', newsItemSchema);
