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
// Route imports
const auth_1 = __importDefault(require("./routes/auth"));
const vibe_1 = __importDefault(require("./routes/vibe"));
const vibes_1 = __importDefault(require("./routes/vibes"));
const group_1 = __importDefault(require("./routes/group"));
const upload_1 = __importDefault(require("./routes/upload"));
const chat_1 = __importDefault(require("./routes/chat"));
const feed_1 = __importDefault(require("./routes/feed"));
const reminders_1 = __importDefault(require("./routes/reminders"));
const app = (0, express_1.default)();
// Connect to MongoDB
(0, db_1.default)();
// Middleware
app.use((0, helmet_1.default)());
app.use((0, cors_1.default)());
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