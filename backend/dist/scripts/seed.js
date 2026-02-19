"use strict";
/**
 * Database Seed Script
 *
 * Creates test users + rich mock data in MongoDB for simulator testing.
 * Run with: npm run seed
 *
 * This allows testing the full app flow in the simulator with real API calls,
 * matching exactly what happens on TestFlight/production.
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.TEST_CHAT_ID = exports.TEST_USERS = void 0;
const mongoose_1 = __importDefault(require("mongoose"));
const dotenv_1 = __importDefault(require("dotenv"));
const User_1 = __importDefault(require("../models/User"));
const Chat_1 = __importDefault(require("../models/Chat"));
const ChatMember_1 = __importDefault(require("../models/ChatMember"));
const Vibe_1 = __importDefault(require("../models/Vibe"));
const Bet_1 = __importDefault(require("../models/Bet"));
const BetParticipant_1 = __importDefault(require("../models/BetParticipant"));
const TeaSpill_1 = __importDefault(require("../models/TeaSpill"));
const TeaGuess_1 = __importDefault(require("../models/TeaGuess"));
const Streak_1 = __importDefault(require("../models/Streak"));
dotenv_1.default.config();
// Test User IDs - use these in the simulator
exports.TEST_USERS = {
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
exports.TEST_CHAT_ID = 'test_chat_main';
const SEEDED_BET_IDS = [
    'seed_bet_active_self',
    'seed_bet_active_callout',
    'seed_bet_completed',
];
const SEEDED_TEA_IDS = [
    'seed_tea_active',
    'seed_tea_revealed',
];
function testUserIds() {
    return Object.values(exports.TEST_USERS).map((user) => user.id);
}
async function seed() {
    const mongoUri = process.env.MONGODB_URI;
    if (!mongoUri) {
        console.error('MONGODB_URI not set in environment');
        process.exit(1);
    }
    console.log('Connecting to MongoDB...');
    await mongoose_1.default.connect(mongoUri);
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
    console.log(`   1. Use "Dev: Skip Login" button or test user ID: ${exports.TEST_USERS.me.id}`);
    console.log(`   2. Fake QA user available: ${exports.TEST_USERS.qa.id}`);
    console.log(`   3. Discover feed includes bets + tea + vibes`);
    console.log(`   4. Chat ID for testing: ${exports.TEST_CHAT_ID}`);
    await mongoose_1.default.disconnect();
}
async function cleanTestData() {
    const users = testUserIds();
    await TeaGuess_1.default.deleteMany({
        $or: [
            { teaId: { $in: SEEDED_TEA_IDS } },
            { userId: { $in: users } },
        ],
    });
    await TeaSpill_1.default.deleteMany({
        $or: [
            { teaId: { $in: SEEDED_TEA_IDS } },
            { chatId: exports.TEST_CHAT_ID, creatorId: { $in: users } },
        ],
    });
    await BetParticipant_1.default.deleteMany({
        $or: [
            { betId: { $in: SEEDED_BET_IDS } },
            { userId: { $in: users } },
        ],
    });
    await Bet_1.default.deleteMany({
        $or: [
            { betId: { $in: SEEDED_BET_IDS } },
            { chatId: exports.TEST_CHAT_ID, creatorId: { $in: users } },
        ],
    });
    await Vibe_1.default.deleteMany({ chatId: exports.TEST_CHAT_ID, userId: { $in: users } });
    await ChatMember_1.default.deleteMany({ chatId: exports.TEST_CHAT_ID, userId: { $in: users } });
    await Streak_1.default.deleteMany({ conversationId: exports.TEST_CHAT_ID });
    await Chat_1.default.deleteMany({ _id: exports.TEST_CHAT_ID });
    await User_1.default.deleteMany({ _id: { $in: users } });
}
async function createTestUsers() {
    for (const userData of Object.values(exports.TEST_USERS)) {
        const existing = await User_1.default.findById(userData.id);
        if (existing) {
            console.log(`  - ${userData.firstName} already exists, updating...`);
            existing.firstName = userData.firstName;
            existing.lastName = userData.lastName;
            existing.email = userData.email;
            existing.auraBalance = 100;
            existing.vibeScore = 120;
            if (!existing.joinedChatIds.includes(exports.TEST_CHAT_ID)) {
                existing.joinedChatIds.push(exports.TEST_CHAT_ID);
            }
            await existing.save();
        }
        else {
            console.log(`  - Creating ${userData.firstName}...`);
            await User_1.default.create({
                _id: userData.id,
                firstName: userData.firstName,
                lastName: userData.lastName,
                email: userData.email,
                auraBalance: 100,
                vibeScore: 120,
                joinedChatIds: [exports.TEST_CHAT_ID],
            });
        }
    }
}
async function createTestChat() {
    const existing = await Chat_1.default.findById(exports.TEST_CHAT_ID);
    if (existing) {
        console.log('  - Test chat already exists, updating members...');
        existing.members = Object.values(exports.TEST_USERS).map(u => u.id);
        await existing.save();
    }
    else {
        console.log('  - Creating test chat...');
        await Chat_1.default.create({
            _id: exports.TEST_CHAT_ID,
            title: 'Test Squad',
            members: Object.values(exports.TEST_USERS).map(u => u.id),
            type: 'group',
            createdBy: exports.TEST_USERS.me.id,
            lastActivityAt: new Date(),
        });
    }
}
async function createTestChatMembers() {
    const now = new Date();
    const userIds = testUserIds();
    for (const userId of userIds) {
        const memberId = `seed_member_${exports.TEST_CHAT_ID}_${userId}`;
        await ChatMember_1.default.updateOne({ chatId: exports.TEST_CHAT_ID, userId }, {
            $set: {
                memberId,
                membershipType: 'full',
                role: userId === exports.TEST_USERS.me.id ? 'admin' : 'member',
                joinedAt: now,
            },
        }, { upsert: true });
    }
}
async function createTestVibes() {
    const now = new Date();
    const oneDayFromNow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const fifteenDaysFromNow = new Date(now.getTime() + 15 * 24 * 60 * 60 * 1000);
    // Delete old test vibes first
    await Vibe_1.default.deleteMany({ chatId: exports.TEST_CHAT_ID, userId: { $in: testUserIds() } });
    const vibes = [
        // Friend 1 - Video (unlocked)
        {
            userId: exports.TEST_USERS.friend1.id,
            chatId: exports.TEST_CHAT_ID,
            type: 'video',
            mediaUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
            thumbnailUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerBlazes.jpg',
            isLocked: false,
            unlockedBy: [],
            reactions: [{ userId: exports.TEST_USERS.me.id, emoji: '🔥', createdAt: now }],
            viewedBy: [],
            expiresAt: oneDayFromNow,
            permanentDeleteAt: fifteenDaysFromNow,
            createdAt: new Date(now.getTime() - 5 * 60 * 1000), // 5 min ago
        },
        // Friend 2 - Photo (unlocked)
        {
            userId: exports.TEST_USERS.friend2.id,
            chatId: exports.TEST_CHAT_ID,
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
            userId: exports.TEST_USERS.friend3.id,
            chatId: exports.TEST_CHAT_ID,
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
            userId: exports.TEST_USERS.friend1.id,
            chatId: exports.TEST_CHAT_ID,
            type: 'mood',
            mood: { emoji: '🚀', text: 'Building something cool!' },
            isLocked: false,
            unlockedBy: [],
            reactions: [],
            viewedBy: [exports.TEST_USERS.me.id],
            expiresAt: oneDayFromNow,
            permanentDeleteAt: fifteenDaysFromNow,
            createdAt: new Date(now.getTime() - 2 * 60 * 60 * 1000), // 2 hours ago
        },
        // Friend 4 - Poll
        {
            userId: exports.TEST_USERS.friend4.id,
            chatId: exports.TEST_CHAT_ID,
            type: 'poll',
            poll: {
                question: 'What should we do this weekend?',
                options: ['Beach day 🏖️', 'Movie night 🎬', 'Game night 🎮', 'Hiking 🥾'],
                votes: [
                    { userId: exports.TEST_USERS.friend1.id, optionIndex: 0 },
                    { userId: exports.TEST_USERS.friend2.id, optionIndex: 2 },
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
            userId: exports.TEST_USERS.friend2.id,
            chatId: exports.TEST_CHAT_ID,
            type: 'battery',
            batteryLevel: 7,
            isLocked: false,
            unlockedBy: [],
            reactions: [{ userId: exports.TEST_USERS.friend3.id, emoji: '🪫', createdAt: now }],
            viewedBy: [],
            expiresAt: oneDayFromNow,
            permanentDeleteAt: fifteenDaysFromNow,
            createdAt: new Date(now.getTime() - 10 * 60 * 1000), // 10 min ago
        },
        // Friend 3 - Song
        {
            userId: exports.TEST_USERS.friend3.id,
            chatId: exports.TEST_CHAT_ID,
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
            userId: exports.TEST_USERS.me.id,
            chatId: exports.TEST_CHAT_ID,
            type: 'mood',
            mood: { emoji: '💻', text: 'Coding vibes' },
            isLocked: false,
            unlockedBy: [],
            reactions: [
                { userId: exports.TEST_USERS.friend1.id, emoji: '🔥', createdAt: now },
                { userId: exports.TEST_USERS.friend2.id, emoji: '💪', createdAt: now },
            ],
            viewedBy: [exports.TEST_USERS.friend1.id, exports.TEST_USERS.friend2.id, exports.TEST_USERS.friend3.id],
            expiresAt: oneDayFromNow,
            permanentDeleteAt: fifteenDaysFromNow,
            createdAt: new Date(now.getTime() - 4 * 60 * 60 * 1000), // 4 hours ago
        },
        // QA user - Photo
        {
            userId: exports.TEST_USERS.qa.id,
            chatId: exports.TEST_CHAT_ID,
            type: 'photo',
            mediaUrl: 'https://images.unsplash.com/photo-1470770903676-69b98201ea1c?w=800',
            isLocked: false,
            unlockedBy: [],
            reactions: [{ userId: exports.TEST_USERS.me.id, emoji: '👀', createdAt: now }],
            viewedBy: [],
            expiresAt: oneDayFromNow,
            permanentDeleteAt: fifteenDaysFromNow,
            createdAt: new Date(now.getTime() - 40 * 60 * 1000), // 40 min ago
        },
    ];
    for (const vibeData of vibes) {
        console.log(`  - Creating ${vibeData.type} vibe from ${vibeData.userId}...`);
        await Vibe_1.default.create(vibeData);
    }
}
async function createTestBets() {
    const now = new Date();
    await BetParticipant_1.default.deleteMany({ betId: { $in: SEEDED_BET_IDS } });
    await Bet_1.default.deleteMany({ betId: { $in: SEEDED_BET_IDS } });
    const bets = [
        {
            betId: SEEDED_BET_IDS[0],
            chatId: exports.TEST_CHAT_ID,
            creatorId: exports.TEST_USERS.friend1.id,
            betType: 'self',
            description: 'I will post 3 workout updates by tonight.',
            deadline: new Date(now.getTime() + 8 * 60 * 60 * 1000),
            status: 'active',
            creationCost: 2,
            createdAt: new Date(now.getTime() - 2 * 60 * 60 * 1000),
            updatedAt: new Date(now.getTime() - 2 * 60 * 60 * 1000),
        },
        {
            betId: SEEDED_BET_IDS[1],
            chatId: exports.TEST_CHAT_ID,
            creatorId: exports.TEST_USERS.qa.id,
            betType: 'callout',
            description: 'Jordan says they can go 24h without soda.',
            deadline: new Date(now.getTime() + 14 * 60 * 60 * 1000),
            status: 'active',
            targetUserId: exports.TEST_USERS.friend2.id,
            creationCost: 2,
            createdAt: new Date(now.getTime() - 75 * 60 * 1000),
            updatedAt: new Date(now.getTime() - 75 * 60 * 1000),
        },
        {
            betId: SEEDED_BET_IDS[2],
            chatId: exports.TEST_CHAT_ID,
            creatorId: exports.TEST_USERS.friend3.id,
            betType: 'dare',
            description: 'Dare accepted: ice bath for 2 minutes.',
            deadline: new Date(now.getTime() - 6 * 60 * 60 * 1000),
            status: 'completed',
            targetUserId: exports.TEST_USERS.friend4.id,
            creationCost: 2,
            createdAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
            updatedAt: new Date(now.getTime() - 4 * 60 * 60 * 1000),
        },
    ];
    await Bet_1.default.insertMany(bets);
    const participants = [
        { participantId: 'seed_participant_1', betId: SEEDED_BET_IDS[0], userId: exports.TEST_USERS.friend1.id, side: 'yes', amount: 25 },
        { participantId: 'seed_participant_2', betId: SEEDED_BET_IDS[0], userId: exports.TEST_USERS.me.id, side: 'yes', amount: 20 },
        { participantId: 'seed_participant_3', betId: SEEDED_BET_IDS[0], userId: exports.TEST_USERS.friend2.id, side: 'no', amount: 30 },
        { participantId: 'seed_participant_4', betId: SEEDED_BET_IDS[1], userId: exports.TEST_USERS.qa.id, side: 'yes', amount: 40 },
        { participantId: 'seed_participant_5', betId: SEEDED_BET_IDS[1], userId: exports.TEST_USERS.friend4.id, side: 'no', amount: 25 },
        { participantId: 'seed_participant_6', betId: SEEDED_BET_IDS[2], userId: exports.TEST_USERS.friend3.id, side: 'yes', amount: 35 },
        { participantId: 'seed_participant_7', betId: SEEDED_BET_IDS[2], userId: exports.TEST_USERS.me.id, side: 'yes', amount: 15 },
    ];
    await BetParticipant_1.default.insertMany(participants);
}
async function createTestTeaSpills() {
    const now = new Date();
    await TeaGuess_1.default.deleteMany({ teaId: { $in: SEEDED_TEA_IDS } });
    await TeaSpill_1.default.deleteMany({ teaId: { $in: SEEDED_TEA_IDS } });
    const teas = [
        {
            teaId: SEEDED_TEA_IDS[0],
            chatId: exports.TEST_CHAT_ID,
            creatorId: exports.TEST_USERS.friend4.id,
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
            chatId: exports.TEST_CHAT_ID,
            creatorId: exports.TEST_USERS.qa.id,
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
    await TeaSpill_1.default.insertMany(teas);
    const guesses = [
        {
            guessId: 'seed_guess_1',
            teaId: SEEDED_TEA_IDS[0],
            userId: exports.TEST_USERS.me.id,
            guess: 'Morgan',
            amount: 25,
        },
        {
            guessId: 'seed_guess_2',
            teaId: SEEDED_TEA_IDS[0],
            userId: exports.TEST_USERS.friend2.id,
            guess: 'Alex',
            amount: 20,
        },
        {
            guessId: 'seed_guess_3',
            teaId: SEEDED_TEA_IDS[1],
            userId: exports.TEST_USERS.friend1.id,
            guess: 'Sam',
            amount: 30,
        },
        {
            guessId: 'seed_guess_4',
            teaId: SEEDED_TEA_IDS[1],
            userId: exports.TEST_USERS.friend3.id,
            guess: 'Alex',
            amount: 15,
        },
    ];
    await TeaGuess_1.default.insertMany(guesses);
}
async function createTestStreak() {
    const existing = await Streak_1.default.findOne({ conversationId: exports.TEST_CHAT_ID });
    if (existing) {
        console.log('  - Updating test streak...');
        existing.currentStreak = 5;
        existing.longestStreak = 12;
        existing.lastPostDate = new Date();
        existing.todayPosters = [exports.TEST_USERS.friend1.id, exports.TEST_USERS.friend2.id, exports.TEST_USERS.qa.id];
        await existing.save();
    }
    else {
        console.log('  - Creating test streak...');
        await Streak_1.default.create({
            conversationId: exports.TEST_CHAT_ID,
            currentStreak: 5,
            longestStreak: 12,
            lastPostDate: new Date(),
            todayPosters: [exports.TEST_USERS.friend1.id, exports.TEST_USERS.friend2.id, exports.TEST_USERS.qa.id],
        });
    }
}
// Run seed
seed().catch(err => {
    console.error('Seed failed:', err);
    process.exit(1);
});
//# sourceMappingURL=seed.js.map