import mongoose, { Schema, Model } from 'mongoose';
import { IBetResolution, BetOutcome } from '../types';

const outcomes: BetOutcome[] = ['yes', 'no', 'expired', 'ducked'];

const betResolutionSchema = new Schema<IBetResolution>({
  resolutionId: { type: String, required: true, unique: true },
  betId: { type: String, required: true, unique: true, index: true },
  outcome: {
    type: String,
    enum: outcomes,
    required: true,
  },
  resolvedBy: { type: String, required: true },
  resolvedAt: { type: Date, default: Date.now },
  notes: { type: String },
});

const BetResolution: Model<IBetResolution> = mongoose.model<IBetResolution>('BetResolution', betResolutionSchema);

export default BetResolution;
