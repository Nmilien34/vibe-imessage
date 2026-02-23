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
    func renderVibeCard(vibeType: VibeType, contextText: String?, isLocked: Bool, senderName: String? = nil) -> UIImage {
        let view = VibeCardBubbleView(
            vibeType: vibeType,
            contextText: contextText,
            isLocked: isLocked,
            senderName: senderName
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
    let senderName: String?

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
            } else if vibeType == .parlay {
                parlayCardLayout
            } else {
                // Type-specific content
                VStack(spacing: 10) {
                    vibeIcon
                    vibeContent
                }
                .padding()
            }

            if vibeType != .parlay {
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
        Image(systemName: vibeType == .parlay ? "person.fill.checkmark" : vibeType.icon)
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

        case .parlay:
            Text("Challenge")
                .font(.headline)
                .foregroundColor(.white)

        default:
            Text("New Vibe")
                .font(.headline)
                .foregroundColor(.white)
        }
    }

    private struct ParlayBubbleDetails {
        let title: String
        let deadline: Date?
        let creatorName: String
    }

    @ViewBuilder
    private var parlayCardLayout: some View {
        let details = parseParlayContext(from: contextText, fallbackSenderName: senderName)

        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "person.fill.checkmark")
                    .font(.system(size: 13, weight: .bold))
                Text("FRIEND CHALLENGE")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(0.4)
            }
            .foregroundColor(.white.opacity(0.92))
            .padding(.top, 12)

            Text(details.title)
                .font(parlayTitleFont(for: details.title))
                .fontWeight(.heavy)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(parlayTitleLineLimit(for: details.title))
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .padding(.horizontal, 14)
                .padding(.top, 6)

            Spacer(minLength: 4)

            Text("\(details.creatorName) went on record")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .padding(.horizontal, 14)

            if let deadline = details.deadline {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                    Text("Closes \(formatCompactDeadline(deadline))")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.top, 2)
            }

            Text("PICK A SIDE: YES / NO")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(Color(red: 0.6, green: 0.2, blue: 1.0))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white)
                .clipShape(Capsule())
                .padding(.top, 4)
                .padding(.bottom, 8)

            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(parlayFooterExpiryLabel(for: details.deadline))
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

    private func parlayTitleFont(for title: String) -> Font {
        let count = title.count
        if count > 220 {
            return .system(size: 10, weight: .heavy, design: .rounded)
        }
        if count > 165 {
            return .system(size: 11, weight: .heavy, design: .rounded)
        }
        if count > 125 {
            return .system(size: 12, weight: .heavy, design: .rounded)
        }
        if count > 95 {
            return .system(size: 13, weight: .heavy, design: .rounded)
        }
        if count > 60 {
            return .system(size: 14, weight: .heavy, design: .rounded)
        }
        return .system(size: 15, weight: .heavy, design: .rounded)
    }

    private func parlayTitleLineLimit(for title: String) -> Int {
        let count = title.count
        if count > 170 { return 5 }
        if count > 95 { return 4 }
        if count > 65 { return 3 }
        return 2
    }

    private func parlayFooterExpiryLabel(for deadline: Date?) -> String {
        guard let deadline else { return "Expires soon" }

        let remaining = Int(deadline.timeIntervalSinceNow)
        if remaining <= 0 { return "Closed" }

        let days = remaining / 86_400
        let hours = (remaining % 86_400) / 3_600
        let minutes = (remaining % 3_600) / 60

        if days > 0 {
            return "Expires in \(days)d \(hours)h"
        }
        if hours > 0 {
            return "Expires in \(hours)h \(minutes)m"
        }
        return "Expires in \(max(1, minutes))m"
    }

    private func parseParlayContext(from rawContext: String?, fallbackSenderName: String?) -> ParlayBubbleDetails {
        let normalizedSender = fallbackSenderName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fallbackCreator = normalizedSender.isEmpty ? "Your friend" : normalizedSender
        let fallback = ParlayBubbleDetails(
            title: "Tap to pick your side",
            deadline: nil,
            creatorName: fallbackCreator
        )

        guard let rawContext = rawContext?.trimmingCharacters(in: .whitespacesAndNewlines), !rawContext.isEmpty else {
            return fallback
        }

        if rawContext.hasPrefix("parlay_v2?") {
            let query = String(rawContext.dropFirst("parlay_v2?".count))
            if let components = URLComponents(string: "https://getvibe.app/open?\(query)") {
                let items = components.queryItems ?? []
                let title = items.first(where: { $0.name == "title" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
                let creator = items.first(where: { $0.name == "creator" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
                let deadline = items.first(where: { $0.name == "deadline" })?.value.flatMap(TimeInterval.init).map {
                    Date(timeIntervalSince1970: $0)
                }

                if let title, !title.isEmpty {
                    let normalizedCreator = creator ?? ""
                    return ParlayBubbleDetails(
                        title: title,
                        deadline: deadline,
                        creatorName: normalizedCreator.isEmpty ? fallbackCreator : normalizedCreator
                    )
                }
            }
        }

        // Legacy format support: "title|amount|opponent"
        let parts = rawContext.split(separator: "|", maxSplits: 2).map(String.init)
        if let first = parts.first {
            let title = first.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                return ParlayBubbleDetails(title: title, deadline: nil, creatorName: fallbackCreator)
            }
        }

        return fallback
    }

    private func formatCompactDeadline(_ deadline: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        if calendar.isDateInToday(deadline) {
            return "today \(timeFormatter.string(from: deadline))"
        }
        if calendar.isDateInTomorrow(deadline) {
            return "tomorrow \(timeFormatter.string(from: deadline))"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate("EEE h:mm a")
        return dateFormatter.string(from: deadline)
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
        case .parlay:   return [Color(red: 1.0, green: 0.2, blue: 0.6), Color(red: 0.6, green: 0.2, blue: 1.0)]
        default:        return [.pink, .purple]
        }
    }
}

extension Color {
    static let transparent = Color.black.opacity(0)
}
