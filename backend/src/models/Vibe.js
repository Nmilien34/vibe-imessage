const mongoose = require('mongoose');

const vibeSchema = new mongoose.Schema({
  // Who posted it
  userId: {
    type: String,
    required: true,
    index: true,
  },

  // Group chat identifier (from iMessage)
  conversationId: {
    type: String,
    required: true,
    index: true,
  },

  // Content type: 'video', 'photo', 'song', 'battery', 'mood', 'poll'
  type: {
    type: String,
    required: true,
    enum: ['video', 'photo', 'song', 'battery', 'mood', 'poll'],
  },

  // Media URL (S3) for video content
  mediaUrl: {
    type: String,
  },

  // Thumbnail for video
  thumbnailUrl: {
    type: String,
  },

  // For song type - Spotify/Apple Music data
  songData: {
    title: String,
    artist: String,
    albumArt: String,
    previewUrl: String,
    spotifyId: String,
  },

  // For battery type
  batteryLevel: {
    type: Number,
    min: 0,
    max: 100,
  },

  // For mood type
  mood: {
    emoji: String,
    text: String,
  },

  // For poll type
  poll: {
    question: String,
    options: [String],
    votes: [{
      userId: String,
      optionIndex: Number,
    }],
  },

  // Lock to unlock feature
  isLocked: {
    type: Boolean,
    default: false,
  },

  // Users who have unlocked this vibe (by posting their own)
  unlockedBy: [{
    type: String,
  }],

  // Reactions
  reactions: [{
    userId: String,
    emoji: String,
    createdAt: { type: Date, default: Date.now },
  }],

  // Views
  viewedBy: [{
    type: String,
  }],

  // Auto-delete after 24 hours
  expiresAt: {
    type: Date,
    required: true,
    index: true,
  },

}, { timestamps: true });

// Index for efficient queries
vibeSchema.index({ conversationId: 1, expiresAt: 1 });
vibeSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 }); // TTL index for auto-delete

module.exports = mongoose.model('Vibe', vibeSchema);
