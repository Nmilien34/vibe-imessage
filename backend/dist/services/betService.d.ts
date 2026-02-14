/**
 * Bet Service - Business Logic Layer
 *
 * Handles all bet creation validation and transactions.
 * Validates user permissions, Aura balance, description length, deadline.
 * Creates bet + deducts Aura atomically.
 */
import { BetType, BetStatus, IBet, IBetParticipant, IBetProof, IBetResolution } from '../types';
interface CreateBetInput {
    chatId: string;
    creatorId: string;
    betType: BetType;
    description: string;
    deadline: Date;
    initialStake: number;
    initialSide: 'yes' | 'no';
    targetUserId?: string;
}
export declare function createBet(input: CreateBetInput): Promise<IBet>;
export declare function getBetById(betId: string): Promise<IBet | null>;
export declare function getBetsByChatId(chatId: string, status?: BetStatus, limit?: number): Promise<IBet[]>;
export declare function isUserInChat(userId: string, chatId: string): Promise<boolean>;
/**
 * Place stake on a bet.
 * Validates all business rules, deducts Aura (held in escrow),
 * creates participant record and transaction log.
 */
export declare function placeBetStake(params: {
    betId: string;
    userId: string;
    side: 'yes' | 'no';
    amount: number;
}): Promise<IBetParticipant>;
/**
 * Get total Aura staked on each side of a bet.
 */
export declare function getBetTotals(betId: string): Promise<{
    totalYes: number;
    totalNo: number;
    totalPot: number;
    yesCount: number;
    noCount: number;
}>;
/**
 * Get all participants for a bet.
 */
export declare function getBetParticipants(betId: string): Promise<IBetParticipant[]>;
/**
 * Get a user's stake in a bet (if any).
 */
export declare function getUserStake(betId: string, userId: string): Promise<IBetParticipant | null>;
/**
 * Submit Proof for Bet
 *
 * BUSINESS RULES:
 * 1. Bet must exist and be active
 * 2. Only authorized users can submit proof:
 *    - Self bets: Creator only
 *    - Callouts: Target user only
 *    - Dares: Target user only
 * 3. Media URL must be provided (from S3 upload)
 * 4. Deadline must not have passed (1 hour grace period)
 * 5. Can submit multiple proofs for same bet
 *
 * SIDE EFFECTS:
 * 1. Creates BetProof record
 * 2. Does NOT change bet status (remains 'active')
 * 3. Resolution happens separately in Phase 2.5
 */
export declare function submitBetProof(params: {
    betId: string;
    userId: string;
    mediaType: 'photo' | 'video';
    mediaUrl: string;
    mediaKey: string;
    thumbnailUrl?: string;
    thumbnailKey?: string;
    caption?: string;
}): Promise<IBetProof>;
/**
 * Get Proofs for Bet
 *
 * Retrieves all proof submissions for a bet.
 */
export declare function getBetProofs(betId: string): Promise<IBetProof[]>;
/**
 * Get User's Proofs for Bet
 *
 * Checks if a specific user has submitted proof for a bet.
 */
export declare function getUserProofs(betId: string, userId: string): Promise<IBetProof[]>;
/**
 * Delete Proof
 *
 * Allows user to delete their own proof before bet is resolved.
 *
 * BUSINESS RULES:
 * 1. Proof must exist
 * 2. User must own the proof
 * 3. Bet must still be active (can't delete after resolution)
 */
export declare function deleteBetProof(proofId: string, userId: string): Promise<void>;
/**
 * Resolve Bet
 *
 * Settles a bet, distributes Aura to winners, updates stats.
 *
 * BUSINESS RULES:
 * 1. Bet must exist and be active
 * 2. Only authorized users can resolve
 * 3. Outcome must be valid: 'yes', 'no', 'expired', 'ducked'
 * 4. Pari-mutuel payout must be exact
 * 5. All payouts must succeed atomically
 *
 * PAYOUT CALCULATION (Pari-Mutuel):
 * Winner payout = (Their stake / Total winning side) × Total pot
 * No house rake (0% fee)
 */
export declare function resolveBet(params: {
    betId: string;
    resolvedBy: string;
    outcome: 'yes' | 'no' | 'expired' | 'ducked';
    notes?: string;
}): Promise<IBetResolution>;
/**
 * Auto-Expire Bets
 *
 * System function to resolve expired bets.
 * Called by cron job or background worker.
 */
export declare function autoExpireBets(): Promise<number>;
/**
 * Get Resolution for Bet
 *
 * Retrieves the resolution record for a bet.
 */
export declare function getBetResolution(betId: string): Promise<IBetResolution | null>;
export {};
//# sourceMappingURL=betService.d.ts.map