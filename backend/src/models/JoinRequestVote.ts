import mongoose, { Schema, Model } from 'mongoose';
import { IJoinRequestVote, JoinDecision } from '../types';

const decisions: JoinDecision[] = ['approve', 'deny'];

const joinRequestVoteSchema = new Schema<IJoinRequestVote>({
  voteId: { type: String, required: true, unique: true },
  requestId: { type: String, required: true, index: true },
  voterId: { type: String, required: true },
  decision: {
    type: String,
    enum: decisions,
    required: true,
  },
  votedAt: { type: Date, default: Date.now },
});

// One vote per voter per request
joinRequestVoteSchema.index({ requestId: 1, voterId: 1 }, { unique: true });

const JoinRequestVote: Model<IJoinRequestVote> = mongoose.model<IJoinRequestVote>('JoinRequestVote', joinRequestVoteSchema);

export default JoinRequestVote;
