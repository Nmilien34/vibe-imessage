import mongoose, { Schema, Model } from 'mongoose';
import { IArchivedVibe, VibeType } from '../types';

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

const archivedVibeSchema = new Schema<IArchivedVibe>(
  {
    originalVibeId: {
      type: String,
      required: true,
      unique: true,
    },
    userId: {
      type: String,
      required: true,
      index: true,
    },
    conversationId: {
      type: String,
      required: true,
      index: true,
    },
    type: {
      type: String,
      required: true,
      enum: vibeTypes,
    },
    wasLocked: {
      type: Boolean,
      default: false,
    },
    metrics: {
      viewCount: { type: Number, default: 0 },
      reactionCount: { type: Number, default: 0 },
      unlockCount: { type: Number, default: 0 },
    },
    originalCreatedAt: {
      type: Date,
      required: true,
    },
    archivedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

archivedVibeSchema.index({ conversationId: 1, originalCreatedAt: -1 });
archivedVibeSchema.index({ userId: 1, originalCreatedAt: -1 });
archivedVibeSchema.index({ type: 1 });
archivedVibeSchema.index({ archivedAt: 1 });

const ArchivedVibe: Model<IArchivedVibe> = mongoose.model<IArchivedVibe>('ArchivedVibe', archivedVibeSchema);

export default ArchivedVibe;
