"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
require("dotenv/config");
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const helmet_1 = __importDefault(require("helmet"));
const db_1 = __importDefault(require("./config/db"));
const scheduler_1 = require("./config/scheduler");
// Route imports
const auth_1 = __importDefault(require("./routes/auth"));
const vibe_1 = __importDefault(require("./routes/vibe"));
const vibes_1 = __importDefault(require("./routes/vibes"));
const group_1 = __importDefault(require("./routes/group"));
const upload_1 = __importDefault(require("./routes/upload"));
const chat_1 = __importDefault(require("./routes/chat"));
const feed_1 = __importDefault(require("./routes/feed"));
const reminders_1 = __importDefault(require("./routes/reminders"));
const vibewire_1 = __importDefault(require("./routes/vibewire"));
const user_1 = __importDefault(require("./routes/user"));
const bet_1 = __importDefault(require("./routes/bet"));
const aura_1 = __importDefault(require("./routes/aura"));
const tea_1 = __importDefault(require("./routes/tea"));
const leaderboard_1 = __importDefault(require("./routes/leaderboard"));
const backgroundJobs_1 = require("./services/backgroundJobs");
const app = (0, express_1.default)();
// Connect to MongoDB
(0, db_1.default)();
// Initialize Vibe Wire Scheduler
(0, scheduler_1.initScheduler)();
(0, backgroundJobs_1.startBackgroundJobs)();
// Middleware
app.use((0, helmet_1.default)());
// CORS Configuration
const allowedOrigins = [
    'http://localhost:3000',
    'http://127.0.0.1:3000',
    'https://vibe-imessage.onrender.com'
];
app.use((0, cors_1.default)({
    origin: function (origin, callback) {
        // Allow requests with no origin (like mobile apps or curl requests)
        if (!origin)
            return callback(null, true);
        if (allowedOrigins.indexOf(origin) !== -1 || process.env.NODE_ENV !== 'production') {
            callback(null, true);
        }
        else {
            callback(new Error('Not allowed by CORS'));
        }
    },
    credentials: true
}));
app.use(express_1.default.json());
// Routes
app.use('/api/auth', auth_1.default);
app.use('/api/vibe', vibe_1.default);
app.use('/api/vibes', vibes_1.default);
app.use('/api/group', group_1.default);
app.use('/api/upload', upload_1.default);
app.use('/api/chat', chat_1.default);
app.use('/api/feed', feed_1.default);
app.use('/api/reminders', reminders_1.default);
app.use('/api/vibewire', vibewire_1.default);
app.use('/api/user', user_1.default);
app.use('/api/bets', bet_1.default);
app.use('/api/aura', aura_1.default);
app.use('/api/tea', tea_1.default);
app.use('/api/leaderboard', leaderboard_1.default);
// Health check
app.get('/health', (_req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});
// Error handler
app.use((err, _req, res, _next) => {
    console.error(err.stack);
    res.status(500).json({ error: 'Something went wrong' });
});
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
//# sourceMappingURL=server.js.map