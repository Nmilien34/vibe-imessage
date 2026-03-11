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
    private var pendingAutoSendMessage: MSMessage?
    private var pendingAutoSendVibeId: String?
    private var pendingAutoSendRetryCount: Int = 0
    private let maxPendingAutoSendRetries = 3

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
        appState.sendStory = { [weak self] (vibeId: String, mediaUrl: String, isLocked: Bool, rawThumbnail: UIImage?, vibeType: VibeType, contextText: String?, linkedBetId: String?) in
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
                self.sendStory(
                    vibeId: vibeId,
                    mediaUrl: mediaUrl,
                    isLocked: isLocked,
                    rawThumbnail: rawThumbnail,
                    vibeType: vibeType,
                    contextText: contextText,
                    linkedBetId: linkedBetId
                )
            }
        }

        appState.presentChallengeAccessPrompt = { [weak self] chatId, betId in
            Task { @MainActor in
                guard let self else { return }
                self.presentBetAccessPrompt(chatId: chatId, betId: betId)
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

        let interactionProbe = UITapGestureRecognizer(target: self, action: #selector(handleUserInteractionForPendingSend))
        interactionProbe.cancelsTouchesInView = false
        interactionProbe.delaysTouchesBegan = false
        interactionProbe.delaysTouchesEnded = false
        view.addGestureRecognizer(interactionProbe)
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
        let messageTypeRaw = params["type"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let chatId = parsed.chatId ?? params["chat_id"]
        let isLocked = parsed.isLocked || params["locked"] == "true"
        let senderId = params["userId"] ?? ""
        let senderName = parsed.sender ?? params["sender"] ?? "Friend"
        let videoUrl = params["url"]
        let isChallengeTap = messageTypeRaw == VibeType.parlay.rawValue && !vibeId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        print("didSelect: betId=\(betId ?? "nil") vibeId=\(vibeId) type=\(messageTypeRaw ?? "nil") chatId=\(chatId ?? "nil") isLocked=\(isLocked) auth=\(appState.isAuthenticated)")

        // If user isn't authenticated, save the deep link for after auth completes
        if !appState.isAuthenticated {
            appState.savePendingDeepLink(
                betId: betId,
                vibeId: vibeId.isEmpty ? nil : vibeId,
                chatId: chatId,
                isLocked: isLocked,
                messageTypeRaw: messageTypeRaw,
                senderName: senderName,
                senderId: senderId
            )
            requestPresentationStyle(.expanded)
            return
        }

        if let betId, !betId.isEmpty {
            requestPresentationStyle(.expanded)
            Task {
                await handleSharedBetTap(
                    betId: betId,
                    chatId: chatId,
                    senderId: senderId,
                    conversation: conversation
                )
            }
            return
        }

        if isChallengeTap {
            requestPresentationStyle(.expanded)
            Task {
                await handleSharedChallengeTap(
                    vibeId: vibeId,
                    chatId: chatId,
                    senderId: senderId,
                    conversation: conversation
                )
            }
            return
        }

        // Check if this message is from the current user
        let isOwnMessage = senderId == appState.userId

        if isLocked && !isOwnMessage {
            // Show unlock prompt for locked content from other users
            Task { @MainActor in
                let resolvedChatId = await resolveSharedChatIfNeeded(chatId: chatId, conversation: conversation)
                let normalizedSenderId = senderId.trimmingCharacters(in: .whitespacesAndNewlines)
                if let resolvedChatId, !normalizedSenderId.isEmpty, normalizedSenderId != appState.userId {
                    await appState.ensureNetworkConnection(targetUserId: normalizedSenderId, sourceChatId: resolvedChatId)
                }
                await appState.loadVibes()
            }
            let lockedParams = LockedMessageParams(
                vibeId: vibeId,
                senderName: senderName,
                videoUrl: videoUrl,
                userId: senderId
            )
            appState.handleLockedMessageTap(params: lockedParams)
        } else {
            // Not locked or own message - show the content
            guard !vibeId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                print("didSelect: Missing vibeId for unlocked message; skipping viewer navigation.")
                return
            }
            requestPresentationStyle(.expanded)
            Task { @MainActor in
                let resolvedChatId = await resolveSharedChatIfNeeded(chatId: chatId, conversation: conversation)
                let normalizedSenderId = senderId.trimmingCharacters(in: .whitespacesAndNewlines)
                if let resolvedChatId, !normalizedSenderId.isEmpty, normalizedSenderId != appState.userId {
                    await appState.ensureNetworkConnection(targetUserId: normalizedSenderId, sourceChatId: resolvedChatId)
                }
                await appState.loadVibes()
                appState.navigateToViewer(opening: vibeId)
            }
        }
    }

    @MainActor
    private func handleSharedChallengeTap(vibeId: String, chatId: String?, senderId: String, conversation: MSConversation) async {
        let trimmedVibeId = vibeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedVibeId.isEmpty else {
            presentSimpleAlert(
                title: "Couldn't open challenge",
                message: "This challenge link is missing the story reference."
            )
            appState.navigateToBetList()
            return
        }

        guard let resolvedChallengeChatId = await appState.resolveSharedChallengeChatId(
            vibeId: trimmedVibeId,
            preferredChatId: chatId,
            conversation: conversation
        ), resolvedChallengeChatId.hasPrefix("chat_") else {
            presentSimpleAlert(
                title: "Couldn't open challenge",
                message: "We couldn't verify this challenge chat. Open My Challenges and pull to refresh."
            )
            appState.navigateToBetList()
            return
        }

        let hasAccess = await appState.hasAccessToChat(resolvedChallengeChatId)
        if hasAccess == false {
            presentBetAccessPrompt(chatId: resolvedChallengeChatId, betId: nil)
            return
        }
        if hasAccess == nil {
            presentSimpleAlert(
                title: "Couldn't verify chat access",
                message: "Check your connection and try again."
            )
            return
        }
        appState.currentChatId = resolvedChallengeChatId

        let normalizedSenderId = senderId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedSenderId.isEmpty,
           normalizedSenderId != appState.userId {
            await appState.ensureNetworkConnection(
                targetUserId: normalizedSenderId,
                sourceChatId: resolvedChallengeChatId
            )
        }

        await appState.loadVibes()

        let opened = await appState.openExactSharedChallenge(
            vibeId: trimmedVibeId,
            preferredChatId: resolvedChallengeChatId
        )
        if !opened {
            presentSimpleAlert(
                title: "Couldn't open challenge",
                message: "We couldn't find this exact challenge. Open My Challenges and pull to refresh."
            )
            appState.navigateToBetList()
        }
    }

    @MainActor
    private func handleSharedBetTap(betId: String, chatId: String?, senderId: String, conversation: MSConversation) async {
        print("handleSharedBetTap: betId=\(betId) chatId=\(chatId ?? "nil") auth=\(appState.isAuthenticated)")
        let trimmedBetId = betId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBetId.isEmpty else {
            appState.navigateToBetList()
            return
        }

        var resolvedChatIdForConnection: String?
        let trimmedChatId = chatId?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedChatId, trimmedChatId.hasPrefix("chat_") {
            let resolvedChatId = await resolveSharedChatIfNeeded(chatId: trimmedChatId, conversation: conversation) ?? trimmedChatId
            resolvedChatIdForConnection = resolvedChatId

            let hasAccess = await appState.hasAccessToChat(resolvedChatId)
            if hasAccess == false {
                presentBetAccessPrompt(chatId: resolvedChatId, betId: trimmedBetId)
                return
            }
            if hasAccess == nil {
                presentSimpleAlert(
                    title: "Couldn't verify chat access",
                    message: "Check your connection and try again."
                )
                return
            }
            appState.currentChatId = resolvedChatId
        }

        let normalizedSenderId = senderId.trimmingCharacters(in: .whitespacesAndNewlines)
        if let resolvedChatIdForConnection,
           !normalizedSenderId.isEmpty,
           normalizedSenderId != appState.userId {
            await appState.ensureNetworkConnection(
                targetUserId: normalizedSenderId,
                sourceChatId: resolvedChatIdForConnection
            )
        }

        await appState.openBetById(trimmedBetId)
    }

    @MainActor
    private func resolveSharedChatIfNeeded(chatId: String?, conversation: MSConversation) async -> String? {
        guard let chatId = chatId?.trimmingCharacters(in: .whitespacesAndNewlines),
              chatId.hasPrefix("chat_")
        else {
            if let existingChatId = appState.currentChatId, existingChatId.hasPrefix("chat_") {
                return existingChatId
            }
            return nil
        }

        if let sharedResolved = await ConversationManager.shared.resolveSharedChatID(
            preferredChatId: chatId,
            conversation: conversation,
            userId: appState.userId
        ) {
            appState.currentChatId = sharedResolved
            return sharedResolved
        }

        let resolvedChatId = await ConversationManager.shared.resolveChatID(
            conversation: conversation,
            userId: appState.userId
        )
        guard resolvedChatId.hasPrefix("chat_") else {
            return nil
        }

        appState.currentChatId = resolvedChatId
        return resolvedChatId
    }

    @MainActor
    private func presentBetAccessPrompt(chatId: String, betId: String?) {
        let alert = UIAlertController(
            title: "You're not in this challenge chat",
            message: "Do you want to request access to join this challenge?",
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
    private func submitBetAccessRequest(chatId: String, betId: String?) async {
        let requester = appState.userFirstName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let requesterName = (requester?.isEmpty == false ? requester! : "A user")
        let reason = "\(requesterName) wants to join this challenge from a shared link."

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

    func sendStory(
        vibeId: String,
        mediaUrl: String,
        isLocked: Bool,
        rawThumbnail: UIImage?,
        vibeType: VibeType,
        contextText: String?,
        linkedBetId: String? = nil
    ) {
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
                isLocked: isLocked,
                senderName: senderName
            )
        }

        // 2. Create Layout with type-specific text
        let layout = MSMessageTemplateLayout()
        layout.image = styledThumbnail
        let resolvedDetails = (vibeType == .parlay) ? parseResolvedBubbleContext(contextText: contextText) : nil
        let stakeDetails = (vibeType == .parlay && resolvedDetails == nil) ? parseStakeBubbleContext(contextText: contextText) : nil
        let parlayDetails = (vibeType == .parlay && resolvedDetails == nil && stakeDetails == nil)
            ? parseParlayBubbleContext(contextText: contextText, fallbackSenderName: senderName)
            : nil

        if isLocked {
            layout.caption = "🔒 \(senderName) posted a locked Vibe"
            layout.subcaption = "Post yours to unlock"
        } else if let resolvedDetails {
            let outcomeLabel = resolvedDetails.outcome.uppercased()
            layout.caption = "⚖️ \(resolvedDetails.callerName) called \(outcomeLabel)"
            let title = truncated(resolvedDetails.title, maxLength: 60)
            layout.subcaption = title
            layout.trailingSubcaption = "Tap for results"
        } else if let stakeDetails {
            let sideLabel = stakeDetails.side.uppercased()
            layout.caption = "🔥 \(stakeDetails.stakerName) just locked in \(sideLabel)"
            let title = truncated(stakeDetails.title, maxLength: 60)
            layout.subcaption = title
            layout.trailingSubcaption = "Tap to join"
        } else if let parlayDetails {
            layout.caption = "🎯 \(parlayDetails.creatorName) went on record"
            if let deadline = parlayDetails.deadline {
                layout.subcaption = "Closes \(formatCompactDeadline(deadline)) • Pick a side"
            } else {
                layout.subcaption = "Pick a side before time runs out"
            }
            layout.trailingSubcaption = "YES / NO"
        } else {
            layout.caption = captionForVibeType(vibeType, senderName: senderName)
            layout.subcaption = "Tap to see it"
        }

        // 3. Create Message
        let message = MSMessage()
        message.layout = layout
        if isLocked {
            message.summaryText = "\(senderName) posted a locked vibe 🔒"
        } else if let resolvedDetails {
            let outcomeLabel = resolvedDetails.outcome.uppercased()
            let title = truncated(resolvedDetails.title, maxLength: 72)
            message.summaryText = "\(resolvedDetails.callerName) called \(outcomeLabel) on \(title). Tap for results."
        } else if let stakeDetails {
            let sideLabel = stakeDetails.side.uppercased()
            let title = truncated(stakeDetails.title, maxLength: 72)
            message.summaryText = "\(stakeDetails.stakerName) just staked \(sideLabel) on \(title). Tap to join."
        } else if let parlayDetails {
            let title = truncated(parlayDetails.title, maxLength: 72)
            if let deadline = parlayDetails.deadline {
                message.summaryText = "\(parlayDetails.creatorName) challenged the chat: \(title). Pick a side before \(formatCompactDeadline(deadline))."
            } else {
                message.summaryText = "\(parlayDetails.creatorName) challenged the chat: \(title). Pick a side."
            }
        } else {
            message.summaryText = "\(senderName) shared a \(vibeType.displayName) vibe"
        }

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
        } else if let suggestedChatId = ConversationManager.shared.suggestedChatId(for: conversation) {
            queryItems.append(URLQueryItem(name: "chat_id", value: suggestedChatId))
            print("MVC sendStory: using suggested chat_id \(suggestedChatId) while resolution is pending")
        }
        if let linkedBetId = linkedBetId?.trimmingCharacters(in: .whitespacesAndNewlines), !linkedBetId.isEmpty {
            queryItems.append(URLQueryItem(name: "bet_id", value: linkedBetId))
            if let parlayDetails {
                queryItems.append(URLQueryItem(name: "bet_title", value: parlayDetails.title))
                if let deadline = parlayDetails.deadline {
                    queryItems.append(URLQueryItem(name: "bet_deadline", value: String(Int(deadline.timeIntervalSince1970))))
                }
            }
        }

        components.queryItems = queryItems
        message.url = components.url

        print("MVC sendStory: url=\(message.url?.absoluteString ?? "nil") chatId=\(appState.currentChatId ?? "nil")")

        // 5. Always attempt direct send first.
        conversation.send(message) { [weak self] error in
            if let nsError = error as NSError? {
                if self?.shouldQueuePendingAutoSend(for: nsError) == true {
                    self?.pendingAutoSendMessage = message
                    self?.pendingAutoSendVibeId = vibeId
                    self?.pendingAutoSendRetryCount = 0
                    print("Auto-send blocked by iMessage policy (\(nsError.domain) code=\(nsError.code)); queued retry on next user interaction.")
                    return
                }

                print("Error sending message directly (\(nsError.domain) code=\(nsError.code)): \(nsError.localizedDescription). Falling back to staged insert.")
                conversation.insert(message) { fallbackError in
                    if let fallbackError = fallbackError {
                        print("Error inserting fallback message: \(fallbackError)")
                    } else {
                        print("MessagesViewController: Inserted fallback vibe message \(vibeId)")
                    }
                }
            } else {
                print("MessagesViewController: Sent vibe message \(vibeId)")
                self?.clearPendingAutoSend()
                guard let self else { return }
                Task { @MainActor [self] in
                    self.requestPresentationStyle(.compact)
                }
            }
        }
    }

    private func clearPendingAutoSend() {
        pendingAutoSendMessage = nil
        pendingAutoSendVibeId = nil
        pendingAutoSendRetryCount = 0
    }

    private func shouldQueuePendingAutoSend(for error: NSError) -> Bool {
        guard error.domain == MSMessagesErrorDomain else { return false }

        // MSMessageErrorCodeSendWithoutRecentInteraction = 9
        // MSMessageErrorCodeSendWhileNotVisible = 10
        return error.code == 9 || error.code == 10
    }

    @objc private func handleUserInteractionForPendingSend() {
        guard let pendingMessage = pendingAutoSendMessage,
              let pendingVibeId = pendingAutoSendVibeId,
              let conversation = activeConversation ?? appState.currentConversation else { return }

        conversation.send(pendingMessage) { [weak self] error in
            guard let self else { return }
            if let nsError = error as NSError? {
                if self.shouldQueuePendingAutoSend(for: nsError) {
                    self.pendingAutoSendRetryCount += 1
                    print("Pending auto-send retry \(self.pendingAutoSendRetryCount) blocked (\(nsError.domain) code=\(nsError.code)).")

                    if self.pendingAutoSendRetryCount >= self.maxPendingAutoSendRetries {
                        print("Pending auto-send retry limit reached; staging message in compose field.")
                        conversation.insert(pendingMessage) { fallbackError in
                            if let fallbackError = fallbackError {
                                print("Error inserting pending fallback message: \(fallbackError)")
                            } else {
                                print("MessagesViewController: Inserted pending fallback vibe message \(pendingVibeId)")
                            }
                        }
                        self.clearPendingAutoSend()
                    }
                    return
                }

                print("Pending auto-send failed (\(nsError.domain) code=\(nsError.code)); staging message in compose field.")
                conversation.insert(pendingMessage) { fallbackError in
                    if let fallbackError = fallbackError {
                        print("Error inserting pending fallback message: \(fallbackError)")
                    } else {
                        print("MessagesViewController: Inserted pending fallback vibe message \(pendingVibeId)")
                    }
                }
                self.clearPendingAutoSend()
                return
            }

            print("MessagesViewController: Sent pending vibe message \(pendingVibeId)")
            self.clearPendingAutoSend()
            Task { @MainActor in
                self.requestPresentationStyle(.compact)
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
        case .parlay:   return "🎯 \(senderName) started a challenge"
        default:        return "✨ \(senderName) just posted!"
        }
    }

    private struct ParlayBubbleContext {
        let title: String
        let deadline: Date?
        let creatorName: String
    }

    private struct StakeBubbleContext {
        let title: String
        let stakerName: String
        let side: String
        let deadline: Date?
    }

    private struct ResolvedBubbleContext {
        let title: String
        let callerName: String
        let outcome: String
    }

    private func parseParlayBubbleContext(contextText: String?, fallbackSenderName: String) -> ParlayBubbleContext? {
        guard let raw = contextText?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        if raw.hasPrefix("parlay_v2?") {
            let query = String(raw.dropFirst("parlay_v2?".count))
            if let components = URLComponents(string: "https://getvibe.app/open?\(query)") {
                let queryItems = components.queryItems ?? []
                let title = queryItems.first(where: { $0.name == "title" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
                let creator = queryItems.first(where: { $0.name == "creator" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
                let deadline = queryItems.first(where: { $0.name == "deadline" })?.value.flatMap(TimeInterval.init).map {
                    Date(timeIntervalSince1970: $0)
                }

                if let title, !title.isEmpty {
                    let normalizedCreator = creator ?? ""
                    let creatorName = normalizedCreator.isEmpty ? fallbackSenderName : normalizedCreator
                    return ParlayBubbleContext(title: title, deadline: deadline, creatorName: creatorName)
                }
            }
        }

        // Legacy format fallback: "title|amount|opponent"
        let legacyParts = raw.split(separator: "|", maxSplits: 2).map(String.init)
        if let first = legacyParts.first {
            let title = first.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                return ParlayBubbleContext(title: title, deadline: nil, creatorName: fallbackSenderName)
            }
        }

        return nil
    }

    private func parseStakeBubbleContext(contextText: String?) -> StakeBubbleContext? {
        guard let raw = contextText?.trimmingCharacters(in: .whitespacesAndNewlines),
              raw.hasPrefix("stake_v1?") else {
            return nil
        }
        let query = String(raw.dropFirst("stake_v1?".count))
        guard let components = URLComponents(string: "https://getvibe.app/open?\(query)") else {
            return nil
        }
        let queryItems = components.queryItems ?? []
        guard let title = queryItems.first(where: { $0.name == "title" })?.value,
              let stakerName = queryItems.first(where: { $0.name == "staker" })?.value,
              let side = queryItems.first(where: { $0.name == "side" })?.value else {
            return nil
        }
        let deadline = queryItems.first(where: { $0.name == "deadline" })?.value
            .flatMap(TimeInterval.init)
            .map { Date(timeIntervalSince1970: $0) }
        return StakeBubbleContext(title: title, stakerName: stakerName, side: side, deadline: deadline)
    }

    private func parseResolvedBubbleContext(contextText: String?) -> ResolvedBubbleContext? {
        guard let raw = contextText?.trimmingCharacters(in: .whitespacesAndNewlines),
              raw.hasPrefix("resolved_v1?") else {
            return nil
        }
        let query = String(raw.dropFirst("resolved_v1?".count))
        guard let components = URLComponents(string: "https://getvibe.app/open?\(query)") else {
            return nil
        }
        let queryItems = components.queryItems ?? []
        guard let title = queryItems.first(where: { $0.name == "title" })?.value,
              let callerName = queryItems.first(where: { $0.name == "caller" })?.value,
              let outcome = queryItems.first(where: { $0.name == "outcome" })?.value else {
            return nil
        }
        return ResolvedBubbleContext(title: title, callerName: callerName, outcome: outcome)
    }

    private func formatCompactDeadline(_ deadline: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        if calendar.isDateInToday(deadline) {
            return "today \(timeFormatter.string(from: deadline))"
        }
        if calendar.isDateInTomorrow(deadline) {
            return "tomorrow \(timeFormatter.string(from: deadline))"
        }

        let nearFormatter = DateFormatter()
        nearFormatter.setLocalizedDateFormatFromTemplate("EEE h:mm a")
        return nearFormatter.string(from: deadline)
    }

    private func truncated(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        return String(text.prefix(maxLength - 1)) + "…"
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
