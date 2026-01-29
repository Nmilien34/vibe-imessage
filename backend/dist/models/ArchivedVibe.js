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
const mongoose_1 = __importStar(require("mongoose"));
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
const archivedVibeSchema = new mongoose_1.Schema({
    originalVibeId: {
        type: String,
        required: true,
        unique: true,
    },
    userId: {
        type: String,
        required: true,
        index: true,
    },
    conversationId: {
        type: String,
        required: true,
        index: true,
    },
    type: {
        type: String,
        required: true,
        enum: vibeTypes,
    },
    wasLocked: {
        type: Boolean,
        default: false,
    },
    metrics: {
        viewCount: { type: Number, default: 0 },
        reactionCount: { type: Number, default: 0 },
        unlockCount: { type: Number, default: 0 },
    },
    originalCreatedAt: {
        type: Date,
        required: true,
    },
    archivedAt: {
        type: Date,
        default: Date.now,
    },
}, { timestamps: true });
archivedVibeSchema.index({ conversationId: 1, originalCreatedAt: -1 });
archivedVibeSchema.index({ userId: 1, originalCreatedAt: -1 });
archivedVibeSchema.index({ type: 1 });
archivedVibeSchema.index({ archivedAt: 1 });
const ArchivedVibe = mongoose_1.default.model('ArchivedVibe', archivedVibeSchema);
exports.default = ArchivedVibe;
//# sourceMappingURL=ArchivedVibe.js.map