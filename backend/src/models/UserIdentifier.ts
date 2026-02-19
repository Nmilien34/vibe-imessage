import mongoose, { Schema, Model } from 'mongoose';
import { ContactIdentifierKind, IUserIdentifier } from '../types';

const identifierKinds: ContactIdentifierKind[] = ['email', 'phone'];

const userIdentifierSchema = new Schema<IUserIdentifier>(
  {
    userId: { type: String, required: true, index: true },
    kind: {
      type: String,
      enum: identifierKinds,
      required: true,
    },
    hash: { type: String, required: true, index: true },
    verifiedAt: { type: Date, default: Date.now },
  },
  {
    timestamps: true,
  }
);

// One verified identifier can belong to only one account.
userIdentifierSchema.index({ kind: 1, hash: 1 }, { unique: true });
// Prevent duplicate claims by the same user.
userIdentifierSchema.index({ userId: 1, kind: 1, hash: 1 }, { unique: true });

const UserIdentifier: Model<IUserIdentifier> = mongoose.model<IUserIdentifier>('UserIdentifier', userIdentifierSchema);

export default UserIdentifier;
