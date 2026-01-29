"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.HISTORY_RETENTION_DAYS = exports.FEED_EXPIRATION_DAYS = void 0;
const mongoose_1 = __importStar(require("mongoose"));
// Retention periods (in days)
exports.FEED_EXPIRATION_DAYS = 1; // 24 hours - visible in feed
exports.HISTORY_RETENTION_DAYS = 15; // 15 days - viewable in history
const vibeTypes = [
    'video',
    'photo',
    'song',
    'battery',
    'mood',
    'poll',
    'dailyDrop',
    'tea',
    'leak',
    'sketch',
    'eta',
    'parlay',
];
const parlayStatuses = ['pending', 'accepted', 'declined', 'settled', 'active', 'resolved', 'cancelled'];
const vibeSchema = new mongoose_1.Schema({
    userId: {
        type: String,
        required: true,
        index: true,
    },
    chatId: {
        type: String,
        required: true,
        index: true,
        ref: 'Chat',
    },
    conversationId: {
        type: String,
        index: true,
    },
    oderId: { type: String },
    type: {
        type: String,
        required: true,
        enum: vibeTypes,
    },
    mediaUrl: { type: String },
    mediaKey: { type: String },
    thumbnailUrl: { type: String },
    thumbnailKey: { type: String },
    songData: {
        title: String,
        artist: String,
        albumArt: String,
        previewUrl: String,
        spotifyId: String,
        spotifyUrl: String,
        appleMusicUrl: String,
    },
    batteryLevel: {
        type: Number,
        min: 0,
        max: 100,
    },
    mood: {
        emoji: String,
        text: String,
    },
    poll: {
        question: String,
        options: [String],
        votes: [
            {
                userId: String,
                optionIndex: Number,
            },
        ],
    },
    parlay: {
        title: String,
        question: String,
        options: [String],
        amount: String,
        wager: String,
        opponentId: String,
        opponentName: String,
        status: {
            type: String,
            enum: parlayStatuses,
            default: 'pending',
        },
        expiresAt: Date,
        votes: [
            {
                oderId: String,
                optionIndex: Number,
            },
        ],
        winnersReceived: [String],
    },
    textStatus: { type: String },
    styleName: { type: String },
    etaStatus: { type: String },
    isLocked: {
        type: Boolean,
        default: false,
    },
    unlockedBy: [{ type: String }],
    reactions: [
        {
            userId: String,
            emoji: String,
            createdAt: { type: Date, default: Date.now },
        },
    ],
    viewedBy: [{ type: String }],
    expiresAt: {
        type: Date,
        required: true,
    },
    permanentDeleteAt: {
        type: Date,
        required: true,
    },
    mediaDeleted: {
        type: Boolean,
        default: false,
    },
}, { timestamps: true });
vibeSchema.index({ chatId: 1, expiresAt: 1 });
vibeSchema.index({ chatId: 1, createdAt: -1 });
vibeSchema.index({ userId: 1, createdAt: -1 });
vibeSchema.index({ permanentDeleteAt: 1 });
vibeSchema.index({ conversationId: 1, expiresAt: 1 });
vibeSchema.index({ permanentDeleteAt: 1 }, { expireAfterSeconds: 0 });
vibeSchema.statics.createWithExpiration = function (data) {
    const now = new Date();
    return this.create({
        ...data,
        expiresAt: data.expiresAt || new Date(now.getTime() + exports.FEED_EXPIRATION_DAYS * 24 * 60 * 60 * 1000),
        permanentDeleteAt: new Date(now.getTime() + exports.HISTORY_RETENTION_DAYS * 24 * 60 * 60 * 1000),
    });
};
const Vibe = mongoose_1.default.model('Vibe', vibeSchema);
exports.default = Vibe;
//# sourceMappingURL=Vibe.js.map