import mongoose, { Schema, Model } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';
import { IConsensusVote, ConsensusVoteChoice } from '../types';

const voteChoices: ConsensusVoteChoice[] = ['yes', 'no'];

const consensusVoteSchema = new Schema<IConsensusVote>(
  {
    voteId: {
      type: String,
      required: true,
      unique: true,
      default: () => `vote_${uuidv4()}`,
    },
    betId: { type: String, required: true, index: true },
    userId: { type: String, required: true, index: true },
    vote: {
      type: String,
      enum: voteChoices,
      required: true,
    },
  },
  { timestamps: true }
);

// One vote per user per bet
consensusVoteSchema.index({ betId: 1, userId: 1 }, { unique: true });

const ConsensusVote: Model<IConsensusVote> = mongoose.model<IConsensusVote>('ConsensusVote', consensusVoteSchema);

export default ConsensusVote;
