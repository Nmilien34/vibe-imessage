import 'dotenv/config';
import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import connectDB from './config/db';
import { initScheduler } from './config/scheduler';

// Route imports
import authRoutes from './routes/auth';
import vibeRoutes from './routes/vibe';
import vibesRoutes from './routes/vibes';
import groupRoutes from './routes/group';
import uploadRoutes from './routes/upload';
import chatRoutes from './routes/chat';
import feedRoutes from './routes/feed';
import remindersRoutes from './routes/reminders';
import vibeWireRoutes from './routes/vibewire';
import userRoutes from './routes/user';
import betRoutes from './routes/bet';
import auraRoutes from './routes/aura';

const app = express();

// Connect to MongoDB
connectDB();

// Initialize Vibe Wire Scheduler
initScheduler();

// Middleware
app.use(helmet());

// CORS Configuration
const allowedOrigins = [
  'http://localhost:3000',
  'http://127.0.0.1:3000',
  'https://vibe-imessage.onrender.com'
];

app.use(cors({
  origin: function (origin, callback) {
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) return callback(null, true);

    if (allowedOrigins.indexOf(origin) !== -1 || process.env.NODE_ENV !== 'production') {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true
}));
app.use(express.json());

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/vibe', vibeRoutes);
app.use('/api/vibes', vibesRoutes);
app.use('/api/group', groupRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/feed', feedRoutes);
app.use('/api/reminders', remindersRoutes);
app.use('/api/vibewire', vibeWireRoutes);
app.use('/api/user', userRoutes);
app.use('/api/bets', betRoutes);
app.use('/api/aura', auraRoutes);

// Health check
app.get('/health', (_req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Error handler
app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
