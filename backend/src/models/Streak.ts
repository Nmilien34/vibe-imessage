import mongoose, { Schema, Model } from 'mongoose';
import { IStreak } from '../types';

const streakSchema = new Schema<IStreak>(
  {
    conversationId: {
      type: String,
      required: true,
      unique: true,
    },
    currentStreak: {
      type: Number,
      default: 0,
    },
    longestStreak: {
      type: Number,
      default: 0,
    },
    lastPostDate: { type: Date },
    todayPosters: [{ type: String }],
  },
  { timestamps: true }
);

const Streak: Model<IStreak> = mongoose.model<IStreak>('Streak', streakSchema);

export default Streak;
