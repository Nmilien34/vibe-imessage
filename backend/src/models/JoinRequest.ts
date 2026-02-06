import mongoose, { Schema, Model } from 'mongoose';
import { IJoinRequest, JoinRequestStatus } from '../types';

const joinRequestStatuses: JoinRequestStatus[] = ['pending', 'approved', 'denied', 'expired'];

const joinRequestSchema = new Schema<IJoinRequest>(
  {
    requestId: { type: String, required: true, unique: true },
    chatId: { type: String, required: true, index: true },
    userId: { type: String, required: true, index: true },
    reason: { type: String },
    contextBetId: { type: String },
    status: {
      type: String,
      enum: joinRequestStatuses,
      default: 'pending',
      index: true,
    },
    resolvedAt: { type: Date },
  },
  { timestamps: true }
);

const JoinRequest: Model<IJoinRequest> = mongoose.model<IJoinRequest>('JoinRequest', joinRequestSchema);

export default JoinRequest;
