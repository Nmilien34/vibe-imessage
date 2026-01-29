import express, { Request, Response, Router } from 'express';
import Reminder from '../models/Reminder';
import { ReminderType } from '../types';

const router: Router = express.Router();

interface CreateReminderRequest {
  chatId: string;
  userId: string;
  type: ReminderType;
  emoji: string;
  title: string;
  date: string;
}

interface DeleteReminderRequest {
  userId: string;
}

// POST /api/reminders — create a reminder
router.post('/', async (req: Request<{}, {}, CreateReminderRequest>, res: Response) => {
  try {
    const { chatId, userId, type, emoji, title, date } = req.body;

    if (!chatId || !userId || !type || !emoji || !title || !date) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const reminder = await Reminder.create({ chatId, userId, type, emoji, title, date: new Date(date) });
    res.status(201).json(reminder);
  } catch (err) {
    console.error('Create reminder error:', err);
    res.status(500).json({ error: 'Failed to create reminder' });
  }
});

// GET /api/reminders/:chatId — get upcoming reminders for a chat
router.get('/:chatId', async (req: Request<{ chatId: string }>, res: Response) => {
  try {
    const now = new Date();
    now.setDate(now.getDate() - 1); // 1-day buffer

    const reminders = await Reminder.find({
      chatId: req.params.chatId,
      date: { $gte: now },
    }).sort({ date: 1 });

    res.json(reminders);
  } catch (err) {
    console.error('Get reminders error:', err);
    res.status(500).json({ error: 'Failed to get reminders' });
  }
});

// DELETE /api/reminders/:id — delete a reminder (creator only)
router.delete('/:id', async (req: Request<{ id: string }, {}, DeleteReminderRequest>, res: Response) => {
  try {
    const { userId } = req.body;
    const reminder = await Reminder.findById(req.params.id);

    if (!reminder) {
      return res.status(404).json({ error: 'Reminder not found' });
    }

    if (reminder.userId !== userId) {
      return res.status(403).json({ error: 'Only the creator can delete this reminder' });
    }

    await Reminder.findByIdAndDelete(req.params.id);
    res.json({ success: true });
  } catch (err) {
    console.error('Delete reminder error:', err);
    res.status(500).json({ error: 'Failed to delete reminder' });
  }
});

export default router;
