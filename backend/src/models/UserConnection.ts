import mongoose, { Schema, Model } from 'mongoose';
import { IUserConnection } from '../types';

const userConnectionSchema = new Schema<IUserConnection>({
  connectionId: { type: String, required: true, unique: true },
  userId1: { type: String, required: true, index: true },
  userId2: { type: String, required: true, index: true },
  sourceChatId: { type: String, required: true },
  establishedAt: { type: Date, default: Date.now },
  lastInteraction: { type: Date, default: Date.now },
});

// Unique pair — userId1 is always the lexicographically smaller ID
userConnectionSchema.index({ userId1: 1, userId2: 1 }, { unique: true });

const UserConnection: Model<IUserConnection> = mongoose.model<IUserConnection>('UserConnection', userConnectionSchema);

export default UserConnection;
