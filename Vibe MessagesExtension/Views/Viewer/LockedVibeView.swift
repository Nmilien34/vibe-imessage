//
//  LockedVibeView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI

struct LockedVibeView: View {
    let vibe: Vibe
    let onUnlock: () -> Void

    @State private var isAnimating = false
    @State private var isVisible = false

    var body: some View {
        ZStack {
            if isVisible {
                // Blurred background hint
                blurredPreview
                    .blur(radius: 30)
                    .overlay(Color.black.opacity(0.5))
                    .transition(.opacity)

                // Lock content
                VStack(spacing: VibeSpacing.xl) {
                    // Animated lock icon
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.purple.opacity(0.3), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 200, height: 200)
                            .scaleEffect(isAnimating ? 1.2 : 1.0)
                            .opacity(isAnimating ? 0.5 : 1.0)

                        Image(systemName: "lock.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(VibeTheme.brandGradient)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .symbolEffect(.pulse)
                    }

                    VStack(spacing: VibeSpacing.sm) {
                        Text("Locked Vibe")
                            .font(VibeTypography.displaySmall)
                            .foregroundColor(.white)

                        Text("Post your own vibe to unlock\nthis content")
                            .font(VibeTypography.bodyMedium)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }

                    // Unlock button
                    Button(action: {
                        VibeHaptic.medium()
                        onUnlock()
                    }) {
                        HStack(spacing: VibeSpacing.sm) {
                            Image(systemName: "plus.circle.fill")
                            Text("Share to Unlock")
                        }
                        .font(VibeTypography.titleMedium)
                        .foregroundColor(.white)
                        .padding(.horizontal, VibeSpacing.xxl)
                        .padding(.vertical, VibeSpacing.lg)
                        .background(VibeTheme.brandGradient)
                        .clipShape(Capsule())
                        .vibeShadow(.lg)
                    }
                    .buttonStyle(VibePressStyle())

                    // Type hint
                    HStack(spacing: VibeSpacing.sm) {
                        Image(systemName: vibe.type.icon)
                        Text(vibe.type.displayName)
                    }
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, VibeSpacing.sm)
                    .padding(.vertical, VibeSpacing.xs)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation(VibeAnimation.smooth) {
                isVisible = true
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    @ViewBuilder
    private var blurredPreview: some View {
        switch vibe.type {
        case .photo:
            if let mediaUrl = vibe.mediaUrl,
               let url = URL(string: mediaUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    vibe.type.color
                }
            } else {
                vibe.type.color
            }
        case .video:
            if let thumbnailUrl = vibe.thumbnailUrl,
               let url = URL(string: thumbnailUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    vibe.type.color
                }
            } else {
                vibe.type.color
            }
        case .song:
            if let albumArt = vibe.songData?.albumArt,
               let url = URL(string: albumArt) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    vibe.type.color
                }
            } else {
                vibe.type.color
            }
        case .battery:
            LinearGradient(
                colors: [.yellow, .orange],
                startPoint: .top,
                endPoint: .bottom
            )
        case .mood:
            LinearGradient(
                colors: [.purple, .pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .poll:
            LinearGradient(
                colors: [.blue, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dailyDrop:
            LinearGradient(
                colors: [.black, .gray],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .tea:
            LinearGradient(
                colors: [.brown, .orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .leak:
            LinearGradient(
                colors: [.red, .pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sketch:
            LinearGradient(
                colors: [.orange, .yellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .eta:
            LinearGradient(
                colors: [.blue, .green],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .parlay:
            LinearGradient(
                colors: [VibeTheme.accent, VibeTheme.accentSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

#Preview {
    LockedVibeView(
        vibe: Vibe(from: MockDecoder())!,
        onUnlock: {}
    )
}

// Mock decoder for preview
private struct MockDecoder: Decoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        fatalError()
    }
    func unkeyedContainer() throws -> UnkeyedDecodingContainer { fatalError() }
    func singleValueContainer() throws -> SingleValueDecodingContainer { fatalError() }
}

extension Vibe {
    fileprivate init?(from decoder: MockDecoder) {
        return nil
    }
}
