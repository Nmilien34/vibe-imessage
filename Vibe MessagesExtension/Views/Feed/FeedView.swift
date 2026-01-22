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
                ExpandedFeedView()
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
            // Streak indicator
            if let streak = appState.streak, streak.currentStreak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(streak.currentStreak) day streak!")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.vertical, 4)
            }

            // Horizontal scroll of vibe rings
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Add button (if user hasn't posted today)
                    if !appState.hasUserPostedToday() {
                        AddVibeButton(size: ringSize) {
                            appState.navigateToComposer()
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
                            if let index = appState.vibes.firstIndex(where: { $0.userId == appState.userId }) {
                                appState.navigateToViewer(startingAt: index)
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
                                if let index = appState.vibes.firstIndex(where: { $0.id == firstVibe.id }) {
                                    appState.navigateToViewer(startingAt: index)
                                }
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

// MARK: - Expanded Feed View (Full screen)
struct ExpandedFeedView: View {
    @EnvironmentObject var appState: AppState

    private let ringSize: CGFloat = 80

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with streak
                headerView

                if appState.isLoading && appState.vibes.isEmpty {
                    loadingView
                } else if appState.vibes.isEmpty {
                    emptyStateView
                } else {
                    vibesGridView
                }
            }
            .background(Color(.systemBackground))
            .refreshable {
                await appState.refreshVibes()
            }
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vibes")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                if let streak = appState.streak, streak.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(streak.currentStreak) day streak")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if streak.currentStreak >= streak.longestStreak && streak.longestStreak > 1 {
                            Text("(Best!)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }

            Spacer()

            // Add vibe button
            Button {
                appState.navigateToComposer()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .padding()
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading vibes...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.pink, .purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("No vibes yet!")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Be the first to share your vibe\nwith this conversation")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                appState.navigateToComposer()
            } label: {
                Label("Share a Vibe", systemImage: "plus")
                    .font(.headline)
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
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding()
    }

    private var vibesGridView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Story rings row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        // Add button
                        if !appState.hasUserPostedToday() {
                            VStack(spacing: 6) {
                                AddVibeButton(size: ringSize) {
                                    appState.navigateToComposer()
                                }
                                Text("Add")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Current user's vibes
                        let currentUserVibes = appState.vibes.filter { $0.userId == appState.userId }
                        if !currentUserVibes.isEmpty {
                            VStack(spacing: 6) {
                                VibeRingView(
                                    vibes: currentUserVibes,
                                    userId: appState.userId,
                                    isCurrentUser: true,
                                    size: ringSize
                                ) {
                                    if let index = appState.vibes.firstIndex(where: { $0.userId == appState.userId }) {
                                        appState.navigateToViewer(startingAt: index)
                                    }
                                }
                                Text("You")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Other users
                        let groupedVibes = appState.vibesGroupedByUser()
                        ForEach(groupedVibes, id: \.first?.userId) { userVibes in
                            if let firstVibe = userVibes.first,
                               firstVibe.userId != appState.userId {
                                VStack(spacing: 6) {
                                    VibeRingView(
                                        vibes: userVibes,
                                        userId: appState.userId,
                                        isCurrentUser: false,
                                        size: ringSize
                                    ) {
                                        if let index = appState.vibes.firstIndex(where: { $0.id == firstVibe.id }) {
                                            appState.navigateToViewer(startingAt: index)
                                        }
                                    }
                                    Text("Friend")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Recent vibes grid
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Vibes")
                        .font(.headline)
                        .padding(.horizontal)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
                        ForEach(Array(appState.vibes.enumerated()), id: \.element.id) { index, vibe in
                            VibeGridCell(vibe: vibe, userId: appState.userId) {
                                appState.navigateToViewer(startingAt: index)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
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
                // Background based on type
                RoundedRectangle(cornerRadius: 12)
                    .fill(vibe.type.color.opacity(0.3))
                    .aspectRatio(1, contentMode: .fit)

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
