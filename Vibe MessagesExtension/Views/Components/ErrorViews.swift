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
        case .networkFailure(let underlying):
            if let apiError = underlying as? APIError {
                switch apiError {
                case .networkError(let nested):
                    if let urlError = nested as? URLError {
                        switch urlError.code {
                        case .notConnectedToInternet, .networkConnectionLost:
                            return "No internet connection. Reconnect and tap Retry."
                        case .timedOut:
                            return "The server is slow to respond. Tap Retry."
                        default:
                            return "Couldn't reach the server. Tap Retry."
                        }
                    }
                    return "Couldn't reach the server. Tap Retry."
                case .httpError(let statusCode, let message):
                    if let message, !message.isEmpty {
                        return message
                    }
                    if statusCode >= 500 {
                        return "The server is having trouble right now. Tap Retry."
                    }
                    return "Couldn't refresh right now. Tap Retry."
                case .invalidResponse, .decodingError:
                    return "Couldn't refresh right now. Tap Retry."
                case .invalidURL, .uploadFailed:
                    return "Please try again."
                }
            }
            return "Couldn't refresh right now. Tap Retry."
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
        VStack(spacing: VibeSpacing.xl) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: error.icon)
                    .font(.system(size: 40))
                    .foregroundColor(.red.opacity(0.8))
            }

            VStack(spacing: VibeSpacing.xs) {
                Text(error.errorDescription ?? "Error")
                    .font(VibeTypography.titleLarge)
                    .foregroundColor(VibeTheme.textPrimary)

                Text(error.recoverySuggestion ?? "")
                    .font(VibeTypography.bodyMedium)
                    .foregroundColor(VibeTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VibeSpacing.xxl)
            }

            VStack(spacing: VibeSpacing.sm) {
                if error.canRetry, let onRetry = onRetry {
                    Button(action: {
                        VibeHaptic.medium()
                        onRetry()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .vibeButton(.primary)
                    }
                    .buttonStyle(VibePressStyle())
                    .padding(.horizontal, VibeSpacing.xxxl + VibeSpacing.xs)
                }

                if error.requiresSettings, let onOpenSettings = onOpenSettings {
                    Button(action: {
                        VibeHaptic.light()
                        onOpenSettings()
                    }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open Settings")
                        }
                        .vibeButton(.secondary)
                    }
                    .buttonStyle(VibePressStyle())
                    .padding(.horizontal, VibeSpacing.xxxl + VibeSpacing.xs)
                }
            }
        }
        .padding(VibeSpacing.lg)
    }

    private var compactView: some View {
        HStack(spacing: VibeSpacing.sm) {
            Image(systemName: error.icon)
                .font(.system(size: 20))
                .foregroundColor(.red.opacity(0.8))

            VStack(alignment: .leading, spacing: VibeSpacing.xxxs) {
                Text(error.errorDescription ?? "Error")
                    .font(VibeTypography.titleSmall)
                    .foregroundColor(VibeTheme.textPrimary)

                Text(error.recoverySuggestion ?? "")
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(VibeTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if error.canRetry, let onRetry = onRetry {
                Button(action: {
                    VibeHaptic.medium()
                    onRetry()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 20))
                        .foregroundColor(VibeTheme.accent)
                }
            }
        }
        .padding(VibeSpacing.md)
        .vibeCard(radius: VibeTheme.radiusMedium)
    }
}

// MARK: - Camera Permission Denied Alert
struct CameraPermissionDeniedView: View {
    @Environment(\.openURL) var openURL
    var onDismiss: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: VibeSpacing.xxl) {
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
                        .foregroundStyle(VibeTheme.brandGradient)

                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 4, height: 80)
                        .rotationEffect(.degrees(45))
                }

                VStack(spacing: VibeSpacing.sm) {
                    Text("Camera Access Needed")
                        .font(VibeTypography.displaySmall)
                        .foregroundColor(.white)

                    Text("To share vibes, Vibe needs access to your camera. Enable it in Settings to start recording.")
                        .font(VibeTypography.bodyMedium)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VibeSpacing.xxl)
                }

                VStack(spacing: VibeSpacing.md) {
                    Button {
                        VibeHaptic.medium()
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open Settings")
                        }
                        .font(VibeTypography.titleMedium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: VibeSpacing.minTouchTarget)
                        .background(VibeTheme.brandGradient)
                        .continuousCorner(VibeTheme.radiusMedium)
                    }
                    .buttonStyle(VibePressStyle())
                    .padding(.horizontal, VibeSpacing.xxxl + VibeSpacing.xs)

                    if let onDismiss = onDismiss {
                        Button(action: onDismiss) {
                            Text("Not Now")
                                .font(VibeTypography.bodyMedium)
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
        HStack(spacing: VibeSpacing.sm) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .symbolEffect(.pulse)

            Text(message)
                .font(VibeTypography.bodySmall)
                .foregroundColor(.white)

            Spacer()

            if let onRetry = onRetry {
                Button(action: {
                    VibeHaptic.medium()
                    onRetry()
                }) {
                    Text("Retry")
                        .font(VibeTypography.titleSmall)
                        .foregroundColor(.white)
                        .padding(.horizontal, VibeSpacing.sm)
                        .padding(.vertical, VibeSpacing.xs)
                        .background(Color.white.opacity(0.2))
                        .continuousCorner(VibeTheme.radiusSmall)
                }
            }

            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(VibeSpacing.md)
        .background(Color.red.gradient)
        .continuousCorner(VibeTheme.radiusMedium)
        .vibeShadow(.md)
    }
}

// MARK: - Upload Error View
struct UploadErrorView: View {
    let error: String?
    var onRetry: (() -> Void)?
    var onCancel: (() -> Void)?

    var body: some View {
        VStack(spacing: VibeSpacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "icloud.slash")
                    .font(.system(size: 32))
                    .foregroundColor(.red)
            }

            VStack(spacing: VibeSpacing.xs) {
                Text("Upload Failed")
                    .font(VibeTypography.titleMedium)
                    .foregroundColor(.white)

                Text(error ?? "Something went wrong. Please try again.")
                    .font(VibeTypography.bodySmall)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: VibeSpacing.md) {
                if let onCancel = onCancel {
                    Button(action: {
                        VibeHaptic.light()
                        onCancel()
                    }) {
                        Text("Cancel")
                            .font(VibeTypography.titleSmall)
                            .foregroundColor(.white)
                            .padding(.horizontal, VibeSpacing.xl)
                            .padding(.vertical, VibeSpacing.sm)
                            .background(Color.white.opacity(0.2))
                            .continuousCorner(VibeTheme.radiusSmall)
                    }
                    .buttonStyle(VibePressStyle())
                }

                if let onRetry = onRetry {
                    Button(action: {
                        VibeHaptic.medium()
                        onRetry()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .font(VibeTypography.titleSmall)
                        .foregroundColor(.white)
                        .padding(.horizontal, VibeSpacing.xl)
                        .padding(.vertical, VibeSpacing.sm)
                        .background(VibeTheme.brandGradient)
                        .continuousCorner(VibeTheme.radiusSmall)
                    }
                    .buttonStyle(VibePressStyle())
                }
            }
        }
        .padding(VibeSpacing.xxl)
        .background(Color.black.opacity(0.8))
        .continuousCorner(VibeTheme.radiusLarge)
    }
}

// MARK: - Video Playback Error View
struct VideoPlaybackErrorView: View {
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: VibeSpacing.md) {
            Image(systemName: "video.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("Video Unavailable")
                .font(VibeTypography.titleMedium)
                .foregroundColor(.white)

            Text("This video couldn't be played")
                .font(VibeTypography.bodySmall)
                .foregroundColor(.gray)

            if let onRetry = onRetry {
                Button(action: {
                    VibeHaptic.medium()
                    onRetry()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(VibeTypography.titleSmall)
                    .foregroundColor(.white)
                    .padding(.horizontal, VibeSpacing.lg)
                    .padding(.vertical, VibeSpacing.xs)
                    .background(Color.white.opacity(0.2))
                    .continuousCorner(VibeTheme.radiusSmall)
                }
                .buttonStyle(VibePressStyle())
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
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
            }
        } else {
            VStack(spacing: VibeSpacing.sm) {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)

                Text("Image couldn't be loaded")
                    .font(VibeTypography.bodySmall)
                    .foregroundColor(.gray)

                if let onRetry = onRetry {
                    Button(action: {
                        VibeHaptic.light()
                        onRetry()
                    }) {
                        Text("Tap to retry")
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(VibeTheme.accent)
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
