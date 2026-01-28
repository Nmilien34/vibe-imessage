//
//  StoryBubbleRenderer.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import UIKit
import SwiftUI

class StoryBubbleRenderer {
    static let shared = StoryBubbleRenderer()

    private init() {}

    /// Renders a story bubble image for photo/video vibes
    @MainActor
    func renderStoryBubble(thumbnail: UIImage?, expiresIn: Int, isLocked: Bool) -> UIImage {
        let view = StoryBubbleView(
            thumbnail: thumbnail,
            expiresIn: expiresIn,
            isLocked: isLocked
        )

        let renderer = ImageRenderer(content: view)
        renderer.scale = UITraitCollection.current.displayScale

        return renderer.uiImage ?? UIImage(systemName: "exclamationmark.triangle")!
    }

    /// Renders a type-specific message card for non-media vibes
    @MainActor
    func renderVibeCard(vibeType: VibeType, contextText: String?, isLocked: Bool) -> UIImage {
        let view = VibeCardBubbleView(
            vibeType: vibeType,
            contextText: contextText,
            isLocked: isLocked
        )

        let renderer = ImageRenderer(content: view)
        renderer.scale = UITraitCollection.current.displayScale

        return renderer.uiImage ?? UIImage(systemName: "exclamationmark.triangle")!
    }
}

// MARK: - Photo/Video Bubble

struct StoryBubbleView: View {
    let thumbnail: UIImage?
    let expiresIn: Int
    let isLocked: Bool

    var body: some View {
        ZStack {
            // Background / Thumbnail
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 300, height: 200)
                    .overlay(Color.black.opacity(isLocked ? 0.3 : 0.1))
            } else {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 300, height: 200)
            }

            // Gradient Overlay
            LinearGradient(
                colors: [.black.opacity(0.6), .transparent, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Lock UI
            if isLocked {
                VStack {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 60, height: 60)
                            .shadow(radius: 10)

                        Image(systemName: "lock.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    }

                    Text("Tap to Unveil")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 8)
                        .shadow(radius: 4)
                }
            } else {
                // Play Icon
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.8))
                    .shadow(radius: 4)
            }

            // Footer Info
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Expires in \(expiresIn)h")
                        .font(.caption)
                        .fontWeight(.semibold)

                    Spacer()
                    Text("Vibes")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.pink)
                        .cornerRadius(8)
                }
                .foregroundColor(.white)
                .padding()
            }
        }
        .frame(width: 300, height: 200)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [.pink, .purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
        )
    }
}

// MARK: - Type-Specific Vibe Card

struct VibeCardBubbleView: View {
    let vibeType: VibeType
    let contextText: String?
    let isLocked: Bool

    var body: some View {
        ZStack {
            // Gradient background using the vibe type's color
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if isLocked {
                // Locked overlay
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 56, height: 56)
                        Image(systemName: "lock.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    Text("Tap to Unveil")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            } else {
                // Type-specific content
                VStack(spacing: 10) {
                    vibeIcon
                    vibeContent
                }
                .padding()
            }

            // Footer
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Expires in 24h")
                        .font(.caption2)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("Vibez")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.25))
                        .cornerRadius(6)
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
        .frame(width: 300, height: 200)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [vibeType.color, vibeType.color.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
        )
    }

    @ViewBuilder
    private var vibeIcon: some View {
        Image(systemName: vibeType.icon)
            .font(.system(size: 36))
            .foregroundColor(.white)
    }

    @ViewBuilder
    private var vibeContent: some View {
        switch vibeType {
        case .battery:
            Text(contextText ?? "0%")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundColor(.white)

        case .mood:
            if let text = contextText {
                // contextText is "emoji|note" format
                let parts = text.split(separator: "|", maxSplits: 1)
                VStack(spacing: 4) {
                    Text(String(parts.first ?? "😊"))
                        .font(.system(size: 50))
                    if parts.count > 1 {
                        Text(String(parts.last!))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                }
            } else {
                Text("😊")
                    .font(.system(size: 50))
            }

        case .poll:
            VStack(spacing: 6) {
                Text("📊 Poll")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.8))
                Text(contextText ?? "Vote now!")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

        case .tea:
            VStack(spacing: 6) {
                Text(contextText ?? "☕️")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

        case .leak:
            Text("🫣 New Leak")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

        case .sketch:
            Text("🎨 Doodle")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

        case .eta:
            Text(contextText ?? "📍 On the way")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)

        case .song:
            VStack(spacing: 4) {
                Text("🎵 Now Playing")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.8))
                Text(contextText ?? "A song")
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

        case .dailyDrop:
            VStack(spacing: 6) {
                Text("🎲 Daily Drop")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.8))
                Text(contextText ?? "Challenge!")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

        default:
            Text("New Vibe")
                .font(.headline)
                .foregroundColor(.white)
        }
    }

    private var gradientColors: [Color] {
        switch vibeType {
        case .battery:  return [.green, .yellow.opacity(0.8)]
        case .mood:     return [.purple, .pink]
        case .poll:     return [.blue, .indigo]
        case .tea:      return [.brown, .orange.opacity(0.7)]
        case .leak:     return [.red, .pink.opacity(0.8)]
        case .sketch:   return [.orange, .cyan]
        case .eta:      return [.blue, .teal]
        case .song:     return [.green, .green.opacity(0.6)]
        case .dailyDrop: return [.black, Color(red: 0.2, green: 0.2, blue: 0.2)]
        default:        return [.pink, .purple]
        }
    }
}

extension Color {
    static let transparent = Color.black.opacity(0)
}
