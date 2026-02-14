/**
 * Tea Spill Service - Business Logic Layer
 *
 * Handles tea spill creation, guessing, revealing, and auto-expiry.
 * Follows the same patterns as betService.ts for Aura transactions.
 */
import { ITeaSpill, ITeaGuess } from '../types';
interface CreateTeaSpillInput {
    chatId: string;
    creatorId: string;
    mysteryText: string;
    answer: string;
    options: string[];
    deadline: Date;
}
export declare function createTeaSpill(input: CreateTeaSpillInput): Promise<ITeaSpill>;
interface GuessTeaSpillInput {
    teaId: string;
    userId: string;
    guess: string;
    amount: number;
}
export declare function guessTeaSpill(input: GuessTeaSpillInput): Promise<ITeaGuess>;
interface RevealResult {
    tea: ITeaSpill;
    payouts: Array<{
        userId: string;
        amount: number;
        type: string;
    }>;
}
export declare function revealTeaSpill(params: {
    teaId: string;
    userId: string;
}): Promise<RevealResult>;
export declare function getTeaSpills(params: {
    chatId: string;
    status?: string;
    limit?: number;
    offset?: number;
}): Promise<{
    teas: ITeaSpill[];
    total: number;
    hasMore: boolean;
}>;
export declare function getTeaSpillsForUser(params: {
    userId: string;
    status?: string;
    limit?: number;
    offset?: number;
}): Promise<{
    teas: ITeaSpill[];
    total: number;
    hasMore: boolean;
}>;
export declare function getTeaById(teaId: string): Promise<ITeaSpill | null>;
export declare function getTeaGuesses(teaId: string): Promise<ITeaGuess[]>;
export declare function autoExpireTeaSpills(): Promise<number>;
export {};
//# sourceMappingURL=teaService.d.ts.map