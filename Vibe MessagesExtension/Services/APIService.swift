import Foundation

/**
 * APIService.swift
 * Handles networking for the Vibe iMessage extension.
 */
class APIService {
    static let shared = APIService()
    
    #if DEBUG
    private let baseURL = "http://localhost:3000/api"
    #else
    private let baseURL = "https://your-production-server.com/api"
    #endif
    
    private let decoder: JSONDecoder
    
    private init() {
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    /**
     * Uploads a video vibe using multipart/form-data.
     * Returns the videoId and the public videoUrl.
     */
    func uploadVideo(videoData: Data, userId: String, chatId: String, isLocked: Bool) async throws -> (videoId: String, videoUrl: String) {
        guard let url = URL(string: "\(baseURL)/vibe/upload") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
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
        
        // Video file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"video.mp4\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(videoData)
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
        }
        
        let decoded = try JSONDecoder().decode(UploadResponse.self, from: data)
        return (decoded.videoId, decoded.videoUrl)
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
    
    /**
     * Returns the current streak for a specific group/chatId.
     */
    func fetchStreak(chatId: String) async throws -> Streak {
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
}
