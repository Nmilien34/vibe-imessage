//
//  MessageService.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import Foundation
import Messages
import UIKit
import AVFoundation

/// Service for creating and managing iMessage messages
final class MessageService: Sendable {

    // MARK: - Singleton
    static let shared = MessageService()
    private init() {}

    // MARK: - Message Creation

    /// Creates an MSMessage for a video story
    /// - Parameters:
    ///   - video: The video recording to create a message for
    ///   - isLocked: Whether the content is locked (requires unlock to view)
    ///   - userId: The user ID of the sender
    ///   - expiresIn: Hours until expiration (default 24)
    /// - Returns: An MSMessage ready to be inserted into the conversation
    func createStoryMessage(
        video: VideoRecording,
        isLocked: Bool,
        userId: String,
        expiresIn: Int = 24
    ) -> MSMessage {
        let message = MSMessage()

        // Create URL with query parameters
        message.url = createMessageURL(
            videoId: video.id.uuidString,
            isLocked: isLocked,
            userId: userId
        )

        // Create template layout
        let layout = MSMessageTemplateLayout()

        // Set thumbnail image
        if let thumbnail = video.thumbnail {
            layout.image = thumbnail
        } else {
            // Generate thumbnail if not available
            if let generatedThumbnail = generateThumbnail(from: video.url) {
                layout.image = generatedThumbnail
            }
        }

        // Set caption with expiration time
        layout.caption = "\(getDisplayName())'s Moment"

        // Set subcaption with expiration and lock status
        var subcaption = "Expires in \(expiresIn)h"
        if isLocked {
            subcaption = "🔒 " + subcaption
        }
        layout.subcaption = subcaption

        // Set trailing subcaption for duration
        layout.trailingSubcaption = video.formattedDuration

        message.layout = layout

        return message
    }

    /// Creates an MSMessage for different vibe types
    /// - Parameters:
    ///   - vibe: The vibe to create a message for
    ///   - thumbnail: Optional thumbnail image
    /// - Returns: An MSMessage ready to be inserted into the conversation
    func createVibeMessage(vibe: Vibe, thumbnail: UIImage? = nil) -> MSMessage {
        let message = MSMessage()

        // Create URL with vibe ID
        message.url = createVibeURL(vibeId: vibe.id, isLocked: vibe.isLocked)

        // Create template layout
        let layout = MSMessageTemplateLayout()

        // Set image based on vibe type
        if let thumbnail = thumbnail {
            layout.image = thumbnail
        } else {
            layout.image = createVibeTypeImage(for: vibe)
        }

        // Set caption based on vibe type
        layout.caption = createCaption(for: vibe)

        // Set subcaption with expiration and lock
        var subcaption = "Expires \(vibe.timeRemainingFormatted)"
        if vibe.isLocked {
            subcaption = "🔒 " + subcaption
        }
        layout.subcaption = subcaption

        message.layout = layout

        return message
    }

    // MARK: - URL Creation

    /// Creates a URL with query parameters for video messages
    private func createMessageURL(videoId: String, isLocked: Bool, userId: String) -> URL? {
        var components = URLComponents()
        components.scheme = "vibe"
        components.host = "story"
        components.queryItems = [
            URLQueryItem(name: "videoId", value: videoId),
            URLQueryItem(name: "locked", value: String(isLocked)),
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "timestamp", value: String(Int(Date().timeIntervalSince1970)))
        ]
        return components.url
    }

    /// Creates a URL with query parameters for vibe messages
    private func createVibeURL(vibeId: String, isLocked: Bool) -> URL? {
        var components = URLComponents()
        components.scheme = "vibe"
        components.host = "view"
        components.queryItems = [
            URLQueryItem(name: "vibeId", value: vibeId),
            URLQueryItem(name: "locked", value: String(isLocked))
        ]
        return components.url
    }

    /// Parses a message URL to extract parameters
    func parseMessageURL(_ url: URL) -> MessageURLParams? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }

        var params: [String: String] = [:]
        for item in queryItems {
            if let value = item.value {
                params[item.name] = value
            }
        }

        return MessageURLParams(
            videoId: params["videoId"],
            vibeId: params["vibeId"],
            isLocked: params["locked"] == "true",
            userId: params["userId"],
            timestamp: params["timestamp"].flatMap { Int($0) }
        )
    }

    // MARK: - Thumbnail Generation

    /// Generates a thumbnail from a video URL (Synchronous wrapper - use with caution or prefer async)
    func generateThumbnail(from videoURL: URL) -> UIImage? {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 300, height: 300)
        
        // Using semaphores to wait for async replacement:
        let semaphore = DispatchSemaphore(value: 0)
        var resultImage: UIImage?
        
        imageGenerator.generateCGImageAsynchronously(for: .zero) { cgImage, _, error in
            if let cgImage = cgImage {
                resultImage = UIImage(cgImage: cgImage)
            }
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 2.0)
        return resultImage
    }

    /// Generates a thumbnail asynchronously
    func generateThumbnail(from videoURL: URL) async -> UIImage? {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 300, height: 300)
        
        do {
            let (cgImage, _) = try await imageGenerator.image(at: .zero)
            return UIImage(cgImage: cgImage)
        } catch {
            print("MessageService: Error generating thumbnail: \(error)")
            return nil
        }
    }

    // MARK: - Helper Functions

    /// Gets a display name for the current user
    private func getDisplayName() -> String {
        // In a real app, this would come from user profile
        // For now, return a generic name
        return "Your"
    }

    /// Creates a caption for a vibe based on its type
    private func createCaption(for vibe: Vibe) -> String {
        switch vibe.type {
        case .photo:
            return "\(getDisplayName()) Photo"
        case .video:
            return "\(getDisplayName()) Moment"
        case .song:
            if let song = vibe.songData {
                return "🎵 \(song.title)"
            }
            return "🎵 Listening to..."
        case .battery:
            if let level = vibe.batteryLevel {
                return "🔋 \(level)%"
            }
            return "🔋 Battery Check"
        case .mood:
            if let mood = vibe.mood {
                return "\(mood.emoji) \(mood.text ?? "Current Mood")"
            }
            return "Current Mood"
        case .poll:
            if let poll = vibe.poll {
                return "📊 \(poll.question)"
            }
            return "📊 Quick Poll"
        case .dailyDrop:
            return "🎲 Daily Drop"
        case .tea:
            if let text = vibe.textStatus {
                return "🫖 \(text)"
            }
            return "🫖 Spilling Tea"
        case .leak:
            return "📸 Camera Leak"
        case .sketch:
            return "✏️ Quick Sketch"
        case .eta:
            if let eta = vibe.etaStatus {
                return "📍 \(eta)"
            }
            return "📍 ETA"
        case .parlay:
            if let parlay = vibe.parlay {
                return "💸 \(parlay.title) - \(parlay.amount)"
            }
            return "💸 Parlay"
        }
    }

    /// Creates a placeholder image for vibe types without thumbnails
    private func createVibeTypeImage(for vibe: Vibe) -> UIImage? {
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Background color based on vibe type
            let backgroundColor: UIColor
            switch vibe.type {
            case .photo:
                backgroundColor = UIColor.systemBlue
            case .video:
                backgroundColor = UIColor.systemPink
            case .song:
                backgroundColor = UIColor.systemGreen
            case .battery:
                backgroundColor = UIColor.systemYellow
            case .mood:
                backgroundColor = UIColor.systemPurple
            case .poll:
                backgroundColor = UIColor.systemBlue
            case .dailyDrop:
                backgroundColor = UIColor.black
            case .tea:
                backgroundColor = UIColor.brown
            case .leak:
                backgroundColor = UIColor.systemRed
            case .sketch:
                backgroundColor = UIColor.systemOrange
            case .eta:
                backgroundColor = UIColor.systemBlue
            case .parlay:
                backgroundColor = UIColor.systemPink
            }

            backgroundColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw icon or emoji in center
            let iconText: String
            switch vibe.type {
            case .photo:
                iconText = "📸"
            case .video:
                iconText = "🎬"
            case .song:
                iconText = "🎵"
            case .battery:
                iconText = "🔋"
            case .mood:
                iconText = vibe.mood?.emoji ?? "😊"
            case .poll:
                iconText = "📊"
            case .dailyDrop:
                iconText = "🎲"
            case .tea:
                iconText = "🫖"
            case .leak:
                iconText = "📸"
            case .sketch:
                iconText = "✏️"
            case .eta:
                iconText = "📍"
            case .parlay:
                iconText = "💸"
            }

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 100)
            ]

            let textSize = iconText.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )

            iconText.draw(in: textRect, withAttributes: attributes)
        }
    }
}

// MARK: - Message URL Parameters
struct MessageURLParams {
    let videoId: String?
    let vibeId: String?
    let isLocked: Bool
    let userId: String?
    let timestamp: Int?

    /// Returns the date from timestamp
    var date: Date? {
        guard let timestamp = timestamp else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}

// MARK: - MSMessage Extension
extension MSMessage {
    /// Convenience initializer for creating a vibe message
    convenience init(vibe: Vibe, thumbnail: UIImage? = nil) {
        self.init()

        let service = MessageService.shared
        let message = service.createVibeMessage(vibe: vibe, thumbnail: thumbnail)

        self.url = message.url
        self.layout = message.layout
    }
}
