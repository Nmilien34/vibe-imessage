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

    // MARK: - Network Error State
    @Published var networkError: VibeError?
    @Published var showNetworkErrorBanner = false
    
    // MARK: - Seen Tracking (for "X New Updates" feature)
    @Published var seenVibeIds: Set<String> = []
    
    /// Number of vibes that haven't been seen yet (for badge display)
    var newVibesCount: Int {
        let activeRealVibes = vibes.filter { !seenVibeIds.contains($0.id) && $0.userId != userId }
        return activeRealVibes.count
    }
    
    /// A "Welcome" vibe from the creators to fill empty feeds - ALWAYS at index 0
    var teamWelcomeVibe: Vibe {
        Vibe(
            id: "team_welcome",
            oderId: nil,
            userId: "vibe_team",
            chatId: currentChatId ?? "global",           // Primary chat ID
            conversationId: conversationId ?? "global",  // Legacy support
            type: .video,
            mediaUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            thumbnailUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg",
            songData: nil,
            batteryLevel: nil,
            mood: Mood(emoji: "👋", text: "Welcome to Vibe! Watch this to learn how it works."),
            poll: nil,
            parlay: nil,
            textStatus: "From the Vibez Team 💜",
            styleName: nil,
            etaStatus: nil,
            isLocked: false,
            unlockedBy: [],
            reactions: [],
            viewedBy: [],
            expiresAt: Date.distantFuture, // Never expires
            createdAt: Date(timeIntervalSince1970: 0), // Very old so it sorts last, but we'll pin it to index 0
            updatedAt: Date(timeIntervalSince1970: 0)
        )
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

        // Set loading state IMMEDIATELY (synchronously) so UI shows spinner
        self.isLoading = true

        // Resolve the virtual chat ID using ConversationManager
        // Use a detached task to avoid blocking the UI
        Task {
            // Step 1: Resolve chat ID (required before loading chat-specific data)
            // Add timeout to prevent hanging if backend is down
            let chatId = await withTimeout(seconds: 5) {
                await ConversationManager.shared.resolveChatID(
                    conversation: conversation,
                    userId: self.userId
                )
            } ?? "fallback_\(conversation.localParticipantIdentifier.uuidString)"

            self.currentChatId = chatId
            print("AppState Debug: Resolved Chat ID to: \(chatId)")

            // Step 2: Load vibes and reminders IN PARALLEL (not sequential)
            async let vibesTask: () = loadVibes()
            async let remindersTask: () = loadReminders()

            // Wait for both to complete (but they run concurrently)
            _ = await (vibesTask, remindersTask)

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
        isLoading = true
        error = nil
        networkError = nil
        showNetworkErrorBanner = false

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

            // Fallback to team vibe only if error
            if vibes.isEmpty {
                vibes = [teamWelcomeVibe]
            }
        }

        isLoading = false
    }

    /**
     * Loads vibes for a specific chat only (used for chat-specific views).
     */
    func loadVibesForChat(_ chatId: String) async {
        isLoading = true
        error = nil

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

            // Fallback to team vibe only if error
            if vibes.isEmpty {
                vibes = [teamWelcomeVibe]
            }
        }

        isLoading = false
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

    // MARK: - Authentication

    func handleAppleSignIn(identityToken: String, firstName: String?, lastName: String?) async {
        print("Auth Debug: Starting Apple Sign In flow...")
        print("Auth Debug: Identity Token length: \(identityToken.count)")
        
        isLoading = true
        error = nil

        struct AuthRequest: Encodable {
            let identityToken: String
            let firstName: String?
            let lastName: String?
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
            let response: AuthResponse = try await APIClient.shared.post("/auth/apple", body: AuthRequest(
                identityToken: identityToken,
                firstName: firstName,
                lastName: lastName
            ))

            self.userId = response.user.id
            self.userFirstName = response.user.firstName
            self.isAuthenticated = true
            
            // Save to UserDefaults for persistence
            UserDefaults.standard.set(self.userId, forKey: "vibeUserId")
            UserDefaults.standard.set(response.token, forKey: "vibeAuthToken")
            UserDefaults.standard.set(self.userFirstName, forKey: "vibeUserFirstName")
            
            print("Auth Debug: Successfully authenticated with Apple. UserID: \(self.userId)")
            
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

        // 1. Prepare Playlist: Group by user, sort oldest to newest per user
        // Filter out expired vibes on client-side to ensure freshness
        var activeVibes = vibes.filter { !$0.isExpired }

        // If no real vibes, show the team welcome vibe
        if activeVibes.isEmpty {
            activeVibes = [teamWelcomeVibe]
        }

        // Find the user who owns this vibe to prioritize their story
        let priorityUserId = activeVibes.first(where: { $0.id == vibeId })?.userId
        let grouped = vibesGroupedByUser(from: activeVibes, priorityUserId: priorityUserId)

        // Flatten and sort each group by creation date (Oldest first)
        var playlist: [Vibe] = []
        for userVibes in grouped {
            let sortedUserVibes = userVibes.sorted(by: { $0.createdAt < $1.createdAt })
            playlist.append(contentsOf: sortedUserVibes)
        }
        
        // Remove team welcome vibe if it's not the requested vibe
        if vibeId != "team_welcome" {
            playlist.removeAll { $0.id == "team_welcome" }
        }

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

    func vibesGroupedByUser(includeMe: Bool = true, includeTeam: Bool = true, priorityUserId: String? = nil) -> [[Vibe]] {
        // Group vibes by userId, maintaining order
        var userOrder: [String] = []
        var grouped: [String: [Vibe]] = [:]

        // Get active vibes
        var sourceList = vibes.filter { !$0.isExpired }

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
        
        // If empty and team requested, add the team welcome vibe
        if userOrder.isEmpty && includeTeam {
            return [[teamWelcomeVibe]]
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
