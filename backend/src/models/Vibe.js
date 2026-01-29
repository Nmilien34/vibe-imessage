const mongoose = require('mongoose');

// Retention periods (in days)
const FEED_EXPIRATION_DAYS = 1;      // 24 hours - visible in feed
const HISTORY_RETENTION_DAYS = 15;   // 15 days - viewable in history, then permanently deleted

const vibeSchema = new mongoose.Schema({
  // Who posted it
  userId: {
    type: String,
    required: true,
    index: true,
  },

  // Our virtual Chat ID (from the distributed ID system)
  chatId: {
    type: String,
    required: true,
    index: true,
    ref: 'Chat',
  },

  // Legacy: iMessage conversation identifier (deprecated, kept for migration)
  conversationId: {
    type: String,
    index: true,
  },

  // Optional order ID for sequencing
  oderId: {
    type: String,
  },

  // Content type
  type: {
    type: String,
    required: true,
    enum: ['video', 'photo', 'song', 'battery', 'mood', 'poll', 'dailyDrop', 'tea', 'leak', 'sketch', 'eta', 'parlay'],
  },

  // Media URL (S3) for video content
  mediaUrl: {
    type: String,
  },

  // S3 key for media (used for deletion)
  mediaKey: {
    type: String,
  },

  // Thumbnail for video
  thumbnailUrl: {
    type: String,
  },

  // S3 key for thumbnail (used for deletion)
  thumbnailKey: {
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

  // For parlay type (bets/wagers)
  parlay: {
    title: String,
    amount: String,
    opponentId: String,
    opponentName: String,
    status: {
      type: String,
      enum: ['pending', 'accepted', 'declined', 'settled'],
      default: 'pending',
    },
  },

  // For tea type - text status/caption
  textStatus: {
    type: String,
  },

  // For sketch type - style/brush name
  styleName: {
    type: String,
  },

  // For eta type - location/ETA status
  etaStatus: {
    type: String,
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

  // Soft expiration - when vibe disappears from main feed (24 hours)
  expiresAt: {
    type: Date,
    required: true,
  },

  // Hard deletion - when vibe and media are permanently deleted (15 days)
  permanentDeleteAt: {
    type: Date,
    required: true,
  },

  // Flag to track if media has been cleaned up
  mediaDeleted: {
    type: Boolean,
    default: false,
  },

}, { timestamps: true });

// Index for efficient queries
vibeSchema.index({ chatId: 1, expiresAt: 1 });
vibeSchema.index({ chatId: 1, createdAt: -1 }); // For history queries
vibeSchema.index({ userId: 1, createdAt: -1 }); // For user history
vibeSchema.index({ permanentDeleteAt: 1 }); // For cleanup job queries
// Legacy index (can be removed after migration)
vibeSchema.index({ conversationId: 1, expiresAt: 1 });

// TTL index - MongoDB will automatically delete documents 15 days after creation
// This is a safety net; the cleanup job should handle S3 deletion first
vibeSchema.index({ permanentDeleteAt: 1 }, { expireAfterSeconds: 0 });

// Static method to create with proper expiration dates
vibeSchema.statics.createWithExpiration = function(data) {
  const now = new Date();
  return this.create({
    ...data,
    expiresAt: data.expiresAt || new Date(now.getTime() + FEED_EXPIRATION_DAYS * 24 * 60 * 60 * 1000),
    permanentDeleteAt: new Date(now.getTime() + HISTORY_RETENTION_DAYS * 24 * 60 * 60 * 1000),
  });
};

// Export constants for use in other files
module.exports = mongoose.model('Vibe', vibeSchema);
module.exports.FEED_EXPIRATION_DAYS = FEED_EXPIRATION_DAYS;
module.exports.HISTORY_RETENTION_DAYS = HISTORY_RETENTION_DAYS;
