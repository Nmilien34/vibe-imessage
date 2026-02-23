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
const claimOutcomes = ['yes', 'no', 'ducked'];
const claimStatuses = ['pending', 'confirmed', 'auto_confirmed', 'disputed'];
const resolutionClaimSchema = new mongoose_1.Schema({
    claimId: { type: String, required: true, unique: true },
    betId: { type: String, required: true, index: true },
    proofId: { type: String, required: true },
    proposedOutcome: {
        type: String,
        enum: claimOutcomes,
        required: true,
    },
    proposedBy: { type: String, required: true, index: true },
    reviewerIds: [{ type: String, required: true }],
    confirmedBy: [{ type: String, default: [] }],
    disputedBy: [{ type: String, default: [] }],
    status: {
        type: String,
        enum: claimStatuses,
        default: 'pending',
        index: true,
    },
    notes: { type: String },
    autoConfirmAt: { type: Date, required: true, index: true },
    finalizedAt: { type: Date },
}, { timestamps: true });
resolutionClaimSchema.index({ betId: 1, status: 1, createdAt: -1 });
const ResolutionClaim = mongoose_1.default.model('ResolutionClaim', resolutionClaimSchema);
exports.default = ResolutionClaim;
//# sourceMappingURL=ResolutionClaim.js.map