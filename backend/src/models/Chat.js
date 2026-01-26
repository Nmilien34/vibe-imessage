const mongoose = require('mongoose');

/**
 * Chat Model - The "Virtual Room"
 *
 * This is the core of our distributed ID system. Since iMessage doesn't give us
 * persistent chat IDs, we create our own "virtual rooms" that persist across
 * devices and sessions.
 *
 * When a user sends a Vibe, the chat_id is embedded in the message URL.
 * Recipients parse this URL and join the same virtual room.
 */
const chatSchema = new mongoose.Schema({
  // Our generated Chat ID (UUID)
  _id: {
    type: String,
    required: true,
  },

  // Optional title for the chat (e.g., "Squad Chat", "Family")
  title: {
    type: String,
    default: null,
  },

  // List of User IDs who are members of this chat
  members: [{
    type: String,
    ref: 'User',
  }],

  // Reference to the most recent vibe (for feed preview)
  lastVibeId: {
    type: String,
    ref: 'Vibe',
    default: null,
  },

  // Timestamp of last activity (for sorting chats)
  lastActivityAt: {
    type: Date,
    default: Date.now,
  },

  // Chat type: 'individual' (1:1) or 'group'
  type: {
    type: String,
    enum: ['individual', 'group'],
    default: 'group',
  },

  // Creator of the chat
  createdBy: {
    type: String,
    ref: 'User',
  },

}, {
  timestamps: true,
  _id: false, // We manage _id ourselves
});

// Index for member lookups
chatSchema.index({ members: 1 });
chatSchema.index({ lastActivityAt: -1 });

// Helper to add a member
chatSchema.methods.addMember = async function(userId) {
  if (!this.members.includes(userId)) {
    this.members.push(userId);
    await this.save();
  }
  return this;
};

// Helper to check if user is a member
chatSchema.methods.isMember = function(userId) {
  return this.members.includes(userId);
};

// Update last activity
chatSchema.methods.touch = async function(vibeId = null) {
  this.lastActivityAt = new Date();
  if (vibeId) {
    this.lastVibeId = vibeId;
  }
  await this.save();
  return this;
};

module.exports = mongoose.model('Chat', chatSchema);
