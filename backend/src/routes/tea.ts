import express, { Request, Response, Router } from 'express';
import { authMiddleware } from '../middleware/auth';
import {
  createTeaSpill,
  guessTeaSpill,
  revealTeaSpill,
  getTeaSpills,
  getTeaById,
  getTeaGuesses,
  autoExpireTeaSpills,
} from '../services/teaService';

const router: Router = express.Router();

/**
 * @route   POST /api/tea/create
 * @desc    Create a new tea spill
 * @access  Private
 */
router.post('/create', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { chatId, mysteryText, answer, options, deadline } = req.body;

    if (!chatId || !mysteryText || !answer || !options || !deadline) {
      return res.status(400).json({ error: 'chatId, mysteryText, answer, options, and deadline are required' });
    }

    const tea = await createTeaSpill({
      chatId,
      creatorId: userId,
      mysteryText,
      answer,
      options,
      deadline: new Date(deadline),
    });

    res.status(201).json({ success: true, tea });
  } catch (error: any) {
    console.error('Create tea spill error:', error);
    res.status(400).json({ error: error.message });
  }
});

/**
 * @route   POST /api/tea/:teaId/guess
 * @desc    Guess on a tea spill
 * @access  Private
 */
router.post('/:teaId/guess', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { teaId } = req.params;
    const { guess, amount } = req.body;

    if (!guess || amount === undefined) {
      return res.status(400).json({ error: 'guess and amount are required' });
    }

    const teaGuess = await guessTeaSpill({
      teaId,
      userId,
      guess,
      amount: Number(amount),
    });

    res.status(201).json({ success: true, guess: teaGuess });
  } catch (error: any) {
    console.error('Guess tea spill error:', error);
    res.status(400).json({ error: error.message });
  }
});

/**
 * @route   POST /api/tea/:teaId/reveal
 * @desc    Reveal a tea spill (creator only)
 * @access  Private
 */
router.post('/:teaId/reveal', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.userId!;
    const { teaId } = req.params;

    const result = await revealTeaSpill({ teaId, userId });

    res.json({ success: true, ...result });
  } catch (error: any) {
    console.error('Reveal tea spill error:', error);
    res.status(400).json({ error: error.message });
  }
});

/**
 * @route   GET /api/tea/chat/:chatId
 * @desc    Get tea spills for a chat
 * @access  Private
 */
router.get('/chat/:chatId', authMiddleware, async (req: Request, res: Response) => {
  try {
    const { chatId } = req.params;
    const { status, limit, offset } = req.query;

    const result = await getTeaSpills({
      chatId,
      status: status as string | undefined,
      limit: limit ? Number(limit) : undefined,
      offset: offset ? Number(offset) : undefined,
    });

    res.json(result);
  } catch (error: any) {
    console.error('Get tea spills error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * @route   GET /api/tea/:teaId
 * @desc    Get a single tea spill
 * @access  Private
 */
router.get('/:teaId', authMiddleware, async (req: Request, res: Response) => {
  try {
    const { teaId } = req.params;

    const tea = await getTeaById(teaId);
    if (!tea) {
      return res.status(404).json({ error: 'Tea spill not found' });
    }

    res.json(tea);
  } catch (error: any) {
    console.error('Get tea by id error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * @route   GET /api/tea/:teaId/guesses
 * @desc    Get all guesses for a tea spill
 * @access  Private
 */
router.get('/:teaId/guesses', authMiddleware, async (req: Request, res: Response) => {
  try {
    const { teaId } = req.params;

    const guesses = await getTeaGuesses(teaId);
    res.json({ guesses });
  } catch (error: any) {
    console.error('Get tea guesses error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * @route   POST /api/tea/auto-expire
 * @desc    Auto-expire tea spills past their deadline
 * @access  Private
 */
router.post('/auto-expire', authMiddleware, async (_req: Request, res: Response) => {
  try {
    const expiredCount = await autoExpireTeaSpills();
    res.json({ success: true, expiredCount });
  } catch (error: any) {
    console.error('Auto-expire tea spills error:', error);
    res.status(500).json({ error: error.message });
  }
});

export default router;
