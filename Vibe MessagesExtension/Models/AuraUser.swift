//
//  AuraUser.swift
//  Vibe MessagesExtension
//
//  Aura economy models matching backend types.
//

import Foundation

// MARK: - AuraStats (from /api/aura/stats)
// Backend getAuraStats returns: balance, lifetimeEarned, lifetimeSpent, canBet, dailyBonusAvailable, nextBonusAt

struct AuraStats: Codable {
    let balance: Int
    let lifetimeEarned: Int
    let lifetimeSpent: Int
    let canBet: Bool
    let dailyBonusAvailable: Bool
    let nextBonusAt: Date?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.balance = try container.decodeIfPresent(Int.self, forKey: .balance) ?? 0
        self.lifetimeEarned = try container.decodeIfPresent(Int.self, forKey: .lifetimeEarned) ?? 0
        self.lifetimeSpent = try container.decodeIfPresent(Int.self, forKey: .lifetimeSpent) ?? 0
        self.canBet = try container.decodeIfPresent(Bool.self, forKey: .canBet) ?? false
        self.dailyBonusAvailable = try container.decodeIfPresent(Bool.self, forKey: .dailyBonusAvailable) ?? true
        self.nextBonusAt = try container.decodeIfPresent(Date.self, forKey: .nextBonusAt)
    }
}

// MARK: - AuraTransaction

struct AuraTransaction: Codable, Identifiable {
    let id: String
    let transactionId: String
    let amount: Int
    let balanceAfter: Int
    let type: String
    let description: String?
    let referenceId: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case transactionId, amount, balanceAfter
        case type, description, referenceId, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.transactionId = try container.decode(String.self, forKey: .transactionId)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? transactionId
        self.amount = try container.decode(Int.self, forKey: .amount)
        self.balanceAfter = try container.decode(Int.self, forKey: .balanceAfter)
        self.type = try container.decode(String.self, forKey: .type)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.referenceId = try container.decodeIfPresent(String.self, forKey: .referenceId)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

// MARK: - Leaderboard

struct LeaderboardEntry: Codable, Identifiable {
    let rank: Int
    let id: String
    let name: String
    let profilePicture: String?
    let auraBalance: Int
    let vibeScore: Int
    let winRate: Int
    let duckRate: Int
}

// MARK: - API Response Types

struct AuraStatsResponse: Codable {
    let success: Bool
    let stats: AuraStats
}

struct AuraTransactionListResponse: Codable {
    let transactions: [AuraTransaction]
    let count: Int
}

struct DailyClaimResponse: Codable {
    let success: Bool
    let claimed: Bool
    let amount: Int
    let newBalance: Int?
    let currentBalance: Int?
    let message: String
}

struct LeaderboardResponse: Codable {
    let leaderboard: [LeaderboardEntry]
    let count: Int
}
