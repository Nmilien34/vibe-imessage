/**
 * Database Seed Script
 *
 * Creates test users + rich mock data in MongoDB for simulator testing.
 * Run with: npm run seed
 *
 * This allows testing the full app flow in the simulator with real API calls,
 * matching exactly what happens on TestFlight/production.
 */

import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from '../models/User';
import Chat from '../models/Chat';
import ChatMember from '../models/ChatMember';
import Vibe from '../models/Vibe';
import Bet from '../models/Bet';
import BetParticipant from '../models/BetParticipant';
import TeaSpill from '../models/TeaSpill';
import TeaGuess from '../models/TeaGuess';
import Streak from '../models/Streak';

dotenv.config();

interface TestUserData {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
}

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
  // Extra fake user for QA checks
  qa: {
    id: 'test_user_qa',
    firstName: 'Morgan',
    lastName: 'QA',
    email: 'morgan.qa@vibe.app',
  },
};

// Test Chat ID
export const TEST_CHAT_ID = 'test_chat_main';
const SEEDED_BET_IDS = [
  'seed_bet_active_self',
  'seed_bet_active_callout',
  'seed_bet_completed',
];
const SEEDED_TEA_IDS = [
  'seed_tea_active',
  'seed_tea_revealed',
];

function testUserIds(): string[] {
  return Object.values(TEST_USERS).map((user) => user.id);
}

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

  console.log('Creating chat memberships...');
  await createTestChatMembers();

  console.log('Creating test vibes...');
  await createTestVibes();

  console.log('Creating test bets...');
  await createTestBets();

  console.log('Creating test tea spills...');
  await createTestTeaSpills();

  console.log('Creating test streak...');
  await createTestStreak();

  console.log('\n✅ Seed complete!');
  console.log('\n📱 To test in simulator:');
  console.log(`   1. Use "Dev: Skip Login" button or test user ID: ${TEST_USERS.me.id}`);
  console.log(`   2. Fake QA user available: ${TEST_USERS.qa.id}`);
  console.log(`   3. Discover feed includes bets + tea + vibes`);
  console.log(`   4. Chat ID for testing: ${TEST_CHAT_ID}`);

  await mongoose.disconnect();
}

async function cleanTestData() {
  const users = testUserIds();

  await TeaGuess.deleteMany({
    $or: [
      { teaId: { $in: SEEDED_TEA_IDS } },
      { userId: { $in: users } },
    ],
  });

  await TeaSpill.deleteMany({
    $or: [
      { teaId: { $in: SEEDED_TEA_IDS } },
      { chatId: TEST_CHAT_ID, creatorId: { $in: users } },
    ],
  });

  await BetParticipant.deleteMany({
    $or: [
      { betId: { $in: SEEDED_BET_IDS } },
      { userId: { $in: users } },
    ],
  });

  await Bet.deleteMany({
    $or: [
      { betId: { $in: SEEDED_BET_IDS } },
      { chatId: TEST_CHAT_ID, creatorId: { $in: users } },
    ],
  });

  await Vibe.deleteMany({ chatId: TEST_CHAT_ID, userId: { $in: users } });
  await ChatMember.deleteMany({ chatId: TEST_CHAT_ID, userId: { $in: users } });
  await Streak.deleteMany({ conversationId: TEST_CHAT_ID });
  await Chat.deleteMany({ _id: TEST_CHAT_ID });
  await User.deleteMany({ _id: { $in: users } });
}

async function createTestUsers() {
  for (const userData of Object.values(TEST_USERS) as TestUserData[]) {
    const existing = await User.findById(userData.id);
    if (existing) {
      console.log(`  - ${userData.firstName} already exists, updating...`);
      existing.firstName = userData.firstName;
      existing.lastName = userData.lastName;
      existing.email = userData.email;
      existing.auraBalance = 100;
      existing.vibeScore = 120;
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
        auraBalance: 100,
        vibeScore: 120,
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
      title: 'Test Squad',
      members: Object.values(TEST_USERS).map(u => u.id),
      type: 'group',
      createdBy: TEST_USERS.me.id,
      lastActivityAt: new Date(),
    });
  }
}

async function createTestChatMembers() {
  const now = new Date();
  const userIds = testUserIds();

  for (const userId of userIds) {
    const memberId = `seed_member_${TEST_CHAT_ID}_${userId}`;
    await ChatMember.updateOne(
      { chatId: TEST_CHAT_ID, userId },
      {
        $set: {
          memberId,
          membershipType: 'full',
          role: userId === TEST_USERS.me.id ? 'admin' : 'member',
          joinedAt: now,
        },
      },
      { upsert: true }
    );
  }
}

async function createTestVibes() {
  const now = new Date();
  const oneDayFromNow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
  const fifteenDaysFromNow = new Date(now.getTime() + 15 * 24 * 60 * 60 * 1000);

  // Delete old test vibes first
  await Vibe.deleteMany({ chatId: TEST_CHAT_ID, userId: { $in: testUserIds() } });

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
    // QA user - Photo
    {
      userId: TEST_USERS.qa.id,
      chatId: TEST_CHAT_ID,
      type: 'photo',
      mediaUrl: 'https://images.unsplash.com/photo-1470770903676-69b98201ea1c?w=800',
      isLocked: false,
      unlockedBy: [],
      reactions: [{ userId: TEST_USERS.me.id, emoji: '👀', createdAt: now }],
      viewedBy: [],
      expiresAt: oneDayFromNow,
      permanentDeleteAt: fifteenDaysFromNow,
      createdAt: new Date(now.getTime() - 40 * 60 * 1000), // 40 min ago
    },
  ];

  for (const vibeData of vibes) {
    console.log(`  - Creating ${vibeData.type} vibe from ${vibeData.userId}...`);
    await Vibe.create(vibeData);
  }
}

async function createTestBets() {
  const now = new Date();

  await BetParticipant.deleteMany({ betId: { $in: SEEDED_BET_IDS } });
  await Bet.deleteMany({ betId: { $in: SEEDED_BET_IDS } });

  const bets = [
    {
      betId: SEEDED_BET_IDS[0],
      chatId: TEST_CHAT_ID,
      creatorId: TEST_USERS.friend1.id,
      betType: 'self',
      description: 'I will post 3 workout updates by tonight.',
      deadline: new Date(now.getTime() + 8 * 60 * 60 * 1000),
      status: 'active',
      creationCost: 10,
      createdAt: new Date(now.getTime() - 2 * 60 * 60 * 1000),
      updatedAt: new Date(now.getTime() - 2 * 60 * 60 * 1000),
    },
    {
      betId: SEEDED_BET_IDS[1],
      chatId: TEST_CHAT_ID,
      creatorId: TEST_USERS.qa.id,
      betType: 'callout',
      description: 'Jordan says they can go 24h without soda.',
      deadline: new Date(now.getTime() + 14 * 60 * 60 * 1000),
      status: 'active',
      targetUserId: TEST_USERS.friend2.id,
      creationCost: 10,
      createdAt: new Date(now.getTime() - 75 * 60 * 1000),
      updatedAt: new Date(now.getTime() - 75 * 60 * 1000),
    },
    {
      betId: SEEDED_BET_IDS[2],
      chatId: TEST_CHAT_ID,
      creatorId: TEST_USERS.friend3.id,
      betType: 'dare',
      description: 'Dare accepted: ice bath for 2 minutes.',
      deadline: new Date(now.getTime() - 6 * 60 * 60 * 1000),
      status: 'completed',
      targetUserId: TEST_USERS.friend4.id,
      creationCost: 10,
      createdAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
      updatedAt: new Date(now.getTime() - 4 * 60 * 60 * 1000),
    },
  ];

  await Bet.insertMany(bets);

  const participants = [
    { participantId: 'seed_participant_1', betId: SEEDED_BET_IDS[0], userId: TEST_USERS.friend1.id, side: 'yes', amount: 25 },
    { participantId: 'seed_participant_2', betId: SEEDED_BET_IDS[0], userId: TEST_USERS.me.id, side: 'yes', amount: 20 },
    { participantId: 'seed_participant_3', betId: SEEDED_BET_IDS[0], userId: TEST_USERS.friend2.id, side: 'no', amount: 30 },
    { participantId: 'seed_participant_4', betId: SEEDED_BET_IDS[1], userId: TEST_USERS.qa.id, side: 'yes', amount: 40 },
    { participantId: 'seed_participant_5', betId: SEEDED_BET_IDS[1], userId: TEST_USERS.friend4.id, side: 'no', amount: 25 },
    { participantId: 'seed_participant_6', betId: SEEDED_BET_IDS[2], userId: TEST_USERS.friend3.id, side: 'yes', amount: 35 },
    { participantId: 'seed_participant_7', betId: SEEDED_BET_IDS[2], userId: TEST_USERS.me.id, side: 'yes', amount: 15 },
  ];

  await BetParticipant.insertMany(participants);
}

async function createTestTeaSpills() {
  const now = new Date();

  await TeaGuess.deleteMany({ teaId: { $in: SEEDED_TEA_IDS } });
  await TeaSpill.deleteMany({ teaId: { $in: SEEDED_TEA_IDS } });

  const teas = [
    {
      teaId: SEEDED_TEA_IDS[0],
      chatId: TEST_CHAT_ID,
      creatorId: TEST_USERS.friend4.id,
      mysteryText: 'Who sent flowers to the office today?',
      answer: 'Morgan',
      options: ['Alex', 'Jordan', 'Morgan', 'Sam'],
      deadline: new Date(now.getTime() + 10 * 60 * 60 * 1000),
      status: 'active',
      creationCost: 10,
      creatorBonusPercent: 0,
      createdAt: new Date(now.getTime() - 95 * 60 * 1000),
      updatedAt: new Date(now.getTime() - 95 * 60 * 1000),
    },
    {
      teaId: SEEDED_TEA_IDS[1],
      chatId: TEST_CHAT_ID,
      creatorId: TEST_USERS.qa.id,
      mysteryText: 'Who accidentally deleted the shared deck?',
      answer: 'Sam',
      options: ['Alex', 'Sam', 'Jordan'],
      deadline: new Date(now.getTime() - 14 * 60 * 60 * 1000),
      status: 'revealed',
      revealedAt: new Date(now.getTime() - 12 * 60 * 60 * 1000),
      creationCost: 10,
      creatorBonusPercent: 0,
      createdAt: new Date(now.getTime() - 22 * 60 * 60 * 1000),
      updatedAt: new Date(now.getTime() - 12 * 60 * 60 * 1000),
    },
  ];

  await TeaSpill.insertMany(teas);

  const guesses = [
    {
      guessId: 'seed_guess_1',
      teaId: SEEDED_TEA_IDS[0],
      userId: TEST_USERS.me.id,
      guess: 'Morgan',
      amount: 25,
    },
    {
      guessId: 'seed_guess_2',
      teaId: SEEDED_TEA_IDS[0],
      userId: TEST_USERS.friend2.id,
      guess: 'Alex',
      amount: 20,
    },
    {
      guessId: 'seed_guess_3',
      teaId: SEEDED_TEA_IDS[1],
      userId: TEST_USERS.friend1.id,
      guess: 'Sam',
      amount: 30,
    },
    {
      guessId: 'seed_guess_4',
      teaId: SEEDED_TEA_IDS[1],
      userId: TEST_USERS.friend3.id,
      guess: 'Alex',
      amount: 15,
    },
  ];

  await TeaGuess.insertMany(guesses);
}

async function createTestStreak() {
  const existing = await Streak.findOne({ conversationId: TEST_CHAT_ID });
  if (existing) {
    console.log('  - Updating test streak...');
    existing.currentStreak = 5;
    existing.longestStreak = 12;
    existing.lastPostDate = new Date();
    existing.todayPosters = [TEST_USERS.friend1.id, TEST_USERS.friend2.id, TEST_USERS.qa.id];
    await existing.save();
  } else {
    console.log('  - Creating test streak...');
    await Streak.create({
      conversationId: TEST_CHAT_ID,
      currentStreak: 5,
      longestStreak: 12,
      lastPostDate: new Date(),
      todayPosters: [TEST_USERS.friend1.id, TEST_USERS.friend2.id, TEST_USERS.qa.id],
    });
  }
}

// Run seed
seed().catch(err => {
  console.error('Seed failed:', err);
  process.exit(1);
});
