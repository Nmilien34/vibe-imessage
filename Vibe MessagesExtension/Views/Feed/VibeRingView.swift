//
//  VibeRingView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI

struct VibeRingView: View {
    let vibes: [Vibe]
    let userId: String
    let isCurrentUser: Bool
    let size: CGFloat
    let onTap: () -> Void

    @State private var animateGradient = false
    @State private var isVisible = false

    private var hasUnviewed: Bool {
        vibes.contains { !$0.hasViewed(userId) && $0.userId != userId }
    }

    private var allViewed: Bool {
        vibes.allSatisfy { $0.hasViewed(userId) || $0.userId == userId }
    }

    private var ringGradient: AngularGradient {
        if hasUnviewed {
            return AngularGradient(
                colors: [.pink, .purple, .blue, .pink],
                center: .center,
                startAngle: .degrees(animateGradient ? 0 : 360),
                endAngle: .degrees(animateGradient ? 360 : 720)
            )
        } else {
            return AngularGradient(
                colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
                center: .center
            )
        }
    }

    private var previewContent: some View {
        Group {
            if let firstVibe = vibes.first {
                switch firstVibe.type {
                case .photo:
                    if let mediaUrl = firstVibe.mediaUrl,
                       let url = URL(string: mediaUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                    } else {
                        Image(systemName: "photo.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundColor(.white)
                    }
                case .video:
                    if let thumbnailUrl = firstVibe.thumbnailUrl,
                       let url = URL(string: thumbnailUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                    } else {
                        Image(systemName: "video.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundColor(.white)
                    }
                case .song:
                    if let albumArt = firstVibe.songData?.albumArt,
                       let url = URL(string: albumArt) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            vibeTypeBackground(firstVibe.type)
                        }
                    } else {
                        vibeTypeBackground(firstVibe.type)
                    }
                case .battery:
                    vibeTypeBackground(firstVibe.type)
                        .overlay {
                            Text("\(firstVibe.batteryLevel ?? 0)%")
                                .font(.system(size: size * 0.25, weight: .bold))
                                .foregroundColor(.white)
                        }
                case .mood:
                    vibeTypeBackground(firstVibe.type)
                        .overlay {
                            Text(firstVibe.mood?.emoji ?? "😊")
                                .font(.system(size: size * 0.4))
                        }
                case .poll:
                    vibeTypeBackground(firstVibe.type)
                        .overlay {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: size * 0.35))
                                .foregroundColor(.white)
                        }
                case .dailyDrop:
                    vibeTypeBackground(firstVibe.type)
                        .overlay {
                            Image(systemName: "die.face.5")
                                .font(.system(size: size * 0.35))
                                .foregroundColor(.white)
                        }
                case .tea:
                    vibeTypeBackground(firstVibe.type)
                        .overlay {
                            Image(systemName: "quote.bubble.fill")
                                .font(.system(size: size * 0.35))
                                .foregroundColor(.white)
                        }
                case .leak:
                    vibeTypeBackground(firstVibe.type)
                        .overlay {
                            Image(systemName: "shutter.releaser")
                                .font(.system(size: size * 0.35))
                                .foregroundColor(.white)
                        }
                case .sketch:
                    vibeTypeBackground(firstVibe.type)
                        .overlay {
                            Image(systemName: "hand.draw.fill")
                                .font(.system(size: size * 0.35))
                                .foregroundColor(.white)
                        }
                case .eta:
                    vibeTypeBackground(firstVibe.type)
                        .overlay {
                            Image(systemName: "location.fill")
                                .font(.system(size: size * 0.35))
                                .foregroundColor(.white)
                        }
                case .parlay:
                    vibeTypeBackground(firstVibe.type)
                        .overlay {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.system(size: size * 0.35))
                                .foregroundColor(.white)
                        }
                }
            } else {
                Color.gray.opacity(0.3)
            }
        }
    }

    private func vibeTypeBackground(_ type: VibeType) -> some View {
        type.color.opacity(0.8)
    }

    var body: some View {
        Group {
            if isVisible {
                Button(action: onTap) {
                    ZStack {
                        // Ring
                        Circle()
                            .strokeBorder(ringGradient, lineWidth: hasUnviewed ? 3 : 2)
                            .frame(width: size, height: size)

                        // Content circle
                        Circle()
                            .fill(Color.black)
                            .frame(width: size - 8, height: size - 8)
                            .overlay {
                                previewContent
                                    .clipShape(Circle())
                                    .frame(width: size - 10, height: size - 10)
                            }

                        // Add button for current user
                        if isCurrentUser {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: size * 0.3, height: size * 0.3)
                                .overlay {
                                    Image(systemName: "plus")
                                        .font(.system(size: size * 0.15, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .offset(x: size * 0.35, y: size * 0.35)
                        }

                        // Vibe count badge
                        if vibes.count > 1 {
                            Text("\(vibes.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Capsule())
                                .offset(x: size * 0.3, y: -size * 0.35)
                        }
                    }
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isVisible = true
            }
            if hasUnviewed {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    animateGradient.toggle()
                }
            }
        }
    }
}

// MARK: - Add Vibe Button
struct AddVibeButton: View {
    let size: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 2, dash: [5, 3])
                    )
                    .frame(width: size, height: size)

                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: size - 8, height: size - 8)

                Image(systemName: "plus")
                    .font(.system(size: size * 0.35, weight: .medium))
                    .foregroundColor(.blue)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 16) {
        AddVibeButton(size: 70) {}

        VibeRingView(
            vibes: [],
            userId: "test",
            isCurrentUser: true,
            size: 70
        ) {}

        VibeRingView(
            vibes: [],
            userId: "test",
            isCurrentUser: false,
            size: 70
        ) {}
    }
    .padding()
    .background(Color.black)
}
