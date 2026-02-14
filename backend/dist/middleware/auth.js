"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.optionalAuth = exports.authMiddleware = void 0;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
/**
 * @middleware authMiddleware
 * @desc Verifies JWT from Authorization header, attaches userId to req.
 *       Returns 401 on missing/invalid/expired token. 500 if JWT_SECRET unset.
 */
const authMiddleware = (req, res, next) => {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        res.status(401).json({ error: 'No token provided' });
        return;
    }
    const secret = process.env.JWT_SECRET;
    if (!secret) {
        console.error('CRITICAL: JWT_SECRET not set');
        res.status(500).json({ error: 'Server configuration error' });
        return;
    }
    try {
        const token = authHeader.substring(7);
        const decoded = jsonwebtoken_1.default.verify(token, secret);
        if (!decoded.userId) {
            res.status(401).json({ error: 'Invalid token' });
            return;
        }
        req.userId = decoded.userId;
        next();
    }
    catch (err) {
        if (err.name === 'TokenExpiredError') {
            res.status(401).json({ error: 'Token expired' });
        }
        else {
            res.status(401).json({ error: 'Invalid token' });
        }
    }
};
exports.authMiddleware = authMiddleware;
/**
 * @middleware optionalAuth
 * @desc Same as authMiddleware but never rejects. req.userId is set if token
 *       is valid, undefined otherwise. Routes can branch on presence.
 */
const optionalAuth = (req, res, next) => {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        next();
        return;
    }
    const secret = process.env.JWT_SECRET;
    if (!secret) {
        next();
        return;
    }
    try {
        const token = authHeader.substring(7);
        const decoded = jsonwebtoken_1.default.verify(token, secret);
        if (decoded.userId) {
            req.userId = decoded.userId;
        }
    }
    catch {
        // silently ignored — req.userId stays undefined
    }
    next();
};
exports.optionalAuth = optionalAuth;
//# sourceMappingURL=auth.js.map