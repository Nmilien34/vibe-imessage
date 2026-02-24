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
        .task {
            await appState.loadAuraStats()
            await appState.loadCurrentUserProfile()
        }
    }
}

// MARK: - Compact Feed View (Challenges-First Drawer)
struct CompactFeedView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            // Flat drawer background to reduce visual noise in compact mode
            RoundedRectangle(cornerRadius: VibeTheme.radiusXL, style: .continuous)
                .fill(VibeTheme.cardBackground)
                .shadow(color: Color.black.opacity(0.03), radius: 4, y: -1)
                .edgesIgnoringSafeArea(.bottom)

            VStack(spacing: 0) {
                // 1. HANDLE + HEADER
                VStack(spacing: VibeSpacing.xs) {
                    Capsule()
                        .fill(VibeTheme.divider)
                        .frame(width: 36, height: 5)
                        .padding(.top, VibeSpacing.sm)

                    // Brand + Aura
                    HStack {
                        Text("Vibes")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(VibeTheme.warm)

                        Spacer()

                        AuraBadge(amount: appState.auraBalance, size: .small)

                        Button {
                            VibeHaptic.selection()
                            appState.requestExpand()
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(VibeTheme.betAccent)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(VibeTheme.surfaceOverlay))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, VibeSpacing.screenHorizontal)
                }

                // 2. COMPACT STORY ROW (secondary)
                // Keep compact + expanded using the same story source so activity feels continuous.
                let groupedVibes = appState.storyGroupsForFeed()
                if !groupedVibes.isEmpty || (appState.isLoading && appState.vibes.isEmpty) {
                    VStack(alignment: .leading, spacing: VibeSpacing.xxs) {
                        HStack(spacing: VibeSpacing.xxs) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(VibeTheme.betAccent)
                            Text("Live stories from your chats")
                                .font(VibeTypography.captionSmall)
                                .foregroundColor(VibeTheme.textSecondary)
                        }
                        .padding(.horizontal, VibeSpacing.screenHorizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: VibeSpacing.sm) {
                                if appState.isLoading && appState.vibes.isEmpty {
                                    ForEach(0..<4, id: \.self) { _ in
                                        CompactStoryDot()
                                    }
                                } else {
                                    ForEach(groupedVibes, id: \.first?.userId) { userVibes in
                                        if let firstVibe = userVibes.first {
                                            let hasUnseen = userVibes.contains { !$0.hasViewed(appState.userId) }
                                            CompactStoryDot(
                                                thumbnailUrl: profileThumbnailURL(for: firstVibe.userId),
                                                fallbackThumbnailUrl: firstVibe.thumbnailUrl ?? firstVibe.mediaUrl,
                                                fallbackInitial: "V",
                                                hasUnseen: hasUnseen && firstVibe.userId != appState.userId,
                                                color: firstVibe.type.color
                                            ) {
                                                VibeHaptic.selection()
                                                appState.navigateToViewer(opening: firstVibe.id)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, VibeSpacing.screenHorizontal)
                        }
                    }
                    .padding(.top, VibeSpacing.sm)
                    .task(id: storyUserCacheTaskKey(for: groupedVibes)) {
                        await appState.loadBatchUsers(ids: storyUserIds(for: groupedVibes))
                    }
                }

                // 3. CHALLENGES FEED
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: VibeSpacing.sm) {
                        if appState.isLoadingBets && appState.activeBets.isEmpty {
                            // Skeleton cards
                            ForEach(0..<2, id: \.self) { _ in
                                CompactCardSkeleton()
                            }
                        } else if appState.activeBets.isEmpty {
                            // Empty state
                            VStack(spacing: VibeSpacing.md) {
                                Image(systemName: "dice")
                                    .font(.system(size: 32))
                                    .foregroundColor(VibeTheme.textTertiary)
                                Text("No active challenges")
                                    .font(VibeTypography.bodyMedium)
                                    .foregroundColor(VibeTheme.textSecondary)
                                Text("Create one to get started!")
                                    .font(VibeTypography.captionSmall)
                                    .foregroundColor(VibeTheme.textTertiary)
                                Text("Or swipe up to see the full product.")
                                    .font(VibeTypography.captionSmall)
                                    .foregroundColor(VibeTheme.textTertiary)
                            }
                            .padding(.top, VibeSpacing.xxxl)
                        } else {
                            // Active bets
                            ForEach(appState.activeBets) { bet in
                                BetCard(
                                    bet: bet,
                                    totals: appState.betTotalsById[bet.betId],
                                    interactionStyle: .quickStake
                                )
                            }
                        }
                    }
                    .padding(.horizontal, VibeSpacing.screenHorizontal)
                    .padding(.top, VibeSpacing.sm)
                    .padding(.bottom, 70) // Space for CTA button
                }

                Spacer(minLength: 0)

                // 4. NEW CHALLENGE CTA
                Button {
                    VibeHaptic.medium()
                    appState.showCreateSheet = true
                } label: {
                    HStack(spacing: VibeSpacing.xs) {
                        Image(systemName: "plus.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        Text("New Challenge")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: VibeSpacing.minTouchTarget)
                    .background(VibeTheme.betAccent)
                    .continuousCorner(VibeTheme.radiusMedium)
                }
                .buttonStyle(VibePressStyle())
                .padding(.horizontal, VibeSpacing.screenHorizontal)
                .padding(.bottom, VibeSpacing.md)
            }
        }
        .sheet(isPresented: $appState.showCreateSheet) {
            CreateChallengeSheet()
                .environmentObject(appState)
        }
    }

    private func profileThumbnailURL(for userId: String) -> String? {
        if userId == appState.userId {
            return appState.userProfilePictureURL
        }
        return appState.userCache[userId]?.profilePicture
    }

    private func storyUserIds(for groups: [[Vibe]]) -> [String] {
        Array(Set(groups.compactMap { $0.first?.userId }))
    }

    private func storyUserCacheTaskKey(for groups: [[Vibe]]) -> String {
        storyUserIds(for: groups).sorted().joined(separator: "|")
    }
}

// MARK: - Compact Story Dot (small circle for compact story row)

struct CompactStoryDot: View {
    var thumbnailUrl: String? = nil
    var fallbackThumbnailUrl: String? = nil
    var fallbackInitial: String = "V"
    var hasUnseen: Bool = false
    var color: Color = .gray
    var size: CGFloat = 52
    var onTap: (() -> Void)? = nil

    private var innerSize: CGFloat {
        size - 6
    }

    private var resolvedThumbnailUrl: String? {
        let candidates: [String?] = [thumbnailUrl, fallbackThumbnailUrl]
        for candidate in candidates {
            guard let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                continue
            }
            return trimmed
        }
        return nil
    }

    private var fallbackGlyph: String {
        let trimmed = fallbackInitial.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "V" }
        return String(first).uppercased()
    }

    private var unreadRingGradient: LinearGradient {
        LinearGradient(
            colors: [VibeTheme.warm, VibeTheme.accentSecondary, VibeTheme.accentCyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var fallbackAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [VibeTheme.warm.opacity(0.95), VibeTheme.accentSecondary.opacity(0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Text(fallbackGlyph)
                    .font(.system(size: max(14, innerSize * 0.42), weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(width: innerSize, height: innerSize)
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            ZStack {
                if hasUnseen {
                    Circle()
                        .strokeBorder(unreadRingGradient, lineWidth: 2.5)
                        .frame(width: size, height: size)
                        .shadow(color: VibeTheme.warm.opacity(0.45), radius: 6)
                        .shadow(color: VibeTheme.accentSecondary.opacity(0.25), radius: 10)

                    Circle()
                        .stroke(unreadRingGradient.opacity(0.65), lineWidth: 4)
                        .blur(radius: 3.5)
                        .frame(width: size, height: size)
                } else {
                    Circle()
                        .strokeBorder(VibeTheme.divider, lineWidth: 1)
                        .frame(width: size, height: size)
                }

                if let urlString = resolvedThumbnailUrl, let url = URL.httpURL(from: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        fallbackAvatar
                    }
                    .frame(width: innerSize, height: innerSize)
                    .clipShape(Circle())
                } else {
                    fallbackAvatar
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Card Skeleton

struct CompactCardSkeleton: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            HStack {
                Circle()
                    .fill(VibeTheme.surfaceOverlay)
                    .frame(width: 28, height: 28)
                RoundedRectangle(cornerRadius: 4)
                    .fill(VibeTheme.surfaceOverlay)
                    .frame(width: 80, height: 14)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(VibeTheme.surfaceOverlay)
                    .frame(width: 50, height: 14)
            }

            RoundedRectangle(cornerRadius: 4)
                .fill(VibeTheme.surfaceOverlay)
                .frame(height: 16)
            RoundedRectangle(cornerRadius: 4)
                .fill(VibeTheme.surfaceOverlay)
                .frame(width: 180, height: 16)

            HStack(spacing: VibeSpacing.sm) {
                RoundedRectangle(cornerRadius: VibeTheme.radiusSmall)
                    .fill(VibeTheme.surfaceOverlay)
                    .frame(height: 36)
                RoundedRectangle(cornerRadius: VibeTheme.radiusSmall)
                    .fill(VibeTheme.surfaceOverlay)
                    .frame(height: 36)
            }
        }
        .padding(VibeSpacing.md)
        .background(VibeTheme.cardBackground)
        .continuousCorner(VibeTheme.radiusMedium)
        .opacity(isAnimating ? 0.5 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Legacy Components (kept for viewer/other usage)

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
                    if hasUnseen {
                        Circle()
                            .strokeBorder(VibeTheme.brandGradient, lineWidth: 2.5)
                            .frame(width: VibeSpacing.iconCircleMedium, height: VibeSpacing.iconCircleMedium)
                    } else {
                        Circle()
                            .strokeBorder(VibeTheme.divider, lineWidth: 1)
                            .frame(width: VibeSpacing.iconCircleMedium, height: VibeSpacing.iconCircleMedium)
                    }

                    if let urlString = thumbnailUrl, let url = URL.httpURL(from: urlString) {
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

struct VibeGridCell: View {
    let vibe: Vibe
    let userId: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if (vibe.type == .video || vibe.type == .photo),
                   let urlString = vibe.thumbnailUrl ?? (vibe.type == .photo ? vibe.mediaUrl : nil),
                   let url = URL.httpURL(from: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
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

                if (vibe.type == .video || vibe.type == .photo) {
                    RoundedRectangle(cornerRadius: VibeTheme.radiusSmall + 4, style: .continuous)
                        .fill(Color.black.opacity(0.2))
                }

                VStack(spacing: VibeSpacing.xs) {
                    contentPreview

                    HStack(spacing: VibeSpacing.xxs) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(vibe.timeRemainingFormatted)
                            .font(VibeTypography.numericSmall)
                    }
                    .foregroundColor(VibeTheme.textSecondary)
                }

                if vibe.isLocked && !vibe.isUnlocked(for: userId) {
                    RoundedRectangle(cornerRadius: VibeTheme.radiusSmall + 4)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 22))
                                .foregroundColor(VibeTheme.textSecondary)
                        }
                }

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
