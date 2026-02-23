"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.processLoginUpdates = processLoginUpdates;
exports.canAfford = canAfford;
exports.isBankrupt = isBankrupt;
exports.getAuraStats = getAuraStats;
exports.getTransactionHistory = getTransactionHistory;
exports.calculateWinRate = calculateWinRate;
exports.calculateDuckRate = calculateDuckRate;
const uuid_1 = require("uuid");
const User_1 = __importDefault(require("../models/User"));
const AuraTransaction_1 = __importDefault(require("../models/AuraTransaction"));
const DAILY_BONUS_AMOUNT = 50;
const BONUS_COOLDOWN_MS = 24 * 60 * 60 * 1000; // 24 hours
/**
 * Computes vibeScore from current bet/callout stats.
 * Base 100. +10 per completed bet, -20 per failed bet, -10 per ignored callout.
 * Floors at 0 — score can never go negative.
 */
function calculateVibeScore(stats) {
    const score = 100 + (stats.betsCompleted * 10) - (stats.betsFailed * 20) - (stats.calloutsIgnored * 10);
    return Math.max(0, score);
}
/**
 * Recomputes user economy snapshot for auth and claim flows.
 *   1. Optionally awards +50 Aura when explicitly requested and eligible
 *   2. Recalculates vibeScore from current bet/callout stats
 *
 * Returns the final values to put directly into the login response.
 */
async function processLoginUpdates(userId, options = {}) {
    const user = await User_1.default.findById(userId);
    if (!user) {
        return { auraBalance: 100, vibeScore: 100, dailyBonusClaimed: false };
    }
    const shouldAwardDailyBonus = options.awardDailyBonus === true;
    let dailyBonusClaimed = false;
    const now = new Date();
    const lastBonus = user.lastDailyBonus ? new Date(user.lastDailyBonus) : null;
    // Award daily bonus only when explicitly requested (e.g. claim endpoint).
    if (shouldAwardDailyBonus && (!lastBonus || (now.getTime() - lastBonus.getTime()) >= BONUS_COOLDOWN_MS)) {
        const newBalance = (user.auraBalance ?? 100) + DAILY_BONUS_AMOUNT;
        user.auraBalance = newBalance;
        user.lifetimeAuraEarned = (user.lifetimeAuraEarned ?? 0) + DAILY_BONUS_AMOUNT;
        user.lastDailyBonus = now;
        dailyBonusClaimed = true;
        await AuraTransaction_1.default.create({
            transactionId: `txn_${(0, uuid_1.v4)()}`,
            userId,
            amount: DAILY_BONUS_AMOUNT,
            balanceAfter: newBalance,
            transactionType: 'daily_bonus',
            description: 'Daily bonus claim',
        });
    }
    // Recalculate vibeScore from current stats
    const vibeScore = calculateVibeScore({
        betsCompleted: user.betsCompleted ?? 0,
        betsFailed: user.betsFailed ?? 0,
        calloutsIgnored: user.calloutsIgnored ?? 0,
    });
    user.vibeScore = vibeScore;
    await user.save();
    return {
        auraBalance: user.auraBalance ?? 100,
        vibeScore,
        dailyBonusClaimed,
    };
}
/**
 * Check if user can afford an amount
 */
async function canAfford(userId, amount) {
    const user = await User_1.default.findById(userId);
    if (!user)
        return false;
    return (user.auraBalance ?? 0) >= amount;
}
/**
 * Check if user is bankrupt (0 or less Aura)
 */
async function isBankrupt(userId) {
    const user = await User_1.default.findById(userId);
    if (!user)
        return true;
    return (user.auraBalance ?? 0) <= 0;
}
/**
 * Get user's Aura stats
 */
async function getAuraStats(userId) {
    const user = await User_1.default.findById(userId);
    if (!user) {
        throw new Error('User not found');
    }
    const now = new Date();
    const lastBonus = user.lastDailyBonus ? new Date(user.lastDailyBonus) : null;
    let dailyBonusAvailable = true;
    let nextBonusAt = null;
    if (lastBonus) {
        const timeSinceLastBonus = now.getTime() - lastBonus.getTime();
        if (timeSinceLastBonus < BONUS_COOLDOWN_MS) {
            dailyBonusAvailable = false;
            nextBonusAt = new Date(lastBonus.getTime() + BONUS_COOLDOWN_MS);
        }
    }
    const balance = user.auraBalance ?? 0;
    return {
        balance,
        lifetimeEarned: user.lifetimeAuraEarned ?? 0,
        lifetimeSpent: user.lifetimeAuraSpent ?? 0,
        canBet: balance > 0,
        dailyBonusAvailable,
        nextBonusAt
    };
}
/**
 * Get recent transactions for a user
 */
async function getTransactionHistory(userId, limit = 20) {
    return await AuraTransaction_1.default.find({ userId })
        .sort({ createdAt: -1 })
        .limit(limit);
}
/**
 * Calculate win rate percentage
 */
function calculateWinRate(betsCompleted, betsCreated) {
    if (betsCreated === 0)
        return 0;
    return Math.round((betsCompleted / betsCreated) * 100);
}
/**
 * Calculate duck rate percentage
 */
function calculateDuckRate(calloutsIgnored, calloutsReceived) {
    if (calloutsReceived === 0)
        return 0;
    return Math.round((calloutsIgnored / calloutsReceived) * 100);
}
//# sourceMappingURL=auraService.js.map