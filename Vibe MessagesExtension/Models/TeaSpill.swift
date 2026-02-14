//
//  TeaSpill.swift
//  Vibe MessagesExtension
//
//  Tea Spill guessing game models matching backend types.
//

import Foundation

// MARK: - Enums

enum TeaSpillStatus: String, Codable {
    case active
    case revealed
    case expired
}

// MARK: - TeaSpill

struct TeaSpill: Codable, Identifiable, Equatable {
    let id: String
    let teaId: String
    let chatId: String
    let creatorId: String
    let mysteryText: String
    let answer: String?        // nil until revealed for non-creators
    let options: [String]
    let deadline: Date
    let status: TeaSpillStatus
    let creationCost: Int?
    let creatorBonusPercent: Int?
    let revealedAt: Date?
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case teaId, chatId, creatorId, mysteryText, answer
        case options, deadline, status, creationCost
        case creatorBonusPercent, revealedAt, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.teaId = try container.decode(String.self, forKey: .teaId)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? teaId
        self.chatId = try container.decode(String.self, forKey: .chatId)
        self.creatorId = try container.decode(String.self, forKey: .creatorId)
        self.mysteryText = try container.decode(String.self, forKey: .mysteryText)
        self.answer = try container.decodeIfPresent(String.self, forKey: .answer)
        self.options = try container.decode([String].self, forKey: .options)
        self.deadline = try container.decode(Date.self, forKey: .deadline)
        self.status = try container.decode(TeaSpillStatus.self, forKey: .status)
        self.creationCost = try container.decodeIfPresent(Int.self, forKey: .creationCost)
        self.creatorBonusPercent = try container.decodeIfPresent(Int.self, forKey: .creatorBonusPercent)
        self.revealedAt = try container.decodeIfPresent(Date.self, forKey: .revealedAt)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    static func == (lhs: TeaSpill, rhs: TeaSpill) -> Bool {
        lhs.teaId == rhs.teaId
    }
}

extension TeaSpill {
    var isExpired: Bool {
        deadline < Date()
    }

    var timeRemaining: TimeInterval {
        deadline.timeIntervalSinceNow
    }

    var timeRemainingFormatted: String {
        let remaining = max(0, timeRemaining)
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - TeaGuess

struct TeaGuess: Codable, Identifiable, Equatable {
    let id: String
    let guessId: String
    let teaId: String
    let userId: String
    let guess: String
    let amount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case guessId, teaId, userId, guess, amount, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.guessId = try container.decode(String.self, forKey: .guessId)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? guessId
        self.teaId = try container.decode(String.self, forKey: .teaId)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.guess = try container.decode(String.self, forKey: .guess)
        self.amount = try container.decode(Int.self, forKey: .amount)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    static func == (lhs: TeaGuess, rhs: TeaGuess) -> Bool {
        lhs.guessId == rhs.guessId
    }
}

// MARK: - API Response Types

struct TeaCreateResponse: Codable {
    let success: Bool
    let tea: TeaSpill
}

struct TeaGuessResponse: Codable {
    let success: Bool
    let guess: TeaGuess
}

struct TeaRevealResponse: Codable {
    let success: Bool
    let tea: TeaSpill
    let payouts: [TeaPayout]?
}

struct TeaPayout: Codable {
    let userId: String
    let amount: Int
    let type: String   // "tea_win" | "tea_refund"
}

struct TeaListResponse: Codable {
    let teas: [TeaSpill]
    let total: Int
    let hasMore: Bool
}

struct TeaGuessListResponse: Codable {
    let guesses: [TeaGuess]
}
