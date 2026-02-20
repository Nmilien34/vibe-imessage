import mongoose, { Schema, Model } from 'mongoose';
import { IResolutionClaim, BetOutcome, ResolutionClaimStatus } from '../types';

const claimOutcomes: BetOutcome[] = ['yes', 'no', 'ducked'];
const claimStatuses: ResolutionClaimStatus[] = ['pending', 'confirmed', 'auto_confirmed', 'disputed'];

const resolutionClaimSchema = new Schema<IResolutionClaim>(
  {
    claimId: { type: String, required: true, unique: true },
    betId: { type: String, required: true, index: true },
    proofId: { type: String, required: true },
    proposedOutcome: {
      type: String,
      enum: claimOutcomes,
      required: true,
    },
    proposedBy: { type: String, required: true, index: true },
    reviewerIds: [{ type: String, required: true }],
    confirmedBy: [{ type: String, default: [] }],
    disputedBy: [{ type: String, default: [] }],
    status: {
      type: String,
      enum: claimStatuses,
      default: 'pending',
      index: true,
    },
    notes: { type: String },
    autoConfirmAt: { type: Date, required: true, index: true },
    finalizedAt: { type: Date },
  },
  { timestamps: true }
);

resolutionClaimSchema.index({ betId: 1, status: 1, createdAt: -1 });

const ResolutionClaim: Model<IResolutionClaim> = mongoose.model<IResolutionClaim>('ResolutionClaim', resolutionClaimSchema);

export default ResolutionClaim;
