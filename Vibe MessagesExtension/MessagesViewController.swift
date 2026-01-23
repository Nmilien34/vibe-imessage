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
        appState.sendStory = { [weak self] (video: VideoRecording, isLocked: Bool) in
            self?.sendStory(video: video, isLocked: isLocked)
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
        appState.setConversation(conversation)
        appState.setPresentationStyle(presentationStyle)

        // Load vibes for this conversation
        Task {
            await appState.loadVibes()
        }
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

        // Parse the message URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return }

        // Extract parameters
        var params: [String: String] = [:]
        for item in queryItems {
            if let value = item.value {
                params[item.name] = value
            }
        }

        let isLocked = params["locked"] == "true" || params["isLocked"] == "true"
        let vibeId = params["videoId"] ?? params["vibeId"] ?? params["id"] ?? ""
        let senderId = params["userId"] ?? ""
        let videoUrl = params["url"]

        // Check if this message is from the current user (can always view own messages)
        let isOwnMessage = senderId == appState.userId

        if isLocked && !isOwnMessage {
            // Show unlock prompt for locked content from other users
            let lockedParams = LockedMessageParams(
                vibeId: vibeId,
                senderName: "Friend", // In real app, get from conversation participants
                videoUrl: videoUrl,
                userId: senderId
            )
            appState.handleLockedMessageTap(params: lockedParams)
        } else {
            // Not locked or own message - show the content
            // Navigate to viewer or handle normally
            requestPresentationStyle(.expanded)

            // Find the vibe in our list and navigate to it
            if let index = appState.vibes.firstIndex(where: { $0.id == vibeId }) {
                appState.navigateToViewer(startingAt: index)
            }
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

    func sendStory(video: VideoRecording, isLocked: Bool) {
        guard let conversation = activeConversation else { return }

        // 1. Upload video (Mock for now)
        // In a real app, you'd upload 'video.url' to your backend here
        // and get back a remote URL and ID.
        let videoId = video.id.uuidString
        let mockRemoteUrl = "https://example.com/videos/\(videoId).mov"

        // 2. Generate raw thumbnail from video
        let rawThumbnail = video.thumbnail ?? generateThumbnail(for: video.url)

        // 3. Create styled bubble with gradient border, play button, expiration
        let styledThumbnail = StoryBubbleRenderer.shared.renderStoryBubble(
            thumbnail: rawThumbnail,
            expiresIn: 24,
            isLocked: isLocked
        )

        // 4. Create Layout
        let layout = MSMessageTemplateLayout()
        layout.image = styledThumbnail
        layout.caption = isLocked ? "🔒 Locked Vibe" : "New Vibe"
        layout.subcaption = "Tap to view • \(Int(video.duration))s"

        // 5. Create Message
        let message = MSMessage(session: conversation.selectedMessage?.session ?? MSSession())
        message.layout = layout
        message.summaryText = isLocked ? "shared a locked vibe" : "shared a vibe"

        // 6. Encode data for the extension to read later
        var components = URLComponents()
        components.scheme = "vibe"
        components.host = "story"
        components.queryItems = [
            URLQueryItem(name: "videoId", value: videoId),
            URLQueryItem(name: "locked", value: String(isLocked)),
            URLQueryItem(name: "url", value: mockRemoteUrl),
            URLQueryItem(name: "userId", value: appState.userId),
            URLQueryItem(name: "timestamp", value: String(Int(Date().timeIntervalSince1970)))
        ]
        message.url = components.url

        // 7. Insert into Conversation
        conversation.insert(message) { [weak self] error in
            if let error = error {
                print("Error inserting message: \(error)")
            } else {
                self?.dismiss()
            }
        }
    }

    private func generateThumbnail(for url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 300, height: 400)

        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("Thumbnail generation failed: \(error)")
            return nil
        }
    }
}
