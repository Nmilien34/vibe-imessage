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
    }

    private func setupSwiftUI() {
        // Set up the callback for presentation style changes
        appState.requestPresentationStyle = { [weak self] style in
            self?.requestPresentationStyle(style)
        }
        
        // Callback for sending a story
        appState.sendStory = { [weak self] (videoId: String, videoUrl: String, isLocked: Bool, rawThumbnail: UIImage?) in
            self?.sendStory(videoId: videoId, videoUrl: videoUrl, isLocked: isLocked, rawThumbnail: rawThumbnail)
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
        hostingController = hosting

        // Add as child view controller
        addChild(hosting)
        view.addSubview(hosting.view)

        // Set up constraints
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
        guard let url = message.url else { return }

        // Parse the message URL using ConversationManager
        let parsed = ConversationManager.shared.parseVibeURL(url)

        // Also extract legacy params for backwards compatibility
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return }

        var params: [String: String] = [:]
        for item in queryItems {
            if let value = item.value {
                params[item.name] = value
            }
        }

        let vibeId = parsed.vibeId ?? params["videoId"] ?? params["vibeId"] ?? params["id"] ?? ""
        let chatId = parsed.chatId ?? params["chat_id"]
        let isLocked = parsed.isLocked || params["locked"] == "true"
        let senderId = params["userId"] ?? ""
        let senderName = parsed.sender ?? params["sender"] ?? "Friend"
        let videoUrl = params["url"]

        // CRITICAL: Join the chat if we have a chat_id
        // This is how users get added to chats when receiving messages
        if let chatId = chatId {
            Task {
                await ConversationManager.shared.resolveChatID(
                    conversation: conversation,
                    userId: appState.userId
                )
                // The resolveChatID will parse the chat_id from selectedMessage
                // and join the chat automatically

                // Also update appState's currentChatId
                await MainActor.run {
                    appState.currentChatId = chatId
                }
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

    func sendStory(videoId: String, videoUrl: String, isLocked: Bool, rawThumbnail: UIImage?) {
        guard let conversation = activeConversation else { return }

        // Get sender's name for personalized bubble
        let senderName = appState.userFirstName ?? "Someone"

        // 1. Create styled bubble
        let styledThumbnail = StoryBubbleRenderer.shared.renderStoryBubble(
            thumbnail: rawThumbnail ?? UIImage(systemName: "play.circle.fill")!,
            expiresIn: 24,
            isLocked: isLocked
        )

        // 2. Create Layout with personalized text
        let layout = MSMessageTemplateLayout()
        layout.image = styledThumbnail

        if isLocked {
            layout.caption = "🔒 \(senderName) posted a locked Vibe"
            layout.subcaption = "Post yours to unlock"
        } else {
            layout.caption = "✨ \(senderName) just posted!"
            layout.subcaption = "Tap to see it"
        }

        // 3. Create Message
        let message = MSMessage(session: conversation.selectedMessage?.session ?? MSSession())
        message.layout = layout
        message.summaryText = isLocked ? "\(senderName) posted a locked vibe 🔒" : "\(senderName) just posted a vibe ✨"

        // 4. Encode data with chat_id for distributed ID system
        var components = URLComponents()
        components.scheme = "vibe"
        components.host = "story"

        // Build query items - include sender name for recipient's UI
        var queryItems = [
            URLQueryItem(name: "vibe_id", value: videoId),
            URLQueryItem(name: "videoId", value: videoId), // Legacy support
            URLQueryItem(name: "locked", value: String(isLocked)),
            URLQueryItem(name: "url", value: videoUrl),
            URLQueryItem(name: "userId", value: appState.userId),
            URLQueryItem(name: "sender", value: senderName), // For personalized UI
            URLQueryItem(name: "timestamp", value: String(Int(Date().timeIntervalSince1970)))
        ]

        // CRITICAL: Include chat_id so recipients can join the chat
        if let chatId = appState.currentChatId {
            queryItems.append(URLQueryItem(name: "chat_id", value: chatId))
        }

        components.queryItems = queryItems
        message.url = components.url

        // 5. Insert into Conversation
        conversation.insert(message) { error in
            if let error = error {
                print("Error inserting message: \(error)")
            } else {
                // Done - AppState handles the local vibe creation and dismiss if needed
            }
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
