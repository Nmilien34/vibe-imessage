//
//  Bet.swift
//  Vibe MessagesExtension
//
//  Betting system models matching backend types.
//

import Foundation

// MARK: - Enums

enum BetType: String, Codable {
    case `self`
    case callout
    case dare
}

enum BetStatus: String, Codable {
    case active
    case completed
    case expired
    case ducked
}

enum BetSide: String, Codable {
    case yes
    case no
}

enum BetOutcome: String, Codable {
    case yes
    case no
    case expired
    case ducked
}

enum ProofMediaType: String, Codable {
    case photo
    case video
}

// MARK: - Bet

struct Bet: Codable, Identifiable, Equatable {
    let id: String
    let betId: String
    let chatId: String
    let creatorId: String
    let betType: BetType
    let description: String
    let deadline: Date
    let status: BetStatus
    let targetUserId: String?
    let creationCost: Int?
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case betId, chatId, creatorId, betType, description
        case deadline, status, targetUserId, creationCost
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.betId = try container.decode(String.self, forKey: .betId)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? betId
        self.chatId = try container.decode(String.self, forKey: .chatId)
        self.creatorId = try container.decode(String.self, forKey: .creatorId)
        self.betType = try container.decode(BetType.self, forKey: .betType)
        self.description = try container.decode(String.self, forKey: .description)
        self.deadline = try container.decode(Date.self, forKey: .deadline)
        self.status = try container.decode(BetStatus.self, forKey: .status)
        self.targetUserId = try container.decodeIfPresent(String.self, forKey: .targetUserId)
        self.creationCost = try container.decodeIfPresent(Int.self, forKey: .creationCost)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    static func == (lhs: Bet, rhs: Bet) -> Bool {
        lhs.betId == rhs.betId
    }
}

extension Bet {
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

// MARK: - BetParticipant

struct BetParticipant: Codable, Identifiable, Equatable {
    let id: String
    let participantId: String
    let betId: String?
    let userId: String
    let side: BetSide
    let amount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case participantId, betId, userId, side, amount, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.participantId = try container.decode(String.self, forKey: .participantId)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? participantId
        self.betId = try container.decodeIfPresent(String.self, forKey: .betId)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.side = try container.decode(BetSide.self, forKey: .side)
        self.amount = try container.decode(Int.self, forKey: .amount)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    static func == (lhs: BetParticipant, rhs: BetParticipant) -> Bool {
        lhs.participantId == rhs.participantId
    }
}

// MARK: - BetTotals (from /api/bets/:betId/participants)

struct BetTotals: Codable {
    let totalYes: Int
    let totalNo: Int
    let totalPot: Int
    let yesCount: Int
    let noCount: Int
}

// MARK: - UserStake (from /api/bets/:betId/my-stake)

struct UserStake: Codable {
    let participantId: String
    let side: BetSide
    let amount: Int
    let createdAt: Date
}

// MARK: - BetProof

struct BetProof: Codable, Identifiable, Equatable {
    let id: String
    let proofId: String
    let betId: String
    let userId: String
    let mediaType: ProofMediaType
    let mediaUrl: String
    let thumbnailUrl: String?
    let caption: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case proofId, betId, userId, mediaType, mediaUrl
        case thumbnailUrl, caption, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.proofId = try container.decode(String.self, forKey: .proofId)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? proofId
        self.betId = try container.decode(String.self, forKey: .betId)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.mediaType = try container.decode(ProofMediaType.self, forKey: .mediaType)
        self.mediaUrl = try container.decode(String.self, forKey: .mediaUrl)
        self.thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        self.caption = try container.decodeIfPresent(String.self, forKey: .caption)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    static func == (lhs: BetProof, rhs: BetProof) -> Bool {
        lhs.proofId == rhs.proofId
    }
}

// MARK: - BetResolution

struct BetResolution: Codable {
    let resolutionId: String
    let betId: String
    let outcome: BetOutcome
    let resolvedBy: String
    let resolvedAt: Date
    let notes: String?
}

// MARK: - API Response Types

struct BetDetailResponse: Codable {
    let bet: Bet
    let participants: [BetParticipant]
    let totals: BetTotals
    let userStake: UserStake?
}

struct BetListResponse: Codable {
    let bets: [Bet]
    let count: Int
}

struct DiscoverBetFeedItem: Codable, Identifiable {
    let id: String
    let bet: Bet
    let accessLevel: String
    let source: String
    let canBet: Bool
    let totals: BetTotals
    let participantCount: Int

    enum CodingKeys: String, CodingKey {
        case bet, accessLevel, source, canBet, totals, participantCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bet = try container.decode(Bet.self, forKey: .bet)
        self.id = bet.betId
        self.accessLevel = try container.decode(String.self, forKey: .accessLevel)
        self.source = try container.decode(String.self, forKey: .source)
        self.canBet = try container.decode(Bool.self, forKey: .canBet)
        self.totals = try container.decode(BetTotals.self, forKey: .totals)
        self.participantCount = try container.decode(Int.self, forKey: .participantCount)
    }
}

struct DiscoverBetResponse: Codable {
    let bets: [DiscoverBetFeedItem]
    let total: Int
    let hasMore: Bool
}

struct CreateBetResponse: Codable {
    let success: Bool
    let bet: Bet
}

struct StakeResponse: Codable {
    let success: Bool
    let participant: BetParticipant
}

struct ProofResponse: Codable {
    let success: Bool
    let proof: BetProof
}

struct ProofListResponse: Codable {
    let proofs: [BetProof]
    let count: Int
}

struct ParticipantsResponse: Codable {
    let participants: [BetParticipant]
    let totals: BetTotals
}

struct UserStakeResponse: Codable {
    let hasStake: Bool
    let stake: UserStake?
}

struct ResolveResponse: Codable {
    let success: Bool
    let resolution: BetResolution
    let bet: BetStatusSummary?
    let message: String?
}

struct BetStatusSummary: Codable {
    let status: BetStatus?
    let finalPot: Int?
}

struct ResolutionResponse: Codable {
    let resolution: BetResolution?
    let message: String?
}
