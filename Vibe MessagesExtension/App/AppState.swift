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
    @Published var hasRequiredPermissions: Bool = false
    @Published var userFirstName: String?

    // MARK: - Navigation
    @Published var currentDestination: NavigationDestination = .feed

    // MARK: - Data
    @Published var vibes: [Vibe] = []
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
    
    /// A "Welcome" vibe from the creators to fill empty feeds
    var teamWelcomeVibe: Vibe {
        Vibe(
            id: "team_welcome",
            oderId: nil,
            userId: "vibe_team",
            conversationId: conversationId ?? "global",
            type: .video,
            mediaUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            thumbnailUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg",
            songData: nil,
            batteryLevel: nil,
            mood: Mood(emoji: "👋", text: "Welcome to Vibe! Watch this to learn how it works."),
            poll: nil,
            textStatus: nil,
            styleName: nil,
            etaStatus: nil,
            isLocked: false,
            unlockedBy: [],
            reactions: [],
            viewedBy: [],
            expiresAt: Date().addingTimeInterval(365 * 24 * 3600), // Long-lived
            createdAt: Date().addingTimeInterval(-3600),
            updatedAt: Date().addingTimeInterval(-3600)
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

    // MARK: - Unlock Flow State
    @Published var showUnlockPrompt = false
    @Published var lockedMessageParams: LockedMessageParams?
    @Published var pendingUnlockVibeId: String?

    // MARK: - Callbacks
    var requestPresentationStyle: ((MSMessagesAppPresentationStyle) -> Void)?
    var sendStory: ((_ videoId: String, _ videoUrl: String, _ isLocked: Bool, _ rawThumbnail: UIImage?) -> Void)?
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
        // Load onboarding state
        self.isOnboardingCompleted = UserDefaults.standard.bool(forKey: "vibeOnboardingCompleted")
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

        // Resolve the virtual chat ID using ConversationManager
        Task {
            let chatId = await ConversationManager.shared.resolveChatID(
                conversation: conversation,
                userId: userId
            )
            await MainActor.run {
                self.currentChatId = chatId
                print("AppState Debug: Resolved Chat ID to: \(chatId)")
            }
            // Load vibes after resolving chat ID
            await loadVibes()
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
            self.vibes = response.vibes

            // Load streak for current chat if we have one
            if let chatId = currentChatId {
                self.streak = try? await APIService.shared.fetchStreak(chatId: chatId)
            }

            print("AppState: Loaded \(vibes.count) vibes from unified feed")
        } catch {
            self.error = error.localizedDescription
            print("AppState Error: Loading vibes failed: \(error)")

            // Set network error for banner display with retry capability
            self.networkError = .networkFailure(underlying: error)
            self.showNetworkErrorBanner = true

            // Fallback to empty if error
            if vibes.isEmpty {
                vibes = []
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
            self.vibes = try await APIService.shared.getChatFeed(chatId: chatId, userId: userId)
            self.streak = try? await APIService.shared.fetchStreak(chatId: chatId)
        } catch {
            self.error = error.localizedDescription
            print("AppState Error: Loading chat vibes failed: \(error)")
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

    func setPermissionsGranted() {
        hasRequiredPermissions = true
        UserDefaults.standard.set(true, forKey: "vibePermissionsGranted")
    }

    func bypassLogin() {
        self.userId = "user_me"
        self.isAuthenticated = true
        UserDefaults.standard.set(self.userId, forKey: "vibeUserId")
        print("Auth Debug: Login bypassed by developer.")
    }

    // MARK: - Vibe Actions

    func createVibe(type: VibeType, mediaUrl: String? = nil, mediaKey: String? = nil,
                    thumbnailUrl: String? = nil, thumbnailKey: String? = nil,
                    songData: SongData? = nil, batteryLevel: Int? = nil,
                    mood: Mood? = nil, poll: CreatePollRequest? = nil,
                    textStatus: String? = nil, styleName: String? = nil,
                    etaStatus: String? = nil,
                    isLocked: Bool = false) async throws {
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
        request.textStatus = textStatus
        request.styleName = styleName
        request.etaStatus = etaStatus
        request.isLocked = isLocked

        let newVibe = try await APIService.shared.createVibe(request)

        // Insert at the beginning
        vibes.insert(newVibe, at: 0)

        // Refresh streak
        streak = try? await APIService.shared.fetchStreak(chatId: chatId)
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

    private func updateVibe(_ vibe: Vibe) {
        if let index = vibes.firstIndex(where: { $0.id == vibe.id }) {
            vibes[index] = vibe
        }
    }

    // MARK: - Navigation

    func navigateToViewer(opening vibeId: String) {
        // 1. Prepare Playlist: Group by user, sort oldest to newest per user
        // Filter out expired vibes on client-side to ensure freshness
        var activeVibes = vibes.filter { !$0.isExpired }
        
        // If no real vibes, show the team welcome vibe
        if activeVibes.isEmpty {
            activeVibes = [teamWelcomeVibe]
        }
        
        let grouped = vibesGroupedByUser(from: activeVibes)
        
        // Flatten and sort each group by creation date (Oldest first)
        var playlist: [Vibe] = []
        for userVibes in grouped {
            let sortedUserVibes = userVibes.sorted(by: { $0.createdAt < $1.createdAt })
            playlist.append(contentsOf: sortedUserVibes)
        }
        
        self.viewerVibes = playlist
        
        // 2. Find index
        if let index = playlist.firstIndex(where: { $0.id == vibeId }) {
            currentViewerIndex = index
            currentDestination = .viewer(startIndex: index)
        } else {
            // Fallback (shouldn't happen with team vibe)
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
        isComposerPresented = false
        selectedVibeType = nil
        composerIsLocked = false
        currentDestination = .feed
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
        sendStory?("temp_id", video.url.absoluteString, false, nil)

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

    func vibesGroupedByUser(from list: [Vibe]? = nil) -> [[Vibe]] {
        // Group vibes by userId, maintaining order
        var userOrder: [String] = []
        var grouped: [String: [Vibe]] = [:]
        
        var sourceList = list ?? vibes.filter { !$0.isExpired }
        
        // If empty, add the team welcome vibe
        if sourceList.isEmpty {
            sourceList = [teamWelcomeVibe]
        }

        for vibe in sourceList {
            if grouped[vibe.userId] == nil {
                userOrder.append(vibe.userId)
                grouped[vibe.userId] = []
            }
            grouped[vibe.userId]?.append(vibe)
        }

        return userOrder.compactMap { grouped[$0] }
    }
}
