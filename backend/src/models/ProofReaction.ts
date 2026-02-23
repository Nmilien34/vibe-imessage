import mongoose, { Schema, Model } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';
import { IProofReaction, ProofReactionType } from '../types';

const proofReactionTypes: ProofReactionType[] = ['confirm', 'dispute'];

const proofReactionSchema = new Schema<IProofReaction>(
  {
    reactionId: {
      type: String,
      required: true,
      unique: true,
      default: () => `pr_${uuidv4()}`,
    },
    proofId: { type: String, required: true, index: true },
    userId: { type: String, required: true, index: true },
    reaction: {
      type: String,
      enum: proofReactionTypes,
      required: true,
    },
  },
  { timestamps: true }
);

// One reaction per user per proof
proofReactionSchema.index({ proofId: 1, userId: 1 }, { unique: true });

const ProofReaction: Model<IProofReaction> = mongoose.model<IProofReaction>('ProofReaction', proofReactionSchema);

export default ProofReaction;
