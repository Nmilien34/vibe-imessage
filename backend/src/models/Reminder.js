const mongoose = require('mongoose');

const reminderSchema = new mongoose.Schema({
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
    enum: ['birthday', 'hangout', 'event', 'custom'],
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
}, {
  timestamps: true,
});

reminderSchema.index({ chatId: 1, date: 1 });

module.exports = mongoose.model('Reminder', reminderSchema);
