import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

declare global {
  namespace Express {
    interface Request {
      userId?: string;
    }
  }
}

interface JWTPayload {
  userId: string;
  iat?: number;
  exp?: number;
}

/**
 * @middleware authMiddleware
 * @desc Verifies JWT from Authorization header, attaches userId to req.
 *       Returns 401 on missing/invalid/expired token. 500 if JWT_SECRET unset.
 */
export const authMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
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
    const decoded = jwt.verify(token, secret) as JWTPayload;

    if (!decoded.userId) {
      res.status(401).json({ error: 'Invalid token' });
      return;
    }

    req.userId = decoded.userId;
    next();
  } catch (err: any) {
    if (err.name === 'TokenExpiredError') {
      res.status(401).json({ error: 'Token expired' });
    } else {
      res.status(401).json({ error: 'Invalid token' });
    }
  }
};

/**
 * @middleware optionalAuth
 * @desc Same as authMiddleware but never rejects. req.userId is set if token
 *       is valid, undefined otherwise. Routes can branch on presence.
 */
export const optionalAuth = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
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
    const decoded = jwt.verify(token, secret) as JWTPayload;
    if (decoded.userId) {
      req.userId = decoded.userId;
    }
  } catch {
    // silently ignored — req.userId stays undefined
  }

  next();
};
