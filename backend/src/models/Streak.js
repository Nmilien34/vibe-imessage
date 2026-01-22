const mongoose = require('mongoose');

const streakSchema = new mongoose.Schema({
  // Group chat identifier
  conversationId: {
    type: String,
    required: true,
    unique: true,
  },

  // Current streak count
  currentStreak: {
    type: Number,
    default: 0,
  },

  // Longest streak ever
  longestStreak: {
    type: Number,
    default: 0,
  },

  // Last day someone posted (for streak calculation)
  lastPostDate: {
    type: Date,
  },

  // Track who posted today
  todayPosters: [{
    type: String,
  }],

}, { timestamps: true });

module.exports = mongoose.model('Streak', streakSchema);
