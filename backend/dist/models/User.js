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
const userSchema = new mongoose_1.Schema({
    _id: {
        type: String,
        default: () => `user_${new mongoose_1.default.Types.ObjectId().toString()}`,
    },
    appleId: {
        type: String,
        unique: true,
        sparse: true,
        index: true,
    },
    appleUUID: {
        type: String,
        index: true,
        sparse: true,
    },
    firstName: { type: String },
    lastName: { type: String },
    email: {
        type: String,
        lowercase: true,
    },
    profilePicture: { type: String },
    birthday: {
        month: { type: Number },
        day: { type: Number },
    },
    joinedChatIds: [
        {
            type: String,
            ref: 'Chat',
        },
    ],
    pushToken: { type: String },
    lastSeen: {
        type: Date,
        default: Date.now,
    },
}, {
    timestamps: true,
    _id: false,
});
userSchema.index({ joinedChatIds: 1 });
userSchema.methods.joinChat = async function (chatId) {
    if (!this.joinedChatIds.includes(chatId)) {
        this.joinedChatIds.push(chatId);
        await this.save();
    }
    return this;
};
userSchema.methods.leaveChat = async function (chatId) {
    this.joinedChatIds = this.joinedChatIds.filter((id) => id !== chatId);
    await this.save();
    return this;
};
const User = mongoose_1.default.model('User', userSchema);
exports.default = User;
//# sourceMappingURL=User.js.map