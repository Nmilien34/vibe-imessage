import mongoose, { Schema, Model } from 'mongoose';
import { IBet, BetType, BetStatus } from '../types';

const betTypes: BetType[] = ['self', 'callout', 'dare'];
const betStatuses: BetStatus[] = ['active', 'completed', 'expired', 'ducked'];

const betSchema = new Schema<IBet>(
  {
    betId: { type: String, required: true, unique: true },
    chatId: { type: String, required: true, index: true },
    creatorId: { type: String, required: true, index: true },
    betType: {
      type: String,
      enum: betTypes,
      required: true,
    },
    description: { type: String, required: true },
    deadline: { type: Date, required: true, index: true },
    status: {
      type: String,
      enum: betStatuses,
      default: 'active',
      index: true,
    },
    targetUserId: { type: String },
    creationCost: { type: Number, default: 10 },
  },
  { timestamps: true }
);

const Bet: Model<IBet> = mongoose.model<IBet>('Bet', betSchema);

export default Bet;
