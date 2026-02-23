/**
 * Bet Service - Business Logic Layer
 *
 * Handles all bet creation validation and transactions.
 * Validates user permissions, Aura balance, description length, deadline.
 * Creates bet + deducts Aura atomically.
 */
import { BetType, BetStatus, BetResolutionType, IBet, IBetParticipant, IBetProof, IBetResolution, IResolutionClaim, IAuraTransaction } from '../types';
interface CreateBetInput {
    chatId: string;
    creatorId: string;
    betType: BetType;
    description: string;
    deadline: Date;
    initialStake: number;
    initialSide: 'yes' | 'no';
    targetUserId?: string;
    participationThreshold?: number;
    resolutionType?: BetResolutionType;
    isAnonymous?: boolean;
}
export interface EligibleBetTarget {
    id: string;
    firstName?: string;
    lastName?: string;
    profilePicture?: string;
}
export declare function getEligibleBetTargets(params: {
    chatId: string;
    userId: string;
}): Promise<EligibleBetTarget[]>;
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
    isAnonymous?: boolean;
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
 * Get current user's stake transactions for a specific bet.
 * Includes both initial stake and any creator top-ups.
 */
export declare function getUserBetStakeTransactions(params: {
    betId: string;
    userId: string;
    limit?: number;
}): Promise<IAuraTransaction[]>;
/**
 * Submit Proof for Bet
 *
 * BUSINESS RULES:
 * 1. Bet must exist and be active/resolving
 * 2. Only authorized users can submit proof:
 *    - Self bets: Creator only
 *    - Callouts: Creator or target user
 *    - Dares: Creator or target user
 * 3. Media URL must be provided (from S3 upload)
 * 4. Deadline must not have passed (1 hour grace period)
 * 5. Can submit multiple proofs for same bet
 *
 * SIDE EFFECTS:
 * 1. Creates BetProof record
 * 2. Sets proof status to pending and opens dispute window
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
    allowedStatuses?: BetStatus[];
}): Promise<IBetResolution>;
/**
 * Get Resolution for Bet
 *
 * Retrieves the resolution record for a bet.
 */
export declare function getBetResolution(betId: string): Promise<IBetResolution | null>;
export declare function refundAllStakes(betId: string): Promise<void>;
export declare function applyDuckPenalty(userId: string, betId: string): Promise<void>;
export declare function voteOnConsensus(params: {
    betId: string;
    userId: string;
    vote: 'yes' | 'no';
}): Promise<{
    yesVotes: number;
    noVotes: number;
    totalVotes: number;
}>;
export declare function reactToProof(params: {
    betId: string;
    proofId: string;
    userId: string;
    reaction: 'confirm' | 'dispute';
}): Promise<{
    proof: IBetProof;
    confirmations: number;
    disputes: number;
}>;
export declare function getBetResolutionPayload(betId: string): Promise<{
    betId: string;
    description: string;
    betType: BetType;
    outcome: 'yes' | 'no' | 'expired' | 'ducked';
    proof: {
        mediaUrl: string;
        thumbnailUrl?: string;
        mediaType: 'photo' | 'video';
    } | null;
    winners: Array<{
        userId: string | null;
        displayName: string;
        stakeAmount: number;
        payout: number;
        netGain: number;
    }>;
    losers: Array<{
        userId: string | null;
        displayName: string;
        stakeAmount: number;
        netLoss: number;
    }>;
    ducked: Array<{
        userId: string | null;
        displayName: string;
        penalty: number;
    }> | null;
    totalPot: number;
    participantCount: number;
}>;
export declare function getPendingResolutionClaim(betId: string): Promise<IResolutionClaim | null>;
/**
 * Claim Resolution With Proof
 *
 * Creates a pending resolution claim and transitions the bet to `resolving`.
 * Payouts only happen once this claim is confirmed (or auto-confirmed).
 */
export declare function claimBetResolution(params: {
    betId: string;
    userId: string;
    outcome: 'yes' | 'no' | 'ducked';
    mediaType: 'photo' | 'video';
    mediaUrl: string;
    mediaKey: string;
    thumbnailUrl?: string;
    thumbnailKey?: string;
    caption?: string;
    notes?: string;
}): Promise<{
    claim: IResolutionClaim;
    proof: IBetProof;
    resolution?: IBetResolution;
}>;
/**
 * Confirm a pending resolution claim.
 * When all reviewers confirm, payouts are finalized.
 */
export declare function confirmBetResolution(params: {
    betId: string;
    userId: string;
}): Promise<{
    claim: IResolutionClaim;
    resolution?: IBetResolution;
}>;
/**
 * Dispute a pending resolution claim.
 * Keeps bet in resolving so additional proof/votes can be submitted.
 */
export declare function disputeBetResolution(params: {
    betId: string;
    userId: string;
    notes?: string;
}): Promise<IResolutionClaim>;
export declare function autoConfirmPendingResolutionClaims(): Promise<number>;
/**
 * Auto-Expire Bets + Auto-Confirm Claims
 *
 * System function to resolve expired bets and auto-confirm pending claims
 * whose review windows have elapsed.
 */
export declare function autoExpireBets(): Promise<{
    expiredCount: number;
    autoConfirmedCount: number;
}>;
export {};
//# sourceMappingURL=betService.d.ts.map