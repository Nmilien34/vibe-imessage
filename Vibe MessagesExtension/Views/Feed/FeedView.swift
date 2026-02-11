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
                .padding(.horizontal, VibeSpacing.screenHorizontal)
                .padding(.top, VibeSpacing.xs)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(VibeAnimation.snappy, value: appState.showNetworkErrorBanner)
            }
        }
    }
}

// MARK: - Compact Feed View (Drawer Style)
struct CompactFeedView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            // Glass material drawer background
            RoundedRectangle(cornerRadius: VibeTheme.radiusXL, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.08), radius: 16, y: -5)
                .edgesIgnoringSafeArea(.bottom)

            VStack(spacing: VibeSpacing.md) {

                // 1. HANDLE & LIVE STATUS
                VStack(spacing: VibeSpacing.xs) {
                    // Drag Handle
                    Capsule()
                        .fill(VibeTheme.divider)
                        .frame(width: 36, height: 5)
                        .padding(.top, VibeSpacing.sm)

                    // Status Row: Streak + Aura Balance + Active Users
                    HStack(spacing: VibeSpacing.xs) {
                        if let streak = appState.streak, streak.currentStreak > 0 {
                            HStack(spacing: VibeSpacing.xxs) {
                                Text("\(streak.currentStreak)")
                                    .font(VibeTypography.captionLarge)
                                    .foregroundColor(.orange)
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                            }

                            Circle()
                                .fill(VibeTheme.divider)
                                .frame(width: 3, height: 3)
                        }

                        // Aura balance pill
                        if appState.auraBalance > 0 {
                            HStack(spacing: VibeSpacing.xxs) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                                Text("\(appState.auraBalance)")
                                    .font(VibeTypography.captionLarge)
                                    .foregroundColor(VibeTheme.textPrimary)
                                    .contentTransition(.numericText())
                            }

                            Circle()
                                .fill(VibeTheme.divider)
                                .frame(width: 3, height: 3)
                        }

                        Text(activeUsersText)
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(VibeTheme.textSecondary)
                    }

                    // Daily Bonus Available indicator
                    if appState.auraStats?.dailyBonusAvailable == true {
                        HStack(spacing: VibeSpacing.xxs) {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 10))
                                .foregroundColor(VibeTheme.accent)
                            Text("Daily Bonus Available")
                                .font(VibeTypography.captionSmall)
                                .foregroundColor(VibeTheme.accent)
                        }
                        .padding(.horizontal, VibeSpacing.sm)
                        .padding(.vertical, VibeSpacing.xxs)
                        .background(VibeTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .onTapGesture {
                    VibeHaptic.light()
                    appState.requestExpand()
                }

                // 2. ACTION RAIL
                HStack(spacing: VibeSpacing.md) {

                    // A. Post Vibe Button (Hero)
                    Button {
                        VibeHaptic.medium()
                        appState.shouldShowVibePicker = true
                        appState.requestExpand()
                    } label: {
                        VStack(spacing: VibeSpacing.xxs) {
                            ZStack {
                                Circle()
                                    .fill(VibeTheme.brandGradient)
                                    .frame(width: VibeSpacing.iconCircleMedium, height: VibeSpacing.iconCircleMedium)
                                    .shadow(color: VibeTheme.accent.opacity(0.4), radius: 8, y: 4)

                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("New Vibe")
                                .font(VibeTypography.captionSmall)
                                .foregroundColor(VibeTheme.textPrimary)
                        }
                    }
                    .buttonStyle(VibePressStyle())

                    // Divider
                    Rectangle()
                        .fill(VibeTheme.divider)
                        .frame(width: 1, height: 40)

                    // B. Friend Stories (Horizontal Scroll)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: VibeSpacing.sm) {
                            if appState.isLoading && appState.vibes.isEmpty {
                                ForEach(0..<3, id: \.self) { _ in
                                    CompactAvatarSkeleton()
                                }
                            } else {
                                let groupedVibes = appState.vibesGroupedByUser(nil, includeMe: true, includeTeam: true)

                                ForEach(groupedVibes, id: \.first?.userId) { userVibes in
                                    if let firstVibe = userVibes.first {
                                        let hasUnseen = userVibes.contains { !$0.hasViewed(appState.userId) }
                                        let isMe = firstVibe.userId == appState.userId

                                        CompactAvatar(
                                            name: appState.nameForUser(firstVibe.userId),
                                            thumbnailUrl: firstVibe.thumbnailUrl ?? firstVibe.mediaUrl,
                                            vibeType: firstVibe.type,
                                            hasUnseen: hasUnseen && !isMe
                                        ) {
                                            VibeHaptic.selection()
                                            appState.navigateToViewer(opening: firstVibe.id)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, VibeSpacing.xxs)
                    }
                }
                .padding(.horizontal, VibeSpacing.screenHorizontal)

                Spacer()
            }
            .padding(.bottom, VibeSpacing.lg)
        }
    }

    private var activeUsersText: String {
        let activeUsers = appState.vibesGroupedByUser()
            .compactMap { $0.first }
            .filter { $0.userId != appState.userId }
            .prefix(2)
            .map { appState.nameForUser($0.userId) }

        if activeUsers.isEmpty {
            return "No one active yet"
        } else if activeUsers.count == 1 {
            return "\(activeUsers[0]) is active"
        } else {
            return "\(activeUsers[0]) & \(activeUsers[1]) are active"
        }
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
            VStack(spacing: VibeSpacing.xxs) {
                ZStack {
                    // Gradient Ring if Unseen
                    if hasUnseen {
                        Circle()
                            .strokeBorder(
                                VibeTheme.brandGradient,
                                lineWidth: 2.5
                            )
                            .frame(width: VibeSpacing.iconCircleMedium, height: VibeSpacing.iconCircleMedium)
                    } else {
                        Circle()
                            .strokeBorder(VibeTheme.divider, lineWidth: 1)
                            .frame(width: VibeSpacing.iconCircleMedium, height: VibeSpacing.iconCircleMedium)
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
                                    .font(.system(size: 20))
                                    .foregroundColor(vibeType.color)
                            )
                    }
                }

                Text(name)
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(hasUnseen ? VibeTheme.textPrimary : VibeTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct CompactAvatarSkeleton: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: VibeSpacing.xxs) {
            Circle()
                .fill(VibeTheme.surfaceOverlay)
                .frame(width: VibeSpacing.iconCircleMedium, height: VibeSpacing.iconCircleMedium)
                .opacity(isAnimating ? 0.5 : 1.0)

            RoundedRectangle(cornerRadius: 4)
                .fill(VibeTheme.surfaceOverlay)
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
        VStack(spacing: VibeSpacing.xxs) {
            Circle()
                .fill(VibeTheme.surfaceOverlay)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color(UIColor.systemGray4), Color(UIColor.systemGray3)],
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
                .fill(VibeTheme.surfaceOverlay)
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
                        VibeTheme.surfaceOverlay
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .continuousCorner(VibeTheme.radiusSmall + 4)
                } else {
                    RoundedRectangle(cornerRadius: VibeTheme.radiusSmall + 4, style: .continuous)
                        .fill(vibe.type.color.opacity(0.3))
                        .aspectRatio(1, contentMode: .fit)
                }

                // Dark overlay for visibility if image present
                if (vibe.type == .video || vibe.type == .photo) {
                    RoundedRectangle(cornerRadius: VibeTheme.radiusSmall + 4, style: .continuous)
                        .fill(Color.black.opacity(0.2))
                }

                // Content preview
                VStack(spacing: VibeSpacing.xs) {
                    contentPreview

                    // Time remaining
                    HStack(spacing: VibeSpacing.xxs) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(vibe.timeRemainingFormatted)
                            .font(VibeTypography.numericSmall)
                    }
                    .foregroundColor(VibeTheme.textSecondary)
                }

                // Lock overlay
                if vibe.isLocked && !vibe.isUnlocked(for: userId) {
                    RoundedRectangle(cornerRadius: VibeTheme.radiusSmall + 4)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 22))
                                .foregroundColor(VibeTheme.textSecondary)
                        }
                }

                // Viewed indicator
                if vibe.hasViewed(userId) || vibe.userId == userId {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(VibeSpacing.xs)
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
                .font(.system(size: 28))
                .foregroundColor(vibe.type.color)
        case .video:
            Image(systemName: "video.fill")
                .font(.system(size: 28))
                .foregroundColor(vibe.type.color)
        case .song:
            VStack(spacing: VibeSpacing.xxs) {
                Image(systemName: "music.note")
                    .font(.system(size: 28))
                    .foregroundColor(vibe.type.color)
                if let song = vibe.songData {
                    Text(song.title)
                        .font(VibeTypography.captionSmall)
                        .lineLimit(1)
                }
            }
        case .battery:
            VStack(spacing: VibeSpacing.xxs) {
                Image(systemName: batteryIcon)
                    .font(.system(size: 28))
                    .foregroundColor(batteryColor)
                Text("\(vibe.batteryLevel ?? 0)%")
                    .font(VibeTypography.captionLarge)
            }
        case .mood:
            Text(vibe.mood?.emoji ?? "")
                .font(.system(size: 34))
            case .poll:
                VStack(spacing: VibeSpacing.xxs) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 28))
                        .foregroundColor(vibe.type.color)
                    if let poll = vibe.poll, let question = poll.question {
                        Text(question)
                            .font(VibeTypography.captionSmall)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
            case .dailyDrop:
                Image(systemName: "die.face.5")
                    .font(.system(size: 28))
                    .foregroundColor(vibe.type.color)
            case .tea:
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 28))
                    .foregroundColor(vibe.type.color)
            case .leak:
                Image(systemName: "shutter.releaser")
                    .font(.system(size: 28))
                    .foregroundColor(vibe.type.color)
            case .sketch:
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 28))
                    .foregroundColor(vibe.type.color)
            case .eta:
                Image(systemName: "location.fill")
                    .font(.system(size: 28))
                    .foregroundColor(vibe.type.color)
            case .parlay:
                VStack(spacing: VibeSpacing.xxs) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(vibe.type.color)
                    if let parlay = vibe.parlay {
                        Text(parlay.displayAmount)
                            .font(VibeTypography.captionLarge)
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
