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

const CREATION_COST = 10;
const MIN_GUESS_AMOUNT = 10;

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
  const membership = await ChatMember.findOne({ chatId, userId: creatorId });
  if (!membership) {
    throw new Error('You must be a member of this chat to create a tea spill');
  }

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
    creatorBonusPercent: 10,
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
  const membership = await ChatMember.findOne({ chatId: tea.chatId, userId });
  if (!membership) {
    throw new Error('You must be in this chat to guess');
  }

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
  const teaGuess = await TeaGuess.create({
    guessId,
    teaId,
    userId,
    guess,
    amount,
  });

  return teaGuess;
}

// ═══════════════════════════════════════════════════════════
// REVEAL TEA SPILL
// ═══════════════════════════════════════════════════════════

interface RevealResult {
  tea: ITeaSpill;
  payouts: Array<{ userId: string; amount: number; type: string }>;
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

  // Get all guesses
  const guesses = await TeaGuess.find({ teaId });

  // Calculate pot
  const pot = guesses.reduce((sum, g) => sum + g.amount, 0);

  // Find correct guessers
  const correctGuesses = guesses.filter(g => g.guess === tea.answer);

  const payouts: Array<{ userId: string; amount: number; type: string }> = [];

  const creatorBonusPercent = tea.creatorBonusPercent ?? 10;

  if (correctGuesses.length > 0) {
    // Creator gets bonus percentage
    const creatorBonus = Math.floor(pot * (creatorBonusPercent / 100));
    if (creatorBonus > 0) {
      payouts.push({ userId: tea.creatorId, amount: creatorBonus, type: 'creator_bonus' });
    }

    // Remaining pot split proportionally among correct guessers
    const remainingPot = pot - creatorBonus;
    const totalCorrectAmount = correctGuesses.reduce((sum, g) => sum + g.amount, 0);

    for (const g of correctGuesses) {
      const payout = Math.floor((g.amount / totalCorrectAmount) * remainingPot);
      if (payout > 0) {
        payouts.push({ userId: g.userId, amount: payout, type: 'tea_win' });
      }
    }
  } else {
    // No correct guessers — creator gets entire pot
    if (pot > 0) {
      payouts.push({ userId: tea.creatorId, amount: pot, type: 'creator_bonus' });
    }
  }

  // Distribute payouts
  for (const payout of payouts) {
    const user = await User.findById(payout.userId);
    if (!user) {
      console.error(`User ${payout.userId} not found during tea payout`);
      continue;
    }

    user.auraBalance = (user.auraBalance ?? 0) + payout.amount;
    user.lifetimeAuraEarned = (user.lifetimeAuraEarned ?? 0) + payout.amount;
    await user.save();

    await AuraTransaction.create({
      transactionId: `txn_${uuidv4()}`,
      userId: payout.userId,
      amount: payout.amount,
      balanceAfter: user.auraBalance,
      transactionType: payout.type,
      referenceId: teaId,
      description: payout.type === 'creator_bonus'
        ? `Creator bonus from tea spill: "${tea.mysteryText.substring(0, 50)}"`
        : `Won tea spill guess: "${tea.mysteryText.substring(0, 50)}"`,
    });
  }

  // Update tea status
  tea.status = 'revealed';
  tea.revealedAt = new Date();
  await tea.save();

  return { tea, payouts };
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
      // Refund all guessers
      const guesses = await TeaGuess.find({ teaId: tea.teaId });

      for (const guess of guesses) {
        const user = await User.findById(guess.userId);
        if (!user) continue;

        user.auraBalance = (user.auraBalance ?? 0) + guess.amount;
        await user.save();

        await AuraTransaction.create({
          transactionId: `txn_${uuidv4()}`,
          userId: guess.userId,
          amount: guess.amount,
          balanceAfter: user.auraBalance,
          transactionType: 'tea_refund',
          referenceId: tea.teaId,
          description: `Refunded ${guess.amount} Aura from expired tea spill`,
        });
      }

      // Update status
      tea.status = 'expired';
      await tea.save();
      expiredCount++;
    } catch (error) {
      console.error(`Failed to expire tea ${tea.teaId}:`, error);
    }
  }

  return expiredCount;
}
