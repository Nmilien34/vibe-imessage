import Foundation

/**
 * APIService.swift
 * Handles networking for the Vibe iMessage extension.
 */
class APIService {
    static let shared = APIService()

    // SET THIS TO TRUE TO ENABLE MOCK MODE (No Backend Required)
    // IMPORTANT: Must be FALSE for production!
    private let useMockData = false

    #if DEBUG
    private let baseURL = "http://localhost:3000/api"
    #else
    private let baseURL = "https://vibe-imessage.onrender.com/api"
    #endif

    private let decoder: JSONDecoder

    private init() {
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Mock Data
    private var mockVibes: [Vibe] = APIService.generateMockVibes()

    private static func generateMockVibes() -> [Vibe] {
        [
            Vibe(
                id: "mock_1",
                oderId: nil,
                userId: "user_friend_1",
                conversationId: "conv_1",
                type: .video,
                mediaUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
                thumbnailUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg",
                songData: nil,
                batteryLevel: nil,
                mood: nil,
                poll: nil,
                parlay: nil,
                textStatus: nil,
                styleName: nil,
                etaStatus: nil,
                isLocked: false,
                unlockedBy: [],
                reactions: [Reaction(userId: "user_me", emoji: "🔥")],
                viewedBy: [],
                expiresAt: Date().addingTimeInterval(86400),
                createdAt: Date().addingTimeInterval(-300),
                updatedAt: Date().addingTimeInterval(-300)
            ),
            Vibe(
                id: "mock_2",
                oderId: nil,
                userId: "user_friend_2",
                conversationId: "conv_1",
                type: .mood,
                mediaUrl: nil,
                thumbnailUrl: nil,
                songData: nil,
                batteryLevel: nil,
                mood: Mood(emoji: "🚀", text: "Building something cool!"),
                poll: nil,
                parlay: nil,
                textStatus: nil,
                styleName: nil,
                etaStatus: nil,
                isLocked: false,
                unlockedBy: [],
                reactions: [],
                viewedBy: [],
                expiresAt: Date().addingTimeInterval(72000),
                createdAt: Date().addingTimeInterval(-600),
                updatedAt: Date().addingTimeInterval(-600)
            ),
            Vibe(
                id: "mock_3",
                oderId: nil,
                userId: "user_friend_3",
                conversationId: "conv_1",
                type: .battery,
                mediaUrl: nil,
                thumbnailUrl: nil,
                songData: nil,
                batteryLevel: 15,
                mood: nil,
                poll: nil,
                parlay: nil,
                textStatus: nil,
                styleName: nil,
                etaStatus: nil,
                isLocked: false,
                unlockedBy: [],
                reactions: [],
                viewedBy: [],
                expiresAt: Date().addingTimeInterval(50000),
                createdAt: Date().addingTimeInterval(-1200),
                updatedAt: Date().addingTimeInterval(-1200)
            ),
            Vibe(
                id: "mock_4",
                oderId: nil,
                userId: "user_me",
                conversationId: "conv_1",
                type: .photo,
                mediaUrl: "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?q=80&w=1000&auto=format&fit=crop",
                thumbnailUrl: nil,
                songData: nil,
                batteryLevel: nil,
                mood: nil,
                poll: nil,
                parlay: nil,
                textStatus: nil,
                styleName: nil,
                etaStatus: nil,
                isLocked: false,
                unlockedBy: [],
                reactions: [Reaction(userId: "user_friend_1", emoji: "❤️")],
                viewedBy: ["user_friend_1", "user_friend_2"],
                expiresAt: Date().addingTimeInterval(40000),
                createdAt: Date().addingTimeInterval(-3600),
                updatedAt: Date().addingTimeInterval(-3600)
            )
        ]
    }
    
    /// Video upload result
    struct VideoUploadResult {
        let videoId: String
        let videoUrl: String
        let videoKey: String?
    }

    /**
     * Uploads a video vibe using multipart/form-data.
     * Returns the videoId, public videoUrl, and S3 key for cleanup tracking.
     */
    func uploadMedia(mediaData: Data, userId: String, chatId: String, isLocked: Bool, isVideo: Bool) async throws -> VideoUploadResult {
        if useMockData {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1s delay to simulate upload
            let mockId = UUID().uuidString
            return VideoUploadResult(
                videoId: mockId,
                videoUrl: "https://mock-s3.com/media/\(mockId).\(isVideo ? "mp4" : "jpg")",
                videoKey: "media/\(mockId).\(isVideo ? "mp4" : "jpg")"
            )
        }

        guard let url = URL(string: "\(baseURL)/vibe/upload") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60 // 1 minute timeout for uploads

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Helper to append text fields
        func appendTextField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendTextField(name: "userId", value: userId)
        appendTextField(name: "chatId", value: chatId)
        appendTextField(name: "isLocked", value: isLocked ? "true" : "false")

        // Media file
        let filename = isVideo ? "video.mp4" : "photo.jpg"
        let contentType = isVideo ? "video/mp4" : "image/jpeg"
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(mediaData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: "Upload failed")
        }

        struct UploadResponse: Decodable {
            let videoId: String
            let videoUrl: String
            let videoKey: String?
        }

        let decoded = try JSONDecoder().decode(UploadResponse.self, from: data)
        return VideoUploadResult(videoId: decoded.videoId, videoUrl: decoded.videoUrl, videoKey: decoded.videoKey)
    }
    
    /**
     * Fetches metadata for a specific story.
     * Checks lock status based on userId.
     */
    func getStory(videoId: String, userId: String) async throws -> Vibe {
        guard var components = URLComponents(string: "\(baseURL)/vibe/\(videoId)") else {
            throw APIError.invalidURL
        }
        
        components.queryItems = [URLQueryItem(name: "userId", value: userId)]
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        return try decoder.decode(Vibe.self, from: data)
    }
    
    /**
     * Marks a story as unlocked for the current user.
     */
    func unlockStory(videoId: String, userId: String) async throws {
        guard let url = URL(string: "\(baseURL)/vibe/\(videoId)/unlock") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["userId": userId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    /**
     * Returns all active stories for a specific group/chatId.
     */
    func getFeed(chatId: String) async throws -> [Vibe] {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3s delay
            return mockVibes.sorted { $0.createdAt > $1.createdAt }
        }

        guard let url = URL(string: "\(baseURL)/vibe/feed/\(chatId)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode([Vibe].self, from: data)
    }

    // MARK: - Unified Feed (New Distributed ID System)

    /**
     * Returns the unified feed - all vibes from all chats the user belongs to.
     * This is the main feed endpoint for the new architecture.
     */
    func getUnifiedFeed(userId: String, limit: Int = 50, offset: Int = 0) async throws -> UnifiedFeedResponse {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)
            return UnifiedFeedResponse(
                vibes: mockVibes.sorted { $0.createdAt > $1.createdAt },
                hasMore: false
            )
        }

        guard var components = URLComponents(string: "\(baseURL)/feed/my-feed") else {
            throw APIError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode(UnifiedFeedResponse.self, from: data)
    }

    /**
     * Returns vibes for a specific chat.
     */
    func getChatFeed(chatId: String, userId: String) async throws -> [Vibe] {
        if useMockData {
            try await Task.sleep(nanoseconds: 200_000_000)
            return mockVibes.sorted { $0.createdAt > $1.createdAt }
        }

        guard var components = URLComponents(string: "\(baseURL)/feed/chat/\(chatId)") else {
            throw APIError.invalidURL
        }

        components.queryItems = [URLQueryItem(name: "userId", value: userId)]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode([Vibe].self, from: data)
    }

    /**
     * Returns vibe history for a user (up to 15 days).
     * Includes vibes that are expired from the main feed but still within retention period.
     */
    func getHistory(chatId: String, userId: String, limit: Int = 50) async throws -> [Vibe] {
        guard var components = URLComponents(string: "\(baseURL)/vibes/\(chatId)/history") else {
            throw APIError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode([Vibe].self, from: data)
    }
    
    /**
     * Returns the current streak for a specific group/chatId.
     */
    func fetchStreak(chatId: String) async throws -> Streak {
        if useMockData {
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2s delay
            return Streak(
                conversationId: chatId,
                currentStreak: 5,
                longestStreak: 12,
                lastPostDate: Date(),
                todayPosters: ["user_me", "user_friend_1"]
            )
        }

        guard let url = URL(string: "\(baseURL)/vibes/\(chatId)/streak") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode(Streak.self, from: data)
    }

    // MARK: - Interactions (Migrated from VibeService)

    func createVibe(_ requestBody: CreateVibeRequest) async throws -> Vibe {
        if useMockData {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
            let newVibe = Vibe(
                id: UUID().uuidString,
                oderId: nil,
                userId: requestBody.userId,
                chatId: requestBody.chatId,
                conversationId: requestBody.conversationId ?? requestBody.chatId,
                type: requestBody.type,
                mediaUrl: requestBody.mediaUrl,
                thumbnailUrl: requestBody.thumbnailUrl,
                songData: requestBody.songData,
                batteryLevel: requestBody.batteryLevel,
                mood: requestBody.mood,
                poll: requestBody.poll.map { Poll(question: $0.question, options: $0.options.map { PollOption(text: $0) }) },
                parlay: requestBody.parlay.map { Parlay(title: $0.title, question: $0.question, options: $0.options, amount: $0.amount, wager: $0.wager, opponentId: $0.opponentId, opponentName: $0.opponentName, status: .pending, expiresAt: nil, votes: nil, winnersReceived: nil) },
                textStatus: requestBody.textStatus,
                styleName: requestBody.styleName,
                etaStatus: requestBody.etaStatus,
                isLocked: requestBody.isLocked,
                unlockedBy: [],
                reactions: [],
                viewedBy: [],
                expiresAt: Date().addingTimeInterval(86400),
                createdAt: Date(),
                updatedAt: Date()
            )
            mockVibes.insert(newVibe, at: 0)
            return newVibe
        }

        guard let url = URL(string: "\(baseURL)/vibes") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode(Vibe.self, from: data)
    }

    func addReaction(vibeId: String, userId: String, emoji: String) async throws -> Vibe {
        if useMockData {
            try await Task.sleep(nanoseconds: 200_000_000)
            if let index = mockVibes.firstIndex(where: { $0.id == vibeId }) {
                var vibe = mockVibes[index]
                var reactions = vibe.reactions.filter { $0.userId != userId }
                reactions.append(Reaction(userId: userId, emoji: emoji))
                vibe = Vibe(
                    id: vibe.id, oderId: vibe.oderId, userId: vibe.userId,
                    conversationId: vibe.conversationId, type: vibe.type,
                    mediaUrl: vibe.mediaUrl, thumbnailUrl: vibe.thumbnailUrl,
                    songData: vibe.songData, batteryLevel: vibe.batteryLevel,
                    mood: vibe.mood, poll: vibe.poll, parlay: vibe.parlay,
                    textStatus: vibe.textStatus, styleName: vibe.styleName, etaStatus: vibe.etaStatus,
                    isLocked: vibe.isLocked, unlockedBy: vibe.unlockedBy,
                    reactions: reactions, viewedBy: vibe.viewedBy,
                    expiresAt: vibe.expiresAt, createdAt: vibe.createdAt, updatedAt: Date()
                )
                mockVibes[index] = vibe
                return vibe
            }
            throw APIError.invalidResponse
        }

        guard let url = URL(string: "\(baseURL)/vibes/\(vibeId)/react") else {
            throw APIError.invalidURL
        }

        struct ReactRequest: Codable {
            let userId: String
            let emoji: String
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ReactRequest(userId: userId, emoji: emoji))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode(Vibe.self, from: data)
    }

    func markViewed(vibeId: String, userId: String) async throws -> Vibe {
        if useMockData {
            try await Task.sleep(nanoseconds: 100_000_000)
            if let index = mockVibes.firstIndex(where: { $0.id == vibeId }) {
                var vibe = mockVibes[index]
                var viewedBy = vibe.viewedBy
                if !viewedBy.contains(userId) { viewedBy.append(userId) }
                vibe = Vibe(
                    id: vibe.id, oderId: vibe.oderId, userId: vibe.userId,
                    conversationId: vibe.conversationId, type: vibe.type,
                    mediaUrl: vibe.mediaUrl, thumbnailUrl: vibe.thumbnailUrl,
                    songData: vibe.songData, batteryLevel: vibe.batteryLevel,
                    mood: vibe.mood, poll: vibe.poll, parlay: vibe.parlay,
                    textStatus: vibe.textStatus, styleName: vibe.styleName, etaStatus: vibe.etaStatus,
                    isLocked: vibe.isLocked, unlockedBy: vibe.unlockedBy,
                    reactions: vibe.reactions, viewedBy: viewedBy,
                    expiresAt: vibe.expiresAt, createdAt: vibe.createdAt, updatedAt: Date()
                )
                mockVibes[index] = vibe
                return vibe
            }
            throw APIError.invalidResponse
        }

        guard let url = URL(string: "\(baseURL)/vibes/\(vibeId)/view") else {
            throw APIError.invalidURL
        }

        struct ViewRequest: Codable {
            let userId: String
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ViewRequest(userId: userId))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode(Vibe.self, from: data)
    }

    func vote(vibeId: String, optionId: String, userId: String) async throws -> Vibe {
        guard let url = URL(string: "\(baseURL)/vibes/\(vibeId)/vote") else {
            throw APIError.invalidURL
        }
        
        struct VoteRequest: Codable {
            let userId: String
            let optionId: String
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(VoteRequest(userId: userId, optionId: optionId))
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        return try decoder.decode(Vibe.self, from: data)
    }

    func respondToParlay(vibeId: String, userId: String, status: String) async throws -> Vibe {
        guard let url = URL(string: "\(baseURL)/vibes/\(vibeId)/parlay/respond") else {
            throw APIError.invalidURL
        }

        struct RespondRequest: Codable {
            let userId: String
            let status: String
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RespondRequest(userId: userId, status: status))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode(Vibe.self, from: data)
    }

    // MARK: - Reminders

    private var mockReminders: [Reminder] = []

    func getReminders(chatId: String) async throws -> [Reminder] {
        if useMockData {
            try await Task.sleep(nanoseconds: 200_000_000)
            return mockReminders
                .filter { $0.chatId == chatId && $0.date >= Date().addingTimeInterval(-86400) }
                .sorted { $0.date < $1.date }
        }

        guard let url = URL(string: "\(baseURL)/reminders/\(chatId)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode([Reminder].self, from: data)
    }

    func createReminder(chatId: String, userId: String, type: ReminderType, emoji: String, title: String, date: Date) async throws -> Reminder {
        if useMockData {
            try await Task.sleep(nanoseconds: 300_000_000)
            let reminder = Reminder(
                id: UUID().uuidString,
                chatId: chatId,
                userId: userId,
                type: type,
                emoji: emoji,
                title: title,
                date: date,
                createdAt: Date()
            )
            mockReminders.append(reminder)
            return reminder
        }

        guard let url = URL(string: "\(baseURL)/reminders") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct CreateReminderRequest: Encodable {
            let chatId: String
            let userId: String
            let type: ReminderType
            let emoji: String
            let title: String
            let date: Date
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(CreateReminderRequest(
            chatId: chatId, userId: userId, type: type, emoji: emoji, title: title, date: date
        ))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode(Reminder.self, from: data)
    }

    func deleteReminder(id: String, userId: String) async throws {
        if useMockData {
            try await Task.sleep(nanoseconds: 200_000_000)
            mockReminders.removeAll { $0.id == id }
            return
        }

        guard let url = URL(string: "\(baseURL)/reminders/\(id)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["userId": userId])

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }

    // MARK: - Group Streaks (Section 9.1)

    /**
     * Returns the current streak for a group/chatId using the new group route.
     */
    func fetchGroupStreak(chatId: String) async throws -> GroupStreak {
        guard let url = URL(string: "\(baseURL)/group/\(chatId)/streak") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        return try decoder.decode(GroupStreak.self, from: data)
    }

    /**
     * Manually increments/updates the streak for a group.
     */
    func incrementGroupStreak(chatId: String, userId: String) async throws -> GroupStreak {
        guard let url = URL(string: "\(baseURL)/group/\(chatId)/streak") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["userId": userId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        return try decoder.decode(GroupStreak.self, from: data)
    }

    func getVibeWire() async throws -> [NewsItem] {
        if useMockData {
            return []
        }
        return try await APIClient.shared.get("/vibewire")
    }
}
