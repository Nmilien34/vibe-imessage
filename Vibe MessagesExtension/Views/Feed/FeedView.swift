//
//  FeedView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI

struct FeedView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.presentationMode {
            case .compact:
                CompactFeedView()
            case .expanded:
                BentoDashboardView()
            }
        }
    }
}

// MARK: - Compact Feed View (Keyboard height)
struct CompactFeedView: View {
    @EnvironmentObject var appState: AppState

    private let ringSize: CGFloat = 60

    var body: some View {
        VStack(spacing: 0) {
            // Top row: Streak + New Updates
            HStack {
                // Streak indicator
                if let streak = appState.streak, streak.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(streak.currentStreak) day streak!")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }

                Spacer()

                // New Updates Badge
                if appState.newVibesCount > 0 {
                    Button {
                        if let firstUnseenVibe = appState.vibes.first(where: {
                            !appState.seenVibeIds.contains($0.id) && $0.userId != appState.userId
                        }) {
                            appState.navigateToViewer(opening: firstUnseenVibe.id)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(appState.newVibesCount) New")
                                .fontWeight(.bold)
                            Text("🥳")
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: [.pink, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

            // Horizontal scroll of vibe rings
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Add button (if user hasn't posted today)
                    if !appState.hasUserPostedToday() {
                        AddVibeButton(size: ringSize) {
                            appState.shouldShowVibePicker = true
                            appState.requestExpand()
                        }
                    }

                    // Current user's vibes first
                    let groupedVibes = appState.vibesGroupedByUser()
                    let currentUserVibes = appState.vibes.filter { $0.userId == appState.userId }

                    if !currentUserVibes.isEmpty {
                        VibeRingView(
                            vibes: currentUserVibes,
                            userId: appState.userId,
                            isCurrentUser: true,
                            size: ringSize
                        ) {
                            // Find first vibe for current user (which is the one displayed in the ring typically, or just open the first one)
                            if let firstVibe = currentUserVibes.first {
                                appState.navigateToViewer(opening: firstVibe.id)
                            }
                        }
                    }

                    // Other users' vibes
                    ForEach(groupedVibes, id: \.first?.userId) { userVibes in
                        if let firstVibe = userVibes.first,
                           firstVibe.userId != appState.userId {
                            VibeRingView(
                                vibes: userVibes,
                                userId: appState.userId,
                                isCurrentUser: false,
                                size: ringSize
                            ) {
                                appState.navigateToViewer(opening: firstVibe.id)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            // Tap to expand hint
            Button {
                appState.requestExpand()
            } label: {
                HStack {
                    Image(systemName: "chevron.up")
                    Text("Tap to expand")
                    Image(systemName: "chevron.up")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding(.bottom, 4)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Vibe Grid Cell
struct VibeGridCell: View {
    let vibe: Vibe
    let userId: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                if (vibe.type == .video || vibe.type == .photo),
                   let urlString = vibe.thumbnailUrl ?? (vibe.type == .photo ? vibe.mediaUrl : nil),
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(vibe.type.color.opacity(0.3))
                        .aspectRatio(1, contentMode: .fit)
                }
                
                // Dark overlay for visibility if image present
                if (vibe.type == .video || vibe.type == .photo) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2))
                }

                // Content preview
                VStack(spacing: 8) {
                    contentPreview

                    // Time remaining
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(vibe.timeRemainingFormatted)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                }

                // Lock overlay
                if vibe.isLocked && !vibe.isUnlocked(for: userId) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Image(systemName: "lock.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                }

                // Viewed indicator
                if vibe.hasViewed(userId) || vibe.userId == userId {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch vibe.type {
        case .photo:
            Image(systemName: "photo.fill")
                .font(.title)
                .foregroundColor(vibe.type.color)
        case .video:
            Image(systemName: "video.fill")
                .font(.title)
                .foregroundColor(vibe.type.color)
        case .song:
            VStack(spacing: 4) {
                Image(systemName: "music.note")
                    .font(.title)
                    .foregroundColor(vibe.type.color)
                if let song = vibe.songData {
                    Text(song.title)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
        case .battery:
            VStack(spacing: 4) {
                Image(systemName: batteryIcon)
                    .font(.title)
                    .foregroundColor(batteryColor)
                Text("\(vibe.batteryLevel ?? 0)%")
                    .font(.caption)
                    .fontWeight(.bold)
            }
        case .mood:
            Text(vibe.mood?.emoji ?? "😊")
                .font(.largeTitle)
            case .poll:
                VStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.title)
                        .foregroundColor(vibe.type.color)
                    if let poll = vibe.poll {
                        Text(poll.question)
                            .font(.caption2)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
            case .dailyDrop:
                Image(systemName: "die.face.5")
                    .font(.title)
                    .foregroundColor(vibe.type.color)
            case .tea:
                Image(systemName: "quote.bubble.fill")
                    .font(.title)
                    .foregroundColor(vibe.type.color)
            case .leak:
                Image(systemName: "shutter.releaser")
                    .font(.title)
                    .foregroundColor(vibe.type.color)
            case .sketch:
                Image(systemName: "hand.draw.fill")
                    .font(.title)
                    .foregroundColor(vibe.type.color)
            case .eta:
                Image(systemName: "location.fill")
                    .font(.title)
                    .foregroundColor(vibe.type.color)
            }
    }

    private var batteryIcon: String {
        guard let level = vibe.batteryLevel else { return "battery.0" }
        switch level {
        case 0..<25: return "battery.25"
        case 25..<50: return "battery.50"
        case 50..<75: return "battery.75"
        default: return "battery.100"
        }
    }

    private var batteryColor: Color {
        guard let level = vibe.batteryLevel else { return .gray }
        switch level {
        case 0..<20: return .red
        case 20..<50: return .yellow
        default: return .green
        }
    }
}

#Preview {
    FeedView()
        .environmentObject(AppState())
}
