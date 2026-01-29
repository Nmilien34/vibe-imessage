"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.vibesRoutes = exports.vibeRoutes = exports.uploadRoutes = exports.remindersRoutes = exports.groupRoutes = exports.feedRoutes = exports.chatRoutes = exports.authRoutes = void 0;
var auth_1 = require("./auth");
Object.defineProperty(exports, "authRoutes", { enumerable: true, get: function () { return __importDefault(auth_1).default; } });
var chat_1 = require("./chat");
Object.defineProperty(exports, "chatRoutes", { enumerable: true, get: function () { return __importDefault(chat_1).default; } });
var feed_1 = require("./feed");
Object.defineProperty(exports, "feedRoutes", { enumerable: true, get: function () { return __importDefault(feed_1).default; } });
var group_1 = require("./group");
Object.defineProperty(exports, "groupRoutes", { enumerable: true, get: function () { return __importDefault(group_1).default; } });
var reminders_1 = require("./reminders");
Object.defineProperty(exports, "remindersRoutes", { enumerable: true, get: function () { return __importDefault(reminders_1).default; } });
var upload_1 = require("./upload");
Object.defineProperty(exports, "uploadRoutes", { enumerable: true, get: function () { return __importDefault(upload_1).default; } });
var vibe_1 = require("./vibe");
Object.defineProperty(exports, "vibeRoutes", { enumerable: true, get: function () { return __importDefault(vibe_1).default; } });
var vibes_1 = require("./vibes");
Object.defineProperty(exports, "vibesRoutes", { enumerable: true, get: function () { return __importDefault(vibes_1).default; } });
//# sourceMappingURL=index.js.map