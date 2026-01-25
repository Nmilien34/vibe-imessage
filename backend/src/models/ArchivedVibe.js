const mongoose = require('mongoose');

/**
 * ArchivedVibe - Minimal metadata kept after permanent deletion
 *
 * This model stores only essential data for analytics purposes
 * after the full vibe and media have been deleted (15+ days old).
 * No media URLs or personal content is retained.
 */
const archivedVibeSchema = new mongoose.Schema({
  // Original vibe ID (for reference)
  originalVibeId: {
    type: String,
    required: true,
    unique: true,
  },

  // Who posted it (anonymized if needed)
  userId: {
    type: String,
    required: true,
    index: true,
  },

  // Group chat identifier
  conversationId: {
    type: String,
    required: true,
    index: true,
  },

  // Content type (for analytics)
  type: {
    type: String,
    required: true,
    enum: ['video', 'photo', 'song', 'battery', 'mood', 'poll', 'dailyDrop', 'tea', 'leak', 'sketch', 'eta'],
  },

  // Was it locked content?
  wasLocked: {
    type: Boolean,
    default: false,
  },

  // Engagement metrics
  metrics: {
    viewCount: { type: Number, default: 0 },
    reactionCount: { type: Number, default: 0 },
    unlockCount: { type: Number, default: 0 },
  },

  // Original timestamps
  originalCreatedAt: {
    type: Date,
    required: true,
  },

  // When it was archived
  archivedAt: {
    type: Date,
    default: Date.now,
  },

}, { timestamps: true });

// Index for analytics queries
archivedVibeSchema.index({ conversationId: 1, originalCreatedAt: -1 });
archivedVibeSchema.index({ userId: 1, originalCreatedAt: -1 });
archivedVibeSchema.index({ type: 1 });
archivedVibeSchema.index({ archivedAt: 1 });

// Optional: TTL to delete archived data after 1 year (365 days)
// Uncomment if you want to auto-delete archived data too
// archivedVibeSchema.index({ archivedAt: 1 }, { expireAfterSeconds: 365 * 24 * 60 * 60 });

module.exports = mongoose.model('ArchivedVibe', archivedVibeSchema);
