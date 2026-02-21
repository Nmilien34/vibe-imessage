//
//  MessagesViewController.swift
//  Vibe MessagesExtension
//
//  Created by Nickson Milien on 1/21/26.
//

import UIKit
import Messages
import SwiftUI
import AVFoundation

class MessagesViewController: MSMessagesAppViewController {

    private var appState = AppState()
    private var hostingController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSwiftUI()
        
        // Start waking up the server early
        appState.awakeServer()
    }

    private func setupSwiftUI() {
        // Set up the callback for presentation style changes
        appState.requestPresentationStyle = { [weak self] style in
            self?.requestPresentationStyle(style)
        }
        
        // Callback for sending a story
        appState.sendStory = { [weak self] (vibeId: String, mediaUrl: String, isLocked: Bool, rawThumbnail: UIImage?, vibeType: VibeType, contextText: String?) in
            Task { @MainActor in
                guard let self else { return }
                // Ensure chat_id is resolved before sending (prevents missing chat_id in URL)
                if let chatId = self.appState.currentChatId, chatId.hasPrefix("fallback_") {
                    if let conversation = self.activeConversation ?? self.appState.currentConversation,
                       self.appState.isAuthenticated {
                        let resolved = await ConversationManager.shared.resolveChatID(
                            conversation: conversation,
                            userId: self.appState.userId
                        )
                        if resolved.hasPrefix("chat_") {
                            self.appState.currentChatId = resolved
                        }
                    }
                }
                self.sendStory(vibeId: vibeId, mediaUrl: mediaUrl, isLocked: isLocked, rawThumbnail: rawThumbnail, vibeType: vibeType, contextText: contextText)
            }
        }

        // Callback when unlock flow completes
        appState.onUnlockComplete = { [weak self] in
            // Refresh vibes to show the now-unlocked content
            Task {
                await self?.appState.refreshVibes()
            }
        }

        // Create the SwiftUI view with the app state
        let rootView = RootView()
            .environmentObject(appState)

        // Embed in UIHostingController
        let hosting = UIHostingController(rootView: rootView)
        hosting.view.backgroundColor = .clear
        hostingController = hosting

        // Add as child view controller
        addChild(hosting)
        view.addSubview(hosting.view)

        // Set up constraints - fill entire view so SwiftUI can handle safe areas
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hosting.didMove(toParent: self)
    }

    // MARK: - Conversation Handling

    override func willBecomeActive(with conversation: MSConversation) {
        print("MVC: willBecomeActive — auth=\(appState.isAuthenticated) userId=\(appState.userId) style=\(presentationStyle.rawValue)")
        // Configure app state with the current conversation
        // setConversation will resolve the chat_id via ConversationManager
        // and automatically load vibes from the unified feed
        appState.setConversation(conversation)
        appState.setPresentationStyle(presentationStyle)
    }

    override func didResignActive(with conversation: MSConversation) {
        // Extension is becoming inactive
    }

    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        // Refresh vibes when receiving a new message
        Task {
            await appState.refreshVibes()
        }
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        // Called when user taps on a message bubble
        guard let url = message.url else {
            print("didSelect: No URL in message, ignoring tap")
            return
        }

        // Parse the message URL using ConversationManager
        let parsed = ConversationManager.shared.parseVibeURL(url)

        // Also extract legacy params for backwards compatibility
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("didSelect: Failed to parse URL components from \(url)")
            return
        }

        var params: [String: String] = [:]
        for item in queryItems {
            if let value = item.value {
                params[item.name] = value
            }
        }

        let vibeId = parsed.vibeId ?? params["videoId"] ?? params["vibeId"] ?? params["id"] ?? ""
        let betId = params["bet_id"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let chatId = parsed.chatId ?? params["chat_id"]
        let isLocked = parsed.isLocked || params["locked"] == "true"
        let senderId = params["userId"] ?? ""
        let senderName = parsed.sender ?? params["sender"] ?? "Friend"
        let videoUrl = params["url"]

        print("didSelect: betId=\(betId ?? "nil") vibeId=\(vibeId) chatId=\(chatId ?? "nil") isLocked=\(isLocked) auth=\(appState.isAuthenticated)")

        // If user isn't authenticated, save the deep link for after auth completes
        if !appState.isAuthenticated {
            appState.savePendingDeepLink(
                betId: betId,
                vibeId: vibeId.isEmpty ? nil : vibeId,
                chatId: chatId,
                isLocked: isLocked,
                senderName: senderName
            )
            requestPresentationStyle(.expanded)
            return
        }

        if let betId, !betId.isEmpty {
            requestPresentationStyle(.expanded)
            Task {
                await handleSharedBetTap(betId: betId, chatId: chatId)
            }
            return
        }

        // CRITICAL: Join the chat if we have a chat_id
        // This is how users get added to chats when receiving messages
        if let chatId = chatId, chatId.hasPrefix("chat_") {
            Task {
                let resolvedChatId = await ConversationManager.shared.resolveChatID(
                    conversation: conversation,
                    userId: appState.userId
                )
                // Use backend-resolved id when available; fall back to parsed id.
                await MainActor.run {
                    appState.currentChatId = resolvedChatId.hasPrefix("chat_")
                        ? resolvedChatId
                        : chatId
                }

                // Refresh vibes for the new chat
                await appState.loadVibes()
            }
        }

        // Check if this message is from the current user
        let isOwnMessage = senderId == appState.userId

        if isLocked && !isOwnMessage {
            // Show unlock prompt for locked content from other users
            let lockedParams = LockedMessageParams(
                vibeId: vibeId,
                senderName: senderName,
                videoUrl: videoUrl,
                userId: senderId
            )
            appState.handleLockedMessageTap(params: lockedParams)
        } else {
            // Not locked or own message - show the content
            requestPresentationStyle(.expanded)
            appState.navigateToViewer(opening: vibeId)
        }
    }

    @MainActor
    private func handleSharedBetTap(betId: String, chatId: String?) async {
        print("handleSharedBetTap: betId=\(betId) chatId=\(chatId ?? "nil") auth=\(appState.isAuthenticated)")
        let trimmedBetId = betId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBetId.isEmpty else {
            appState.navigateToBetList()
            return
        }

        let trimmedChatId = chatId?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedChatId, trimmedChatId.hasPrefix("chat_") {
            let hasAccess = await appState.hasAccessToChat(trimmedChatId)
            if hasAccess == false {
                presentBetAccessPrompt(chatId: trimmedChatId, betId: trimmedBetId)
                return
            }
            appState.currentChatId = trimmedChatId
        }

        await appState.openBetById(trimmedBetId)
    }

    @MainActor
    private func presentBetAccessPrompt(chatId: String, betId: String) {
        let alert = UIAlertController(
            title: "You're not in this challenge chat",
            message: "Do you want to request access to join this bet?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Request Access", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            Task {
                await self.submitBetAccessRequest(chatId: chatId, betId: betId)
            }
        }))

        present(alert, animated: true)
    }

    @MainActor
    private func submitBetAccessRequest(chatId: String, betId: String) async {
        let requester = appState.userFirstName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let requesterName = (requester?.isEmpty == false ? requester! : "A user")
        let reason = "\(requesterName) wants to join this challenge from a shared bet link."

        do {
            let message = try await appState.requestJoinChallengeChat(
                chatId: chatId,
                betId: betId,
                reason: reason
            )
            presentSimpleAlert(title: "Request Sent", message: message)
        } catch {
            presentSimpleAlert(
                title: "Request Failed",
                message: error.localizedDescription
            )
        }
    }

    @MainActor
    private func presentSimpleAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    override func didStartSending(_ message: MSMessage, conversation: MSConversation) {
        // User sent a message
    }

    override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {
        // User cancelled sending
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        // Prepare for presentation style change
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        // Update app state with new presentation style
        appState.setPresentationStyle(presentationStyle)
    }
    
    // MARK: - Sending Stories

    func sendStory(vibeId: String, mediaUrl: String, isLocked: Bool, rawThumbnail: UIImage?, vibeType: VibeType, contextText: String?) {
        guard let conversation = activeConversation ?? appState.currentConversation else {
            print("MessagesViewController Warning: No active conversation available. Failed to send vibe \(vibeId).")
            return
        }

        let senderName = appState.userFirstName ?? "Someone"
        let isMediaType = vibeType == .photo || vibeType == .video

        // 1. Render the appropriate bubble image
        let styledThumbnail: UIImage
        if isMediaType {
            styledThumbnail = StoryBubbleRenderer.shared.renderStoryBubble(
                thumbnail: rawThumbnail ?? UIImage(systemName: "play.circle.fill")!,
                expiresIn: 24,
                isLocked: isLocked
            )
        } else {
            styledThumbnail = StoryBubbleRenderer.shared.renderVibeCard(
                vibeType: vibeType,
                contextText: contextText,
                isLocked: isLocked
            )
        }

        // 2. Create Layout with type-specific text
        let layout = MSMessageTemplateLayout()
        layout.image = styledThumbnail

        if isLocked {
            layout.caption = "🔒 \(senderName) posted a locked Vibe"
            layout.subcaption = "Post yours to unlock"
        } else {
            layout.caption = captionForVibeType(vibeType, senderName: senderName)
            layout.subcaption = "Tap to see it"
        }

        // 3. Create Message
        let message = MSMessage()
        message.layout = layout
        message.summaryText = isLocked ? "\(senderName) posted a locked vibe 🔒" : "\(senderName) shared a \(vibeType.displayName) vibe"

        // 4. Encode data with chat_id for distributed ID system
        var components = URLComponents()
        components.scheme = "https"
        components.host = "getvibe.app"
        components.path = "/open"

        var queryItems = [
            URLQueryItem(name: "vibe_id", value: vibeId),
            URLQueryItem(name: "videoId", value: vibeId), // Legacy support
            URLQueryItem(name: "locked", value: String(isLocked)),
            URLQueryItem(name: "url", value: mediaUrl),
            URLQueryItem(name: "type", value: vibeType.rawValue),
            URLQueryItem(name: "userId", value: appState.userId),
            URLQueryItem(name: "sender", value: senderName),
            URLQueryItem(name: "timestamp", value: String(Int(Date().timeIntervalSince1970)))
        ]

        if let chatId = appState.currentChatId, !chatId.hasPrefix("fallback_") {
            queryItems.append(URLQueryItem(name: "chat_id", value: chatId))
        }

        components.queryItems = queryItems
        message.url = components.url

        print("MVC sendStory: url=\(message.url?.absoluteString ?? "nil") chatId=\(appState.currentChatId ?? "nil")")

        // 5. Insert into Conversation
        conversation.insert(message) { error in
            if let error = error {
                print("Error inserting message: \(error)")
            } else {
                print("MessagesViewController: Inserted vibe message \(vibeId)")
            }
        }
    }

    private func captionForVibeType(_ type: VibeType, senderName: String) -> String {
        switch type {
        case .battery:  return "🔋 \(senderName) shared their battery"
        case .mood:     return "😊 \(senderName) shared their mood"
        case .poll:     return "📊 \(senderName) created a poll"
        case .tea:      return "☕️ \(senderName) spilled the tea"
        case .leak:     return "🫣 \(senderName) leaked something"
        case .sketch:   return "🎨 \(senderName) sent a doodle"
        case .eta:      return "📍 \(senderName) shared their ETA"
        case .song:     return "🎵 \(senderName) shared a song"
        case .dailyDrop: return "🎲 \(senderName) sent a challenge"
        case .parlay:   return "💸 \(senderName) sent a parlay"
        default:        return "✨ \(senderName) just posted!"
        }
    }

    private func generateThumbnail(for url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 300, height: 400)

        // Using semaphores to wait for async replacement:
        let semaphore = DispatchSemaphore(value: 0)
        var resultImage: UIImage?
        
        generator.generateCGImageAsynchronously(for: .zero) { cgImage, _, error in
            if let cgImage = cgImage {
                resultImage = UIImage(cgImage: cgImage)
            }
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 2.0)
        return resultImage
    }
}
