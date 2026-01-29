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
const chatTypes = ['individual', 'group'];
const chatSchema = new mongoose_1.Schema({
    _id: {
        type: String,
        required: true,
    },
    title: {
        type: String,
        default: null,
    },
    members: [
        {
            type: String,
            ref: 'User',
        },
    ],
    lastVibeId: {
        type: String,
        ref: 'Vibe',
        default: null,
    },
    lastActivityAt: {
        type: Date,
        default: Date.now,
    },
    type: {
        type: String,
        enum: chatTypes,
        default: 'group',
    },
    createdBy: {
        type: String,
        ref: 'User',
    },
}, {
    timestamps: true,
    _id: false,
});
chatSchema.index({ members: 1 });
chatSchema.index({ lastActivityAt: -1 });
chatSchema.methods.addMember = async function (userId) {
    if (!this.members.includes(userId)) {
        this.members.push(userId);
        await this.save();
    }
    return this;
};
chatSchema.methods.isMember = function (userId) {
    return this.members.includes(userId);
};
chatSchema.methods.touch = async function (vibeId) {
    this.lastActivityAt = new Date();
    if (vibeId) {
        this.lastVibeId = vibeId;
    }
    await this.save();
    return this;
};
const Chat = mongoose_1.default.model('Chat', chatSchema);
exports.default = Chat;
//# sourceMappingURL=Chat.js.map