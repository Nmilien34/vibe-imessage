import mongoose, { Schema, Model } from 'mongoose';
import { ITeaGuess } from '../types';

const teaGuessSchema = new Schema<ITeaGuess>(
  {
    guessId: { type: String, required: true, unique: true },
    teaId: { type: String, required: true, index: true },
    userId: { type: String, required: true, index: true },
    guess: { type: String, required: true },
    amount: { type: Number, required: true, min: 10 },
  },
  { timestamps: true }
);

// One guess per user per tea
teaGuessSchema.index({ teaId: 1, userId: 1 }, { unique: true });

const TeaGuess: Model<ITeaGuess> = mongoose.model<ITeaGuess>('TeaGuess', teaGuessSchema);

export default TeaGuess;
