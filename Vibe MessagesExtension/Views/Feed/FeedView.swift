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
        ZStack(alignment: .top) {
            Group {
                switch appState.presentationMode {
                case .compact:
                    CompactFeedView()
                case .expanded:
                    BentoDashboardView()
                }
            }

            // Network Error Banner
            if appState.showNetworkErrorBanner {
                NetworkErrorBanner(
                    message: appState.networkError?.recoverySuggestion ?? "Connection failed",
                    onRetry: {
                        appState.retryLoadVibes()
                    },
                    onDismiss: {
                        appState.dismissNetworkError()
                    }
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: appState.showNetworkErrorBanner)
            }
        }
    }
}

// MARK: - Compact Feed View (Drawer Style)
struct CompactFeedView: View {
    @EnvironmentObject var appState: AppState

    let vibezPink = Color(red: 1.0, green: 0.2, blue: 0.6)
    let vibezPurple = Color(red: 0.6, green: 0.2, blue: 1.0)

    var body: some View {
        ZStack {
            // Background
            Color.white
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: Color.black.opacity(0.1), radius: 10, y: -5)
                .edgesIgnoringSafeArea(.bottom)

            VStack(spacing: 16) {

                // 1. THE HANDLE & LIVE STATUS
                VStack(spacing: 8) {
                    // Drag Handle
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)

                    // Live Status Text (The "Hook")
                    HStack(spacing: 6) {
                        if let streak = appState.streak, streak.currentStreak > 0 {
                            Text("🔥 \(streak.currentStreak) Day Streak")
                                .foregroundColor(.orange)
                                .font(.system(size: 12, weight: .bold, design: .rounded))

                            Circle().fill(Color.gray.opacity(0.3)).frame(width: 3, height: 3)
                        }

                        Text(activeUsersText)
                            .foregroundColor(.gray)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                }
                .onTapGesture {
                    appState.requestExpand()
                }

                // 2. THE ACTION RAIL
                HStack(spacing: 16) {

                    // A. The "Post Vibe" Button (Hero)
                    Button {
                        appState.shouldShowVibePicker = true
                        appState.requestExpand()
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [vibezPink, vibezPurple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 56, height: 56)
                                    .shadow(color: vibezPink.opacity(0.4), radius: 8, x: 0, y: 4)

                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("New Vibe")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                        }
                    }

                    // Divider
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 1, height: 40)

                    // B. Friend Stories (Horizontal Scroll)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            if appState.isLoading && appState.vibes.isEmpty {
                                ForEach(0..<3, id: \.self) { _ in
                                    CompactAvatarSkeleton()
                                }
                            } else {
                                let groupedVibes = appState.vibesGroupedByUser()

                                ForEach(groupedVibes, id: \.first?.userId) { userVibes in
                                    if let firstVibe = userVibes.first {
                                        let hasUnseen = userVibes.contains { !$0.hasViewed(appState.userId) }
                                        let isMe = firstVibe.userId == appState.userId

                                        CompactAvatar(
                                            name: isMe ? "You" : nameForUser(firstVibe.userId),
                                            thumbnailUrl: firstVibe.thumbnailUrl ?? firstVibe.mediaUrl,
                                            vibeType: firstVibe.type,
                                            hasUnseen: hasUnseen && !isMe
                                        ) {
                                            appState.navigateToViewer(opening: firstVibe.id)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.bottom, 20)
        }
    }

    private var activeUsersText: String {
        let activeUsers = appState.vibesGroupedByUser()
            .compactMap { $0.first }
            .filter { $0.userId != appState.userId }
            .prefix(2)
            .map { nameForUser($0.userId) }

        if activeUsers.isEmpty {
            return "No one active yet"
        } else if activeUsers.count == 1 {
            return "\(activeUsers[0]) is active"
        } else {
            return "\(activeUsers[0]) & \(activeUsers[1]) are active"
        }
    }

    private func nameForUser(_ id: String) -> String {
        if id == appState.userId { return "You" }
        let names = ["Sarah", "Mike", "Jess", "Alex", "Sam", "Emma", "Liam", "Olivia"]
        let index = abs(id.hashValue) % names.count
        return names[index]
    }
}

// MARK: - Compact Avatar
struct CompactAvatar: View {
    var name: String
    var thumbnailUrl: String?
    var vibeType: VibeType
    var hasUnseen: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    // Gradient Ring if Unseen
                    if hasUnseen {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.pink, .orange],
                                    startPoint: .topTrailing,
                                    endPoint: .bottomLeading
                                ),
                                lineWidth: 2.5
                            )
                            .frame(width: 56, height: 56)
                    } else {
                        Circle()
                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                            .frame(width: 56, height: 56)
                    }

                    // Avatar content
                    if let urlString = thumbnailUrl, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(vibeType.color.opacity(0.2))
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(vibeType.color.opacity(0.15))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: vibeType.icon)
                                    .font(.title3)
                                    .foregroundColor(vibeType.color)
                            )
                    }
                }

                Text(name)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(hasUnseen ? .black : .gray)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct CompactAvatarSkeleton: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 56, height: 56)
                .opacity(isAnimating ? 0.5 : 1.0)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 40, height: 10)
                .opacity(isAnimating ? 0.5 : 1.0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Skeleton Ring View (Loading Placeholder)
struct SkeletonRingView: View {
    let size: CGFloat
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.gray.opacity(0.2), .gray.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                )
                .opacity(isAnimating ? 0.5 : 1.0)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: isAnimating
                )

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.8, height: 10)
                .opacity(isAnimating ? 0.5 : 1.0)
        }
        .onAppear {
            isAnimating = true
        }
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
