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

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self)) ?? BetType.`self`.rawValue

        switch rawValue {
        case BetType.`self`.rawValue:
            self = .self
        case BetType.callout.rawValue:
            self = .callout
        case BetType.dare.rawValue:
            self = .dare
        case "prediction":
            // Legacy client fallback for new server bet type.
            self = .self
        default:
            self = .self
        }
    }
}

enum BetLifecycleStatus: String, Codable {
    case pending
    case active
    case resolving
    case completed
    case expired
    case ducked
    case cancelled

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self)) ?? BetLifecycleStatus.active.rawValue

        switch rawValue {
        case BetLifecycleStatus.pending.rawValue, "pending_resolution":
            self = .pending
        case BetLifecycleStatus.active.rawValue:
            self = .active
        case BetLifecycleStatus.resolving.rawValue:
            self = .resolving
        case BetLifecycleStatus.completed.rawValue:
            self = .completed
        case BetLifecycleStatus.expired.rawValue:
            self = .expired
        case BetLifecycleStatus.ducked.rawValue:
            self = .ducked
        case BetLifecycleStatus.cancelled.rawValue:
            self = .cancelled
        default:
            self = .active
        }
    }
}

enum BetStatus: String, Codable {
    case active
    case pendingResolution = "pending_resolution"
    case completed
    case expired
    case ducked

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let lifecycle = (try? container.decode(BetLifecycleStatus.self)) ?? .active
        self = BetStatus(lifecycleStatus: lifecycle)
    }

    init(lifecycleStatus: BetLifecycleStatus) {
        switch lifecycleStatus {
        case .active:
            self = .active
        case .pending, .resolving:
            self = .pendingResolution
        case .completed:
            self = .completed
        case .expired, .cancelled:
            self = .expired
        case .ducked:
            self = .ducked
        }
    }
}

enum BetSide: String, Codable {
    case yes
    case no
}

enum BetResolutionType: String, Codable {
    case proof
    case observable
    case consensus
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

enum BetProofStatus: String, Codable {
    case pending
    case confirmed
    case disputed
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
    let lifecycleStatus: BetLifecycleStatus
    let status: BetStatus
    let targetUserId: String?
    let creationCost: Int?
    let participationThreshold: Double?
    let resolutionType: BetResolutionType?
    let thresholdMemberCount: Int?
    let activatedAt: Date?
    let originalDeadlineDuration: Int?
    let observableDeclaredOutcome: BetSide?
    let observableDeclaredBy: String?
    let observableDeclaredAt: Date?
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case betId, chatId, creatorId, betType, description
        case deadline, status, targetUserId, creationCost
        case participationThreshold, resolutionType, thresholdMemberCount, activatedAt, originalDeadlineDuration
        case observableDeclaredOutcome, observableDeclaredBy, observableDeclaredAt
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
        self.lifecycleStatus = try container.decode(BetLifecycleStatus.self, forKey: .status)
        self.status = BetStatus(lifecycleStatus: lifecycleStatus)
        self.targetUserId = try container.decodeIfPresent(String.self, forKey: .targetUserId)
        self.creationCost = try container.decodeIfPresent(Int.self, forKey: .creationCost)
        self.participationThreshold = try container.decodeIfPresent(Double.self, forKey: .participationThreshold)
        self.resolutionType = try container.decodeIfPresent(BetResolutionType.self, forKey: .resolutionType)
        self.thresholdMemberCount = try container.decodeIfPresent(Int.self, forKey: .thresholdMemberCount)
        self.activatedAt = try container.decodeIfPresent(Date.self, forKey: .activatedAt)
        self.originalDeadlineDuration = try container.decodeIfPresent(Int.self, forKey: .originalDeadlineDuration)
        self.observableDeclaredOutcome = try container.decodeIfPresent(BetSide.self, forKey: .observableDeclaredOutcome)
        self.observableDeclaredBy = try container.decodeIfPresent(String.self, forKey: .observableDeclaredBy)
        self.observableDeclaredAt = try container.decodeIfPresent(Date.self, forKey: .observableDeclaredAt)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    static func == (lhs: Bet, rhs: Bet) -> Bool {
        lhs.betId == rhs.betId
    }
}

extension Bet {
    var isPendingThreshold: Bool {
        lifecycleStatus == .pending
    }

    var isResolving: Bool {
        lifecycleStatus == .resolving
    }

    var supportsStaking: Bool {
        lifecycleStatus == .active || lifecycleStatus == .pending
    }

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
    let isAnonymous: Bool?
    let payout: Int?
    let won: Bool?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case participantId, betId, userId, side, amount, isAnonymous, payout, won, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.participantId = try container.decode(String.self, forKey: .participantId)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? participantId
        self.betId = try container.decodeIfPresent(String.self, forKey: .betId)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.side = try container.decode(BetSide.self, forKey: .side)
        self.amount = try container.decode(Int.self, forKey: .amount)
        self.isAnonymous = try container.decodeIfPresent(Bool.self, forKey: .isAnonymous)
        self.payout = try container.decodeIfPresent(Int.self, forKey: .payout)
        self.won = try container.decodeIfPresent(Bool.self, forKey: .won)
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
    let isAnonymous: Bool?
    let payout: Int?
    let won: Bool?
    let createdAt: Date
}

// MARK: - BetStakeTransaction (from /api/bets/:betId/my-stake-transactions)

struct BetStakeTransaction: Codable, Identifiable {
    let id: String
    let transactionId: String
    let amount: Int
    let balanceAfter: Int
    let description: String?
    let referenceId: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case transactionId, amount, balanceAfter
        case description, referenceId, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.transactionId = try container.decode(String.self, forKey: .transactionId)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? transactionId
        self.amount = try container.decode(Int.self, forKey: .amount)
        self.balanceAfter = try container.decode(Int.self, forKey: .balanceAfter)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.referenceId = try container.decodeIfPresent(String.self, forKey: .referenceId)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
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
    let status: BetProofStatus?
    let confirmations: Int?
    let disputes: Int?
    let disputeDeadline: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case proofId, betId, userId, mediaType, mediaUrl
        case thumbnailUrl, caption, status, confirmations, disputes, disputeDeadline, createdAt
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
        self.status = try container.decodeIfPresent(BetProofStatus.self, forKey: .status)
        self.confirmations = try container.decodeIfPresent(Int.self, forKey: .confirmations)
        self.disputes = try container.decodeIfPresent(Int.self, forKey: .disputes)
        self.disputeDeadline = try container.decodeIfPresent(Date.self, forKey: .disputeDeadline)
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

enum ResolutionClaimStatus: String, Codable {
    case pending
    case confirmed
    case autoConfirmed = "auto_confirmed"
    case disputed
}

struct ResolutionClaim: Codable {
    let claimId: String
    let betId: String
    let proofId: String
    let proposedOutcome: BetOutcome
    let proposedBy: String
    let reviewerIds: [String]
    let confirmedBy: [String]
    let disputedBy: [String]
    let status: ResolutionClaimStatus
    let notes: String?
    let autoConfirmAt: Date
    let finalizedAt: Date?
    let createdAt: Date
    let updatedAt: Date
}

struct ResolutionClaimViewer: Codable {
    let canReview: Bool
    let hasActed: Bool
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
    let chargedFee: Int?
    let totalDebited: Int?
    let isNewStake: Bool?
    let thresholdActivated: Bool?
    let betStatus: BetStatus?
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

struct StakeTransactionListResponse: Codable {
    let transactions: [BetStakeTransaction]
    let totalStaked: Int
    let count: Int
}

struct ResolveResponse: Codable {
    let success: Bool
    let resolution: BetResolution?
    let bet: BetStatusSummary?
    let message: String?
}

struct BetStatusSummary: Codable {
    let status: BetStatus?
    let finalPot: Int?
}

struct ResolutionProofMedia: Codable {
    let mediaUrl: String
    let thumbnailUrl: String?
    let mediaType: ProofMediaType
}

struct ResolutionPayoutEntry: Codable, Identifiable {
    let id: String
    let userId: String?
    let displayName: String
    let stakeAmount: Int
    let payout: Int?
    let netGain: Int?
    let netLoss: Int?

    enum CodingKeys: String, CodingKey {
        case userId, displayName, stakeAmount, payout, netGain, netLoss
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try container.decodeIfPresent(String.self, forKey: .userId)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.stakeAmount = try container.decode(Int.self, forKey: .stakeAmount)
        self.payout = try container.decodeIfPresent(Int.self, forKey: .payout)
        self.netGain = try container.decodeIfPresent(Int.self, forKey: .netGain)
        self.netLoss = try container.decodeIfPresent(Int.self, forKey: .netLoss)
        self.id = userId ?? UUID().uuidString
    }
}

struct ResolutionDuckEntry: Codable, Identifiable {
    let id: String
    let userId: String?
    let displayName: String
    let penalty: Int

    enum CodingKeys: String, CodingKey {
        case userId, displayName, penalty
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try container.decodeIfPresent(String.self, forKey: .userId)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.penalty = try container.decode(Int.self, forKey: .penalty)
        self.id = userId ?? UUID().uuidString
    }
}

struct ResolutionResponse: Codable {
    let betId: String
    let description: String
    let betType: BetType
    let outcome: BetOutcome
    let proof: ResolutionProofMedia?
    let winners: [ResolutionPayoutEntry]
    let losers: [ResolutionPayoutEntry]
    let ducked: [ResolutionDuckEntry]?
    let totalPot: Int
    let participantCount: Int
}

struct ResolutionClaimResponse: Codable {
    let claim: ResolutionClaim?
    let viewer: ResolutionClaimViewer?
}

struct ClaimResolutionResponse: Codable {
    let success: Bool
    let claim: ResolutionClaim
    let proof: BetProof
    let resolution: BetResolution?
    let message: String?
}

struct ResolutionClaimActionResponse: Codable {
    let success: Bool
    let claim: ResolutionClaim
    let resolution: BetResolution?
    let message: String?
}
