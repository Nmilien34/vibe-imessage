import mongoose, { Schema, Model } from 'mongoose';
import { IBetParticipant, BetSide } from '../types';

const sides: BetSide[] = ['yes', 'no'];

const betParticipantSchema = new Schema<IBetParticipant>(
  {
    participantId: { type: String, required: true, unique: true },
    betId: { type: String, required: true, index: true },
    userId: { type: String, required: true, index: true },
    side: {
      type: String,
      enum: sides,
      required: true,
    },
    amount: { type: Number, required: true, min: 10 },
  },
  { timestamps: true }
);

// One participation per user per bet
betParticipantSchema.index({ betId: 1, userId: 1 }, { unique: true });

const BetParticipant: Model<IBetParticipant> = mongoose.model<IBetParticipant>('BetParticipant', betParticipantSchema);

export default BetParticipant;
