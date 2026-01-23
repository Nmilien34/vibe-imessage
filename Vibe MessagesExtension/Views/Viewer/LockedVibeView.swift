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

    var body: some View {
        ZStack {
            // Blurred background hint
            blurredPreview
                .blur(radius: 30)
                .overlay(Color.black.opacity(0.5))

            // Lock content
            VStack(spacing: 24) {
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
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.pink, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                }

                VStack(spacing: 12) {
                    Text("Locked Vibe")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Post your own vibe to unlock\nthis content")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }

                // Unlock button
                Button(action: onUnlock) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Share to Unlock")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .purple.opacity(0.5), radius: 10, y: 5)
                }

                // Type hint
                HStack(spacing: 8) {
                    Image(systemName: vibe.type.icon)
                    Text(vibe.type.displayName)
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .onAppear {
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
