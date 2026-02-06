import { v4 as uuidv4 } from 'uuid';
import User from '../models/User';
import AuraTransaction from '../models/AuraTransaction';

const DAILY_BONUS_AMOUNT = 50;
const BONUS_COOLDOWN_MS = 24 * 60 * 60 * 1000; // 24 hours

/**
 * Computes vibeScore from current bet/callout stats.
 * Base 100. +10 per completed bet, -20 per failed bet, -10 per ignored callout.
 * Floors at 0 — score can never go negative.
 */
function calculateVibeScore(stats: {
  betsCompleted: number;
  betsFailed: number;
  calloutsIgnored: number;
}): number {
  const score = 100 + (stats.betsCompleted * 10) - (stats.betsFailed * 20) - (stats.calloutsIgnored * 10);
  return Math.max(0, score);
}

/**
 * Runs on every login. Two jobs:
 *   1. Awards +50 Aura if 24h has passed since lastDailyBonus (or never claimed)
 *   2. Recalculates vibeScore from current bet/callout stats
 *
 * Returns the final values to put directly into the login response.
 */
export async function processLoginUpdates(userId: string): Promise<{
  auraBalance: number;
  vibeScore: number;
  dailyBonusClaimed: boolean;
}> {
  const user = await User.findById(userId);
  if (!user) {
    return { auraBalance: 1000, vibeScore: 100, dailyBonusClaimed: false };
  }

  let dailyBonusClaimed = false;
  const now = new Date();
  const lastBonus = user.lastDailyBonus ? new Date(user.lastDailyBonus) : null;

  // Award daily bonus if cooldown has passed (or never claimed)
  if (!lastBonus || (now.getTime() - lastBonus.getTime()) >= BONUS_COOLDOWN_MS) {
    const newBalance = (user.auraBalance ?? 1000) + DAILY_BONUS_AMOUNT;
    user.auraBalance = newBalance;
    user.lifetimeAuraEarned = (user.lifetimeAuraEarned ?? 0) + DAILY_BONUS_AMOUNT;
    user.lastDailyBonus = now;
    dailyBonusClaimed = true;

    await AuraTransaction.create({
      transactionId: `txn_${uuidv4()}`,
      userId,
      amount: DAILY_BONUS_AMOUNT,
      balanceAfter: newBalance,
      transactionType: 'daily_bonus',
      description: 'Daily login bonus',
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
    auraBalance: user.auraBalance ?? 1000,
    vibeScore,
    dailyBonusClaimed,
  };
}

/**
 * Check if user can afford an amount
 */
export async function canAfford(userId: string, amount: number): Promise<boolean> {
  const user = await User.findById(userId);
  if (!user) return false;
  return (user.auraBalance ?? 0) >= amount;
}

/**
 * Check if user is bankrupt (0 or less Aura)
 */
export async function isBankrupt(userId: string): Promise<boolean> {
  const user = await User.findById(userId);
  if (!user) return true;
  return (user.auraBalance ?? 0) <= 0;
}

/**
 * Get user's Aura stats
 */
export async function getAuraStats(userId: string): Promise<{
  balance: number;
  lifetimeEarned: number;
  lifetimeSpent: number;
  canBet: boolean;
  dailyBonusAvailable: boolean;
  nextBonusAt: Date | null;
}> {
  const user = await User.findById(userId);

  if (!user) {
    throw new Error('User not found');
  }

  const now = new Date();
  const lastBonus = user.lastDailyBonus ? new Date(user.lastDailyBonus) : null;

  let dailyBonusAvailable = true;
  let nextBonusAt: Date | null = null;

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
export async function getTransactionHistory(
  userId: string,
  limit: number = 20
): Promise<any[]> {
  return await AuraTransaction.find({ userId })
    .sort({ createdAt: -1 })
    .limit(limit);
}

/**
 * Calculate win rate percentage
 */
export function calculateWinRate(betsCompleted: number, betsCreated: number): number {
  if (betsCreated === 0) return 0;
  return Math.round((betsCompleted / betsCreated) * 100);
}

/**
 * Calculate duck rate percentage
 */
export function calculateDuckRate(calloutsIgnored: number, calloutsReceived: number): number {
  if (calloutsReceived === 0) return 0;
  return Math.round((calloutsIgnored / calloutsReceived) * 100);
}
