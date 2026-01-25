//
//  ErrorViews.swift
//  Vibe MessagesExtension
//
//  Created on 1/25/26.
//

import SwiftUI

// MARK: - Error Types
enum VibeError: Error, LocalizedError {
    case cameraPermissionDenied
    case microphonePermissionDenied
    case networkFailure(underlying: Error?)
    case uploadFailed(underlying: Error?)
    case videoPlaybackFailed
    case photoLoadFailed
    case sessionExpired
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied:
            return "Camera Access Required"
        case .microphonePermissionDenied:
            return "Microphone Access Required"
        case .networkFailure:
            return "Connection Failed"
        case .uploadFailed:
            return "Upload Failed"
        case .videoPlaybackFailed:
            return "Video Unavailable"
        case .photoLoadFailed:
            return "Image Unavailable"
        case .sessionExpired:
            return "Session Expired"
        case .unknown(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .cameraPermissionDenied:
            return "Vibe needs camera access to record videos. Please enable it in Settings."
        case .microphonePermissionDenied:
            return "Vibe needs microphone access for audio. Please enable it in Settings."
        case .networkFailure:
            return "Please check your internet connection and try again."
        case .uploadFailed:
            return "Something went wrong while uploading. Tap to retry."
        case .videoPlaybackFailed:
            return "This video couldn't be loaded. It may have been removed."
        case .photoLoadFailed:
            return "This image couldn't be loaded. Please try again."
        case .sessionExpired:
            return "Please sign in again to continue."
        case .unknown:
            return "Please try again later."
        }
    }

    var icon: String {
        switch self {
        case .cameraPermissionDenied:
            return "camera.fill"
        case .microphonePermissionDenied:
            return "mic.fill"
        case .networkFailure:
            return "wifi.exclamationmark"
        case .uploadFailed:
            return "icloud.slash"
        case .videoPlaybackFailed:
            return "video.slash"
        case .photoLoadFailed:
            return "photo"
        case .sessionExpired:
            return "person.crop.circle.badge.exclamationmark"
        case .unknown:
            return "exclamationmark.triangle"
        }
    }

    var canRetry: Bool {
        switch self {
        case .networkFailure, .uploadFailed, .videoPlaybackFailed, .photoLoadFailed:
            return true
        default:
            return false
        }
    }

    var requiresSettings: Bool {
        switch self {
        case .cameraPermissionDenied, .microphonePermissionDenied:
            return true
        default:
            return false
        }
    }
}

// MARK: - Generic Error View
struct ErrorView: View {
    let error: VibeError
    var onRetry: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var compact: Bool = false

    var body: some View {
        if compact {
            compactView
        } else {
            fullView
        }
    }

    private var fullView: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: error.icon)
                    .font(.system(size: 40))
                    .foregroundColor(.red.opacity(0.8))
            }

            // Text
            VStack(spacing: 8) {
                Text(error.errorDescription ?? "Error")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(error.recoverySuggestion ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Actions
            VStack(spacing: 12) {
                if error.canRetry, let onRetry = onRetry {
                    Button(action: onRetry) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.pink, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 48)
                }

                if error.requiresSettings, let onOpenSettings = onOpenSettings {
                    Button(action: onOpenSettings) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open Settings")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 48)
                }
            }
        }
        .padding()
    }

    private var compactView: some View {
        HStack(spacing: 12) {
            Image(systemName: error.icon)
                .font(.title3)
                .foregroundColor(.red.opacity(0.8))

            VStack(alignment: .leading, spacing: 2) {
                Text(error.errorDescription ?? "Error")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(error.recoverySuggestion ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if error.canRetry, let onRetry = onRetry {
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }
}

// MARK: - Camera Permission Denied Alert
struct CameraPermissionDeniedView: View {
    @Environment(\.openURL) var openURL
    var onDismiss: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                // Animated camera icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.red.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.pink, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Slash overlay
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 4, height: 80)
                        .rotationEffect(.degrees(45))
                }

                VStack(spacing: 12) {
                    Text("Camera Access Needed")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("To share vibes, Vibe needs access to your camera. Enable it in Settings to start recording.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 16) {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open Settings")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.pink, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 48)

                    if let onDismiss = onDismiss {
                        Button(action: onDismiss) {
                            Text("Not Now")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Network Error Banner
struct NetworkErrorBanner: View {
    let message: String
    var onRetry: (() -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title3)
                .foregroundColor(.white)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()

            if let onRetry = onRetry {
                Button(action: onRetry) {
                    Text("Retry")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                }
            }

            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.9))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
    }
}

// MARK: - Upload Error View
struct UploadErrorView: View {
    let error: String?
    var onRetry: (() -> Void)?
    var onCancel: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            // Error icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "icloud.slash")
                    .font(.system(size: 32))
                    .foregroundColor(.red)
            }

            VStack(spacing: 8) {
                Text("Upload Failed")
                    .font(.headline)
                    .foregroundColor(.white)

                Text(error ?? "Something went wrong. Please try again.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                if let onCancel = onCancel {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                    }
                }

                if let onRetry = onRetry {
                    Button(action: onRetry) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.pink, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding(32)
        .background(Color.black.opacity(0.8))
        .cornerRadius(20)
    }
}

// MARK: - Video Playback Error View
struct VideoPlaybackErrorView: View {
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("Video Unavailable")
                .font(.headline)
                .foregroundColor(.white)

            Text("This video couldn't be played")
                .font(.subheadline)
                .foregroundColor(.gray)

            if let onRetry = onRetry {
                Button(action: onRetry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - Image Load Error View
struct ImageLoadErrorView: View {
    var onRetry: (() -> Void)?
    var compact: Bool = false

    var body: some View {
        if compact {
            ZStack {
                Color.gray.opacity(0.3)
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundColor(.gray)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)

                Text("Image couldn't be loaded")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                if let onRetry = onRetry {
                    Button(action: onRetry) {
                        Text("Tap to retry")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview("Full Error View") {
    ErrorView(
        error: .networkFailure(underlying: nil),
        onRetry: { print("Retry") }
    )
}

#Preview("Camera Permission") {
    CameraPermissionDeniedView()
}

#Preview("Upload Error") {
    ZStack {
        Color.black.ignoresSafeArea()
        UploadErrorView(
            error: "Network connection lost",
            onRetry: { },
            onCancel: { }
        )
    }
}
