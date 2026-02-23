import mongoose, { Schema, Model } from 'mongoose';
import { IBet, BetType, BetStatus, BetResolutionType } from '../types';

const betTypes: BetType[] = ['self', 'callout', 'dare', 'prediction'];
const betStatuses: BetStatus[] = ['pending', 'active', 'completed', 'expired', 'ducked', 'resolving', 'cancelled'];
const betResolutionTypes: BetResolutionType[] = ['proof', 'observable', 'consensus'];

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
    creationCost: { type: Number, default: 0 },
    participationThreshold: { type: Number, min: 0.1, max: 1.0 },
    resolutionType: {
      type: String,
      enum: betResolutionTypes,
    },
    thresholdMemberCount: { type: Number },
    activatedAt: { type: Date },
    originalDeadlineDuration: { type: Number },
    observableDeclaredOutcome: {
      type: String,
      enum: ['yes', 'no'],
    },
    observableDeclaredBy: { type: String },
    observableDeclaredAt: { type: Date },
  },
  { timestamps: true }
);

const Bet: Model<IBet> = mongoose.model<IBet>('Bet', betSchema);

export default Bet;
