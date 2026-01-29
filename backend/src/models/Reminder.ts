import mongoose, { Schema, Model } from 'mongoose';
import { IReminder, ReminderType } from '../types';

const reminderTypes: ReminderType[] = ['birthday', 'hangout', 'event', 'custom'];

const reminderSchema = new Schema<IReminder>(
  {
    chatId: {
      type: String,
      ref: 'Chat',
      required: true,
    },
    userId: {
      type: String,
      ref: 'User',
      required: true,
    },
    type: {
      type: String,
      enum: reminderTypes,
      required: true,
    },
    emoji: {
      type: String,
      required: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
    },
    date: {
      type: Date,
      required: true,
    },
  },
  { timestamps: true }
);

reminderSchema.index({ chatId: 1, date: 1 });

const Reminder: Model<IReminder> = mongoose.model<IReminder>('Reminder', reminderSchema);

export default Reminder;
