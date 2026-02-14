/**
 * Runs on every login. Two jobs:
 *   1. Awards +50 Aura if 24h has passed since lastDailyBonus (or never claimed)
 *   2. Recalculates vibeScore from current bet/callout stats
 *
 * Returns the final values to put directly into the login response.
 */
export declare function processLoginUpdates(userId: string): Promise<{
    auraBalance: number;
    vibeScore: number;
    dailyBonusClaimed: boolean;
}>;
/**
 * Check if user can afford an amount
 */
export declare function canAfford(userId: string, amount: number): Promise<boolean>;
/**
 * Check if user is bankrupt (0 or less Aura)
 */
export declare function isBankrupt(userId: string): Promise<boolean>;
/**
 * Get user's Aura stats
 */
export declare function getAuraStats(userId: string): Promise<{
    balance: number;
    lifetimeEarned: number;
    lifetimeSpent: number;
    canBet: boolean;
    dailyBonusAvailable: boolean;
    nextBonusAt: Date | null;
}>;
/**
 * Get recent transactions for a user
 */
export declare function getTransactionHistory(userId: string, limit?: number): Promise<any[]>;
/**
 * Calculate win rate percentage
 */
export declare function calculateWinRate(betsCompleted: number, betsCreated: number): number;
/**
 * Calculate duck rate percentage
 */
export declare function calculateDuckRate(calloutsIgnored: number, calloutsReceived: number): number;
//# sourceMappingURL=auraService.d.ts.map