import 'dotenv/config';
import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import connectDB from './config/db';

// Route imports
import authRoutes from './routes/auth';
import vibeRoutes from './routes/vibe';
import vibesRoutes from './routes/vibes';
import groupRoutes from './routes/group';
import uploadRoutes from './routes/upload';
import chatRoutes from './routes/chat';
import feedRoutes from './routes/feed';
import remindersRoutes from './routes/reminders';

const app = express();

// Connect to MongoDB
connectDB();

// Middleware
app.use(helmet());
app.use(cors());
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
