"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const auth_1 = require("../middleware/auth");
const ChatMember_1 = __importDefault(require("../models/ChatMember"));
const teaService_1 = require("../services/teaService");
const router = express_1.default.Router();
function sanitizeTeaForViewer(tea, viewerId) {
    const teaObj = typeof tea?.toObject === 'function' ? tea.toObject() : tea;
    const isCreator = teaObj.creatorId === viewerId;
    const canSeeAnswer = isCreator || teaObj.status === 'revealed';
    return {
        ...teaObj,
        answer: canSeeAnswer ? teaObj.answer : undefined,
        creatorId: isCreator ? teaObj.creatorId : 'anonymous',
    };
}
/**
 * @route   POST /api/tea/create
 * @desc    Create a new tea spill
 * @access  Private
 */
router.post('/create', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { chatId, mysteryText, answer, options, deadline } = req.body;
        if (!chatId || !mysteryText || !answer || !options || !deadline) {
            return res.status(400).json({ error: 'chatId, mysteryText, answer, options, and deadline are required' });
        }
        const tea = await (0, teaService_1.createTeaSpill)({
            chatId,
            creatorId: userId,
            mysteryText,
            answer,
            options,
            deadline: new Date(deadline),
        });
        res.status(201).json({ success: true, tea });
    }
    catch (error) {
        console.error('Create tea spill error:', error);
        res.status(400).json({ error: error.message });
    }
});
/**
 * @route   POST /api/tea/:teaId/guess
 * @desc    Guess on a tea spill
 * @access  Private
 */
router.post('/:teaId/guess', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { teaId } = req.params;
        const { guess, amount } = req.body;
        if (!guess || amount === undefined) {
            return res.status(400).json({ error: 'guess and amount are required' });
        }
        const teaGuess = await (0, teaService_1.guessTeaSpill)({
            teaId,
            userId,
            guess,
            amount: Number(amount),
        });
        res.status(201).json({ success: true, guess: teaGuess });
    }
    catch (error) {
        console.error('Guess tea spill error:', error);
        res.status(400).json({ error: error.message });
    }
});
/**
 * @route   POST /api/tea/:teaId/reveal
 * @desc    Reveal a tea spill (creator only)
 * @access  Private
 */
router.post('/:teaId/reveal', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { teaId } = req.params;
        const result = await (0, teaService_1.revealTeaSpill)({ teaId, userId });
        res.json({ success: true, ...result });
    }
    catch (error) {
        console.error('Reveal tea spill error:', error);
        res.status(400).json({ error: error.message });
    }
});
/**
 * @route   GET /api/tea/discover
 * @desc    Get tea spills across all chats the user belongs to
 * @access  Private
 */
router.get('/discover', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { status, limit, offset } = req.query;
        const result = await (0, teaService_1.getTeaSpillsForUser)({
            userId,
            status: status,
            limit: limit ? Number(limit) : undefined,
            offset: offset ? Number(offset) : undefined,
        });
        res.json({
            ...result,
            teas: result.teas.map(tea => sanitizeTeaForViewer(tea, userId)),
        });
    }
    catch (error) {
        console.error('Get discover tea spills error:', error);
        res.status(500).json({ error: error.message });
    }
});
/**
 * @route   GET /api/tea/chat/:chatId
 * @desc    Get tea spills for a chat
 * @access  Private
 */
router.get('/chat/:chatId', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { chatId } = req.params;
        const { status, limit, offset } = req.query;
        const membership = await ChatMember_1.default.findOne({ chatId, userId });
        if (!membership) {
            return res.status(403).json({ error: 'You are not in this chat' });
        }
        const result = await (0, teaService_1.getTeaSpills)({
            chatId,
            status: status,
            limit: limit ? Number(limit) : undefined,
            offset: offset ? Number(offset) : undefined,
        });
        res.json({
            ...result,
            teas: result.teas.map(tea => sanitizeTeaForViewer(tea, userId)),
        });
    }
    catch (error) {
        console.error('Get tea spills error:', error);
        res.status(500).json({ error: error.message });
    }
});
/**
 * @route   GET /api/tea/:teaId
 * @desc    Get a single tea spill
 * @access  Private
 */
router.get('/:teaId', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { teaId } = req.params;
        const tea = await (0, teaService_1.getTeaById)(teaId);
        if (!tea) {
            return res.status(404).json({ error: 'Tea spill not found' });
        }
        const membership = await ChatMember_1.default.findOne({ chatId: tea.chatId, userId });
        if (!membership) {
            return res.status(403).json({ error: 'You are not in this chat' });
        }
        res.json(sanitizeTeaForViewer(tea, userId));
    }
    catch (error) {
        console.error('Get tea by id error:', error);
        res.status(500).json({ error: error.message });
    }
});
/**
 * @route   GET /api/tea/:teaId/guesses
 * @desc    Get all guesses for a tea spill
 * @access  Private
 */
router.get('/:teaId/guesses', auth_1.authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { teaId } = req.params;
        const tea = await (0, teaService_1.getTeaById)(teaId);
        if (!tea) {
            return res.status(404).json({ error: 'Tea spill not found' });
        }
        const membership = await ChatMember_1.default.findOne({ chatId: tea.chatId, userId });
        if (!membership) {
            return res.status(403).json({ error: 'You are not in this chat' });
        }
        const canViewGuesses = tea.status === 'revealed' || tea.creatorId === userId;
        if (!canViewGuesses) {
            return res.status(403).json({ error: 'Guesses are available after reveal' });
        }
        const guesses = await (0, teaService_1.getTeaGuesses)(teaId);
        res.json({ guesses });
    }
    catch (error) {
        console.error('Get tea guesses error:', error);
        res.status(500).json({ error: error.message });
    }
});
/**
 * @route   POST /api/tea/auto-expire
 * @desc    Auto-expire tea spills past their deadline
 * @access  Private
 */
router.post('/auto-expire', auth_1.authMiddleware, async (_req, res) => {
    try {
        const expiredCount = await (0, teaService_1.autoExpireTeaSpills)();
        res.json({ success: true, expiredCount });
    }
    catch (error) {
        console.error('Auto-expire tea spills error:', error);
        res.status(500).json({ error: error.message });
    }
});
exports.default = router;
//# sourceMappingURL=tea.js.map