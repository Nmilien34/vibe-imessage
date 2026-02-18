/**
 * Tea Spill Service - Business Logic Layer
 *
 * Handles tea spill creation, guessing, revealing, and auto-expiry.
 * Follows the same patterns as betService.ts for Aura transactions.
 */

import { v4 as uuidv4 } from 'uuid';
import User from '../models/User';
import TeaSpill from '../models/TeaSpill';
import TeaGuess from '../models/TeaGuess';
import AuraTransaction from '../models/AuraTransaction';
import ChatMember from '../models/ChatMember';
import { ITeaSpill, ITeaGuess } from '../types';
import { ensureChatMembershipIfKnown } from './chatMembershipService';

const CREATION_COST = 10;
const MIN_GUESS_AMOUNT = 10;

async function requireChatMembership(chatId: string, userId: string, errorMessage: string): Promise<void> {
  let membership = await ChatMember.findOne({ chatId, userId });
  if (!membership) {
    const repaired = await ensureChatMembershipIfKnown(chatId, userId);
    if (repaired) {
      membership = await ChatMember.findOne({ chatId, userId });
    }
  }

  if (!membership) {
    throw new Error(errorMessage);
  }
}

function isDuplicateKeyError(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code?: number }).code === 11000
  );
}

// ═══════════════════════════════════════════════════════════
// CREATE TEA SPILL
// ═══════════════════════════════════════════════════════════

interface CreateTeaSpillInput {
  chatId: string;
  creatorId: string;
  mysteryText: string;
  answer: string;
  options: string[];
  deadline: Date;
}

export async function createTeaSpill(input: CreateTeaSpillInput): Promise<ITeaSpill> {
  const { chatId, creatorId, mysteryText, answer, options, deadline } = input;

  // Verify creator is in chat
  await requireChatMembership(chatId, creatorId, 'You must be a member of this chat to create a tea spill');

  // Verify creator has sufficient Aura
  const creator = await User.findById(creatorId);
  if (!creator) {
    throw new Error('Creator not found');
  }

  if ((creator.auraBalance ?? 0) < CREATION_COST) {
    throw new Error(`Insufficient Aura. Need ${CREATION_COST}, have ${creator.auraBalance ?? 0}`);
  }

  // Deduct creation cost
  const newBalance = (creator.auraBalance ?? 0) - CREATION_COST;
  creator.auraBalance = newBalance;
  creator.lifetimeAuraSpent = (creator.lifetimeAuraSpent ?? 0) + CREATION_COST;
  await creator.save();

  const teaId = `tea_${Date.now()}_${uuidv4().substring(0, 6)}`;

  // Record transaction
  await AuraTransaction.create({
    transactionId: `txn_${uuidv4()}`,
    userId: creatorId,
    amount: -CREATION_COST,
    balanceAfter: newBalance,
    transactionType: 'tea_creation',
    referenceId: teaId,
    description: `Created tea spill: ${mysteryText.substring(0, 50)}...`,
  });

  // Create tea spill
  const tea = await TeaSpill.create({
    teaId,
    chatId,
    creatorId,
    mysteryText,
    answer,
    options,
    deadline,
    status: 'active',
    creationCost: CREATION_COST,
    creatorBonusPercent: 0,
  });

  return tea;
}

// ═══════════════════════════════════════════════════════════
// GUESS TEA SPILL
// ═══════════════════════════════════════════════════════════

interface GuessTeaSpillInput {
  teaId: string;
  userId: string;
  guess: string;
  amount: number;
}

export async function guessTeaSpill(input: GuessTeaSpillInput): Promise<ITeaGuess> {
  const { teaId, userId, guess, amount } = input;

  // Fetch tea and validate
  const tea = await TeaSpill.findOne({ teaId });
  if (!tea) throw new Error('Tea spill not found');
  if (tea.status !== 'active') throw new Error(`Cannot guess on ${tea.status} tea spill`);
  if (tea.deadline <= new Date()) throw new Error('Tea spill deadline has passed');

  // Verify chat membership
  await requireChatMembership(tea.chatId, userId, 'You must be in this chat to guess');

  // Creator cannot guess on their own tea
  if (userId === tea.creatorId) {
    throw new Error('Creator cannot guess on their own tea spill');
  }

  // Validate guess is in options
  if (!tea.options.includes(guess)) {
    throw new Error('Guess must be one of the available options');
  }

  // Validate amount
  if (amount < MIN_GUESS_AMOUNT) {
    throw new Error(`Minimum guess amount is ${MIN_GUESS_AMOUNT} Aura`);
  }
  if (!Number.isInteger(amount)) {
    throw new Error(`Minimum guess amount is ${MIN_GUESS_AMOUNT} Aura`);
  }

  // Check user balance
  const user = await User.findById(userId);
  if (!user) throw new Error('User not found');

  if ((user.auraBalance ?? 0) < amount) {
    throw new Error(`Insufficient Aura. Need ${amount}, have ${user.auraBalance ?? 0}`);
  }

  // Prevent duplicate guesses
  const existing = await TeaGuess.findOne({ teaId, userId });
  if (existing) {
    throw new Error('You have already guessed on this tea spill');
  }

  // Deduct amount from user
  const newBalance = (user.auraBalance ?? 0) - amount;
  user.auraBalance = newBalance;
  user.lifetimeAuraSpent = (user.lifetimeAuraSpent ?? 0) + amount;
  await user.save();

  const guessId = `guess_${Date.now()}_${uuidv4().substring(0, 6)}`;

  // Record transaction
  await AuraTransaction.create({
    transactionId: `txn_${uuidv4()}`,
    userId,
    amount: -amount,
    balanceAfter: newBalance,
    transactionType: 'tea_guess',
    referenceId: teaId,
    description: `Guessed on tea spill: "${tea.mysteryText.substring(0, 50)}"`,
  });

  // Create guess
  let teaGuess: ITeaGuess;
  try {
    teaGuess = await TeaGuess.create({
      guessId,
      teaId,
      userId,
      guess,
      amount,
    });
  } catch (error) {
    if (isDuplicateKeyError(error)) {
      throw new Error('You have already guessed on this tea spill');
    }
    throw error;
  }

  return teaGuess;
}

// ═══════════════════════════════════════════════════════════
// REVEAL TEA SPILL
// ═══════════════════════════════════════════════════════════

interface RevealResult {
  tea: ITeaSpill;
  payouts: Array<{ userId: string; amount: number; type: string }>;
}

function computeProportionalPayouts(
  guesses: ITeaGuess[],
  totalPot: number,
  payoutType: 'tea_win'
): Array<{ userId: string; amount: number; type: string }> {
  if (guesses.length === 0 || totalPot <= 0) return [];

  const totalWinningStake = guesses.reduce((sum, g) => sum + g.amount, 0);
  if (totalWinningStake <= 0) return [];

  const basePayouts = guesses.map(g => ({
    userId: g.userId.toString(),
    amount: Math.floor((g.amount / totalWinningStake) * totalPot),
    type: payoutType,
  }));

  let distributed = basePayouts.reduce((sum, p) => sum + p.amount, 0);
  let remainder = totalPot - distributed;

  // Ensure every Aura from the pot is returned (no silent burn from rounding).
  for (let i = 0; remainder > 0 && basePayouts.length > 0; i++) {
    const idx = i % basePayouts.length;
    basePayouts[idx].amount += 1;
    remainder -= 1;
    distributed += 1;
  }

  return basePayouts.filter(p => p.amount > 0);
}

async function distributePayouts(
  tea: ITeaSpill,
  payouts: Array<{ userId: string; amount: number; type: string }>
): Promise<void> {
  for (const payout of payouts) {
    const user = await User.findById(payout.userId);
    if (!user) {
      console.error(`User ${payout.userId} not found during tea payout`);
      continue;
    }

    user.auraBalance = (user.auraBalance ?? 0) + payout.amount;
    if (payout.type === 'tea_win') {
      user.lifetimeAuraEarned = (user.lifetimeAuraEarned ?? 0) + payout.amount;
    }
    await user.save();

    const isWin = payout.type === 'tea_win';
    await AuraTransaction.create({
      transactionId: `txn_${uuidv4()}`,
      userId: payout.userId,
      amount: payout.amount,
      balanceAfter: user.auraBalance,
      transactionType: isWin ? 'tea_win' : 'tea_refund',
      referenceId: tea.teaId,
      description: isWin
        ? `Won tea spill guess: "${tea.mysteryText.substring(0, 50)}"`
        : `Refunded tea spill guess: "${tea.mysteryText.substring(0, 50)}"`,
    });
  }
}

async function settleTeaSpill(tea: ITeaSpill & { save: () => Promise<any> }): Promise<RevealResult> {
  const guesses = await TeaGuess.find({ teaId: tea.teaId }).sort({ createdAt: 1 });
  const pot = guesses.reduce((sum, g) => sum + g.amount, 0);
  const correctGuesses = guesses.filter(g => g.guess === tea.answer);

  let payouts: Array<{ userId: string; amount: number; type: string }> = [];

  if (correctGuesses.length > 0) {
    payouts = computeProportionalPayouts(correctGuesses, pot, 'tea_win');
  } else {
    // If no one guessed correctly, refund all guessers.
    payouts = guesses.map(g => ({
      userId: g.userId.toString(),
      amount: g.amount,
      type: 'tea_refund',
    }));
  }

  await distributePayouts(tea, payouts);

  tea.status = 'revealed';
  tea.revealedAt = new Date();
  await tea.save();

  return { tea, payouts };
}

export async function revealTeaSpill(params: {
  teaId: string;
  userId: string;
}): Promise<RevealResult> {
  const { teaId, userId } = params;

  // Fetch tea and verify creator
  const tea = await TeaSpill.findOne({ teaId });
  if (!tea) throw new Error('Tea spill not found');
  if (tea.creatorId !== userId) throw new Error('Only the creator can reveal a tea spill');
  if (tea.status !== 'active') throw new Error(`Tea spill is already ${tea.status}`);
  if (tea.deadline > new Date()) throw new Error('Cannot reveal tea spill before deadline');

  return settleTeaSpill(tea);
}

// ═══════════════════════════════════════════════════════════
// QUERY FUNCTIONS
// ═══════════════════════════════════════════════════════════

export async function getTeaSpills(params: {
  chatId: string;
  status?: string;
  limit?: number;
  offset?: number;
}): Promise<{ teas: ITeaSpill[]; total: number; hasMore: boolean }> {
  const { chatId, status, limit = 20, offset = 0 } = params;

  const query: any = { chatId };
  if (status) query.status = status;

  const total = await TeaSpill.countDocuments(query);
  const teas = await TeaSpill.find(query)
    .sort({ createdAt: -1 })
    .skip(offset)
    .limit(limit);

  return {
    teas,
    total,
    hasMore: offset + limit < total,
  };
}

export async function getTeaSpillsForUser(params: {
  userId: string;
  status?: string;
  limit?: number;
  offset?: number;
}): Promise<{ teas: ITeaSpill[]; total: number; hasMore: boolean }> {
  const { userId, status, limit = 20, offset = 0 } = params;
  const memberships = await ChatMember.find({ userId });
  const chatIds = memberships.map(m => m.chatId);

  if (chatIds.length === 0) {
    return { teas: [], total: 0, hasMore: false };
  }

  const query: any = { chatId: { $in: chatIds } };
  if (status) query.status = status;

  const total = await TeaSpill.countDocuments(query);
  const teas = await TeaSpill.find(query)
    .sort({ createdAt: -1 })
    .skip(offset)
    .limit(limit);

  return {
    teas,
    total,
    hasMore: offset + limit < total,
  };
}

export async function getTeaById(teaId: string): Promise<ITeaSpill | null> {
  return await TeaSpill.findOne({ teaId });
}

export async function getTeaGuesses(teaId: string): Promise<ITeaGuess[]> {
  return await TeaGuess.find({ teaId }).sort({ createdAt: 1 });
}

// ═══════════════════════════════════════════════════════════
// AUTO-EXPIRE
// ═══════════════════════════════════════════════════════════

export async function autoExpireTeaSpills(): Promise<number> {
  const now = new Date();

  const expiredTeas = await TeaSpill.find({
    status: 'active',
    deadline: { $lt: now },
  });

  let expiredCount = 0;

  for (const tea of expiredTeas) {
    try {
      await settleTeaSpill(tea);
      expiredCount++;
    } catch (error) {
      console.error(`Failed to expire tea ${tea.teaId}:`, error);
    }
  }

  return expiredCount;
}
