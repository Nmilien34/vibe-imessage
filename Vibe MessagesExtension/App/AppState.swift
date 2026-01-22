//
//  AppState.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import Foundation
import Messages
import SwiftUI

enum PresentationMode {
    case compact
    case expanded
}

enum NavigationDestination: Equatable {
    case feed
    case viewer(startIndex: Int)
    case composer
}

@MainActor
class AppState: ObservableObject {
    // MARK: - Conversation Context
    @Published var conversationId: String?
    @Published var userId: String
    @Published var presentationMode: PresentationMode = .compact

    // MARK: - Navigation
    @Published var currentDestination: NavigationDestination = .feed

    // MARK: - Data
    @Published var vibes: [Vibe] = []
    @Published var streak: Streak?
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Composer State
    @Published var selectedVibeType: VibeType?
    @Published var isComposerPresented = false

    // MARK: - Viewer State
    @Published var currentViewerIndex = 0

    // MARK: - Callbacks
    var requestPresentationStyle: ((MSMessagesAppPresentationStyle) -> Void)?

    private let vibeService = VibeService.shared

    init() {
        // Generate a persistent user ID for this device
        if let storedUserId = UserDefaults.standard.string(forKey: "vibeUserId") {
            self.userId = storedUserId
        } else {
            let newUserId = UUID().uuidString
            UserDefaults.standard.set(newUserId, forKey: "vibeUserId")
            self.userId = newUserId
        }
    }

    // MARK: - Conversation Handling

    func setConversation(_ conversation: MSConversation?) {
        guard let conversation = conversation else {
            conversationId = nil
            return
        }

        // Use localParticipantIdentifier as a unique conversation ID
        conversationId = conversation.localParticipantIdentifier.uuidString
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

    func loadVibes() async {
        guard let conversationId = conversationId else {
            error = "No conversation ID"
            return
        }

        isLoading = true
        error = nil

        do {
            vibes = try await vibeService.fetchVibes(conversationId: conversationId)
            streak = try await vibeService.fetchStreak(conversationId: conversationId)
        } catch {
            self.error = error.localizedDescription
            print("Error loading vibes: \(error)")
        }

        isLoading = false
    }

    func refreshVibes() async {
        await loadVibes()
    }

    // MARK: - Vibe Actions

    func createVibe(type: VibeType, mediaUrl: String? = nil, thumbnailUrl: String? = nil,
                    songData: SongData? = nil, batteryLevel: Int? = nil,
                    mood: Mood? = nil, poll: CreatePollRequest? = nil,
                    isLocked: Bool = false) async throws {
        guard let conversationId = conversationId else {
            throw APIError.invalidURL
        }

        var request = CreateVibeRequest(
            userId: userId,
            conversationId: conversationId,
            type: type
        )
        request.mediaUrl = mediaUrl
        request.thumbnailUrl = thumbnailUrl
        request.songData = songData
        request.batteryLevel = batteryLevel
        request.mood = mood
        request.poll = poll
        request.isLocked = isLocked

        let newVibe = try await vibeService.createVibe(request)

        // Insert at the beginning
        vibes.insert(newVibe, at: 0)

        // Refresh streak
        streak = try? await vibeService.fetchStreak(conversationId: conversationId)
    }

    func addReaction(to vibe: Vibe, emoji: String) async {
        do {
            let updatedVibe = try await vibeService.addReaction(
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
            let updatedVibe = try await vibeService.markViewed(
                vibeId: vibe.id,
                userId: userId
            )
            updateVibe(updatedVibe)
        } catch {
            print("Error marking as viewed: \(error)")
        }
    }

    func vote(on vibe: Vibe, optionId: String) async {
        do {
            let updatedVibe = try await vibeService.vote(
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

    func navigateToViewer(startingAt index: Int) {
        currentViewerIndex = index
        currentDestination = .viewer(startIndex: index)
        requestExpand()
    }

    func navigateToComposer(type: VibeType? = nil) {
        selectedVibeType = type
        currentDestination = .composer
        requestExpand()
    }

    func navigateToFeed() {
        currentDestination = .feed
    }

    func dismissComposer() {
        isComposerPresented = false
        selectedVibeType = nil
        currentDestination = .feed
    }

    // MARK: - Helpers

    func hasUserPostedToday() -> Bool {
        streak?.userPostedToday(userId) ?? false
    }

    func vibesGroupedByUser() -> [[Vibe]] {
        // Group vibes by userId, maintaining order
        var userOrder: [String] = []
        var grouped: [String: [Vibe]] = [:]

        for vibe in vibes {
            if grouped[vibe.userId] == nil {
                userOrder.append(vibe.userId)
                grouped[vibe.userId] = []
            }
            grouped[vibe.userId]?.append(vibe)
        }

        return userOrder.compactMap { grouped[$0] }
    }
}
