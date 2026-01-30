import mongoose, { Schema, Model } from 'mongoose';
import { IVibe, VibeType, ParlayStatus } from '../types';

// Retention periods (in days)
export const FEED_EXPIRATION_DAYS = 1; // 24 hours - visible in feed
export const HISTORY_RETENTION_DAYS = 15; // 15 days - viewable in history

const vibeTypes: VibeType[] = [
  'video',
  'photo',
  'song',
  'battery',
  'mood',
  'poll',
  'dailyDrop',
  'tea',
  'leak',
  'sketch',
  'eta',
  'parlay',
];

const parlayStatuses: ParlayStatus[] = ['pending', 'accepted', 'declined', 'settled', 'active', 'resolved', 'cancelled'];

interface IVibeModel extends Model<IVibe> {
  createWithExpiration(data: Partial<IVibe>): Promise<IVibe>;
}

const vibeSchema = new Schema<IVibe>(
  {
    userId: {
      type: String,
      required: true,
      index: true,
    },
    chatId: {
      type: String,
      required: true,
      index: true,
      ref: 'Chat',
    },
    conversationId: {
      type: String,
      index: true,
    },
    oderId: { type: String },
    type: {
      type: String,
      required: true,
      enum: vibeTypes,
    },
    mediaUrl: { type: String },
    mediaKey: { type: String },
    thumbnailUrl: { type: String },
    thumbnailKey: { type: String },
    songData: {
      title: String,
      artist: String,
      albumArt: String,
      previewUrl: String,
      spotifyId: String,
      spotifyUrl: String,
      appleMusicUrl: String,
    },
    batteryLevel: {
      type: Number,
      min: 0,
      max: 100,
    },
    mood: {
      emoji: String,
      text: String,
    },
    poll: {
      question: String,
      options: [String],
      votes: [
        {
          userId: String,
          optionIndex: Number,
        },
      ],
    },
    parlay: {
      title: String,
      question: String,
      options: [String],
      amount: String,
      wager: String,
      opponentId: String,
      opponentName: String,
      status: {
        type: String,
        enum: parlayStatuses,
        default: 'pending',
      },
      expiresAt: Date,
      votes: [
        {
          oderId: String,
          optionIndex: Number,
        },
      ],
      winnersReceived: [String],
    },
    textStatus: { type: String },
    styleName: { type: String },
    etaStatus: { type: String },
    isLocked: {
      type: Boolean,
      default: false,
    },
    unlockedBy: [{ type: String }],
    reactions: [
      {
        userId: String,
        emoji: String,
        createdAt: { type: Date, default: Date.now },
      },
    ],
    viewedBy: [{ type: String }],
    expiresAt: {
      type: Date,
      required: true,
    },
    permanentDeleteAt: {
      type: Date,
      required: true,
    },
    mediaDeleted: {
      type: Boolean,
      default: false,
    },
  },
  { timestamps: true }
);

vibeSchema.index({ chatId: 1, expiresAt: 1 });
vibeSchema.index({ chatId: 1, createdAt: -1 });
vibeSchema.index({ userId: 1, createdAt: -1 });
vibeSchema.index({ conversationId: 1, expiresAt: 1 });
vibeSchema.index({ permanentDeleteAt: 1 }, { expireAfterSeconds: 0 });

vibeSchema.statics.createWithExpiration = function (data: Partial<IVibe>) {
  const now = new Date();
  return this.create({
    ...data,
    expiresAt: data.expiresAt || new Date(now.getTime() + FEED_EXPIRATION_DAYS * 24 * 60 * 60 * 1000),
    permanentDeleteAt: new Date(now.getTime() + HISTORY_RETENTION_DAYS * 24 * 60 * 60 * 1000),
  });
};

const Vibe: IVibeModel = mongoose.model<IVibe, IVibeModel>('Vibe', vibeSchema);

export default Vibe;
