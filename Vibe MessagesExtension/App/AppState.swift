//
//  AppState.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import Foundation
import Messages
import SwiftUI
import Combine
import Contacts
import CryptoKit

enum PresentationMode {
    case compact
    case expanded
}

enum NavigationDestination: Equatable {
    case feed
    case viewer(startIndex: Int)
    case composer
    case unlockComposer  // Special composer mode for unlock flow
    case profile
    case auraHub
    case betDetail
    case betList
    case teaGuess
    case teaReveal
    case networkSettings
}

enum DashboardTab: Int, CaseIterable {
    case feed, tea, board, me
}

enum BetStatusFilter: String, CaseIterable {
    case all, active, pending, completed, expired, ducked
}

/// Parameters for a locked message that was tapped
struct LockedMessageParams: Equatable {
    let vibeId: String
    let senderName: String
    let videoUrl: String?
    let userId: String?
}

@MainActor
class AppState: ObservableObject {
    private let auraBalanceStorageKey = "vibeAuraBalance"
    private let seenTeamTutorialIdsStorageKey = "vibeSeenTeamTutorialIds"
    private var seenTeamTutorialVibeIds: Set<String> = []
    // MARK: - Conversation Context
    @Published var conversationId: String?
    @Published var userId: String
    @Published var isAuthenticated: Bool = false
    @Published var presentationMode: PresentationMode = .compact
    
    // MARK: - Onboarding & Permissions
    @Published var isOnboardingCompleted: Bool = false
    @Published var isBirthdayCollected: Bool = false
    @Published var hasRequiredPermissions: Bool = false
    @Published var userFirstName: String?
    @Published var userProfilePictureURL: String?

    // MARK: - Navigation
    @Published var currentDestination: NavigationDestination = .feed

    // MARK: - Data
    @Published var vibes: [Vibe] = []
    @Published var reminders: [Reminder] = []
    @Published var streak: Streak?
    @Published var isLoading = false
    @Published var error: String?
    
    // News Data (Moved from BentoDashboardView)
    @Published var newsItems: [NewsItem] = []
    @Published var isLoadingNews = false

    // MARK: - Aura Economy
    @Published var auraBalance: Int = 0
    @Published var vibeScore: Int = 100
    @Published var auraStats: AuraStats?
    @Published var auraTransactions: [AuraTransaction] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var isLoadingLeaderboard = false
    @Published var leaderboardErrorMessage: String?

    // MARK: - Betting
    @Published var activeBets: [Bet] = [] // current-chat (compact)
    @Published var expandedBets: [Bet] = [] // all-chats (expanded feed)
    @Published var betTotalsById: [String: BetTotals] = [:]
    @Published var betCanStakeById: [String: Bool] = [:]
    @Published var isLoadingBets = false

    // MARK: - Tea Spills
    @Published var activeTeaSpills: [TeaSpill] = [] // current-chat (compact)
    @Published var expandedTeaSpills: [TeaSpill] = [] // all-chats (expanded tea tab)
    @Published var isLoadingTea = false

    // MARK: - Dashboard Tabs
    @Published var activeTab: DashboardTab = .feed
    @Published var showCreateSheet = false
    @Published var betFilter: BetStatusFilter = .all

    // MARK: - User Cache & Network
    @Published var userCache: [String: CachedUser] = [:]
    @Published var audienceGraph: AudienceGraph?
    @Published var networkUsers: [NetworkUser] = []
    @Published var contactDiscoveryEnabled: Bool = false
    @Published var betSourceById: [String: String] = [:]

    var filteredBets: [Bet] {
        let source = expandedBets
        switch betFilter {
        case .all: return source
        case .active: return source.filter { displayStatus(for: $0) == .active }
        case .pending: return source.filter { displayStatus(for: $0) == .pendingResolution }
        case .completed: return source.filter { displayStatus(for: $0) == .completed }
        case .expired: return source.filter { displayStatus(for: $0) == .expired }
        case .ducked: return source.filter { displayStatus(for: $0) == .ducked }
        }
    }

    private func displayStatus(for bet: Bet) -> BetStatus {
        if bet.status == .active && bet.isExpired {
            return .expired
        }
        return bet.status
    }

    private func shouldAppearInCompactBetRail(_ bet: Bet) -> Bool {
        bet.lifecycleStatus == .active || bet.lifecycleStatus == .pending || bet.lifecycleStatus == .resolving
    }

    // MARK: - Detail View State
    @Published var selectedBet: Bet?
    @Published var selectedTea: TeaSpill?
    @Published var teaRevealResponse: TeaRevealResponse?

    // MARK: - Network Error State
    @Published var networkError: VibeError?
    @Published var showNetworkErrorBanner = false
    
    // MARK: - Seen Tracking (for "X New Updates" feature)
    @Published var seenVibeIds: Set<String> = []
    
    /// Number of vibes that haven't been seen yet (for badge display)
    var newVibesCount: Int {
        let activeRealVibes = vibes.filter { !seenVibeIds.contains($0.id) && $0.userId != userId && $0.userId != "vibe_team" }
        return activeRealVibes.count
    }
    
    /// A 4-slide tutorial pack from the creators that appears as one story bubble.
    var teamTutorialVibes: [Vibe] {
        let chatId = currentChatId ?? "global"
        let legacyConversationId = conversationId ?? "global"
        let tutorialBetId = bestJoinableBet()?.betId
            ?? activeBets.first?.betId
            ?? expandedBets.first?.betId
        let slides: [(id: String, text: String, image: String, type: VibeType, parlay: Parlay?, styleName: String?)] = [
            (
                id: "team_welcome",
                text: "Welcome to Vibes, where you and your chats can have fun.",
                image: "https://images.pexels.com/photos/1674752/pexels-photo-1674752.jpeg?auto=compress&cs=tinysrgb&w=1080&h=1920&fit=crop",
                type: .photo,
                parlay: nil,
                styleName: nil
            ),
            (
                id: "team_tutorial_2",
                text: "Start challenges, callouts, dares, or drop some tea.",
                image: "https://images.pexels.com/photos/1763075/pexels-photo-1763075.jpeg?auto=compress&cs=tinysrgb&w=1080&h=1920&fit=crop",
                type: .photo,
                parlay: nil,
                styleName: nil
            ),
            (
                id: "team_tutorial_3",
                text: "First challenge is on us: share Vibes with friends for more Aura.",
                image: "https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg?auto=compress&cs=tinysrgb&w=1080&h=1920&fit=crop",
                type: .parlay,
                parlay: Parlay(
                    title: "Share Vibes with 2 friends today",
                    question: nil,
                    options: nil,
                    betId: tutorialBetId,
                    amount: "50 Aura",
                    wager: nil,
                    opponentId: nil,
                    opponentName: "Your chat",
                    status: .accepted,
                    expiresAt: nil,
                    votes: nil,
                    winnersReceived: nil
                ),
                styleName: nil
            ),
            (
                id: "team_tutorial_4",
                text: "First tea is on us: our founder is bald.",
                image: "https://images.pexels.com/photos/302899/pexels-photo-302899.jpeg?auto=compress&cs=tinysrgb&w=1080&h=1920&fit=crop",
                type: .tea,
                parlay: nil,
                styleName: "Fire"
            )
        ]

        return slides.enumerated().map { index, slide in
            let createdAt = Date(timeIntervalSince1970: Double(index + 1))
            let viewedBy = seenTeamTutorialVibeIds.contains(slide.id) ? [userId] : []
            return Vibe(
                id: slide.id,
                oderId: nil,
                userId: "vibe_team",
                chatId: chatId,
                conversationId: legacyConversationId,
                type: slide.type,
                mediaUrl: slide.type == .parlay ? nil : slide.image,
                thumbnailUrl: slide.image,
                songData: nil,
                batteryLevel: nil,
                mood: nil,
                poll: nil,
                parlay: slide.parlay,
                textStatus: slide.text,
                styleName: slide.styleName,
                etaStatus: nil,
                isLocked: false,
                unlockedBy: [],
                reactions: [],
                viewedBy: viewedBy,
                expiresAt: Date.distantFuture,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        }
    }

    var teamWelcomeVibe: Vibe {
        teamTutorialVibes[0]
    }

    private var teamTutorialVibeIds: Set<String> {
        Set(teamTutorialVibes.map(\.id))
    }

    // MARK: - Composer State
    @Published var selectedVibeType: VibeType?
    @Published var composerIsLocked: Bool = false
    @Published var isComposerPresented = false
    @Published var shouldShowVibePicker = false

    // MARK: - Viewer State
    @Published var viewerVibes: [Vibe] = []
    @Published var currentViewerIndex = 0
    @Published var pendingViewerVibeId: String?

    // MARK: - Unlock Flow State
    @Published var showUnlockPrompt = false
    @Published var lockedMessageParams: LockedMessageParams?
    @Published var pendingUnlockVibeId: String?

    // MARK: - Pending Deep Link (saved when tapping a bubble before auth)
    @Published var pendingDeepLinkBetId: String?
    @Published var pendingDeepLinkVibeId: String?
    @Published var pendingDeepLinkChatId: String?
    @Published var pendingDeepLinkIsLocked: Bool = false
    @Published var pendingDeepLinkSenderName: String?
    @Published var pendingDeepLinkSenderId: String?

    // MARK: - Callbacks
    var requestPresentationStyle: ((MSMessagesAppPresentationStyle) -> Void)?
    var sendStory: ((_ vibeId: String, _ mediaUrl: String, _ isLocked: Bool, _ rawThumbnail: UIImage?, _ vibeType: VibeType, _ contextText: String?, _ linkedBetId: String?) -> Void)?
    var onUnlockComplete: (() -> Void)?
    
    // MARK: - Usage Analytics (for Dynamic Dashboard)
    var topUserVibeTypes: [VibeType] {
        let userVibes = vibes.filter { $0.userId == userId }
        var counts: [VibeType: Int] = [:]
        
        for vibe in userVibes {
            // photo/video are handled by "Post Vibe"
            // dailyDrop is handled by its own card
            if vibe.type != .photo && vibe.type != .video && vibe.type != .dailyDrop {
                counts[vibe.type, default: 0] += 1
            }
        }
        
        // Sort by count descending
        let sorted = counts.sorted { $0.value > $1.value }.map { $0.key }
        
        var results: [VibeType] = Array(sorted.prefix(2))
        
        // Fallback defaults if user hasn't used enough types
        // Default 1: POV (Video + Locked) - we represent it as .video here
        // Default 2: Battery
        let fallbacks: [VibeType] = [.video, .battery]
        
        for fallback in fallbacks {
            if results.count < 2 && !results.contains(fallback) {
                results.append(fallback)
            }
        }
        
        // Ensure we always have exactly 2
        while results.count < 2 {
            if results.count == 0 {
                results = [.video, .battery]
            } else if results.count == 1 {
                results.append(results[0] == .video ? .battery : .video)
            }
        }
        
        return results
    }


    init() {
        // Reset onboarding if launched with -resetOnboarding argument (useful for testing)
        if ProcessInfo.processInfo.arguments.contains("-resetOnboarding") {
            UserDefaults.standard.removeObject(forKey: "vibeOnboardingCompleted")
            UserDefaults.standard.removeObject(forKey: "vibeBirthdayCollected")
            UserDefaults.standard.removeObject(forKey: "vibeUserFirstName")
            UserDefaults.standard.removeObject(forKey: "vibePermissionsGranted")
            UserDefaults.standard.removeObject(forKey: "vibeUserId")
            UserDefaults.standard.removeObject(forKey: "vibeAuthToken")
            UserDefaults.standard.removeObject(forKey: "vibeUserProfilePicture")
            UserDefaults.standard.removeObject(forKey: "vibeAuraBalance")
            UserDefaults.standard.removeObject(forKey: seenTeamTutorialIdsStorageKey)
            print("AppState: Reset onboarding state via launch argument")
            
            // Force reset of Published properties
            self.isOnboardingCompleted = false
            self.isBirthdayCollected = false
            self.userFirstName = nil
            self.hasRequiredPermissions = false
            self.userId = "anonymous"
            self.isAuthenticated = false
            return
        }

        // Load onboarding state
        self.isOnboardingCompleted = UserDefaults.standard.bool(forKey: "vibeOnboardingCompleted")
        self.isBirthdayCollected = UserDefaults.standard.bool(forKey: "vibeBirthdayCollected")
        let storedFirstName = UserDefaults.standard.string(forKey: "vibeUserFirstName")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedStoredFirstName = storedFirstName?.lowercased()
        if let storedFirstName,
           !storedFirstName.isEmpty,
           normalizedStoredFirstName != "user",
           normalizedStoredFirstName != "vibe user",
           normalizedStoredFirstName != "unknown",
           normalizedStoredFirstName != "unknown user",
           normalizedStoredFirstName != "anonymous",
           normalizedStoredFirstName != "anon" {
            self.userFirstName = storedFirstName
        } else {
            self.userFirstName = nil
        }
        self.userProfilePictureURL = UserDefaults.standard.string(forKey: "vibeUserProfilePicture")
        self.auraBalance = max(0, UserDefaults.standard.integer(forKey: auraBalanceStorageKey))
        self.hasRequiredPermissions = UserDefaults.standard.bool(forKey: "vibePermissionsGranted")
        if let storedTutorialIds = UserDefaults.standard.array(forKey: seenTeamTutorialIdsStorageKey) as? [String] {
            self.seenTeamTutorialVibeIds = Set(storedTutorialIds)
        }

        // Check for existing session.
        // Require both user id and token to avoid "authenticated but no token" state.
        if
            let storedUserId = UserDefaults.standard.string(forKey: "vibeUserId"),
            let storedToken = UserDefaults.standard.string(forKey: "vibeAuthToken"),
            !storedToken.isEmpty
        {
            self.userId = storedUserId
            self.isAuthenticated = true
        } else {
            self.userId = "anonymous"
            self.isAuthenticated = false
        }
    }

    private func updateAuraBalance(_ value: Int) {
        let safe = max(0, value)
        auraBalance = safe
        UserDefaults.standard.set(safe, forKey: auraBalanceStorageKey)
    }

    private func normalizedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func isPlaceholderFirstName(_ value: String?) -> Bool {
        guard let normalized = normalizedNonEmpty(value)?.lowercased() else { return true }
        return normalized == "user"
            || normalized == "vibe user"
            || normalized == "unknown"
            || normalized == "unknown user"
            || normalized == "anonymous"
            || normalized == "anon"
    }

    private func resolvedFirstName(firstName: String?, email: String?) -> String? {
        if let firstName = normalizedNonEmpty(firstName), !isPlaceholderFirstName(firstName) {
            return firstName
        }

        guard
            let email = normalizedNonEmpty(email),
            let localPart = email.split(separator: "@").first
        else {
            return nil
        }

        let cleaned = localPart
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return nil }
        return cleaned.capitalized
    }

    // MARK: - Conversation Handling

    /// The current virtual chat ID (from our distributed ID system)
    @Published var currentChatId: String?

    /// Task that resolves the real (non-fallback) chat ID in the background.
    /// Can be awaited by write operations to ensure they never send a fallback ID.
    private var chatIdResolutionTask: Task<String, Error>?

    /// Reference to the current MSConversation for message packing
    var currentConversation: MSConversation?

    private func makeChatIdResolutionTask(
        for conversation: MSConversation,
        refreshDataOnLateResolution: Bool
    ) -> Task<String, Error> {
        Task {
            let timeouts: [Double] = [3, 20, 45]

            for (index, timeout) in timeouts.enumerated() {
                let resolvedChatId = await withTimeout(seconds: timeout) {
                    await ConversationManager.shared.resolveChatID(
                        conversation: conversation,
                        userId: self.userId
                    )
                }

                if let chatId = resolvedChatId, !chatId.hasPrefix("fallback_") {
                    let wasDifferent = self.currentChatId != chatId
                    self.currentChatId = chatId

                    if index == 0 {
                        print("AppState Debug: Resolved Chat ID to: \(chatId)")
                    } else {
                        print("AppState Debug: Resolved Chat ID on retry attempt \(index + 1): \(chatId)")
                    }

                    if refreshDataOnLateResolution && wasDifferent && index > 0 {
                        async let reminders: () = loadReminders()
                        async let bets: () = loadBets()
                        async let tea: () = loadTeaSpills()
                        _ = await (reminders, bets, tea)
                    }

                    return chatId
                }

                if let lastResolutionError = ConversationManager.shared.lastResolutionError,
                   let apiError = lastResolutionError as? APIError {
                    switch apiError {
                    case .httpError(let statusCode, let message):
                        if statusCode == 401 || statusCode == 403 {
                            let fallbackMessage = statusCode == 401
                                ? "Your session expired. Please sign in again."
                                : "You don't have access to this chat."
                            throw APIError.httpError(statusCode: statusCode, message: message ?? fallbackMessage)
                        }

                        // 4xx failures are deterministic and won't recover on retry.
                        if (400...499).contains(statusCode) {
                            throw APIError.httpError(
                                statusCode: statusCode,
                                message: message ?? "Couldn't connect this chat. Please retry."
                            )
                        }
                    case .invalidURL, .invalidResponse, .decodingError:
                        throw apiError
                    case .networkError, .uploadFailed:
                        break
                    }
                }

                if Task.isCancelled {
                    throw CancellationError()
                }
                print("AppState Debug: Chat ID resolution attempt \(index + 1) failed, retrying...")
            }

            throw APIError.networkError(
                NSError(
                    domain: "Vibe",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to connect to chat. Please try again."]
                )
            )
        }
    }

    func setConversation(_ conversation: MSConversation?) {
        guard let conversation = conversation else {
            conversationId = nil
            currentChatId = nil
            chatIdResolutionTask?.cancel()
            chatIdResolutionTask = nil
            currentConversation = nil
            return
        }

        chatIdResolutionTask?.cancel()
        currentConversation = conversation

        // Legacy: Use localParticipantIdentifier
        let identifier = conversation.localParticipantIdentifier.uuidString
        if identifier.isEmpty || identifier == "00000000-0000-0000-0000-000000000000" {
            print("AppState Warning: Received invalid localParticipantIdentifier")
        }
        conversationId = identifier
        print("AppState Debug: Set Conversation ID to: \(conversationId ?? "nil")")

        // Use a fallback chat ID immediately so the UI can render right away.
        // The real chat ID will be resolved in the background.
        let fallbackChatId = "fallback_\(conversation.localParticipantIdentifier.uuidString)"
        self.currentChatId = fallbackChatId
        self.isLoading = true

        // Show welcome vibe immediately so the user never sees a blank screen
        if vibes.isEmpty {
            vibes = teamTutorialVibes
        }

        // Store the resolution task so write operations (createBet, createTeaSpill, createVibe)
        // can await the real chat ID instead of sending a fallback ID.
        if isAuthenticated && userId != "anonymous" {
            chatIdResolutionTask = makeChatIdResolutionTask(
                for: conversation,
                refreshDataOnLateResolution: true
            )
        } else {
            chatIdResolutionTask = nil
            print("AppState Debug: Skipping chat resolution until authenticated")
        }

        // Load all data IN PARALLEL — don't block on chat ID resolution for reads
        Task {
            async let vibesTask: () = loadVibes()
            async let remindersTask: () = loadReminders()
            async let newsTask: () = loadNews()
            async let auraTask: () = loadAuraStats()
            async let profileTask: () = loadCurrentUserProfile()
            async let betsTask: () = loadBets()
            async let teaTask: () = loadTeaSpills()

            _ = await (vibesTask, remindersTask, newsTask, auraTask, profileTask, betsTask, teaTask)

            self.isLoading = false
        }
    }

    /// Helper to add timeout to async operations
    private func withTimeout<T>(seconds: Double, operation: @escaping () async -> T) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask {
                await operation()
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }

            // Return first completed result
            if let result = await group.next() {
                group.cancelAll()
                return result
            }
            return nil
        }
    }

    /// Awaits the real (non-fallback) chat ID. Throws if resolution fails or no conversation is set.
    func awaitResolvedChatId() async throws -> String {
        // Fast path: already resolved
        if let chatId = currentChatId, !chatId.hasPrefix("fallback_") {
            return chatId
        }
        guard isAuthenticated else {
            throw APIError.httpError(statusCode: 401, message: "Please sign in to continue.")
        }
        // If conversation became available after auth, lazily bootstrap resolution.
        if chatIdResolutionTask == nil,
           let conversation = currentConversation,
           isAuthenticated,
           userId != "anonymous" {
            chatIdResolutionTask = makeChatIdResolutionTask(
                for: conversation,
                refreshDataOnLateResolution: false
            )
        }

        guard let task = chatIdResolutionTask else {
            throw APIError.networkError(
                NSError(
                    domain: "Vibe",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Chat is still initializing. Please try again."]
                )
            )
        }

        do {
            return try await task.value
        } catch {
            guard let conversation = currentConversation, isAuthenticated, userId != "anonymous" else {
                throw error
            }

            // A failed resolution task should not permanently block write operations.
            print("AppState Debug: Chat ID resolution failed, retrying on demand: \(error)")
            chatIdResolutionTask?.cancel()
            let retryTask = makeChatIdResolutionTask(
                for: conversation,
                refreshDataOnLateResolution: false
            )
            chatIdResolutionTask = retryTask
            return try await retryTask.value
        }
    }

    private func resolvedChatIdForRead() async -> String? {
        if let chatId = currentChatId, !chatId.hasPrefix("fallback_") {
            return chatId
        }
        return try? await awaitResolvedChatId()
    }

    func setPresentationStyle(_ style: MSMessagesAppPresentationStyle) {
        presentationMode = style == .expanded ? .expanded : .compact
    }

    func requestExpand() {
        requestPresentationStyle?(.expanded)
    }

    func requestCompact() {
        requestPresentationStyle?(.compact)
    }

    // MARK: - Chat Access

    func hasAccessToChat(_ chatId: String) async -> Bool? {
        let trimmed = chatId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isAuthenticated, !trimmed.isEmpty else { return false }

        struct UserChatsResponse: Decodable {
            let chats: [ChatSummary]
        }

        struct ChatSummary: Decodable {
            let id: String

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                if let mongoId = try container.decodeIfPresent(String.self, forKey: .mongoId), !mongoId.isEmpty {
                    id = mongoId
                    return
                }
                if let chatId = try container.decodeIfPresent(String.self, forKey: .chatId), !chatId.isEmpty {
                    id = chatId
                    return
                }
                throw DecodingError.dataCorruptedError(
                    forKey: .mongoId,
                    in: container,
                    debugDescription: "Missing chat id"
                )
            }

            enum CodingKeys: String, CodingKey {
                case mongoId = "_id"
                case chatId
            }
        }

        do {
            let response: UserChatsResponse = try await APIClient.shared.get("/chat/user/\(userId)/chats")
            return response.chats.contains { $0.id == trimmed }
        } catch let apiError as APIError {
            print("AppState Error: Checking chat access failed: \(apiError)")
            if case .httpError(let statusCode, _) = apiError, statusCode == 403 || statusCode == 404 {
                return false
            }
            return nil
        } catch {
            print("AppState Error: Checking chat access failed: \(error)")
            return nil
        }
    }

    func requestJoinChallengeChat(chatId: String, betId: String?, reason: String?) async throws -> String {
        struct JoinRequestBody: Encodable {
            let reason: String?
            let betId: String?
        }

        struct JoinRequestResponse: Decodable {
            let success: Bool?
            let message: String?
        }

        let payload = JoinRequestBody(
            reason: reason?.trimmingCharacters(in: .whitespacesAndNewlines),
            betId: betId
        )

        let response: JoinRequestResponse = try await APIClient.shared.post(
            "/chat/\(chatId)/request",
            body: payload
        )

        return response.message ?? "Join request submitted."
    }

    func syncContactHashes(_ contactHashes: [String], replace: Bool = true, enableDiscovery: Bool = true) async {
        guard isAuthenticated else { return }

        struct SyncContactsRequest: Encodable {
            let contactHashes: [String]
            let replace: Bool
            let enableDiscovery: Bool
        }

        struct SyncContactsResponse: Decodable {
            let processed: Int?
            let matchedUsers: Int?
            let audienceSize: Int?
        }

        let sanitized = Array(Set(contactHashes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }))
            .filter { !$0.isEmpty }

        guard !sanitized.isEmpty else { return }

        do {
            let response: SyncContactsResponse = try await APIClient.shared.post(
                "/feed/contacts/sync",
                body: SyncContactsRequest(
                    contactHashes: sanitized,
                    replace: replace,
                    enableDiscovery: enableDiscovery
                )
            )
            print("AppState Debug: Synced contacts. Processed=\(response.processed ?? 0), Matches=\(response.matchedUsers ?? 0), Audience=\(response.audienceSize ?? 0)")
        } catch {
            print("AppState Error: Contact sync failed: \(error)")
        }
    }

    // MARK: - Data Loading

    /**
     * Loads the unified feed - vibes from ALL chats the user belongs to.
     * This is the new architecture that shows vibes from individual friends
     * and group chats in one feed, sorted by most recent.
     */
    func loadVibes() async {
        guard isAuthenticated else { return }

        error = nil
        networkError = nil
        showNetworkErrorBanner = false

        defer {
            // Guarantee loading state is cleared even if something unexpected happens
            isLoading = false
        }

        do {
            // Use the unified feed endpoint - gets vibes from ALL joined chats
            let response = try await APIService.shared.getUnifiedFeed(userId: userId)

            // Filter out the team vibe if it's in the response (shouldn't be, but just in case)
            var userVibes = response.vibes.filter { $0.id != "team_welcome" }

            // Deduplicate by ID (keep the first occurrence of each unique vibe)
            var seenIds = Set<String>()
            userVibes = userVibes.filter { vibe in
                if seenIds.contains(vibe.id) {
                    return false
                } else {
                    seenIds.insert(vibe.id)
                    return true
                }
            }

            self.vibes = userVibes

            // Handle pending navigation
            if let pendingId = pendingViewerVibeId {
                self.pendingViewerVibeId = nil
                navigateToViewer(opening: pendingId)
            }

            // Load streak for current chat if we have one
            if let chatId = currentChatId {
                self.streak = try? await APIService.shared.fetchStreak(chatId: chatId)
            }

            print("AppState: Loaded \(vibes.count) vibes")
        } catch {
            self.error = error.localizedDescription
            print("AppState Error: Loading vibes failed: \(error)")

            // Show the red retry banner only for genuine connectivity/server-availability issues.
            if shouldShowFeedNetworkBanner(for: error) {
                self.networkError = .networkFailure(underlying: error)
                self.showNetworkErrorBanner = true
            } else {
                self.networkError = nil
                self.showNetworkErrorBanner = false
            }

            // Fallback to tutorial pack if we have no real user content loaded.
            if vibes.isEmpty || vibes.allSatisfy({ $0.userId == "vibe_team" }) {
                vibes = teamTutorialVibes
            }
        }
    }

    private func shouldShowFeedNetworkBanner(for error: Error) -> Bool {
        if error is CancellationError {
            return false
        }

        if let apiError = error as? APIError {
            switch apiError {
            case .networkError(let nested):
                if nested is CancellationError {
                    return false
                }
                if let urlError = nested as? URLError {
                    return isConnectivityURLError(urlError)
                }
                if let nestedAPIError = nested as? APIError {
                    return shouldShowFeedNetworkBanner(for: nestedAPIError)
                }
                return true
            case .httpError(let statusCode, _):
                return statusCode >= 500 || statusCode == 408 || statusCode == 429
            case .invalidURL, .invalidResponse, .decodingError, .uploadFailed:
                return false
            }
        }

        if let urlError = error as? URLError {
            return isConnectivityURLError(urlError)
        }

        return false
    }

    private func isConnectivityURLError(_ urlError: URLError) -> Bool {
        switch urlError.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .timedOut,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed,
             .dataNotAllowed,
             .internationalRoamingOff,
             .secureConnectionFailed:
            return true
        case .cancelled:
            return false
        default:
            return false
        }
    }

    /**
     * Loads the 'Vibe Wire' news feed.
     */
    func loadNews() async {
        guard newsItems.isEmpty else { return }
        isLoadingNews = true
        
        do {
            let items: [NewsItem] = try await APIService.shared.getVibeWire()
            self.newsItems = items
        } catch {
            print("AppState Error: Loading news failed: \(error)")
        }
        
        isLoadingNews = false
    }
    
    /**
     * Wakes up the server early.
     */
    func awakeServer() {
        APIClient.shared.awakeServer()
    }
    
    /**
     * Sharing logic for news
     */
    func shareNewsInChat(_ item: NewsItem) {
        print("AppState Debug: Sharing news in chat: \(item.headline)")
        // Implementation for sharing would go here (e.g., embedding in a message)
    }

    /**
     * Loads vibes for a specific chat only (used for chat-specific views).
     */
    func loadVibesForChat(_ chatId: String) async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            let chatVibes = try await APIService.shared.getChatFeed(chatId: chatId, userId: userId)

            // Filter out the team vibe if it's in the response
            var userVibes = chatVibes.filter { $0.id != "team_welcome" }

            // Deduplicate by ID (keep the first occurrence of each unique vibe)
            var seenIds = Set<String>()
            userVibes = userVibes.filter { vibe in
                if seenIds.contains(vibe.id) {
                    return false
                } else {
                    seenIds.insert(vibe.id)
                    return true
                }
            }

            self.vibes = userVibes
            self.streak = try? await APIService.shared.fetchStreak(chatId: chatId)
        } catch {
            self.error = error.localizedDescription
            print("AppState Error: Loading chat vibes failed: \(error)")

            // Fallback to tutorial pack only if error
            if vibes.isEmpty {
                vibes = teamTutorialVibes
            }
        }
    }

    func refreshVibes() async {
        await loadVibes()
    }

    func retryLoadVibes() {
        Task {
            await loadVibes()
        }
    }

    func dismissNetworkError() {
        showNetworkErrorBanner = false
        networkError = nil
    }

    // MARK: - Reminders

    func loadReminders() async {
        guard let chatId = await resolvedChatIdForRead() else { return }
        do {
            let loaded = try await APIService.shared.getReminders(chatId: chatId)
            self.reminders = loaded
        } catch {
            print("AppState Error: Loading reminders failed: \(error)")
        }
    }

    func createReminder(type: ReminderType, emoji: String, title: String, date: Date) async {
        guard let chatId = await resolvedChatIdForRead() else { return }
        do {
            let reminder = try await APIService.shared.createReminder(
                chatId: chatId, userId: userId, type: type, emoji: emoji, title: title, date: date
            )
            reminders.append(reminder)
            reminders.sort { $0.date < $1.date }
        } catch {
            print("AppState Error: Creating reminder failed: \(error)")
        }
    }

    func deleteReminder(id: String) async {
        do {
            try await APIService.shared.deleteReminder(id: id, userId: userId)
            reminders.removeAll { $0.id == id }
        } catch {
            print("AppState Error: Deleting reminder failed: \(error)")
        }
    }

    // MARK: - Aura Economy

    func loadCurrentUserProfile() async {
        guard isAuthenticated else { return }

        struct UserProfileResponse: Decodable {
            let user: UserData
        }

        struct UserData: Decodable {
            let id: String
            let firstName: String?
            let email: String?
            let profilePicture: String?
            let auraBalance: Int?
            let vibeScore: Int?
            let contactDiscoveryEnabled: Bool?
        }

        do {
            let response: UserProfileResponse = try await APIClient.shared.get("/user/me")

            let firstName = resolvedFirstName(firstName: response.user.firstName, email: response.user.email)
            self.userFirstName = firstName
            UserDefaults.standard.set(firstName, forKey: "vibeUserFirstName")

            self.userProfilePictureURL = response.user.profilePicture
            UserDefaults.standard.set(response.user.profilePicture, forKey: "vibeUserProfilePicture")

            if let auraBalance = response.user.auraBalance {
                updateAuraBalance(auraBalance)
            }
            if let vibeScore = response.user.vibeScore {
                self.vibeScore = vibeScore
            }
            self.contactDiscoveryEnabled = response.user.contactDiscoveryEnabled ?? false
        } catch {
            print("AppState Error: Loading profile failed: \(error)")
        }
    }

    func loadAuraStats() async {
        guard isAuthenticated else { return }
        do {
            let stats = try await AuraService.shared.getStats()
            self.auraStats = stats
            updateAuraBalance(stats.balance)
        } catch {
            print("AppState Error: Loading aura stats failed: \(error)")
        }
    }

    func updateProfilePicture(imageData: Data, fileType: String = "jpg") async throws {
        struct UpdateProfilePictureRequest: Encodable {
            let profilePicture: String
        }

        struct UpdateProfilePictureResponse: Decodable {
            let success: Bool?
            let user: UserData
        }

        struct UserData: Decodable {
            let id: String
            let profilePicture: String?
        }

        let uploadResult = try await VibeService.shared.uploadMediaWithKey(
            data: imageData,
            fileType: fileType,
            folder: "profiles"
        )

        let response: UpdateProfilePictureResponse = try await APIClient.shared.put(
            "/user/profile-picture",
            body: UpdateProfilePictureRequest(profilePicture: uploadResult.url)
        )

        let resolvedURL = response.user.profilePicture ?? uploadResult.url
        self.userProfilePictureURL = resolvedURL
        UserDefaults.standard.set(resolvedURL, forKey: "vibeUserProfilePicture")
    }

    func loadAuraTransactions(limit: Int = 20) async {
        do {
            self.auraTransactions = try await AuraService.shared.getTransactions(limit: limit)
        } catch {
            print("AppState Error: Loading aura transactions failed: \(error)")
        }
    }

    func claimDailyBonus() async -> DailyClaimResponse? {
        do {
            let response = try await AuraService.shared.claimDailyBonus()
            if response.claimed, let newBalance = response.newBalance {
                updateAuraBalance(newBalance)
            }
            return response
        } catch {
            print("AppState Error: Claiming daily bonus failed: \(error)")
            return nil
        }
    }

    func loadLeaderboard(sortBy: String = "auraBalance") async {
        guard isAuthenticated else { return }
        isLoadingLeaderboard = true
        leaderboardErrorMessage = nil
        defer { isLoadingLeaderboard = false }

        do {
            self.leaderboard = try await AuraService.shared.getLeaderboard(sortBy: sortBy)
        } catch {
            self.leaderboardErrorMessage = error.localizedDescription
            print("AppState Error: Loading leaderboard failed: \(error)")
        }
    }

    // MARK: - Betting

    private func cacheDiscoverBetItems(_ items: [DiscoverBetFeedItem]) {
        for item in items {
            betTotalsById[item.bet.betId] = item.totals
            betCanStakeById[item.bet.betId] = item.canBet && item.bet.supportsStaking && !item.bet.isExpired
            betSourceById[item.bet.betId] = item.source
        }
    }

    private func deduplicateBets(_ bets: [Bet]) -> [Bet] {
        var seen = Set<String>()
        return bets.filter { bet in
            if seen.contains(bet.betId) {
                return false
            }
            seen.insert(bet.betId)
            return true
        }
    }

    private func deduplicateTea(_ teas: [TeaSpill]) -> [TeaSpill] {
        var seen = Set<String>()
        return teas.filter { tea in
            if seen.contains(tea.teaId) {
                return false
            }
            seen.insert(tea.teaId)
            return true
        }
    }

    private func hydrateCompactBetMetrics(_ bets: [Bet]) async {
        for bet in bets {
            do {
                let participants = try await BettingService.shared.getParticipants(betId: bet.betId)
                betTotalsById[bet.betId] = participants.totals
            } catch {
                // Keep rendering even if metrics fetch fails for a card
            }

            do {
                let myStake = try await BettingService.shared.getMyStake(betId: bet.betId)
                betCanStakeById[bet.betId] = !myStake.hasStake && bet.supportsStaking && !bet.isExpired
            } catch {
                // Default to enabled for active cards if stake lookup fails
                betCanStakeById[bet.betId] = bet.supportsStaking && !bet.isExpired
            }
        }
    }

    func loadBets() async {
        guard isAuthenticated else { return }
        guard let chatId = await resolvedChatIdForRead() else { return }
        isLoadingBets = true
        defer { isLoadingBets = false }

        do {
            async let active = BettingService.shared.getBetsForChat(chatId: chatId, statusRaw: .active)
            async let pending = BettingService.shared.getBetsForChat(chatId: chatId, statusRaw: .pending)
            async let resolving = BettingService.shared.getBetsForChat(chatId: chatId, statusRaw: .resolving)

            let activeResponse = try await active
            let pendingResponse = try await pending
            let resolvingResponse = try await resolving

            let compactBets = deduplicateBets(
                (activeResponse.bets + pendingResponse.bets + resolvingResponse.bets)
                    .sorted { $0.createdAt > $1.createdAt }
            )

            self.activeBets = compactBets
            await hydrateCompactBetMetrics(compactBets)
        } catch {
            print("AppState Error: Loading bets failed: \(error)")
        }
    }

    func loadExpandedBets() async {
        guard isAuthenticated else { return }
        isLoadingBets = true
        defer { isLoadingBets = false }

        do {
            async let active = BettingService.shared.getDiscoverBets(statusRaw: .active)
            async let pending = BettingService.shared.getDiscoverBets(statusRaw: .pending)
            async let resolving = BettingService.shared.getDiscoverBets(statusRaw: .resolving)
            async let completed = BettingService.shared.getDiscoverBets(statusRaw: .completed)
            async let expired = BettingService.shared.getDiscoverBets(statusRaw: .expired)
            async let ducked = BettingService.shared.getDiscoverBets(statusRaw: .ducked)

            let activeResponse = try await active
            let pendingResponse = try await pending
            let resolvingResponse = try await resolving
            let completedResponse = try await completed
            let expiredResponse = try await expired
            let duckedResponse = try await ducked
            let combinedItems = activeResponse.bets + pendingResponse.bets + resolvingResponse.bets
                + completedResponse.bets + expiredResponse.bets + duckedResponse.bets

            cacheDiscoverBetItems(combinedItems)

            let bets = combinedItems
                .map(\.bet)
                .sorted { $0.createdAt > $1.createdAt }

            self.expandedBets = deduplicateBets(bets)

            // Populate user cache with real names
            let creatorIds = Array(Set(combinedItems.map(\.bet.creatorId)))
            await loadBatchUsers(ids: creatorIds)
        } catch {
            print("AppState Error: Loading expanded bets failed: \(error)")
        }
    }

    func createBet(
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
        let chatId = try await awaitResolvedChatId()
        let bet = try await BettingService.shared.createBet(
            chatId: chatId,
            betType: betType,
            description: description,
            deadline: deadline,
            initialStake: initialStake,
            initialSide: initialSide,
            targetUserId: targetUserId,
            participationThreshold: participationThreshold,
            resolutionType: resolutionType,
            isAnonymous: isAnonymous
        )
        activeBets.insert(bet, at: 0)
        expandedBets.insert(bet, at: 0)
        expandedBets = deduplicateBets(expandedBets)
        betTotalsById[bet.betId] = BetTotals(
            totalYes: initialSide == .yes ? initialStake : 0,
            totalNo: initialSide == .no ? initialStake : 0,
            totalPot: initialStake,
            yesCount: initialSide == .yes ? 1 : 0,
            noCount: initialSide == .no ? 1 : 0
        )
        betCanStakeById[bet.betId] = false
        // Refresh aura after bet creation
        await loadAuraStats()
        return bet
    }

    @discardableResult
    func publishChallengeMessage(
        bet: Bet,
        title: String,
        amount: Int,
        targetUserId: String? = nil
    ) async throws -> Vibe {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayAmount = "\(amount) Aura"
        let targetName = targetUserId.map { nameForUser($0) }

        let parlayRequest = CreateParlayRequest(
            title: trimmedTitle,
            question: nil,
            options: nil,
            betId: bet.betId,
            amount: displayAmount,
            wager: nil,
            opponentId: targetUserId,
            opponentName: targetName
        )

        let challengeVibe = try await createVibe(
            type: .parlay,
            parlay: parlayRequest,
            textStatus: trimmedTitle,
            isLocked: false
        )

        let contextText = buildParlayBubbleContext(
            title: trimmedTitle,
            stakeText: displayAmount,
            targetName: targetName,
            deadline: bet.deadline,
            creatorName: nameForUser(bet.creatorId)
        )
        sendVibeMessage(
            vibeId: challengeVibe.id,
            isLocked: false,
            vibeType: .parlay,
            contextText: contextText,
            linkedBetId: bet.betId
        )

        if let targetUserId,
           targetUserId != userId,
           !targetUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await ensureNetworkConnection(targetUserId: targetUserId, sourceChatId: bet.chatId)
        }

        return challengeVibe
    }

    func placeBetStake(betId: String, side: BetSide, amount: Int) async throws -> BetParticipant {
        let stakeResponse = try await BettingService.shared.placeStake(betId: betId, side: side, amount: amount)
        let participant = stakeResponse.participant
        // Reflect stake deduction immediately in UI, then reconcile from backend.
        let totalDebited = stakeResponse.totalDebited ?? amount
        updateAuraBalance(auraBalance - totalDebited)
        betCanStakeById[betId] = false

        // Send stake notification bubble to the iMessage chat.
        if let bet = expandedBets.first(where: { $0.betId == betId })
            ?? activeBets.first(where: { $0.betId == betId }) {
            sendStakeMessage(bet: bet, side: side)
        }

        async let compactBetsTask: () = loadBets()
        async let expandedBetsTask: () = loadExpandedBets()
        async let auraTask: () = loadAuraStats()
        async let profileTask: () = loadCurrentUserProfile()
        _ = await (compactBetsTask, expandedBetsTask, auraTask, profileTask)
        return participant
    }

    func resolveBet(betId: String, outcome: BetOutcome, notes: String? = nil) async throws {
        let response = try await BettingService.shared.resolveBet(betId: betId, outcome: outcome, notes: notes)

        // Notify the chat that the result was called.
        if let bet = expandedBets.first(where: { $0.betId == betId })
            ?? activeBets.first(where: { $0.betId == betId }) {
            sendResolutionMessage(bet: bet, outcome: outcome)
        }

        await refreshBetResolutionCaches()
        betCanStakeById[betId] = false
        if response.resolution != nil {
            await loadAuraStats()
        }
    }

    @discardableResult
    func claimBetResolution(
        bet: Bet,
        outcome: BetOutcome,
        mediaType: ProofMediaType,
        mediaUrl: String,
        mediaKey: String,
        thumbnailUrl: String? = nil,
        thumbnailKey: String? = nil,
        caption: String? = nil,
        notes: String? = nil
    ) async throws -> ClaimResolutionResponse {
        let response = try await BettingService.shared.claimResolution(
            betId: bet.betId,
            outcome: outcome,
            mediaType: mediaType,
            mediaUrl: mediaUrl,
            mediaKey: mediaKey,
            thumbnailUrl: thumbnailUrl,
            thumbnailKey: thumbnailKey,
            caption: caption,
            notes: notes
        )

        do {
            _ = try await createBetResolutionStory(
                bet: bet,
                mediaType: mediaType,
                mediaUrl: mediaUrl,
                mediaKey: mediaKey,
                thumbnailUrl: thumbnailUrl,
                thumbnailKey: thumbnailKey,
                caption: caption
            )
        } catch {
            // Claim has already succeeded at this point; keep the betting state consistent.
            print("AppState Warning: Resolution claim succeeded but story creation failed: \(error)")
        }

        // Notify the chat that a resolution was claimed.
        sendResolutionMessage(bet: bet, outcome: outcome)

        await refreshBetResolutionCaches()
        betCanStakeById[bet.betId] = false

        if response.resolution != nil {
            await loadAuraStats()
        }

        return response
    }

    @discardableResult
    func createBetResolutionStory(
        bet: Bet,
        mediaType: ProofMediaType,
        mediaUrl: String,
        mediaKey: String,
        thumbnailUrl: String? = nil,
        thumbnailKey: String? = nil,
        caption: String? = nil
    ) async throws -> Vibe {
        let vibeType: VibeType = mediaType == .video ? .video : .photo

        var request = CreateVibeRequest(
            userId: userId,
            chatId: bet.chatId,
            conversationId: conversationId,
            type: vibeType
        )

        request.mediaUrl = mediaUrl
        request.mediaKey = mediaKey
        request.thumbnailUrl = thumbnailUrl
        request.thumbnailKey = thumbnailKey
        request.textStatus = caption
        request.parlay = CreateParlayRequest(
            title: nil,
            question: nil,
            options: nil,
            betId: bet.betId,
            amount: nil,
            wager: nil,
            opponentId: nil,
            opponentName: nil
        )

        let vibe = try await APIService.shared.createVibe(request)
        vibes.removeAll { $0.id == vibe.id }
        vibes.insert(vibe, at: 0)
        return vibe
    }

    func getPendingResolutionClaim(betId: String) async -> ResolutionClaim? {
        do {
            let response = try await BettingService.shared.getResolutionClaim(betId: betId)
            return response.claim
        } catch {
            print("AppState Error: Loading pending resolution claim failed: \(error)")
            return nil
        }
    }

    @discardableResult
    func confirmBetResolutionClaim(betId: String) async throws -> ResolutionClaimActionResponse {
        let response = try await BettingService.shared.confirmResolutionClaim(betId: betId)
        await refreshBetResolutionCaches()
        betCanStakeById[betId] = false
        if response.resolution != nil {
            await loadAuraStats()
        }
        return response
    }

    @discardableResult
    func disputeBetResolutionClaim(betId: String, notes: String? = nil) async throws -> ResolutionClaimActionResponse {
        let response = try await BettingService.shared.disputeResolutionClaim(betId: betId, notes: notes)
        await refreshBetResolutionCaches()
        return response
    }

    @discardableResult
    func voteOnBet(betId: String, vote: BetSide) async throws -> BettingService.ConsensusVoteCounts {
        let response = try await BettingService.shared.voteOnBet(betId: betId, vote: vote)
        await refreshBetResolutionCaches()
        return response
    }

    @discardableResult
    func confirmBetProof(betId: String, proofId: String) async throws -> BettingService.ProofReactionCounts {
        let response = try await BettingService.shared.confirmProof(betId: betId, proofId: proofId)
        await refreshBetResolutionCaches()
        return response
    }

    @discardableResult
    func disputeBetProof(betId: String, proofId: String) async throws -> BettingService.ProofReactionCounts {
        let response = try await BettingService.shared.disputeProof(betId: betId, proofId: proofId)
        await refreshBetResolutionCaches()
        return response
    }

    func quickStake(betId: String, side: BetSide, amount: Int = 25) {
        Task {
            do {
                _ = try await placeBetStake(betId: betId, side: side, amount: amount)
                VibeHaptic.success()
            } catch {
                print("AppState Error: Quick stake failed: \(error)")
            }
        }
    }

    // MARK: - Tea Spills

    func loadTeaSpills() async {
        guard isAuthenticated else { return }
        guard let chatId = await resolvedChatIdForRead() else { return }
        isLoadingTea = true
        defer { isLoadingTea = false }

        do {
            let response = try await TeaSpillService.shared.getTeaSpills(chatId: chatId, status: .active)
            self.activeTeaSpills = response.teas
        } catch {
            print("AppState Error: Loading tea spills failed: \(error)")
        }
    }

    func loadExpandedTeaSpills() async {
        guard isAuthenticated else { return }
        isLoadingTea = true
        defer { isLoadingTea = false }

        do {
            async let active = TeaSpillService.shared.getDiscoverTeaSpills(status: .active)
            async let revealed = TeaSpillService.shared.getDiscoverTeaSpills(status: .revealed)

            let activeResponse = try await active
            let revealedResponse = try await revealed
            let combined = activeResponse.teas + revealedResponse.teas

            self.expandedTeaSpills = deduplicateTea(
                combined.sorted { $0.createdAt > $1.createdAt }
            )
        } catch {
            print("AppState Error: Loading expanded tea spills failed: \(error)")
        }
    }

    func createTeaSpill(mysteryText: String, answer: String, options: [String], deadline: Date) async throws -> TeaSpill {
        let chatId = try await awaitResolvedChatId()
        let tea = try await TeaSpillService.shared.createTeaSpill(
            chatId: chatId,
            mysteryText: mysteryText,
            answer: answer,
            options: options,
            deadline: deadline
        )
        activeTeaSpills.insert(tea, at: 0)
        expandedTeaSpills.insert(tea, at: 0)
        expandedTeaSpills = deduplicateTea(expandedTeaSpills)
        await loadAuraStats()
        return tea
    }

    func guessTeaSpill(teaId: String, guess: String, amount: Int) async throws -> TeaGuess {
        let teaGuess = try await TeaSpillService.shared.guessTeaSpill(teaId: teaId, guess: guess, amount: amount)
        await loadAuraStats()
        return teaGuess
    }

    func revealTeaSpill(teaId: String) async throws -> TeaRevealResponse {
        let response = try await TeaSpillService.shared.revealTeaSpill(teaId: teaId)
        // Move from active to resolved
        activeTeaSpills.removeAll { $0.teaId == teaId }
        if let index = expandedTeaSpills.firstIndex(where: { $0.teaId == teaId }) {
            expandedTeaSpills[index] = response.tea
        }
        await loadAuraStats()
        return response
    }

    // MARK: - Authentication

    func handleAppleSignIn(
        identityToken: String,
        userIdentifier: String?,
        firstName: String?,
        lastName: String?,
        email: String?
    ) async {
        print("Auth Debug: Starting Apple Sign In flow...")
        print("Auth Debug: Identity Token length: \(identityToken.count)")
        
        isLoading = true
        error = nil

        struct AuthRequest: Encodable {
            let identityToken: String
            let userIdentifier: String?
            let firstName: String?
            let lastName: String?
            let email: String?
        }

        struct AuthResponse: Decodable {
            let token: String
            let user: UserData
        }

        struct UserData: Decodable {
            let id: String
            let firstName: String?
            let lastName: String?
            let email: String?
            let profilePicture: String?
            let auraBalance: Int?
            let vibeScore: Int?
        }

        do {
            let requestBody = AuthRequest(
                identityToken: identityToken.trimmingCharacters(in: .whitespacesAndNewlines),
                userIdentifier: userIdentifier,
                firstName: firstName,
                lastName: lastName,
                email: email
            )

            var attempts = 0
            let maxAttempts = 2
            var response: AuthResponse?

            while attempts < maxAttempts {
                do {
                    response = try await APIClient.shared.post("/auth/apple", body: requestBody)
                    break
                } catch let apiError as APIError {
                    attempts += 1
                    if case .httpError(let statusCode, _) = apiError, statusCode == 503, attempts < maxAttempts {
                        try? await Task.sleep(nanoseconds: 700_000_000)
                        continue
                    }
                    throw apiError
                } catch {
                    throw error
                }
            }

            guard let response else {
                throw APIError.invalidResponse
            }

            self.userId = response.user.id
            let resolvedName = resolvedFirstName(
                firstName: response.user.firstName ?? firstName,
                email: response.user.email ?? email
            )
            self.userFirstName = resolvedName
            self.isAuthenticated = true

            if let profilePicture = response.user.profilePicture {
                self.userProfilePictureURL = profilePicture
            }
            if let auraBalance = response.user.auraBalance {
                updateAuraBalance(auraBalance)
            }
            if let vibeScore = response.user.vibeScore {
                self.vibeScore = vibeScore
            }
            
            // Save to UserDefaults for persistence
            UserDefaults.standard.set(self.userId, forKey: "vibeUserId")
            UserDefaults.standard.set(response.token, forKey: "vibeAuthToken")
            UserDefaults.standard.set(resolvedName, forKey: "vibeUserFirstName")
            UserDefaults.standard.set(self.userProfilePictureURL, forKey: "vibeUserProfilePicture")
            
            print("Auth Debug: Successfully authenticated with Apple. UserID: \(self.userId)")

            if let conversation = currentConversation {
                setConversation(conversation)
            }

            // Load aura stats after successful auth
            async let auraTask: () = loadAuraStats()
            async let profileTask: () = loadCurrentUserProfile()
            _ = await (auraTask, profileTask)

            // For returning users who already passed all gates, process deep link now
            if hasRequiredPermissions && isBirthdayCollected {
                if pendingDeepLinkBetId != nil || pendingDeepLinkVibeId != nil {
                    await processPendingDeepLink()
                }
            }

        } catch {
            self.error = "Sign in failed: \(error.localizedDescription)"
            print("Auth Debug: Apple Auth Error: \(error)")
        }

        isLoading = false
    }

    func completeOnboarding() {
        isOnboardingCompleted = true
        UserDefaults.standard.set(true, forKey: "vibeOnboardingCompleted")
    }

    func saveBirthday(month: Int, day: Int) {
        UserDefaults.standard.set(month, forKey: "vibeBirthdayMonth")
        UserDefaults.standard.set(day, forKey: "vibeBirthdayDay")
        UserDefaults.standard.set(true, forKey: "vibeBirthdayCollected")
        isBirthdayCollected = true

        // Fire backend API call
        Task {
            struct BirthdayRequest: Encodable {
                let userId: String
                let month: Int
                let day: Int
            }
            do {
                struct BirthdayResponse: Decodable {}
                let _: BirthdayResponse = try await APIClient.shared.put("/auth/birthday", body: BirthdayRequest(
                    userId: userId, month: month, day: day
                ))
            } catch {
                print("Birthday save error: \(error)")
            }
        }
    }

    func skipBirthday() {
        UserDefaults.standard.set(true, forKey: "vibeBirthdayCollected")
        isBirthdayCollected = true
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: "vibeUserId")
        UserDefaults.standard.removeObject(forKey: "vibeAuthToken")
        UserDefaults.standard.removeObject(forKey: "vibeUserFirstName")
        UserDefaults.standard.removeObject(forKey: "vibeUserProfilePicture")
        UserDefaults.standard.removeObject(forKey: "vibeAuraBalance")

        isAuthenticated = false
        userId = "anonymous"
        userFirstName = nil
        userProfilePictureURL = nil

        // Clear user-bound state to avoid stale UI after logout.
        auraBalance = 0
        vibeScore = 100
        auraStats = nil
        auraTransactions = []
        leaderboard = []
        activeBets = []
        expandedBets = []
        betTotalsById = [:]
        betCanStakeById = [:]
        activeTeaSpills = []
        expandedTeaSpills = []
        selectedBet = nil
        selectedTea = nil
        teaRevealResponse = nil

        navigateToFeed()
    }

    func setPermissionsGranted() {
        hasRequiredPermissions = true
        UserDefaults.standard.set(true, forKey: "vibePermissionsGranted")

        // Process any pending deep link now that all auth gates are complete
        if pendingDeepLinkBetId != nil || pendingDeepLinkVibeId != nil {
            Task {
                await processPendingDeepLink()
            }
        }
    }

    /// Development-only login that authenticates with the backend using a test user.
    /// This creates a real user in the database, allowing full testing of the API.
    /// Run `npm run seed` on the backend first to populate test data.
    func bypassLogin() {
        Task {
            await devLogin()
        }
    }

    @MainActor
    private func devLogin() async {
        isLoading = true
        error = nil

        // Test user ID - must match the seed script
        let testUserId = "test_user_me"

        struct DevLoginRequest: Encodable {
            let userId: String
        }

        struct DevLoginResponse: Decodable {
            let token: String
            let user: UserData
        }

        struct UserData: Decodable {
            let id: String
            let firstName: String?
            let lastName: String?
            let email: String?
            let profilePicture: String?
            let auraBalance: Int?
            let vibeScore: Int?
        }

        do {
            let response: DevLoginResponse = try await APIClient.shared.post(
                "/auth/dev-login",
                body: DevLoginRequest(userId: testUserId)
            )

            self.userId = response.user.id
            let resolvedName = resolvedFirstName(firstName: response.user.firstName, email: response.user.email)
            self.userFirstName = resolvedName
            self.isAuthenticated = true

            if let profilePicture = response.user.profilePicture {
                self.userProfilePictureURL = profilePicture
            }
            if let auraBalance = response.user.auraBalance {
                updateAuraBalance(auraBalance)
            }
            if let vibeScore = response.user.vibeScore {
                self.vibeScore = vibeScore
            }

            // Save to UserDefaults for persistence
            UserDefaults.standard.set(self.userId, forKey: "vibeUserId")
            UserDefaults.standard.set(response.token, forKey: "vibeAuthToken")
            UserDefaults.standard.set(resolvedName, forKey: "vibeUserFirstName")
            UserDefaults.standard.set(self.userProfilePictureURL, forKey: "vibeUserProfilePicture")

            print("Auth Debug: Dev login successful. UserID: \(self.userId)")

            if let conversation = currentConversation {
                setConversation(conversation)
            }

            // Load aura stats after successful auth
            async let auraTask: () = loadAuraStats()
            async let profileTask: () = loadCurrentUserProfile()
            _ = await (auraTask, profileTask)

        } catch {
            self.error = "Dev login failed: \(error.localizedDescription)"
            print("Auth Debug: Dev login error: \(error)")

            // Fallback to old behavior if backend isn't running
            print("Auth Debug: Falling back to local-only dev login")
            self.userId = testUserId
            self.userFirstName = "Test"
            self.userProfilePictureURL = nil
            self.isAuthenticated = true
            UserDefaults.standard.set(self.userId, forKey: "vibeUserId")
            UserDefaults.standard.set(self.userFirstName, forKey: "vibeUserFirstName")
        }

        isLoading = false
    }

    // MARK: - Vibe Actions

    @discardableResult
    func createVibe(type: VibeType, mediaUrl: String? = nil, mediaKey: String? = nil,
                    thumbnailUrl: String? = nil, thumbnailKey: String? = nil,
                    songData: SongData? = nil, batteryLevel: Int? = nil,
                    mood: Mood? = nil, poll: CreatePollRequest? = nil,
                    parlay: CreateParlayRequest? = nil,
                    textStatus: String? = nil, styleName: String? = nil,
                    etaStatus: String? = nil,
                    isLocked: Bool = false) async throws -> Vibe {
        // Await the real (non-fallback) chatId before creating
        let chatId = try await awaitResolvedChatId()

        var request = CreateVibeRequest(
            userId: userId,
            chatId: chatId,
            conversationId: conversationId, // Keep for backwards compatibility
            type: type
        )
        request.mediaUrl = mediaUrl
        request.mediaKey = mediaKey
        request.thumbnailUrl = thumbnailUrl
        request.thumbnailKey = thumbnailKey
        request.songData = songData
        request.batteryLevel = batteryLevel
        request.mood = mood
        request.poll = poll
        request.parlay = parlay
        request.textStatus = textStatus
        request.styleName = styleName
        request.etaStatus = etaStatus
        request.isLocked = isLocked

        let newVibe = try await APIService.shared.createVibe(request)

        // Remove any existing vibe with the same ID (shouldn't happen, but just in case)
        vibes.removeAll { $0.id == newVibe.id }

        // Insert locally for immediate feedback
        // Insert at index 0 now that team vibe is handled dynamically in grouping
        vibes.insert(newVibe, at: 0)
        
        print("AppState: Created Vibe \(newVibe.id) for user \(userId) in chat \(chatId)")

        // Refresh streak
        streak = try? await APIService.shared.fetchStreak(chatId: chatId)

        return newVibe
    }

    /// Sends an iMessage bubble for any vibe type
    func sendVibeMessage(
        vibeId: String,
        mediaUrl: String = "",
        isLocked: Bool,
        thumbnail: UIImage? = nil,
        vibeType: VibeType,
        contextText: String? = nil,
        linkedBetId: String? = nil
    ) {
        guard let sendStory else {
            print("AppState Warning: sendStory callback is not set. Skipping iMessage send for vibe \(vibeId).")
            return
        }

        if Thread.isMainThread {
            sendStory(vibeId, mediaUrl, isLocked, thumbnail, vibeType, contextText, linkedBetId)
        } else {
            Task { @MainActor in
                sendStory(vibeId, mediaUrl, isLocked, thumbnail, vibeType, contextText, linkedBetId)
            }
        }
    }

    /// Encodes a rich challenge payload used to render compelling iMessage bet bubbles.
    func buildParlayBubbleContext(
        title: String,
        stakeText: String? = nil,
        targetName: String? = nil,
        deadline: Date? = nil,
        creatorName: String? = nil
    ) -> String {
        var components = URLComponents()
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "title", value: title.trimmingCharacters(in: .whitespacesAndNewlines))
        ]

        if let stakeText = stakeText?.trimmingCharacters(in: .whitespacesAndNewlines), !stakeText.isEmpty {
            queryItems.append(URLQueryItem(name: "stake", value: stakeText))
        }
        if let targetName = targetName?.trimmingCharacters(in: .whitespacesAndNewlines), !targetName.isEmpty {
            queryItems.append(URLQueryItem(name: "target", value: targetName))
        }
        if let deadline {
            queryItems.append(URLQueryItem(name: "deadline", value: String(Int(deadline.timeIntervalSince1970))))
        }
        if let creatorName = creatorName?.trimmingCharacters(in: .whitespacesAndNewlines), !creatorName.isEmpty {
            queryItems.append(URLQueryItem(name: "creator", value: creatorName))
        }

        components.queryItems = queryItems
        return "parlay_v2?\(components.percentEncodedQuery ?? "")"
    }

    /// Sends a bet as an interactive MSMessage bubble into the current conversation.
    func sendBetMessage(bet: Bet) {
        let creatorName = nameForUser(bet.creatorId)
        sendVibeMessage(
            vibeId: bet.betId,
            isLocked: false,
            vibeType: .parlay,
            contextText: buildParlayBubbleContext(
                title: bet.description,
                deadline: bet.deadline,
                creatorName: creatorName
            ),
            linkedBetId: bet.betId
        )
    }

    /// Sends a stake notification bubble so the chat knows someone locked in.
    func sendStakeMessage(bet: Bet, side: BetSide) {
        let stakerName = userFirstName ?? "Someone"
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "title", value: bet.description.trimmingCharacters(in: .whitespacesAndNewlines)),
            URLQueryItem(name: "staker", value: stakerName),
            URLQueryItem(name: "side", value: side.rawValue),
        ]
        if let deadline = bet.deadline as Date? {
            components.queryItems?.append(URLQueryItem(name: "deadline", value: String(Int(deadline.timeIntervalSince1970))))
        }
        let contextText = "stake_v1?\(components.percentEncodedQuery ?? "")"

        sendVibeMessage(
            vibeId: bet.betId,
            isLocked: false,
            vibeType: .parlay,
            contextText: contextText,
            linkedBetId: bet.betId
        )
    }

    /// Sends a resolution notification bubble so the chat knows a bet result was called.
    func sendResolutionMessage(bet: Bet, outcome: BetOutcome) {
        let callerName = userFirstName ?? "Someone"
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "title", value: bet.description.trimmingCharacters(in: .whitespacesAndNewlines)),
            URLQueryItem(name: "caller", value: callerName),
            URLQueryItem(name: "outcome", value: outcome.rawValue),
        ]
        let contextText = "resolved_v1?\(components.percentEncodedQuery ?? "")"

        sendVibeMessage(
            vibeId: bet.betId,
            isLocked: false,
            vibeType: .parlay,
            contextText: contextText,
            linkedBetId: bet.betId
        )
    }

    func addReaction(to vibe: Vibe, emoji: String) async {
        do {
            let updatedVibe = try await APIService.shared.addReaction(
                vibeId: vibe.id,
                userId: userId,
                emoji: emoji
            )
            updateVibe(updatedVibe)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func markAsViewed(_ vibe: Vibe) async {
        if vibe.userId == "vibe_team" {
            markTeamTutorialAsSeen()
            return
        }

        guard !vibe.hasViewed(userId) else { return }

        do {
            let updatedVibe = try await APIService.shared.markViewed(
                vibeId: vibe.id,
                userId: userId
            )
            updateVibe(updatedVibe)
        } catch {
            print("Error marking as viewed: \(error)")
        }
        
        // Also mark as seen locally (for aggregation badge)
        markVibeAsSeen(vibe.id)
    }

    private func markTeamTutorialAsSeen() {
        let tutorialIds = teamTutorialVibeIds
        let previousCount = seenTeamTutorialVibeIds.count
        seenTeamTutorialVibeIds.formUnion(tutorialIds)

        if seenTeamTutorialVibeIds.count != previousCount {
            UserDefaults.standard.set(Array(seenTeamTutorialVibeIds).sorted(), forKey: seenTeamTutorialIdsStorageKey)
        }

        for tutorialId in tutorialIds {
            seenVibeIds.insert(tutorialId)
        }

        for index in vibes.indices where vibes[index].userId == "vibe_team" {
            if !vibes[index].viewedBy.contains(userId) {
                vibes[index].viewedBy.append(userId)
            }
        }

        for index in viewerVibes.indices where viewerVibes[index].userId == "vibe_team" {
            if !viewerVibes[index].viewedBy.contains(userId) {
                viewerVibes[index].viewedBy.append(userId)
            }
        }
    }
    
    /// Mark a vibe as "seen" locally (for "New Updates" badge tracking)
    func markVibeAsSeen(_ vibeId: String) {
        seenVibeIds.insert(vibeId)
    }
    
    /// Mark all current vibes as seen
    func markAllVibesAsSeen() {
        for vibe in vibes {
            seenVibeIds.insert(vibe.id)
        }
    }

    func vote(on vibe: Vibe, optionId: String) async {
        guard let poll = vibe.poll else {
            self.error = "Poll is unavailable."
            return
        }
        let optionIndex: Int
        if let index = poll.options.firstIndex(where: { $0.id == optionId }) {
            optionIndex = index
        } else if let parsed = Int(optionId), parsed >= 0, parsed < poll.options.count {
            optionIndex = parsed
        } else {
            self.error = "Invalid poll option."
            return
        }

        do {
            let updatedVibe = try await APIService.shared.vote(
                vibeId: vibe.id,
                optionIndex: optionIndex,
                userId: userId
            )
            updateVibe(updatedVibe)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func respondToParlay(on vibe: Vibe, status: ParlayStatus) async {
        do {
            let updatedVibe = try await APIService.shared.respondToParlay(
                vibeId: vibe.id,
                userId: userId,
                status: status.rawValue
            )
            updateVibe(updatedVibe)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func updateVibe(_ vibe: Vibe) {
        if let index = vibes.firstIndex(where: { $0.id == vibe.id }) {
            vibes[index] = vibe
        }
    }

    // MARK: - Navigation

    func navigateToViewer(opening vibeId: String) {
        // If we're currently loading, set this as pending so it opens when ready
        if isLoading && vibes.count <= 1 {
            pendingViewerVibeId = vibeId
            requestExpand()
            return
        }

        // Team tutorial should play as a self-contained 4-slide sequence.
        if teamTutorialVibeIds.contains(vibeId) {
            let tutorialPlaylist = teamTutorialVibes.sorted(by: { $0.createdAt < $1.createdAt })
            self.viewerVibes = tutorialPlaylist
            if let index = tutorialPlaylist.firstIndex(where: { $0.id == vibeId }) {
                currentViewerIndex = index
                currentDestination = .viewer(startIndex: index)
            } else {
                currentViewerIndex = 0
                currentDestination = .viewer(startIndex: 0)
            }
            requestExpand()
            return
        }

        // 1. Prepare Playlist: Group by user, sort oldest to newest per user
        // Filter out expired vibes on client-side to ensure freshness
        var activeVibes = vibes.filter { !$0.isExpired }

        // If no real vibes, show the team tutorial pack.
        if activeVibes.isEmpty {
            activeVibes = teamTutorialVibes
        }

        // Find the user who owns this vibe to prioritize their story
        let priorityUserId = activeVibes.first(where: { $0.id == vibeId })?.userId
        let grouped = vibesGroupedByUser(activeVibes, priorityUserId: priorityUserId)

        // Flatten and sort each group by creation date (Oldest first)
        var playlist: [Vibe] = []
        for userVibes in grouped {
            let sortedUserVibes = userVibes.sorted(by: { $0.createdAt < $1.createdAt })
            playlist.append(contentsOf: sortedUserVibes)
        }
        
        // Tutorial slides are removed from normal story playback.
        playlist.removeAll { teamTutorialVibeIds.contains($0.id) }

        // Deduplicate playlist by ID (keep first occurrence)
        var seenIds = Set<String>()
        playlist = playlist.filter { vibe in
            if seenIds.contains(vibe.id) {
                return false
            } else {
                seenIds.insert(vibe.id)
                return true
            }
        }

        self.viewerVibes = playlist

        // 2. Find index
        if let index = playlist.firstIndex(where: { $0.id == vibeId }) {
            currentViewerIndex = index
            currentDestination = .viewer(startIndex: index)
        } else {
            // If vibeId not found, fallback to first
            currentViewerIndex = 0
            currentDestination = .viewer(startIndex: 0)
        }

        requestExpand()
    }

    func navigateToComposer(type: VibeType? = nil, isLocked: Bool = false) {
        selectedVibeType = type
        composerIsLocked = isLocked
        currentDestination = .composer
        requestExpand()
    }

    func navigateToFeed() {
        currentDestination = .feed
        Task {
            await loadAuraStats()
            await loadCurrentUserProfile()
        }
    }

    func navigateToProfile() {
        currentDestination = .profile
        requestExpand()
    }

    func navigateToAuraHub() {
        currentDestination = .auraHub
        requestExpand()
    }

    func navigateToBetDetail(bet: Bet) {
        selectedBet = bet
        currentDestination = .betDetail
        requestExpand()
    }

    func navigateToBetList() {
        currentDestination = .betList
        requestExpand()
    }

    func resolveBetForStory(_ vibe: Vibe) async -> Bet? {
        let rawBetId = vibe.parlay?.betId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasExplicitBetId = rawBetId?.isEmpty == false

        guard let betId = rawBetId, hasExplicitBetId else {
            if let matched = matchBetForVibe(vibe, in: activeBets + expandedBets) {
                return matched
            }

            // No direct betId on this vibe: open the best available active bet for join/stake flow.
            if let joinable = bestJoinableBet() {
                return joinable
            }

            // Refresh once to improve first-time reliability in viewer entry points.
            await refreshBetResolutionCaches()

            if let matched = matchBetForVibe(vibe, in: activeBets + expandedBets) {
                return matched
            }

            if let joinable = bestJoinableBet() {
                return joinable
            }

            return nil
        }

        if let cachedBet = (activeBets + expandedBets).first(where: { $0.betId == betId }) {
            return cachedBet
        }

        do {
            let detail = try await BettingService.shared.getBet(betId: betId)
            let bet = detail.bet

            betTotalsById[bet.betId] = detail.totals
            betCanStakeById[bet.betId] = detail.userStake == nil && bet.supportsStaking && !bet.isExpired

            expandedBets = deduplicateBets([bet] + expandedBets)
            if shouldAppearInCompactBetRail(bet) {
                activeBets = deduplicateBets([bet] + activeBets)
            }

            return bet
        } catch {
            print("AppState Error: Failed to open bet \(betId) from story: \(error)")
            // Stale/missing deep-link IDs should still resolve through local + refreshed matching.
            if let matched = matchBetForVibe(vibe, in: activeBets + expandedBets) {
                return matched
            }

            if let joinable = bestJoinableBet() {
                return joinable
            }

            await refreshBetResolutionCaches()

            if let refreshedExact = (activeBets + expandedBets).first(where: { $0.betId == betId }) {
                return refreshedExact
            }

            if let matched = matchBetForVibe(vibe, in: activeBets + expandedBets) {
                return matched
            }

            if let joinable = bestJoinableBet() {
                return joinable
            }

            return nil
        }
    }

    private func refreshBetResolutionCaches() async {
        async let compactRefresh: () = loadBets()
        async let expandedRefresh: () = loadExpandedBets()
        _ = await (compactRefresh, expandedRefresh)
    }

    func openBetFromVibe(_ vibe: Vibe) async {
        if let bet = await resolveBetForStory(vibe) {
            navigateToBetDetail(bet: bet)
        } else {
            navigateToBetList()
        }
    }

    func openBetById(_ betId: String) async {
        let trimmed = betId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            navigateToBetList()
            return
        }

        if let cachedBet = (activeBets + expandedBets).first(where: { $0.betId == trimmed }) {
            navigateToBetDetail(bet: cachedBet)
            return
        }

        do {
            let detail = try await BettingService.shared.getBet(betId: trimmed)
            let bet = detail.bet

            betTotalsById[bet.betId] = detail.totals
            betCanStakeById[bet.betId] = detail.userStake == nil && bet.supportsStaking && !bet.isExpired

            expandedBets = deduplicateBets([bet] + expandedBets)
            if shouldAppearInCompactBetRail(bet) {
                activeBets = deduplicateBets([bet] + activeBets)
            }

            navigateToBetDetail(bet: bet)
        } catch {
            print("AppState Error: Failed to open shared bet \(trimmed): \(error)")
            await refreshBetResolutionCaches()

            if let refreshed = (activeBets + expandedBets).first(where: { $0.betId == trimmed }) {
                navigateToBetDetail(bet: refreshed)
            } else {
                navigateToBetList()
            }
        }
    }

    // MARK: - Pending Deep Link Processing

    /// Saves deep link parameters when a bubble is tapped before auth is complete.
    func savePendingDeepLink(
        betId: String?,
        vibeId: String?,
        chatId: String?,
        isLocked: Bool,
        senderName: String?,
        senderId: String?
    ) {
        pendingDeepLinkBetId = betId
        pendingDeepLinkVibeId = vibeId
        pendingDeepLinkChatId = chatId
        pendingDeepLinkIsLocked = isLocked
        pendingDeepLinkSenderName = senderName
        pendingDeepLinkSenderId = senderId
        print("AppState: Saved pending deep link — bet=\(betId ?? "nil"), vibe=\(vibeId ?? "nil"), chat=\(chatId ?? "nil")")
    }

    /// Processes a saved deep link after auth + onboarding completes.
    func processPendingDeepLink() async {
        // Handle pending bet deep link
        if let betId = pendingDeepLinkBetId, !betId.isEmpty {
            let chatId = pendingDeepLinkChatId
            let senderId = pendingDeepLinkSenderId
            clearPendingDeepLink()

            // Resolve chat membership first
            if let chatId = chatId, chatId.hasPrefix("chat_"), let conversation = currentConversation {
                let resolvedSharedChatId = await ConversationManager.shared.resolveSharedChatID(
                    preferredChatId: chatId,
                    conversation: conversation,
                    userId: userId
                )
                let finalChatId = resolvedSharedChatId ?? chatId

                let hasAccess = await hasAccessToChat(finalChatId)
                if hasAccess == false {
                    error = "You don't have access to this chat."
                    navigateToBetList()
                    return
                }
                if hasAccess == nil {
                    error = "Couldn't verify chat access. Check your connection and try again."
                    navigateToBetList()
                    return
                }

                if hasAccess == true {
                    currentChatId = finalChatId
                    if let senderId = senderId, !senderId.isEmpty, senderId != userId {
                        await ensureNetworkConnection(targetUserId: senderId, sourceChatId: finalChatId)
                    }
                }
            }

            await openBetById(betId)
            return
        }

        // Handle pending vibe deep link
        if let vibeId = pendingDeepLinkVibeId, !vibeId.isEmpty {
            let isLocked = pendingDeepLinkIsLocked
            let senderName = pendingDeepLinkSenderName
            let chatId = pendingDeepLinkChatId
            let senderId = pendingDeepLinkSenderId
            clearPendingDeepLink()

            if let chatId = chatId, chatId.hasPrefix("chat_"), let conversation = currentConversation {
                let resolvedSharedChatId = await ConversationManager.shared.resolveSharedChatID(
                    preferredChatId: chatId,
                    conversation: conversation,
                    userId: userId
                )
                let finalChatId = resolvedSharedChatId ?? chatId

                let hasAccess = await hasAccessToChat(finalChatId)
                if hasAccess == true {
                    currentChatId = finalChatId
                    if let senderId = senderId, !senderId.isEmpty, senderId != userId {
                        await ensureNetworkConnection(targetUserId: senderId, sourceChatId: finalChatId)
                    }
                }
            }

            if isLocked {
                let lockedParams = LockedMessageParams(
                    vibeId: vibeId,
                    senderName: senderName ?? "Friend",
                    videoUrl: nil,
                    userId: nil
                )
                handleLockedMessageTap(params: lockedParams)
            } else {
                await loadVibes()
                navigateToViewer(opening: vibeId)
            }
            return
        }

        clearPendingDeepLink()
    }

    private func clearPendingDeepLink() {
        pendingDeepLinkBetId = nil
        pendingDeepLinkVibeId = nil
        pendingDeepLinkChatId = nil
        pendingDeepLinkIsLocked = false
        pendingDeepLinkSenderName = nil
        pendingDeepLinkSenderId = nil
    }

    private func bestJoinableBet() -> Bet? {
        let merged = deduplicateBets(activeBets + expandedBets)
            .sorted { $0.createdAt > $1.createdAt }

        // Prefer active + not expired + user can still stake.
        if let candidate = merged.first(where: { bet in
            bet.supportsStaking
                && !bet.isExpired
                && (betCanStakeById[bet.betId] ?? true)
        }) {
            return candidate
        }

        // Fallback to any stake-open/non-expired bet detail.
        return merged.first(where: { $0.supportsStaking && !$0.isExpired })
    }

    private func matchBetForVibe(_ vibe: Vibe, in candidates: [Bet]) -> Bet? {
        let merged = deduplicateBets(candidates)
        let scoped = merged.filter { $0.supportsStaking && !$0.isExpired }

        let rawQuery = (vibe.parlay?.title ?? vibe.parlay?.question ?? vibe.textStatus ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawQuery.isEmpty else { return nil }

        let query = normalizeMatchText(rawQuery)
        guard !query.isEmpty else { return nil }
        let queryTokens = Set(matchTokens(rawQuery))

        let rankedMatches: [(bet: Bet, score: Int)] = scoped.compactMap { bet in
            let description = normalizeMatchText(bet.description)
            if description.contains(query) || query.contains(description) {
                return (bet: bet, score: 10_000)
            }

            let descriptionTokens = Set(matchTokens(bet.description))
            guard !descriptionTokens.isEmpty && !queryTokens.isEmpty else { return nil }

            let overlap = queryTokens.intersection(descriptionTokens).count
            let minRequired = min(3, max(2, Int(ceil(Double(queryTokens.count) * 0.45))))
            guard overlap >= minRequired else { return nil }

            return (bet: bet, score: overlap)
        }

        return rankedMatches
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.bet.createdAt > rhs.bet.createdAt
                }
                return lhs.score > rhs.score
            }
            .first?.bet
    }

    private func normalizeMatchText(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func matchTokens(_ value: String) -> [String] {
        normalizeMatchText(value)
            .split(separator: " ")
            .map(String.init)
            .map { token in
                switch token {
                case "w", "wth":
                    return "with"
                case "u":
                    return "you"
                default:
                    return token
                }
            }
    }

    func navigateToTeaGuess(tea: TeaSpill) {
        selectedTea = tea
        currentDestination = .teaGuess
        requestExpand()
    }

    func navigateToTeaReveal(tea: TeaSpill, response: TeaRevealResponse) {
        selectedTea = tea
        teaRevealResponse = response
        currentDestination = .teaReveal
        requestExpand()
    }

    func dismissComposer() {
        isComposerPresented = false
        selectedVibeType = nil
        composerIsLocked = false
        currentDestination = .feed
        requestCompact()
    }

    // MARK: - Unlock Flow

    /// Called when a locked message bubble is tapped
    func handleLockedMessageTap(params: LockedMessageParams) {
        lockedMessageParams = params
        pendingUnlockVibeId = params.vibeId
        showUnlockPrompt = true
        requestExpand()
    }

    /// Called when user taps "Open Camera" on unlock prompt
    func startUnlockRecording() {
        showUnlockPrompt = false
        currentDestination = .unlockComposer
    }

    /// Called when user dismisses the unlock prompt
    func dismissUnlockPrompt() {
        showUnlockPrompt = false
        lockedMessageParams = nil
        pendingUnlockVibeId = nil
    }

    /// Called after recording is complete during unlock flow
    func completeUnlockFlow(video: VideoRecording) {
        // In the new flow, we should upload the video first. 
        // For now, to fix the compiler error, I'll use placeholders.
        // The real upload happens in VideoComposerView.swift.
        // If we are here, we might need a separate upload step.
        sendStory?("temp_id", video.url.absoluteString, false, nil, .video, nil, nil)

        // Mark the pending vibe as unlocked locally
        if let vibeId = pendingUnlockVibeId,
           let index = vibes.firstIndex(where: { $0.id == vibeId }) {
            var updatedVibe = vibes[index]
            // Add current user to unlockedBy (local update, server would do this too)
            if !updatedVibe.unlockedBy.contains(userId) {
                updatedVibe.unlockedBy.append(userId)
            }
            vibes[index] = updatedVibe
        }

        // Notify completion
        onUnlockComplete?()

        // Reset state
        pendingUnlockVibeId = nil
        lockedMessageParams = nil
        currentDestination = .feed
    }

    /// Check if we're in unlock flow mode
    var isInUnlockFlow: Bool {
        pendingUnlockVibeId != nil
    }

    // MARK: - Helpers

    func hasUserPostedToday() -> Bool {
        streak?.userPostedToday(userId) ?? false
    }

    /// Story groups shown in feed UIs (compact + expanded).
    /// Team tutorial is always pinned first.
    /// Filters out known seeded/mock identities to avoid confusing "ghost" bubbles.
    func storyGroupsForFeed() -> [[Vibe]] {
        let active = vibes.filter { !$0.isExpired }

        let filtered = active.filter { vibe in
            if vibe.userId == "vibe_team" { return false }
            if vibe.id.hasPrefix("mock_") { return false }
            if let oderId = vibe.oderId, oderId.hasPrefix("mock_") { return false }
            if let chatId = vibe.chatId, isSeededChatId(chatId) { return false }
            if vibe.userId != userId && isSeededUserId(vibe.userId) { return false }
            return true
        }

        let realGroups = vibesGroupedByUser(filtered, includeMe: true, includeTeam: false)
        if realGroups.isEmpty {
            return [teamTutorialVibes]
        }

        return [teamTutorialVibes] + realGroups
    }

    private func isSeededUserId(_ value: String) -> Bool {
        value.hasPrefix("user_friend_")
            || value.hasPrefix("friend_")
            || value == "user_me"
            || value == "user123"
            || value.hasPrefix("mock_")
            || value.hasPrefix("test_user_")
            || value.hasPrefix("seed_")
            || value == "test_user_qa"
    }

    private func isSeededChatId(_ value: String) -> Bool {
        value.hasPrefix("test_chat_")
            || value.hasPrefix("seed_")
    }

    func vibesGroupedByUser(_ customVibes: [Vibe]? = nil, includeMe: Bool = true, includeTeam: Bool = true, priorityUserId: String? = nil) -> [[Vibe]] {
        // Group vibes by userId, maintaining order
        var userOrder: [String] = []
        var grouped: [String: [Vibe]] = [:]
        // Get active vibes
        var sourceList = (customVibes ?? vibes).filter { !$0.isExpired }

        // Filter out Me/Team if requested
        if !includeMe {
            sourceList = sourceList.filter { $0.userId != userId }
        }
        if !includeTeam {
            sourceList = sourceList.filter { $0.userId != "vibe_team" }
        }

        // Deduplicate source list by ID
        var seenIds = Set<String>()
        sourceList = sourceList.filter { vibe in
            if seenIds.contains(vibe.id) {
                return false
            } else {
                seenIds.insert(vibe.id)
                return true
            }
        }

        for vibe in sourceList {
            if grouped[vibe.userId] == nil {
                userOrder.append(vibe.userId)
                grouped[vibe.userId] = []
            }
            grouped[vibe.userId]?.append(vibe)
        }
        
        // If empty and team requested, add the team tutorial pack.
        if userOrder.isEmpty && includeTeam {
            return [teamTutorialVibes]
        }
        
        // If priorityUserId is set, move it to the front of userOrder
        if let priority = priorityUserId, let index = userOrder.firstIndex(of: priority) {
            let user = userOrder.remove(at: index)
            userOrder.insert(user, at: 0)
        }

        return userOrder.compactMap { grouped[$0] }
    }

    // MARK: - Consistent Name Generation
    func nameForUser(_ id: String) -> String {
        if id == userId { return "You" }
        if id == "vibe_team" { return "Vibez" }

        // Check user cache for real names from backend
        if let cached = userCache[id] {
            let cachedName = cached.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !isPlaceholderFirstName(cachedName) {
                return cachedName
            }
        }

        // Consistent Friend Mappings for simulator/mock
        if id.contains("friend_1") || id.contains("friend1") { return "Sarah" }
        if id.contains("friend_2") || id.contains("friend2") { return "Mike" }
        if id.contains("friend_3") || id.contains("friend3") { return "Jess" }
        if id.contains("friend_4") || id.contains("friend4") { return "Alex" }
        if id.contains("friend_5") || id.contains("friend5") { return "Sam" }

        // Deterministic Fallback
        let names = ["Emma", "Liam", "Olivia", "Noah", "Ava", "Ethan", "Sophia", "Mason"]
        let index = abs(id.hashValue) % names.count
        return names[index]
    }

    // MARK: - User Cache & Network

    func loadBatchUsers(ids: [String]) async {
        let uncachedIds = ids.filter { userCache[$0] == nil && $0 != userId && $0 != "vibe_team" }
        guard !uncachedIds.isEmpty else { return }

        let chunks = stride(from: 0, to: uncachedIds.count, by: 100).map {
            Array(uncachedIds[$0..<min($0 + 100, uncachedIds.count)])
        }

        for chunk in chunks {
            do {
                struct BatchRequest: Encodable { let userIds: [String] }
                let response: BatchUserResponse = try await APIClient.shared.post(
                    "/user/batch",
                    body: BatchRequest(userIds: chunk)
                )
                for user in response.users {
                    userCache[user.id] = user
                }
            } catch {
                print("AppState Error: Batch user load failed: \(error)")
            }
        }
    }

    func loadAudienceGraph() async {
        guard isAuthenticated else { return }
        do {
            let graph: AudienceGraph = try await APIClient.shared.get("/feed/audience")
            self.audienceGraph = graph

            await loadBatchUsers(ids: graph.mergedUserIds)

            var result: [NetworkUser] = []
            for uid in graph.groupUserIds {
                if let cached = userCache[uid] {
                    result.append(NetworkUser(id: uid, user: cached, source: "group"))
                }
            }
            for uid in graph.contactUserIds where !graph.groupUserIds.contains(uid) {
                if let cached = userCache[uid] {
                    result.append(NetworkUser(id: uid, user: cached, source: "contact"))
                }
            }
            self.networkUsers = result
        } catch {
            print("AppState Error: Loading audience graph failed: \(error)")
        }
    }

    func ensureNetworkConnection(targetUserId: String, sourceChatId: String, refreshAudience: Bool = true) async {
        guard isAuthenticated else { return }

        let trimmedTargetUserId = targetUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSourceChatId = sourceChatId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedTargetUserId.isEmpty,
            trimmedTargetUserId != userId,
            trimmedSourceChatId.hasPrefix("chat_")
        else {
            return
        }

        if audienceGraph?.groupUserIds.contains(trimmedTargetUserId) == true {
            return
        }

        struct ConnectionRequest: Encodable {
            let targetUserId: String
            let sourceChatId: String
        }

        struct ConnectionResponse: Decodable {
            let success: Bool?
        }

        do {
            let _: ConnectionResponse = try await APIClient.shared.post(
                "/feed/connection",
                body: ConnectionRequest(targetUserId: trimmedTargetUserId, sourceChatId: trimmedSourceChatId)
            )

            if refreshAudience {
                await loadAudienceGraph()
            }
        } catch {
            print("AppState Error: Ensuring network connection failed: \(error)")
        }
    }

    func revokeVisibility(targetUserId: String) async {
        struct RevokeRequest: Encodable { let targetUserId: String }
        struct RevokeResponse: Codable { let success: Bool }
        do {
            let _: RevokeResponse = try await APIClient.shared.post(
                "/feed/visibility/revoke",
                body: RevokeRequest(targetUserId: targetUserId)
            )
            await loadAudienceGraph()
        } catch {
            print("AppState Error: Revoking visibility failed: \(error)")
        }
    }

    func toggleContactDiscovery(enabled: Bool) async {
        struct DiscoveryRequest: Encodable {
            let contactHashes: [String]
            let enableDiscovery: Bool
        }
        struct DiscoveryResponse: Codable {
            let processed: Int?
            let audienceSize: Int?
        }
        do {
            let _: DiscoveryResponse = try await APIClient.shared.post(
                "/feed/contacts/sync",
                body: DiscoveryRequest(contactHashes: [], enableDiscovery: enabled)
            )
            self.contactDiscoveryEnabled = enabled
            await loadAudienceGraph()
        } catch {
            print("AppState Error: Toggling contact discovery failed: \(error)")
        }
    }

    func navigateToNetworkSettings() {
        currentDestination = .networkSettings
        requestExpand()
        Task { await loadAudienceGraph() }
    }

    func syncContactsIfNeeded() async {
        guard isAuthenticated, contactDiscoveryEnabled else { return }

        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var hashes = Set<String>()

        do {
            try store.enumerateContacts(with: request) { contact, stop in
                for emailValue in contact.emailAddresses {
                    let normalized = (emailValue.value as String)
                        .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if !normalized.isEmpty {
                        let digest = SHA256.hash(data: Data("email:\(normalized)".utf8))
                        hashes.insert("e:" + digest.map { String(format: "%02x", $0) }.joined())
                    }
                }
                for phoneValue in contact.phoneNumbers {
                    let trimmed = phoneValue.value.stringValue
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let digits = trimmed.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                    if !digits.isEmpty {
                        let normalized = trimmed.hasPrefix("+") ? "+\(digits)" : digits
                        let digest = SHA256.hash(data: Data("phone:\(normalized)".utf8))
                        hashes.insert("p:" + digest.map { String(format: "%02x", $0) }.joined())
                    }
                }
                if hashes.count >= 5000 { stop.pointee = true }
            }

            guard !hashes.isEmpty else { return }
            await syncContactHashes(Array(hashes), replace: false, enableDiscovery: true)
        } catch {
            print("AppState Error: Background contact re-sync failed: \(error)")
        }
    }
}
