import mongoose, { Schema, Model } from 'mongoose';
import { IAuraTransaction } from '../types';

const auraTransactionSchema = new Schema<IAuraTransaction>(
  {
    transactionId: { type: String, required: true, unique: true },
    userId: { type: String, required: true, index: true },
    amount: { type: Number, required: true },
    balanceAfter: { type: Number, required: true },
    transactionType: { type: String, required: true, index: true },
    referenceId: { type: String, index: true },
    description: { type: String },
  },
  { timestamps: true }
);

const AuraTransaction: Model<IAuraTransaction> = mongoose.model<IAuraTransaction>('AuraTransaction', auraTransactionSchema);

export default AuraTransaction;
