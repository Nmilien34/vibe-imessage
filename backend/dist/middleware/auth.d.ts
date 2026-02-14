import { Request, Response, NextFunction } from 'express';
declare global {
    namespace Express {
        interface Request {
            userId?: string;
        }
    }
}
/**
 * @middleware authMiddleware
 * @desc Verifies JWT from Authorization header, attaches userId to req.
 *       Returns 401 on missing/invalid/expired token. 500 if JWT_SECRET unset.
 */
export declare const authMiddleware: (req: Request, res: Response, next: NextFunction) => void;
/**
 * @middleware optionalAuth
 * @desc Same as authMiddleware but never rejects. req.userId is set if token
 *       is valid, undefined otherwise. Routes can branch on presence.
 */
export declare const optionalAuth: (req: Request, res: Response, next: NextFunction) => void;
//# sourceMappingURL=auth.d.ts.map