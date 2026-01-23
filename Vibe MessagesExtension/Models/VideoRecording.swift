//
//  VideoRecording.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import Foundation
import UIKit

/// Represents a recorded video with its metadata
struct VideoRecording: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let duration: TimeInterval
    let thumbnail: UIImage?
    let timestamp: Date

    /// Maximum allowed duration for a vibe video (15 seconds)
    static let maxDuration: TimeInterval = 15.0

    init(
        id: UUID = UUID(),
        url: URL,
        duration: TimeInterval,
        thumbnail: UIImage? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.duration = duration
        self.thumbnail = thumbnail
        self.timestamp = timestamp
    }

    /// Returns the video data if the file exists
    var videoData: Data? {
        try? Data(contentsOf: url)
    }

    /// Formatted duration string (e.g., "0:15")
    var formattedDuration: String {
        let seconds = Int(duration)
        return String(format: "0:%02d", seconds)
    }

    /// Check if video is within the max duration limit
    var isValidDuration: Bool {
        duration <= Self.maxDuration
    }

    /// File size in bytes
    var fileSize: Int64? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
    }

    /// Formatted file size string
    var formattedFileSize: String {
        guard let size = fileSize else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    // MARK: - Equatable
    static func == (lhs: VideoRecording, rhs: VideoRecording) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - VideoRecording Error
enum VideoRecordingError: Error, LocalizedError {
    case durationExceeded
    case fileNotFound
    case invalidFormat
    case thumbnailGenerationFailed

    var errorDescription: String? {
        switch self {
        case .durationExceeded:
            return "Video exceeds maximum duration of \(Int(VideoRecording.maxDuration)) seconds"
        case .fileNotFound:
            return "Video file not found"
        case .invalidFormat:
            return "Invalid video format"
        case .thumbnailGenerationFailed:
            return "Failed to generate thumbnail"
        }
    }
}
