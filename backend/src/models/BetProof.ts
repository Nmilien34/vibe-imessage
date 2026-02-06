import mongoose, { Schema, Model } from 'mongoose';
import { IBetProof, ProofMediaType } from '../types';

const mediaTypes: ProofMediaType[] = ['photo', 'video'];

const betProofSchema = new Schema<IBetProof>(
  {
    proofId: { type: String, required: true, unique: true },
    betId: { type: String, required: true, index: true },
    userId: { type: String, required: true },
    mediaType: {
      type: String,
      enum: mediaTypes,
      required: true,
    },
    mediaUrl: { type: String, required: true },
    mediaKey: { type: String, required: true },
    thumbnailUrl: { type: String },
    thumbnailKey: { type: String },
    caption: { type: String },
  },
  { timestamps: true }
);

const BetProof: Model<IBetProof> = mongoose.model<IBetProof>('BetProof', betProofSchema);

export default BetProof;
