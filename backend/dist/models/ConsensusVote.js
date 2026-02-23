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
const uuid_1 = require("uuid");
const voteChoices = ['yes', 'no'];
const consensusVoteSchema = new mongoose_1.Schema({
    voteId: {
        type: String,
        required: true,
        unique: true,
        default: () => `vote_${(0, uuid_1.v4)()}`,
    },
    betId: { type: String, required: true, index: true },
    userId: { type: String, required: true, index: true },
    vote: {
        type: String,
        enum: voteChoices,
        required: true,
    },
}, { timestamps: true });
// One vote per user per bet
consensusVoteSchema.index({ betId: 1, userId: 1 }, { unique: true });
const ConsensusVote = mongoose_1.default.model('ConsensusVote', consensusVoteSchema);
exports.default = ConsensusVote;
//# sourceMappingURL=ConsensusVote.js.map