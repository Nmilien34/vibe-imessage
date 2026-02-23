//
//  AuraService.swift
//  Vibe MessagesExtension
//
//  Service for Aura economy API calls.
//  Backend routes: /api/aura/*
//

import Foundation

actor AuraService {
    static let shared = AuraService()
    private let api = APIClient.shared

    private init() {}

    // MARK: - Get Aura Stats

    func getStats() async throws -> AuraStats {
        let response: AuraStatsResponse = try await api.get("/aura/stats")
        return response.stats
    }

    // MARK: - Get Transaction History

    func getTransactions(limit: Int = 20) async throws -> [AuraTransaction] {
        let response: AuraTransactionListResponse = try await api.get("/aura/transactions?limit=\(limit)")
        return response.transactions
    }

    // MARK: - Claim Daily Bonus

    func claimDailyBonus() async throws -> DailyClaimResponse {
        return try await api.postEmpty("/aura/claim-daily")
    }

    // MARK: - Get Leaderboard

    func getLeaderboard(limit: Int = 20, sortBy: String = "auraBalance") async throws -> [LeaderboardEntry] {
        _ = sortBy // Server leaderboard is Aura-sorted by design in loop spec.
        let response: LeaderboardResponse = try await api.get("/leaderboard?limit=\(limit)")
        return response.leaderboard
    }
}
