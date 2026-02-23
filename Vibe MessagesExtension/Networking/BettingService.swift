//
//  BettingService.swift
//  Vibe MessagesExtension
//
//  Service for betting system API calls.
//  Backend routes: /api/bets/*
//

import Foundation

actor BettingService {
    static let shared = BettingService()
    private let api = APIClient.shared

    private init() {}

    private func statusQueryValue(_ status: BetStatus) -> String {
        // Server now uses "pending" where legacy client used "pending_resolution".
        if status == .pendingResolution {
            return "pending"
        }
        return status.rawValue
    }

    // MARK: - Create Bet

    struct CreateBetRequest: Encodable {
        let chatId: String
        let betType: String
        let description: String
        let deadline: Date
        let initialStake: Int
        let initialSide: String
        let targetUserId: String?
        let participationThreshold: Double?
        let resolutionType: String?
        let isAnonymous: Bool?
    }

    func createBet(
        chatId: String,
        betType: BetType,
        description: String,
        deadline: Date,
        initialStake: Int,
        initialSide: BetSide = .yes,
        targetUserId: String? = nil,
        participationThreshold: Double? = nil,
        resolutionType: BetResolutionType? = nil,
        isAnonymous: Bool = false
    ) async throws -> Bet {
        let response: CreateBetResponse = try await api.post(
            "/bets/create",
            body: CreateBetRequest(
                chatId: chatId,
                betType: betType.rawValue,
                description: description,
                deadline: deadline,
                initialStake: initialStake,
                initialSide: initialSide.rawValue,
                targetUserId: targetUserId,
                participationThreshold: participationThreshold,
                resolutionType: resolutionType?.rawValue,
                isAnonymous: isAnonymous
            )
        )
        return response.bet
    }

    // MARK: - Get Bet Detail

    func getBet(betId: String) async throws -> BetDetailResponse {
        return try await api.get("/bets/\(betId)")
    }

    // MARK: - Get Bets for Chat

    func getBetsForChat(chatId: String, status: BetStatus? = nil, limit: Int = 50) async throws -> BetListResponse {
        var path = "/bets/chat/\(chatId)?limit=\(limit)"
        if let status = status {
            path += "&status=\(statusQueryValue(status))"
        }
        return try await api.get(path)
    }

    func getBetsForChat(chatId: String, statusRaw: BetLifecycleStatus, limit: Int = 50) async throws -> BetListResponse {
        let path = "/bets/chat/\(chatId)?limit=\(limit)&status=\(statusRaw.rawValue)"
        return try await api.get(path)
    }

    // MARK: - Discover Bets (All Chats)

    func getDiscoverBets(status: BetStatus? = nil, limit: Int = 50, offset: Int = 0) async throws -> DiscoverBetResponse {
        var path = "/feed/discover?limit=\(limit)&offset=\(offset)"
        if let status = status {
            path += "&status=\(statusQueryValue(status))"
        }
        return try await api.get(path)
    }

    func getDiscoverBets(statusRaw: BetLifecycleStatus, limit: Int = 50, offset: Int = 0) async throws -> DiscoverBetResponse {
        let path = "/feed/discover?limit=\(limit)&offset=\(offset)&status=\(statusRaw.rawValue)"
        return try await api.get(path)
    }

    // MARK: - Place Stake

    struct PlaceStakeRequest: Encodable {
        let side: String
        let amount: Int
        let isAnonymous: Bool?
    }

    func placeStake(
        betId: String,
        side: BetSide,
        amount: Int,
        isAnonymous: Bool = false
    ) async throws -> StakeResponse {
        let response: StakeResponse = try await api.post(
            "/bets/\(betId)/stake",
            body: PlaceStakeRequest(side: side.rawValue, amount: amount, isAnonymous: isAnonymous)
        )
        return response
    }

    // MARK: - Get My Stake

    func getMyStake(betId: String) async throws -> UserStakeResponse {
        return try await api.get("/bets/\(betId)/my-stake")
    }

    // MARK: - Get My Stake Transactions

    func getMyStakeTransactions(betId: String, limit: Int = 50) async throws -> StakeTransactionListResponse {
        return try await api.get("/bets/\(betId)/my-stake-transactions?limit=\(limit)")
    }

    // MARK: - Get Participants

    func getParticipants(betId: String) async throws -> ParticipantsResponse {
        return try await api.get("/bets/\(betId)/participants")
    }

    // MARK: - Submit Proof

    struct SubmitProofRequest: Encodable {
        let mediaType: String
        let mediaUrl: String
        let mediaKey: String
        let thumbnailUrl: String?
        let thumbnailKey: String?
        let caption: String?
    }

    func submitProof(
        betId: String,
        mediaType: ProofMediaType,
        mediaUrl: String,
        mediaKey: String,
        thumbnailUrl: String? = nil,
        thumbnailKey: String? = nil,
        caption: String? = nil
    ) async throws -> BetProof {
        let response: ProofResponse = try await api.post(
            "/bets/\(betId)/proof",
            body: SubmitProofRequest(
                mediaType: mediaType.rawValue,
                mediaUrl: mediaUrl,
                mediaKey: mediaKey,
                thumbnailUrl: thumbnailUrl,
                thumbnailKey: thumbnailKey,
                caption: caption
            )
        )
        return response.proof
    }

    // MARK: - Get Proofs

    func getProofs(betId: String) async throws -> ProofListResponse {
        return try await api.get("/bets/\(betId)/proofs")
    }

    // MARK: - Proof Reactions

    struct ProofReactionCounts: Codable {
        let success: Bool
        let proof: ProofReactionState
    }

    struct ProofReactionState: Codable {
        let proofId: String
        let status: BetProofStatus?
        let confirmations: Int
        let disputes: Int
        let disputeDeadline: Date?
    }

    func confirmProof(betId: String, proofId: String) async throws -> ProofReactionCounts {
        return try await api.postEmpty("/bets/\(betId)/proof/\(proofId)/confirm")
    }

    func disputeProof(betId: String, proofId: String) async throws -> ProofReactionCounts {
        return try await api.postEmpty("/bets/\(betId)/proof/\(proofId)/dispute")
    }

    // MARK: - Consensus Vote

    struct ConsensusVoteRequest: Encodable {
        let vote: String
    }

    struct ConsensusVoteCounts: Codable {
        let success: Bool
        let counts: VoteCounts
    }

    struct VoteCounts: Codable {
        let yesVotes: Int
        let noVotes: Int
        let totalVotes: Int
    }

    func voteOnBet(betId: String, vote: BetSide) async throws -> ConsensusVoteCounts {
        return try await api.post(
            "/bets/\(betId)/vote",
            body: ConsensusVoteRequest(vote: vote.rawValue)
        )
    }

    // MARK: - Resolve Bet

    struct ResolveBetRequest: Encodable {
        let outcome: String
        let notes: String?
    }

    func resolveBet(betId: String, outcome: BetOutcome, notes: String? = nil) async throws -> ResolveResponse {
        return try await api.post(
            "/bets/\(betId)/resolve",
            body: ResolveBetRequest(outcome: outcome.rawValue, notes: notes)
        )
    }

    // MARK: - Claim Resolution

    struct ClaimResolutionRequest: Encodable {
        let outcome: String
        let mediaType: String
        let mediaUrl: String
        let mediaKey: String
        let thumbnailUrl: String?
        let thumbnailKey: String?
        let caption: String?
        let notes: String?
    }

    func claimResolution(
        betId: String,
        outcome: BetOutcome,
        mediaType: ProofMediaType,
        mediaUrl: String,
        mediaKey: String,
        thumbnailUrl: String? = nil,
        thumbnailKey: String? = nil,
        caption: String? = nil,
        notes: String? = nil
    ) async throws -> ClaimResolutionResponse {
        return try await api.post(
            "/bets/\(betId)/claim-resolution",
            body: ClaimResolutionRequest(
                outcome: outcome.rawValue,
                mediaType: mediaType.rawValue,
                mediaUrl: mediaUrl,
                mediaKey: mediaKey,
                thumbnailUrl: thumbnailUrl,
                thumbnailKey: thumbnailKey,
                caption: caption,
                notes: notes
            )
        )
    }

    func getResolutionClaim(betId: String) async throws -> ResolutionClaimResponse {
        return try await api.get("/bets/\(betId)/resolution-claim")
    }

    func confirmResolutionClaim(betId: String) async throws -> ResolutionClaimActionResponse {
        return try await api.postEmpty("/bets/\(betId)/confirm-resolution")
    }

    struct DisputeResolutionRequest: Encodable {
        let notes: String?
    }

    func disputeResolutionClaim(betId: String, notes: String? = nil) async throws -> ResolutionClaimActionResponse {
        return try await api.post(
            "/bets/\(betId)/dispute-resolution",
            body: DisputeResolutionRequest(notes: notes)
        )
    }

    // MARK: - Get Resolution

    func getResolution(betId: String) async throws -> ResolutionResponse {
        return try await api.get("/bets/\(betId)/resolution")
    }
}
