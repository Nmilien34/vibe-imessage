//
//  ConversationManager.swift
//  Vibe MessagesExtension
//
//  The "Trojan Horse" - Distributed ID System
//
//  Since iMessage doesn't provide persistent chat IDs, we create our own
//  virtual chat room system. This manager handles:
//  1. Resolving/creating chat IDs for conversations
//  2. Parsing chat IDs from incoming messages
//  3. Packing outgoing messages with chat IDs
//

import Foundation
import Messages

@MainActor
class ConversationManager: ObservableObject {
    static let shared = ConversationManager()

    // MARK: - Constants
    private let chatIdPrefix = "chat_"
    private let urlScheme = "vibez"
    private let userDefaultsPrefix = "vibe_chatid_"

    // MARK: - Published State
    @Published var currentChatId: String?
    @Published var isResolvingChat = false

    private init() {}

    // MARK: - Function A: Resolve Chat ID

    /**
     * Resolves the Chat ID for the current conversation.
     *
     * Logic:
     * 1. Check if there's a selected message with embedded chat_id
     * 2. Check UserDefaults for previously mapped conversation
     * 3. If neither, create a new chat and save the mapping
     */
    func resolveChatID(
        conversation: MSConversation,
        userId: String
    ) async -> String {
        isResolvingChat = true
        defer { isResolvingChat = false }

        // Step 1: Check if there's a selected message with chat_id
        if let selectedMessage = conversation.selectedMessage,
           let url = selectedMessage.url,
           let chatId = extractChatId(from: url) {
            // Save this mapping for future use
            saveChatIdMapping(
                localParticipantId: conversation.localParticipantIdentifier.uuidString,
                chatId: chatId
            )
            // Join this chat on the backend
            await joinChat(chatId: chatId, userId: userId)
            currentChatId = chatId
            print("ConversationManager: Resolved chat_id from selected message: \(chatId)")
            return chatId
        }

        // Step 2: Check UserDefaults for existing mapping
        let localId = conversation.localParticipantIdentifier.uuidString
        if let savedChatId = getChatIdMapping(for: localId) {
            currentChatId = savedChatId
            print("ConversationManager: Found saved chat_id: \(savedChatId)")
            return savedChatId
        }

        // Step 3: Create a new chat
        let newChatId = await createNewChat(userId: userId)
        saveChatIdMapping(localParticipantId: localId, chatId: newChatId)
        currentChatId = newChatId
        print("ConversationManager: Created new chat_id: \(newChatId)")
        return newChatId
    }

    // MARK: - Function B: Pack Message

    /**
     * Creates an MSMessage with embedded vibe_id and chat_id.
     *
     * The URL payload allows recipients to:
     * 1. Join the same virtual chat room
     * 2. View the specific vibe
     */
    func packMessage(
        vibeId: String,
        chatId: String,
        thumbnail: UIImage?,
        caption: String = "Check my Vibe",
        isLocked: Bool = false
    ) -> MSMessage {
        let message = MSMessage()

        // Create the URL with embedded IDs
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "vibe_id", value: vibeId),
            URLQueryItem(name: "chat_id", value: chatId),
            URLQueryItem(name: "locked", value: isLocked ? "1" : "0"),
        ]
        message.url = components.url

        // Create the visual layout
        let layout = MSMessageTemplateLayout()

        // Set thumbnail image
        if let thumbnail = thumbnail {
            layout.image = thumbnail
        }

        // Set text
        layout.caption = caption
        layout.trailingCaption = isLocked ? "🔒 Tap to unlock" : "Tap to watch"

        message.layout = layout

        return message
    }

    /**
     * Creates a live layout message (interactive bubble).
     */
    func packLiveMessage(
        vibeId: String,
        chatId: String,
        thumbnail: UIImage?,
        senderName: String,
        isLocked: Bool = false
    ) -> MSMessage {
        let message = MSMessage()

        // Create the URL with embedded IDs
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "vibe_id", value: vibeId),
            URLQueryItem(name: "chat_id", value: chatId),
            URLQueryItem(name: "locked", value: isLocked ? "1" : "0"),
            URLQueryItem(name: "sender", value: senderName),
        ]
        message.url = components.url

        // Use MSMessageLiveLayout for interactive bubble
        // Fallback to template layout
        let alternateLayout = MSMessageTemplateLayout()
        if let thumbnail = thumbnail {
            alternateLayout.image = thumbnail
        }
        alternateLayout.caption = isLocked ? "🔒 Locked Vibe" : "\(senderName)'s Vibe"
        alternateLayout.trailingCaption = "Tap to view"

        message.layout = alternateLayout

        return message
    }

    // MARK: - URL Parsing

    /**
     * Extracts the chat_id from a Vibe URL.
     */
    func extractChatId(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        return queryItems.first(where: { $0.name == "chat_id" })?.value
    }

    /**
     * Extracts the vibe_id from a Vibe URL.
     */
    func extractVibeId(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        return queryItems.first(where: { $0.name == "vibe_id" })?.value
    }

    /**
     * Extracts lock status from a Vibe URL.
     */
    func extractIsLocked(from url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return false
        }
        return queryItems.first(where: { $0.name == "locked" })?.value == "1"
    }

    /**
     * Parse all data from a Vibe URL.
     */
    func parseVibeURL(_ url: URL) -> (vibeId: String?, chatId: String?, isLocked: Bool, sender: String?) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return (nil, nil, false, nil)
        }

        let vibeId = queryItems.first(where: { $0.name == "vibe_id" })?.value
        let chatId = queryItems.first(where: { $0.name == "chat_id" })?.value
        let isLocked = queryItems.first(where: { $0.name == "locked" })?.value == "1"
        let sender = queryItems.first(where: { $0.name == "sender" })?.value

        return (vibeId, chatId, isLocked, sender)
    }

    // MARK: - UserDefaults Mapping

    private func saveChatIdMapping(localParticipantId: String, chatId: String) {
        let key = userDefaultsPrefix + localParticipantId
        UserDefaults.standard.set(chatId, forKey: key)
        print("ConversationManager: Saved mapping \(localParticipantId) -> \(chatId)")
    }

    private func getChatIdMapping(for localParticipantId: String) -> String? {
        let key = userDefaultsPrefix + localParticipantId
        return UserDefaults.standard.string(forKey: key)
    }

    // MARK: - Backend API Calls

    private func createNewChat(userId: String) async -> String {
        // Generate a local chat ID
        let chatId = "chat_\(UUID().uuidString)"

        // Call backend to create the chat
        do {
            let _: ChatResponse = try await APIClient.shared.post(
                "/chat/create",
                body: CreateChatRequest(userId: userId, title: nil, type: "group")
            )
            // Use the returned chatId if available, otherwise use our generated one
            return chatId
        } catch {
            print("ConversationManager: Failed to create chat on backend: \(error)")
            // Return our local ID anyway - backend will sync later
            return chatId
        }
    }

    private func joinChat(chatId: String, userId: String) async {
        do {
            let _: JoinChatResponse = try await APIClient.shared.post(
                "/chat/join",
                body: JoinChatRequest(userId: userId, chatId: chatId)
            )
            print("ConversationManager: Joined chat \(chatId)")
        } catch {
            print("ConversationManager: Failed to join chat: \(error)")
        }
    }
}

// MARK: - Request/Response Types

struct CreateChatRequest: Codable {
    let userId: String
    let title: String?
    let type: String
}

struct ChatResponse: Codable {
    let chatId: String
    let chat: ChatData?
}

struct ChatData: Codable {
    let id: String
    let title: String?
    let members: [String]

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case members
    }
}

struct JoinChatRequest: Codable {
    let userId: String
    let chatId: String
}

struct JoinChatResponse: Codable {
    let success: Bool
    let chat: ChatData?
}
