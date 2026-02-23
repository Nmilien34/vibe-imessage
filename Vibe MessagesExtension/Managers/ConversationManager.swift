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
import Combine
import Messages
import CryptoKit

@MainActor
class ConversationManager: ObservableObject {
    static let shared = ConversationManager()

    // MARK: - Constants
    private let chatIdPrefix = "chat_"
    private let urlScheme = "https"
    private let userDefaultsPrefix = "vibe_chatid_"

    // MARK: - Published State
    @Published var currentChatId: String?
    @Published var isResolvingChat = false
    @Published private(set) var lastResolutionError: Error?

    private init() {}

    // MARK: - Function A: Resolve Chat ID

    /**
     * Resolves the Chat ID for the current conversation.
     *
     * Logic:
     * 1. Check if there's a selected message with embedded chat_id
     * 2. Check UserDefaults for previously mapped conversation
     * 3. If neither, try deterministic participant-based chat_id
     * 4. If all else fails, create a new chat and save the mapping
     */
    func resolveChatID(
        conversation: MSConversation,
        userId: String
    ) async -> String {
        lastResolutionError = nil
        isResolvingChat = true
        defer { isResolvingChat = false }
        let mappingKey = conversationMappingKey(for: conversation)
        let lookupKeys = [mappingKey] + legacyConversationMappingKeys(for: conversation)
        let deterministicChatId = deterministicChatId(for: conversation)

        // Step 1: Check if there's a selected message with chat_id
        if let selectedMessage = conversation.selectedMessage,
           let url = selectedMessage.url,
           let embeddedChatId = extractChatId(from: url) {
            if isValidBackendChatId(embeddedChatId),
               let resolved = await resolveChatOnBackend(userId: userId, preferredChatId: embeddedChatId) {
                saveChatIdMapping(mappingKey: mappingKey, chatId: resolved)
                for key in lookupKeys where key != mappingKey {
                    saveChatIdMapping(mappingKey: key, chatId: resolved)
                }
                currentChatId = resolved
                print("ConversationManager: Resolved chat_id from selected message: \(resolved)")
                return resolved
            }
            print("ConversationManager: Ignoring invalid/unresolvable selected chat_id: \(embeddedChatId)")
        }

        // Step 2: Resolve a deterministic participant-scoped chat first.
        if let deterministicChatId,
           let resolved = await resolveChatOnBackend(userId: userId, preferredChatId: deterministicChatId) {
            saveChatIdMapping(mappingKey: mappingKey, chatId: resolved)
            for key in lookupKeys where key != mappingKey {
                saveChatIdMapping(mappingKey: key, chatId: resolved)
            }
            currentChatId = resolved
            print("ConversationManager: Resolved deterministic chat_id: \(resolved)")
            return resolved
        }

        // Step 3: Check UserDefaults for existing mapping.
        if let savedChatId = lookupKeys.compactMap({ getChatIdMapping(for: $0) }).first {
            if isValidBackendChatId(savedChatId),
               let resolved = await resolveChatOnBackend(userId: userId, preferredChatId: savedChatId) {
                saveChatIdMapping(mappingKey: mappingKey, chatId: resolved)
                for key in lookupKeys where key != mappingKey {
                    saveChatIdMapping(mappingKey: key, chatId: resolved)
                }
                currentChatId = resolved
                print("ConversationManager: Found saved chat_id: \(resolved)")
                return resolved
            }

            // Stale mapping (old fallback/invalid id): clear and recreate.
            for key in lookupKeys {
                removeChatIdMapping(for: key)
            }
        }

        // Step 4: Resolve/create a backend chat.
        if let newChatId = await resolveChatOnBackend(userId: userId, preferredChatId: nil) {
            saveChatIdMapping(mappingKey: mappingKey, chatId: newChatId)
            for key in lookupKeys where key != mappingKey {
                saveChatIdMapping(mappingKey: key, chatId: newChatId)
            }
            currentChatId = newChatId
            print("ConversationManager: Created new chat_id: \(newChatId)")
            return newChatId
        }

        // Last-resort local fallback; write paths will reject this id.
        let fallbackId = "fallback_\(UUID().uuidString)"
        currentChatId = fallbackId
        print("ConversationManager: Backend resolve failed, using \(fallbackId)")
        return fallbackId
    }

    /// Resolves the exact chat id provided by a shared bubble URL.
    /// This is preferred over local deterministic ids when opening shared content.
    func resolveSharedChatID(
        preferredChatId: String,
        conversation: MSConversation,
        userId: String
    ) async -> String? {
        let normalizedChatId = preferredChatId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidBackendChatId(normalizedChatId) else { return nil }

        lastResolutionError = nil
        let mappingKey = conversationMappingKey(for: conversation)
        let lookupKeys = [mappingKey] + legacyConversationMappingKeys(for: conversation)

        guard let resolved = await resolveChatOnBackend(userId: userId, preferredChatId: normalizedChatId) else {
            return nil
        }

        saveChatIdMapping(mappingKey: mappingKey, chatId: resolved)
        for key in lookupKeys where key != mappingKey {
            saveChatIdMapping(mappingKey: key, chatId: resolved)
        }
        currentChatId = resolved
        print("ConversationManager: Resolved shared chat_id: \(resolved)")
        return resolved
    }

    /// Provides a deterministic participant-scoped chat id that can be embedded in outgoing messages
    /// even before backend chat resolution finishes.
    func suggestedChatId(for conversation: MSConversation) -> String? {
        deterministicChatId(for: conversation)
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
        components.host = "getvibe.app"
        components.path = "/open"
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
        components.host = "getvibe.app"
        components.path = "/open"
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

    private func conversationMappingKey(for conversation: MSConversation) -> String {
        let signature = participantSignature(for: conversation)
        if !signature.isEmpty {
            return signature
        }
        return conversation.localParticipantIdentifier.uuidString
    }

    private func legacyConversationMappingKeys(for conversation: MSConversation) -> [String] {
        let local = conversation.localParticipantIdentifier.uuidString
        let remotes = conversation.remoteParticipantIdentifiers
            .map(\.uuidString)
            .sorted()
            .joined(separator: "|")

        var keys: [String] = []
        if !local.isEmpty {
            keys.append(local)
        }
        if !local.isEmpty && !remotes.isEmpty {
            keys.append("\(local)|\(remotes)")
        }
        return Array(Set(keys))
    }

    private func participantSignature(for conversation: MSConversation) -> String {
        let zeroUUID = "00000000-0000-0000-0000-000000000000"
        let participantIds = ([conversation.localParticipantIdentifier] + conversation.remoteParticipantIdentifiers)
            .map(\.uuidString)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty && $0 != zeroUUID }

        return Array(Set(participantIds))
            .sorted()
            .joined(separator: "|")
    }

    private func deterministicChatId(for conversation: MSConversation) -> String? {
        let signature = participantSignature(for: conversation)
        guard !signature.isEmpty else { return nil }

        let digest = SHA256.hash(data: Data(signature.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let prefix = String(hex.prefix(24))
        return "chat_\(prefix)"
    }

    private func saveChatIdMapping(mappingKey: String, chatId: String) {
        let key = userDefaultsPrefix + mappingKey
        UserDefaults.standard.set(chatId, forKey: key)
        print("ConversationManager: Saved mapping \(mappingKey) -> \(chatId)")
    }

    private func getChatIdMapping(for mappingKey: String) -> String? {
        let key = userDefaultsPrefix + mappingKey
        return UserDefaults.standard.string(forKey: key)
    }

    private func removeChatIdMapping(for mappingKey: String) {
        let key = userDefaultsPrefix + mappingKey
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func isValidBackendChatId(_ chatId: String) -> Bool {
        chatId.hasPrefix(chatIdPrefix) && chatId.count > chatIdPrefix.count
    }

    // MARK: - Backend API Calls

    private func resolveChatOnBackend(
        userId: String,
        preferredChatId: String?
    ) async -> String? {
        do {
            let response: ResolveChatAPIResponse = try await APIClient.shared.post(
                "/chat/resolve",
                body: ResolveChatAPIRequest(
                    userId: userId,
                    chatId: preferredChatId,
                    appleUUID: nil,
                    title: nil
                )
            )

            guard isValidBackendChatId(response.chatId) else {
                print("ConversationManager: Invalid backend chat id format: \(response.chatId)")
                return nil
            }

            return response.chatId
        } catch {
            lastResolutionError = error
            print("ConversationManager: Failed to resolve chat on backend: \(error)")
            return nil
        }
    }
}

// MARK: - Request/Response Types

struct ResolveChatAPIRequest: Codable {
    let userId: String
    let chatId: String?
    let appleUUID: String?
    let title: String?
}

struct ResolveChatAPIResponse: Codable {
    let chatId: String
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
