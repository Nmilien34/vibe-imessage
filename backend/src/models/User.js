const mongoose = require('mongoose');

/**
 * User Model
 *
 * Represents a Vibe user. The key innovation here is `joinedChatIds` which
 * tracks all "virtual chat rooms" this user belongs to, enabling the unified feed.
 */
const userSchema = new mongoose.Schema({
  // Our App's internal User ID (auto-generated or from Apple)
  _id: {
    type: String,
    default: () => `user_${new mongoose.Types.ObjectId().toString()}`,
  },

  // Apple Sign-In subject identifier (stable across devices)
  appleId: {
    type: String,
    unique: true,
    sparse: true,
    index: true,
  },

  // Temporary mapping from iMessage's localParticipantIdentifier
  // Note: This changes per device, but useful for session mapping
  appleUUID: {
    type: String,
    index: true,
    sparse: true,
  },

  // User profile info
  firstName: {
    type: String,
  },
  lastName: {
    type: String,
  },
  email: {
    type: String,
    lowercase: true,
  },
  profilePicture: {
    type: String,
  },
  birthday: {
    month: { type: Number },
    day: { type: Number },
  },

  // Array of Chat IDs this user belongs to (enables unified feed)
  joinedChatIds: [{
    type: String,
    ref: 'Chat',
  }],

  // Push notification token
  pushToken: {
    type: String,
  },

  // Last seen for presence
  lastSeen: {
    type: Date,
    default: Date.now,
  },

}, {
  timestamps: true,
  _id: false, // We manage _id ourselves
});

// Index for efficient feed queries
userSchema.index({ joinedChatIds: 1 });

// Helper to add user to a chat
userSchema.methods.joinChat = async function(chatId) {
  if (!this.joinedChatIds.includes(chatId)) {
    this.joinedChatIds.push(chatId);
    await this.save();
  }
  return this;
};

// Helper to leave a chat
userSchema.methods.leaveChat = async function(chatId) {
  this.joinedChatIds = this.joinedChatIds.filter(id => id !== chatId);
  await this.save();
  return this;
};

module.exports = mongoose.model('User', userSchema);
