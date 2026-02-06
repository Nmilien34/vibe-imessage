import mongoose, { Schema, Model } from 'mongoose';
import { ITeaSpill, TeaSpillStatus } from '../types';

const teaSpillStatuses: TeaSpillStatus[] = ['active', 'revealed', 'expired'];

const teaSpillSchema = new Schema<ITeaSpill>(
  {
    teaId: { type: String, required: true, unique: true },
    chatId: { type: String, required: true, index: true },
    creatorId: { type: String, required: true },
    mysteryText: { type: String, required: true },
    answer: { type: String },
    options: [{ type: String }],
    deadline: { type: Date, required: true },
    status: {
      type: String,
      enum: teaSpillStatuses,
      default: 'active',
      index: true,
    },
    creationCost: { type: Number, default: 10 },
    creatorBonusPercent: { type: Number, default: 10 },
    revealedAt: { type: Date },
  },
  { timestamps: true }
);

const TeaSpill: Model<ITeaSpill> = mongoose.model<ITeaSpill>('TeaSpill', teaSpillSchema);

export default TeaSpill;
