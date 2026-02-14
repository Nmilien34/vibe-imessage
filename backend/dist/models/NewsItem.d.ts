import mongoose, { Document } from 'mongoose';
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
export declare const NewsItem: mongoose.Model<INewsItem, {}, {}, {}, mongoose.Document<unknown, {}, INewsItem, {}, {}> & INewsItem & Required<{
    _id: mongoose.Types.ObjectId;
}> & {
    __v: number;
}, any>;
//# sourceMappingURL=NewsItem.d.ts.map