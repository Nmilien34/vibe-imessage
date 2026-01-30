/**
 * Database Seed Script
 *
 * Creates test users, chats, and vibes for simulator testing.
 * Run with: npm run seed
 *
 * This allows testing the full app flow in the simulator with real API calls,
 * matching exactly what happens on TestFlight/production.
 */

import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from '../models/User';
import Chat from '../models/Chat';
import Vibe from '../models/Vibe';
import Streak from '../models/Streak';

dotenv.config();

// Test User IDs - use these in the simulator
export const TEST_USERS = {
  // Primary test user (you in the simulator)
  me: {
    id: 'test_user_me',
    firstName: 'Test',
    lastName: 'User',
    email: 'test@vibe.app',
  },
  // Friends for the feed
  friend1: {
    id: 'test_user_friend1',
    firstName: 'Alex',
    lastName: 'Chen',
    email: 'alex@vibe.app',
  },
  friend2: {
    id: 'test_user_friend2',
    firstName: 'Jordan',
    lastName: 'Smith',
    email: 'jordan@vibe.app',
  },
  friend3: {
    id: 'test_user_friend3',
    firstName: 'Sam',
    lastName: 'Wilson',
    email: 'sam@vibe.app',
  },
  friend4: {
    id: 'test_user_friend4',
    firstName: 'Riley',
    lastName: 'Brown',
    email: 'riley@vibe.app',
  },
};

// Test Chat ID
export const TEST_CHAT_ID = 'test_chat_main';

async function seed() {
  const mongoUri = process.env.MONGODB_URI;
  if (!mongoUri) {
    console.error('MONGODB_URI not set in environment');
    process.exit(1);
  }

  console.log('Connecting to MongoDB...');
  await mongoose.connect(mongoUri);
  console.log('Connected!\n');

  // Check for --clean flag
  const shouldClean = process.argv.includes('--clean');

  if (shouldClean) {
    console.log('Cleaning existing test data...');
    await cleanTestData();
    console.log('Clean complete!\n');
  }

  console.log('Creating test users...');
  await createTestUsers();

  console.log('Creating test chat...');
  await createTestChat();

  console.log('Creating test vibes...');
  await createTestVibes();

  console.log('Creating test streak...');
  await createTestStreak();

  console.log('\n✅ Seed complete!');
  console.log('\n📱 To test in simulator:');
  console.log(`   1. Use "Dev: Skip Login" button or test user ID: ${TEST_USERS.me.id}`);
  console.log(`   2. The feed will show vibes from test friends`);
  console.log(`   3. Chat ID for testing: ${TEST_CHAT_ID}`);

  await mongoose.disconnect();
}

async function cleanTestData() {
  // Delete test users
  const testUserIds = Object.values(TEST_USERS).map(u => u.id);
  await User.deleteMany({ _id: { $in: testUserIds } });

  // Delete test chat
  await Chat.deleteMany({ _id: TEST_CHAT_ID });

  // Delete vibes from test users
  await Vibe.deleteMany({ userId: { $in: testUserIds } });

  // Delete test streak
  await Streak.deleteMany({ conversationId: TEST_CHAT_ID });
}

async function createTestUsers() {
  for (const [key, userData] of Object.entries(TEST_USERS)) {
    const existing = await User.findById(userData.id);
    if (existing) {
      console.log(`  - ${userData.firstName} already exists, updating...`);
      existing.firstName = userData.firstName;
      existing.lastName = userData.lastName;
      existing.email = userData.email;
      if (!existing.joinedChatIds.includes(TEST_CHAT_ID)) {
        existing.joinedChatIds.push(TEST_CHAT_ID);
      }
      await existing.save();
    } else {
      console.log(`  - Creating ${userData.firstName}...`);
      await User.create({
        _id: userData.id,
        firstName: userData.firstName,
        lastName: userData.lastName,
        email: userData.email,
        joinedChatIds: [TEST_CHAT_ID],
      });
    }
  }
}

async function createTestChat() {
  const existing = await Chat.findById(TEST_CHAT_ID);
  if (existing) {
    console.log('  - Test chat already exists, updating members...');
    existing.members = Object.values(TEST_USERS).map(u => u.id);
    await existing.save();
  } else {
    console.log('  - Creating test chat...');
    await Chat.create({
      _id: TEST_CHAT_ID,
      title: 'Test Group',
      members: Object.values(TEST_USERS).map(u => u.id),
      type: 'group',
      createdBy: TEST_USERS.me.id,
      lastActivityAt: new Date(),
    });
  }
}

async function createTestVibes() {
  const now = new Date();
  const oneDayFromNow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
  const fifteenDaysFromNow = new Date(now.getTime() + 15 * 24 * 60 * 60 * 1000);

  // Delete old test vibes first
  const testUserIds = Object.values(TEST_USERS).map(u => u.id);
  await Vibe.deleteMany({ userId: { $in: testUserIds } });

  const vibes = [
    // Friend 1 - Video (unlocked)
    {
      userId: TEST_USERS.friend1.id,
      chatId: TEST_CHAT_ID,
      type: 'video',
      mediaUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      thumbnailUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerBlazes.jpg',
      isLocked: false,
      unlockedBy: [],
      reactions: [{ userId: TEST_USERS.me.id, emoji: '🔥', createdAt: now }],
      viewedBy: [],
      expiresAt: oneDayFromNow,
      permanentDeleteAt: fifteenDaysFromNow,
      createdAt: new Date(now.getTime() - 5 * 60 * 1000), // 5 min ago
    },
    // Friend 2 - Photo (unlocked)
    {
      userId: TEST_USERS.friend2.id,
      chatId: TEST_CHAT_ID,
      type: 'photo',
      mediaUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800',
      isLocked: false,
      unlockedBy: [],
      reactions: [],
      viewedBy: [],
      expiresAt: oneDayFromNow,
      permanentDeleteAt: fifteenDaysFromNow,
      createdAt: new Date(now.getTime() - 20 * 60 * 1000), // 20 min ago
    },
    // Friend 3 - Locked Video (POV style)
    {
      userId: TEST_USERS.friend3.id,
      chatId: TEST_CHAT_ID,
      type: 'video',
      mediaUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      thumbnailUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerEscapes.jpg',
      isLocked: true,
      unlockedBy: [],
      reactions: [],
      viewedBy: [],
      expiresAt: oneDayFromNow,
      permanentDeleteAt: fifteenDaysFromNow,
      createdAt: new Date(now.getTime() - 60 * 60 * 1000), // 1 hour ago
    },
    // Friend 1 - Mood
    {
      userId: TEST_USERS.friend1.id,
      chatId: TEST_CHAT_ID,
      type: 'mood',
      mood: { emoji: '🚀', text: 'Building something cool!' },
      isLocked: false,
      unlockedBy: [],
      reactions: [],
      viewedBy: [TEST_USERS.me.id],
      expiresAt: oneDayFromNow,
      permanentDeleteAt: fifteenDaysFromNow,
      createdAt: new Date(now.getTime() - 2 * 60 * 60 * 1000), // 2 hours ago
    },
    // Friend 4 - Poll
    {
      userId: TEST_USERS.friend4.id,
      chatId: TEST_CHAT_ID,
      type: 'poll',
      poll: {
        question: 'What should we do this weekend?',
        options: ['Beach day 🏖️', 'Movie night 🎬', 'Game night 🎮', 'Hiking 🥾'],
        votes: [
          { userId: TEST_USERS.friend1.id, optionIndex: 0 },
          { userId: TEST_USERS.friend2.id, optionIndex: 2 },
        ],
      },
      isLocked: false,
      unlockedBy: [],
      reactions: [],
      viewedBy: [],
      expiresAt: oneDayFromNow,
      permanentDeleteAt: fifteenDaysFromNow,
      createdAt: new Date(now.getTime() - 30 * 60 * 1000), // 30 min ago
    },
    // Friend 2 - Battery
    {
      userId: TEST_USERS.friend2.id,
      chatId: TEST_CHAT_ID,
      type: 'battery',
      batteryLevel: 7,
      isLocked: false,
      unlockedBy: [],
      reactions: [{ userId: TEST_USERS.friend3.id, emoji: '🪫', createdAt: now }],
      viewedBy: [],
      expiresAt: oneDayFromNow,
      permanentDeleteAt: fifteenDaysFromNow,
      createdAt: new Date(now.getTime() - 10 * 60 * 1000), // 10 min ago
    },
    // Friend 3 - Song
    {
      userId: TEST_USERS.friend3.id,
      chatId: TEST_CHAT_ID,
      type: 'song',
      songData: {
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        albumArt: 'https://i.scdn.co/image/ab67616d0000b2738863bc11d2aa12b54f5aeb36',
        previewUrl: null,
        spotifyId: '0VjIjW4GlUZAMYd2vXMi3b',
        spotifyUrl: 'https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b',
      },
      isLocked: false,
      unlockedBy: [],
      reactions: [],
      viewedBy: [],
      expiresAt: oneDayFromNow,
      permanentDeleteAt: fifteenDaysFromNow,
      createdAt: new Date(now.getTime() - 3 * 60 * 60 * 1000), // 3 hours ago
    },
    // Me - Mood (my own vibe in feed)
    {
      userId: TEST_USERS.me.id,
      chatId: TEST_CHAT_ID,
      type: 'mood',
      mood: { emoji: '💻', text: 'Coding vibes' },
      isLocked: false,
      unlockedBy: [],
      reactions: [
        { userId: TEST_USERS.friend1.id, emoji: '🔥', createdAt: now },
        { userId: TEST_USERS.friend2.id, emoji: '💪', createdAt: now },
      ],
      viewedBy: [TEST_USERS.friend1.id, TEST_USERS.friend2.id, TEST_USERS.friend3.id],
      expiresAt: oneDayFromNow,
      permanentDeleteAt: fifteenDaysFromNow,
      createdAt: new Date(now.getTime() - 4 * 60 * 60 * 1000), // 4 hours ago
    },
  ];

  for (const vibeData of vibes) {
    console.log(`  - Creating ${vibeData.type} vibe from ${vibeData.userId}...`);
    await Vibe.create(vibeData);
  }
}

async function createTestStreak() {
  const existing = await Streak.findOne({ conversationId: TEST_CHAT_ID });
  if (existing) {
    console.log('  - Updating test streak...');
    existing.currentStreak = 5;
    existing.longestStreak = 12;
    existing.lastPostDate = new Date();
    existing.todayPosters = [TEST_USERS.friend1.id, TEST_USERS.friend2.id];
    await existing.save();
  } else {
    console.log('  - Creating test streak...');
    await Streak.create({
      conversationId: TEST_CHAT_ID,
      currentStreak: 5,
      longestStreak: 12,
      lastPostDate: new Date(),
      todayPosters: [TEST_USERS.friend1.id, TEST_USERS.friend2.id],
    });
  }
}

// Run seed
seed().catch(err => {
  console.error('Seed failed:', err);
  process.exit(1);
});
