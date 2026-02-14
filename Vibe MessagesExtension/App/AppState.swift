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
}

enum DashboardTab: Int, CaseIterable {
    case feed, tea, board, me
}

enum BetStatusFilter: String, CaseIterable {
    case all, active, completed
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

    var filteredBets: [Bet] {
        let source = expandedBets
        switch betFilter {
        case .all: return source
        case .active: return source.filter { $0.status == .active }
        case .completed: return source.filter { $0.status == .completed }
        }
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
            ?? "seed_bet_active_self"
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
                text: "Share bets, callouts, dares, or even drop the tea.",
                image: "https://images.pexels.com/photos/1763075/pexels-photo-1763075.jpeg?auto=compress&cs=tinysrgb&w=1080&h=1920&fit=crop",
                type: .photo,
                parlay: nil,
                styleName: nil
            ),
            (
                id: "team_tutorial_3",
                text: "First bet is on us: share Vibes with friends for more Aura points.",
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
                viewedBy: [],
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

    // MARK: - Callbacks
    var requestPresentationStyle: ((MSMessagesAppPresentationStyle) -> Void)?
    var sendStory: ((_ vibeId: String, _ mediaUrl: String, _ isLocked: Bool, _ rawThumbnail: UIImage?, _ vibeType: VibeType, _ contextText: String?) -> Void)?
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
        self.userFirstName = UserDefaults.standard.string(forKey: "vibeUserFirstName")
        self.hasRequiredPermissions = UserDefaults.standard.bool(forKey: "vibePermissionsGranted")

        // Check for existing session
        if let storedUserId = UserDefaults.standard.string(forKey: "vibeUserId") {
            self.userId = storedUserId
            self.isAuthenticated = true
        } else {
            // Start unauthenticated
            self.userId = "anonymous"
            self.isAuthenticated = false
        }
    }

    // MARK: - Conversation Handling

    /// The current virtual chat ID (from our distributed ID system)
    @Published var currentChatId: String?

    /// Reference to the current MSConversation for message packing
    var currentConversation: MSConversation?

    func setConversation(_ conversation: MSConversation?) {
        guard let conversation = conversation else {
            conversationId = nil
            currentChatId = nil
            currentConversation = nil
            return
        }

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

        Task {
            // Step 1: Resolve real chat ID with a SHORT timeout (3s).
            // If backend is cold/down, we proceed with fallback and retry later.
            let resolvedChatId = await withTimeout(seconds: 3) {
                await ConversationManager.shared.resolveChatID(
                    conversation: conversation,
                    userId: self.userId
                )
            }

            if let chatId = resolvedChatId {
                self.currentChatId = chatId
                print("AppState Debug: Resolved Chat ID to: \(chatId)")
            } else {
                print("AppState Debug: Chat ID resolution timed out, using fallback: \(fallbackChatId)")
                // Retry resolution in background with longer timeout (won't block UI)
                Task {
                    let retryId = await withTimeout(seconds: 20) {
                        await ConversationManager.shared.resolveChatID(
                            conversation: conversation,
                            userId: self.userId
                        )
                    }
                    if let retryId = retryId {
                        self.currentChatId = retryId
                        print("AppState Debug: Late-resolved Chat ID to: \(retryId)")
                        // Reload chat-specific data with correct ID
                        async let reminders: () = loadReminders()
                        async let bets: () = loadBets()
                        async let tea: () = loadTeaSpills()
                        _ = await (reminders, bets, tea)
                    }
                }
            }

            // Step 2: Load all data IN PARALLEL — don't wait for chat ID retry
            async let vibesTask: () = loadVibes()
            async let remindersTask: () = loadReminders()
            async let newsTask: () = loadNews()
            async let auraTask: () = loadAuraStats()
            async let betsTask: () = loadBets()
            async let teaTask: () = loadTeaSpills()

            _ = await (vibesTask, remindersTask, newsTask, auraTask, betsTask, teaTask)

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

    func setPresentationStyle(_ style: MSMessagesAppPresentationStyle) {
        presentationMode = style == .expanded ? .expanded : .compact
    }

    func requestExpand() {
        requestPresentationStyle?(.expanded)
    }

    func requestCompact() {
        requestPresentationStyle?(.compact)
    }

    // MARK: - Data Loading

    /**
     * Loads the unified feed - vibes from ALL chats the user belongs to.
     * This is the new architecture that shows vibes from individual friends
     * and group chats in one feed, sorted by most recent.
     */
    func loadVibes() async {
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

            // Set network error for banner display with retry capability
            self.networkError = .networkFailure(underlying: error)
            self.showNetworkErrorBanner = true

            // Fallback to tutorial pack if we have no real user content loaded.
            if vibes.isEmpty || vibes.allSatisfy({ $0.userId == "vibe_team" }) {
                vibes = teamTutorialVibes
            }
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
        guard let chatId = currentChatId else { return }
        do {
            let loaded = try await APIService.shared.getReminders(chatId: chatId)
            self.reminders = loaded
        } catch {
            print("AppState Error: Loading reminders failed: \(error)")
        }
    }

    func createReminder(type: ReminderType, emoji: String, title: String, date: Date) async {
        guard let chatId = currentChatId else { return }
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

    func loadAuraStats() async {
        do {
            let stats = try await AuraService.shared.getStats()
            self.auraStats = stats
            self.auraBalance = stats.balance
        } catch {
            print("AppState Error: Loading aura stats failed: \(error)")
        }
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
                self.auraBalance = newBalance
            }
            return response
        } catch {
            print("AppState Error: Claiming daily bonus failed: \(error)")
            return nil
        }
    }

    func loadLeaderboard(sortBy: String = "auraBalance") async {
        do {
            self.leaderboard = try await AuraService.shared.getLeaderboard(sortBy: sortBy)
        } catch {
            print("AppState Error: Loading leaderboard failed: \(error)")
        }
    }

    // MARK: - Betting

    private func cacheDiscoverBetItems(_ items: [DiscoverBetFeedItem]) {
        for item in items {
            betTotalsById[item.bet.betId] = item.totals
            betCanStakeById[item.bet.betId] = item.canBet && item.bet.status == .active
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
                betCanStakeById[bet.betId] = !myStake.hasStake && bet.status == .active && !bet.isExpired
            } catch {
                // Default to enabled for active cards if stake lookup fails
                betCanStakeById[bet.betId] = bet.status == .active && !bet.isExpired
            }
        }
    }

    func loadBets() async {
        guard let chatId = currentChatId else { return }
        isLoadingBets = true
        defer { isLoadingBets = false }

        do {
            let response = try await BettingService.shared.getBetsForChat(chatId: chatId, status: .active)
            self.activeBets = response.bets
            await hydrateCompactBetMetrics(response.bets)
        } catch {
            print("AppState Error: Loading bets failed: \(error)")
        }
    }

    func loadExpandedBets() async {
        isLoadingBets = true
        defer { isLoadingBets = false }

        do {
            async let active = BettingService.shared.getDiscoverBets(status: .active)
            async let completed = BettingService.shared.getDiscoverBets(status: .completed)

            let activeResponse = try await active
            let completedResponse = try await completed
            let combinedItems = activeResponse.bets + completedResponse.bets

            cacheDiscoverBetItems(combinedItems)

            let bets = combinedItems
                .map(\.bet)
                .sorted { $0.createdAt > $1.createdAt }

            self.expandedBets = deduplicateBets(bets)
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
        targetUserId: String? = nil
    ) async throws -> Bet {
        guard let chatId = currentChatId else {
            throw APIError.invalidURL
        }
        let bet = try await BettingService.shared.createBet(
            chatId: chatId,
            betType: betType,
            description: description,
            deadline: deadline,
            initialStake: initialStake,
            initialSide: initialSide,
            targetUserId: targetUserId
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

    func placeBetStake(betId: String, side: BetSide, amount: Int) async throws -> BetParticipant {
        let participant = try await BettingService.shared.placeStake(betId: betId, side: side, amount: amount)
        betCanStakeById[betId] = false
        await loadBets()
        await loadExpandedBets()
        // Refresh aura after staking
        await loadAuraStats()
        return participant
    }

    func resolveBet(betId: String, outcome: BetOutcome, notes: String? = nil) async throws {
        _ = try await BettingService.shared.resolveBet(betId: betId, outcome: outcome, notes: notes)
        // Remove from active bets
        activeBets.removeAll { $0.betId == betId }
        expandedBets.removeAll { $0.betId == betId }
        betCanStakeById[betId] = false
        // Refresh aura after resolution
        await loadAuraStats()
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
        guard let chatId = currentChatId else { return }
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
        guard let chatId = currentChatId else {
            throw APIError.invalidURL
        }
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
            self.userFirstName = response.user.firstName
            self.isAuthenticated = true
            
            // Save to UserDefaults for persistence
            UserDefaults.standard.set(self.userId, forKey: "vibeUserId")
            UserDefaults.standard.set(response.token, forKey: "vibeAuthToken")
            UserDefaults.standard.set(self.userFirstName, forKey: "vibeUserFirstName")
            
            print("Auth Debug: Successfully authenticated with Apple. UserID: \(self.userId)")

            // Load aura stats after successful auth
            await loadAuraStats()
            _ = await claimDailyBonus()

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

        isAuthenticated = false
        userId = "anonymous"
        userFirstName = nil

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
        }

        do {
            let response: DevLoginResponse = try await APIClient.shared.post(
                "/auth/dev-login",
                body: DevLoginRequest(userId: testUserId)
            )

            self.userId = response.user.id
            self.userFirstName = response.user.firstName
            self.isAuthenticated = true

            // Save to UserDefaults for persistence
            UserDefaults.standard.set(self.userId, forKey: "vibeUserId")
            UserDefaults.standard.set(response.token, forKey: "vibeAuthToken")
            UserDefaults.standard.set(self.userFirstName, forKey: "vibeUserFirstName")

            print("Auth Debug: Dev login successful. UserID: \(self.userId)")

            // Load aura stats after successful auth
            await loadAuraStats()
            _ = await claimDailyBonus()

        } catch {
            self.error = "Dev login failed: \(error.localizedDescription)"
            print("Auth Debug: Dev login error: \(error)")

            // Fallback to old behavior if backend isn't running
            print("Auth Debug: Falling back to local-only dev login")
            self.userId = testUserId
            self.userFirstName = "Test"
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
        // Use the virtual chatId from our distributed ID system
        guard let chatId = currentChatId else {
            throw APIError.invalidURL
        }

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
    func sendVibeMessage(vibeId: String, mediaUrl: String = "", isLocked: Bool, thumbnail: UIImage? = nil, vibeType: VibeType, contextText: String? = nil) {
        sendStory?(vibeId, mediaUrl, isLocked, thumbnail, vibeType, contextText)
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
        do {
            let updatedVibe = try await APIService.shared.vote(
                vibeId: vibe.id,
                optionId: optionId,
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
        guard let betId = vibe.parlay?.betId, !betId.isEmpty else {
            if let matched = matchBetForVibe(vibe, in: activeBets + expandedBets) {
                return matched
            }

            // No direct betId on this vibe: open the best available active bet for join/stake flow.
            if let joinable = bestJoinableBet() {
                return joinable
            }

            // Refresh once to improve first-time reliability in viewer entry points.
            async let compactRefresh: () = loadBets()
            async let expandedRefresh: () = loadExpandedBets()
            _ = await (compactRefresh, expandedRefresh)

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
            betCanStakeById[bet.betId] = detail.userStake == nil && bet.status == .active && !bet.isExpired

            expandedBets = deduplicateBets([bet] + expandedBets)
            if bet.status == .active {
                activeBets = deduplicateBets([bet] + activeBets)
            }

            return bet
        } catch {
            print("AppState Error: Failed to open bet \(betId) from story: \(error)")
            // If specific deep-link fails, still try to route user into a joinable bet flow.
            if let joinable = bestJoinableBet() {
                return joinable
            }
            return nil
        }
    }

    func openBetFromVibe(_ vibe: Vibe) async {
        if let bet = await resolveBetForStory(vibe) {
            navigateToBetDetail(bet: bet)
        } else {
            navigateToBetList()
        }
    }

    private func bestJoinableBet() -> Bet? {
        let merged = deduplicateBets(activeBets + expandedBets)
            .sorted { $0.createdAt > $1.createdAt }

        // Prefer active + not expired + user can still stake.
        if let candidate = merged.first(where: { bet in
            bet.status == .active
                && !bet.isExpired
                && (betCanStakeById[bet.betId] ?? true)
        }) {
            return candidate
        }

        // Fallback to any active/non-expired bet detail.
        return merged.first(where: { $0.status == .active && !$0.isExpired })
    }

    private func matchBetForVibe(_ vibe: Vibe, in candidates: [Bet]) -> Bet? {
        let merged = deduplicateBets(candidates)
        let scoped = merged.filter { $0.status == .active && !$0.isExpired }

        let rawQuery = (vibe.parlay?.title ?? vibe.parlay?.question ?? vibe.textStatus ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawQuery.isEmpty else { return nil }

        let query = normalizeMatchText(rawQuery)
        guard !query.isEmpty else { return nil }

        return scoped.first(where: { bet in
            let description = normalizeMatchText(bet.description)
            return description.contains(query) || query.contains(description)
        })
    }

    private func normalizeMatchText(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
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
        sendStory?("temp_id", video.url.absoluteString, false, nil, .video, nil)

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
    /// Filters out known seeded/mock identities to avoid confusing "ghost" bubbles.
    /// Falls back to one team tutorial bubble when no real stories remain.
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

        if filtered.isEmpty {
            return [teamTutorialVibes]
        }

        return vibesGroupedByUser(filtered, includeMe: true, includeTeam: false)
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
}
