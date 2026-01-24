//
//  APIClient.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case networkError(Error)
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, let message):
            return message ?? "HTTP Error: \(statusCode)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .uploadFailed:
            return "Upload failed"
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    // SET THIS TO TRUE TO ENABLE MOCK MODE (No Backend Required)
    let useMockData = true

    #if DEBUG
    private let baseURL = "http://localhost:3000/api"
    #else
    private let baseURL = "https://your-production-server.com/api"
    #endif

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // MARK: - Mock Data Store
    private var mockVibes: [Vibe] = []
    private var mockUsers: [String: String] = ["user123": "You"]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Handle ISO8601 variations
            if let date = ISO8601DateFormatter().date(from: dateString) {
                return date
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        
        // Load mock data asynchronously or lazily
        self.loadMockData()
    }

    private func loadMockData() {
        self.mockVibes = [
            // 1. Unlocked Video (Story) - Friend 1
            Vibe(
                id: UUID().uuidString,
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
            
            // 2. Unlocked Photo - Friend 2
            Vibe(
                id: UUID().uuidString,
                oderId: nil,
                userId: "user_friend_2",
                conversationId: "conv_1",
                type: .photo,
                mediaUrl: "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?q=80&w=1000&auto=format&fit=crop",
                thumbnailUrl: nil,
                songData: nil,
                batteryLevel: nil,
                mood: nil,
                poll: nil,
                textStatus: nil,
                styleName: nil,
                etaStatus: nil,
                isLocked: false,
                unlockedBy: [],
                reactions: [],
                viewedBy: [],
                expiresAt: Date().addingTimeInterval(85000),
                createdAt: Date().addingTimeInterval(-1200),
                updatedAt: Date().addingTimeInterval(-1200)
            ),

            // 3. Locked POV - Friend 3
            Vibe(
                id: UUID().uuidString,
                oderId: nil,
                userId: "user_friend_3",
                conversationId: "conv_1",
                type: .video,
                mediaUrl: nil,
                thumbnailUrl: nil,
                songData: nil,
                batteryLevel: nil,
                mood: nil,
                poll: nil,
                textStatus: nil,
                styleName: nil,
                etaStatus: nil,
                isLocked: true,
                unlockedBy: [],
                reactions: [],
                viewedBy: [],
                expiresAt: Date().addingTimeInterval(80000),
                createdAt: Date().addingTimeInterval(-3600),
                updatedAt: Date().addingTimeInterval(-3600)
            ),

            // 4. Unlocked Mood - Friend 1
            Vibe(
                id: UUID().uuidString,
                oderId: nil,
                userId: "user_friend_1",
                conversationId: "conv_1",
                type: .mood,
                mediaUrl: nil,
                thumbnailUrl: nil,
                songData: nil,
                batteryLevel: nil,
                mood: Mood(emoji: "🚀", text: "Launching something new!"),
                poll: nil,
                textStatus: nil,
                styleName: nil,
                etaStatus: nil,
                isLocked: false,
                unlockedBy: [],
                reactions: [],
                viewedBy: ["user_me"],
                expiresAt: Date().addingTimeInterval(40000),
                createdAt: Date().addingTimeInterval(-7200),
                updatedAt: Date().addingTimeInterval(-7200)
            ),

            // 5. Unlocked Poll - Friend 4
            Vibe(
                id: UUID().uuidString,
                oderId: nil,
                userId: "user_friend_4",
                conversationId: "conv_1",
                type: .poll,
                mediaUrl: nil,
                thumbnailUrl: nil,
                songData: nil,
                batteryLevel: nil,
                mood: nil,
                poll: Poll(question: "Pizza or Tacos?", options: [PollOption(id: "o1", text: "Pizza"), PollOption(id: "o2", text: "Tacos")]),
                textStatus: nil,
                styleName: nil,
                etaStatus: nil,
                isLocked: false,
                unlockedBy: [],
                reactions: [],
                viewedBy: [],
                expiresAt: Date().addingTimeInterval(90000),
                createdAt: Date().addingTimeInterval(-100),
                updatedAt: Date().addingTimeInterval(-100)
            ),
            
            // 6. Unlocked Battery - Friend 5
            Vibe(
                id: UUID().uuidString,
                oderId: nil,
                userId: "user_friend_5",
                conversationId: "conv_1",
                type: .battery,
                mediaUrl: nil,
                thumbnailUrl: nil,
                songData: nil,
                batteryLevel: 12,
                mood: nil,
                poll: nil,
                textStatus: nil,
                styleName: nil,
                etaStatus: nil,
                isLocked: false,
                unlockedBy: [],
                reactions: [Reaction(userId: "user_me", emoji: "🪫")],
                viewedBy: [],
                expiresAt: Date().addingTimeInterval(3600),
                createdAt: Date().addingTimeInterval(-50),
                updatedAt: Date().addingTimeInterval(-50)
            ),

            // 7. Unlocked Song - Friend 2
            Vibe(
                id: UUID().uuidString,
                oderId: nil,
                userId: "user_friend_2",
                conversationId: "conv_1",
                type: .song,
                mediaUrl: nil,
                thumbnailUrl: nil,
                songData: SongData(
                    title: "Starboy",
                    artist: "The Weeknd",
                    albumArt: "https://upload.wikimedia.org/wikipedia/en/3/39/The_Weeknd_-_Starboy.png",
                    previewUrl: nil,
                    spotifyId: "s1"
                ),
                batteryLevel: nil,
                mood: nil,
                poll: nil,
                textStatus: nil,
                styleName: nil,
                etaStatus: nil,
                isLocked: false,
                unlockedBy: [],
                reactions: [],
                viewedBy: [],
                expiresAt: Date().addingTimeInterval(70000),
                createdAt: Date().addingTimeInterval(-5000),
                updatedAt: Date().addingTimeInterval(-5000)
            ),
            
            // --- PROFILE / HISTORY (user_me) ---
            
            Vibe(
                id: UUID().uuidString,
                oderId: nil,
                userId: "user_me",
                conversationId: "conv_1",
                type: .mood,
                mediaUrl: nil,
                thumbnailUrl: nil,
                songData: nil,
                batteryLevel: nil,
                mood: Mood(emoji: "😴", text: "Long day..."),
                poll: nil,
                textStatus: nil,
                styleName: nil,
                etaStatus: nil,
                isLocked: false,
                unlockedBy: [],
                reactions: [Reaction(userId: "user_friend_1", emoji: "☕️")],
                viewedBy: ["user_friend_1", "user_friend_2"],
                expiresAt: Date().addingTimeInterval(10000),
                createdAt: Date().addingTimeInterval(-40000),
                updatedAt: Date().addingTimeInterval(-40000)
            ),
            
            Vibe(
                id: UUID().uuidString,
                oderId: nil,
                userId: "user_me",
                conversationId: "conv_1",
                type: .photo,
                mediaUrl: "https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?q=80&w=1000&auto=format&fit=crop",
                thumbnailUrl: nil,
                songData: nil,
                batteryLevel: nil,
                mood: nil,
                poll: pollPlaceholder(),
                textStatus: nil,
                styleName: nil,
                etaStatus: nil,
                isLocked: false,
                unlockedBy: [],
                reactions: [Reaction(userId: "user_friend_2", emoji: "⛰️")],
                viewedBy: ["user_friend_2"],
                expiresAt: Date().addingTimeInterval(20000),
                createdAt: Date().addingTimeInterval(-50000),
                updatedAt: Date().addingTimeInterval(-50000)
            ),
            
            Vibe(
                id: UUID().uuidString,
                oderId: nil,
                userId: "user_me",
                conversationId: "conv_1",
                type: .song,
                mediaUrl: nil,
                thumbnailUrl: nil,
                songData: SongData(
                    title: "Midnight City",
                    artist: "M83",
                    albumArt: "https://upload.wikimedia.org/wikipedia/en/7/7b/M83_-_Midnight_City.jpg",
                    previewUrl: nil,
                    spotifyId: "song_1"
                ),
                batteryLevel: nil,
                mood: nil,
                poll: nil,
                textStatus: nil,
                styleName: nil,
                etaStatus: nil,
                isLocked: false,
                unlockedBy: [],
                reactions: [],
                viewedBy: [],
                expiresAt: Date().addingTimeInterval(5000),
                createdAt: Date().addingTimeInterval(-80000),
                updatedAt: Date().addingTimeInterval(-80000)
            ),
            
            Vibe(
                id: UUID().uuidString,
                oderId: nil,
                userId: "user_me",
                conversationId: "conv_1",
                type: .battery,
                mediaUrl: nil,
                thumbnailUrl: nil,
                songData: nil,
                batteryLevel: 95,
                mood: nil,
                poll: nil,
                textStatus: nil,
                styleName: nil,
                etaStatus: nil,
                isLocked: false,
                unlockedBy: [],
                reactions: [],
                viewedBy: [],
                expiresAt: Date().addingTimeInterval(2000),
                createdAt: Date().addingTimeInterval(-85000),
                updatedAt: Date().addingTimeInterval(-85000)
            )
        ]
    }

    private func pollPlaceholder() -> Poll? { nil }


    func get<T: Decodable>(_ path: String) async throws -> T {
        print("API Debug: GET request to \(path)")
        if useMockData {
            return try await performMockGet(path)
        }
        
        let urlString = baseURL + path
        guard let url = URL(string: urlString) else {
            print("API Error: Malformed URL string: \(urlString)")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        return try await performRequest(request)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        print("API Debug: POST request to \(path)")
        if useMockData {
            return try await performMockPost(path, body: body)
        }
        
        let urlString = baseURL + path
        guard let url = URL(string: urlString) else {
            print("API Error: Malformed URL string: \(urlString)")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        return try await performRequest(request)
    }

    func postEmpty<T: Decodable>(_ path: String) async throws -> T {
        if useMockData {
            return try await performMockPost(path, body: EmptyBody())
        }
        
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        return try await performRequest(request)
    }

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let message = try? JSONDecoder().decode([String: String].self, from: data)["error"]
                throw APIError.httpError(statusCode: httpResponse.statusCode, message: message)
            }

            return try decoder.decode(T.self, from: data)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - S3 Upload
    func uploadToS3(data: Data, presignedUrl: String, contentType: String) async throws {
        if useMockData {
            // Simulate upload delay
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            return
        }
        
        guard let url = URL(string: presignedUrl) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        do {
            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.uploadFailed
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Mock Implementation
    
    private struct EmptyBody: Encodable {}

    private func performMockGet<T: Decodable>(_ path: String) async throws -> T {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // Handle Streaks (must check before generic vibes, or handle specific suffix)
        if path.hasSuffix("/streak") || path.contains("/streaks") {
            let streak = Streak(
                conversationId: "conv_1",
                currentStreak: 5,
                longestStreak: 12,
                lastPostDate: Date(),
                todayPosters: ["me"]
            )
            let response = StreakResponse(streak: streak)
            if let result = response as? T {
                return result
            }
        }

        // Handle Vibes List
        if path.contains("/vibes") && !path.contains("/streak") {
            // Retrieve vibes (filter by conversation if needed, for now return all)
            let response = VibesResponse(vibes: mockVibes.sorted(by: { $0.createdAt > $1.createdAt }))
            if let result = response as? T {
                return result
            }
        }
        
        if path.contains("/auth/generate-upload-url") {
            let response = PresignedUrlResponse(
                uploadUrl: "https://mock-s3.com/upload",
                publicUrl: "https://mock-s3.com/file.mov",
                key: UUID().uuidString
            )
            if let result = response as? T {
                return result
            }
        }

        throw APIError.invalidURL
    }

    private func performMockPost<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // Handle Apple Auth (Mock)
        if path.contains("/auth/apple") {
            // Since we use Generics T, we need to create the expected structure
            // In a real app we'd decode B to AuthRequest, but here we just return a success response
            let response = """
            {
                "token": "mock_jwt_token_123",
                "user": {
                    "id": "user_me",
                    "firstName": "Vibe",
                    "lastName": "User",
                    "email": "user@example.com"
                }
            }
            """.data(using: .utf8)!
            
            return try decoder.decode(T.self, from: response)
        }
        
        // Add new vibe
        if path.hasSuffix("/vibes") {
             // We need to 'decode' the body to create a vibe, but we can't easily do that generics.
             // For this simple mock, we'll try to cast B or construct a dummy.
             // Since we know the app sends CreateVibeRequest...
            if let request = body as? CreateVibeRequest {
                let newVibe = Vibe(
                    id: UUID().uuidString,
                    oderId: nil,
                    userId: request.userId,
                    conversationId: request.conversationId,
                    type: request.type,
                    mediaUrl: request.mediaUrl,
                    thumbnailUrl: request.thumbnailUrl,
                    songData: request.songData,
                    batteryLevel: request.batteryLevel,
                    mood: request.mood,
                    poll: request.poll.map { Poll(question: $0.question, options: $0.options.map { PollOption(text: $0) }) },
                    textStatus: request.textStatus,
                    styleName: request.styleName,
                    etaStatus: request.etaStatus,
                    isLocked: request.isLocked,
                    unlockedBy: [],
                    reactions: [],
                    viewedBy: [],
                    expiresAt: Date().addingTimeInterval(86400),
                    createdAt: Date(),
                    updatedAt: Date()
                )
                mockVibes.insert(newVibe, at: 0)
                
                if let result = VibeResponse(vibe: newVibe) as? T {
                    return result
                }
            }
        }
        
        // Handle Presigned URL (Mock)
        if path.contains("/upload/presigned-url") {
             let response = PresignedUrlResponse(
                 uploadUrl: "https://mock-s3.com/upload",
                 publicUrl: "https://mock-s3.com/file-\(UUID().uuidString)", // Unique URL to avoid caching issues in mock
                 key: UUID().uuidString
             )
             if let result = response as? T {
                 return result
             }
        }
        
        // Handle Interactions (View, Unlock)
        if path.contains("/view") || path.contains("/unlock") {
             // For simplicity, just return success if T is Void or similar response
             // In a real mock we'd find the vibe and update it
             // Let's assume the response expected is VibeResponse or just success
             if T.self == VibeResponse.self, let vibe = mockVibes.first {
                 return VibeResponse(vibe: vibe) as! T
             }
        }

        throw APIError.invalidURL
    }
}
