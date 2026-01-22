//
//  VibeService.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import Foundation

actor VibeService {
    static let shared = VibeService()
    private let api = APIClient.shared

    private init() {}

    // MARK: - Vibes

    func fetchVibes(conversationId: String) async throws -> [Vibe] {
        let response: VibesResponse = try await api.get("/vibes/\(conversationId)")
        return response.vibes
    }

    func createVibe(_ request: CreateVibeRequest) async throws -> Vibe {
        let response: VibeResponse = try await api.post("/vibes", body: request)
        return response.vibe
    }

    func addReaction(vibeId: String, userId: String, emoji: String) async throws -> Vibe {
        struct ReactRequest: Codable {
            let userId: String
            let emoji: String
        }
        let response: VibeResponse = try await api.post(
            "/vibes/\(vibeId)/react",
            body: ReactRequest(userId: userId, emoji: emoji)
        )
        return response.vibe
    }

    func markViewed(vibeId: String, userId: String) async throws -> Vibe {
        struct ViewRequest: Codable {
            let userId: String
        }
        let response: VibeResponse = try await api.post(
            "/vibes/\(vibeId)/view",
            body: ViewRequest(userId: userId)
        )
        return response.vibe
    }

    func vote(vibeId: String, optionId: String, userId: String) async throws -> Vibe {
        struct VoteRequest: Codable {
            let userId: String
            let optionId: String
        }
        let response: VibeResponse = try await api.post(
            "/vibes/\(vibeId)/vote",
            body: VoteRequest(userId: userId, optionId: optionId)
        )
        return response.vibe
    }

    // MARK: - Streaks

    func fetchStreak(conversationId: String) async throws -> Streak {
        let response: StreakResponse = try await api.get("/vibes/\(conversationId)/streak")
        return response.streak
    }

    // MARK: - Upload

    func getPresignedUrl(fileType: String, folder: String = "vibes") async throws -> PresignedUrlResponse {
        struct PresignedRequest: Codable {
            let fileType: String
            let folder: String
        }
        return try await api.post(
            "/upload/presigned-url",
            body: PresignedRequest(fileType: fileType, folder: folder)
        )
    }

    func uploadMedia(data: Data, fileType: String, folder: String = "vibes") async throws -> String {
        // Get presigned URL
        let presigned = try await getPresignedUrl(fileType: fileType, folder: folder)

        // Determine content type
        let contentType: String
        switch fileType.lowercased() {
        case "mp4", "mov":
            contentType = "video/\(fileType.lowercased())"
        case "jpg", "jpeg":
            contentType = "image/jpeg"
        case "png":
            contentType = "image/png"
        case "gif":
            contentType = "image/gif"
        default:
            contentType = "application/octet-stream"
        }

        // Upload to S3
        try await api.uploadToS3(data: data, presignedUrl: presigned.uploadUrl, contentType: contentType)

        return presigned.publicUrl
    }
}
