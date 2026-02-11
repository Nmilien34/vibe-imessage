//
//  VibeViewerView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI
import AVKit
import Combine

struct VibeViewerView: View {
    @EnvironmentObject var appState: AppState
    let startIndex: Int

    @State private var currentIndex: Int = 0
    @State private var showReactions = false
    @State private var dragOffset: CGFloat = 0
    @State private var streakScale: CGFloat = 1.0
    @State private var isInitialLoading = true

    // Auto-advance timer states
    @State private var progress: Double = 0.0
    @State private var timer: Timer?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if isInitialLoading {
                    ViewerSkeletonView()
                } else if appState.viewerVibes.isEmpty {
                    emptyState
                } else {
                    ZStack {
                        TabView(selection: $currentIndex) {
                            ForEach(Array(appState.viewerVibes.enumerated()), id: \.element.id) { index, vibe in
                                vibeContent(vibe, geometry: geometry)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .onChange(of: currentIndex) { oldIndex, newIndex in
                            markAsViewed(at: newIndex)
                            startTimer()

                            if oldIndex < appState.viewerVibes.count && newIndex < appState.viewerVibes.count {
                                if appState.viewerVibes[oldIndex].userId != appState.viewerVibes[newIndex].userId {
                                    VibeHaptic.medium()
                                }
                            }
                        }

                        // Tap Navigation Overlay
                        HStack(spacing: 0) {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { goToPrevious() }

                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { goToNext() }
                        }
                    }

                    // Overlay UI
                    VStack(spacing: 0) {
                        topBar
                        Spacer()
                        bottomBar
                    }
                }
            }
        }
        .onAppear {
            currentIndex = startIndex
            markAsViewed(at: startIndex)
            appState.requestExpand()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(VibeAnimation.snappy) {
                    isInitialLoading = false
                }
                startTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func goToNext() {
        if currentIndex < appState.viewerVibes.count - 1 {
            withAnimation(VibeAnimation.snappy) {
                currentIndex += 1
            }
        } else {
            appState.navigateToFeed()
        }
    }

    private func goToPrevious() {
        if currentIndex > 0 {
            withAnimation(VibeAnimation.snappy) {
                currentIndex -= 1
            }
        }
    }

    // MARK: - Auto-Advance Timer Functions

    private func startTimer() {
        stopTimer()
        progress = 0.0

        guard currentIndex < appState.viewerVibes.count else { return }
        let vibe = appState.viewerVibes[currentIndex]

        let duration: Double = vibe.type == .photo ? 5.0 : 10.0
        let interval = 0.05

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            progress += (interval / duration)
            if progress >= 1.0 {
                stopTimer()
                goToNext()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func progressWidth(for index: Int, totalWidth: CGFloat) -> CGFloat {
        if index < currentIndex {
            return totalWidth
        } else if index == currentIndex {
            return totalWidth * progress
        } else {
            return 0
        }
    }

    private var emptyState: some View {
        VStack(spacing: VibeSpacing.lg) {
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundColor(VibeTheme.textTertiary)
            Text("No vibes to show")
                .font(VibeTypography.titleMedium)
                .foregroundColor(VibeTheme.textSecondary)
        }
    }

    @State private var musicPlayer: AVPlayer?

    private func vibeContent(_ vibe: Vibe, geometry: GeometryProxy) -> some View {
        ZStack {
            if vibe.isExpired {
                ExpiredStoryView()
            } else if vibe.isLocked && !vibe.isUnlocked(for: appState.userId) {
                LockedVibeView(vibe: vibe) {
                    appState.navigateToComposer()
                }
            } else {
                ZStack {
                    Group {
                        if vibe.type == .photo {
                            PhotoVibeContent(vibe: vibe)
                        } else if vibe.type == .video {
                            VideoVibeContent(vibe: vibe)
                        } else if vibe.type == .song {
                            SongVibeContent(vibe: vibe)
                        } else if vibe.type == .battery {
                            BatteryVibeContent(vibe: vibe)
                        } else if vibe.type == .mood {
                            MoodVibeContent(vibe: vibe)
                        } else if vibe.type == .poll {
                            PollVibeContent(vibe: vibe)
                        } else if vibe.type == .tea {
                            TeaVibeContent(vibe: vibe)
                        } else if vibe.type == .sketch {
                            SketchVibeContent(vibe: vibe)
                        } else if vibe.type == .parlay {
                            ParlayVibeContent(vibe: vibe)
                        } else if vibe.type == .eta {
                            ETAVibeContent(vibe: vibe)
                        } else {
                            PhotoVibeContent(vibe: vibe)
                        }
                    }
                    .transition(.opacity)

                    // Text Overlay
                    if let text = vibe.textStatus, !text.isEmpty {
                        VStack {
                            Spacer()
                            Text(text)
                                .font(VibeTypography.titleLarge)
                                .foregroundColor(.white)
                                .padding(.horizontal, VibeSpacing.lg)
                                .padding(.vertical, VibeSpacing.sm)
                                .background(.ultraThinMaterial)
                                .continuousCorner(VibeTheme.radiusMedium)
                                .vibeShadow(.sm)
                            Spacer()
                        }
                        .padding(.bottom, 100)
                    }
                }
                .animation(VibeAnimation.smooth, value: vibe.isUnlocked(for: appState.userId))
            }
        }
        .scaleEffect(currentIndex == appState.viewerVibes.firstIndex(where: { $0.id == vibe.id }) ? 1.0 : 0.92)
        .opacity(currentIndex == appState.viewerVibes.firstIndex(where: { $0.id == vibe.id }) ? 1.0 : 0.7)
        .animation(VibeAnimation.snappy, value: currentIndex)
        .onAppear {
            if let song = vibe.songData, let previewUrl = song.previewUrl, let url = URL(string: previewUrl) {
                musicPlayer = AVPlayer(url: url)
                musicPlayer?.play()
            }
        }
        .onDisappear {
            musicPlayer?.pause()
            musicPlayer = nil
        }
    }

    private var topBar: some View {
        VStack(spacing: VibeSpacing.sm) {
            // Progress indicators
            if !appState.viewerVibes.isEmpty {
                HStack(spacing: VibeSpacing.xxxs) {
                    ForEach(0..<appState.viewerVibes.count, id: \.self) { index in
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.3))
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: progressWidth(for: index, totalWidth: geo.size.width))
                                    .animation(.linear(duration: 0.05), value: progress)
                            }
                        }
                        .frame(height: 3)
                    }
                }
            }

            // User Info & Close Button
            HStack(spacing: VibeSpacing.sm) {
                if currentIndex < appState.viewerVibes.count {
                    let vibe = appState.viewerVibes[currentIndex]

                    // Profile Bubble
                    Circle()
                        .fill(vibe.type.color.opacity(0.3))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Text(String(appState.nameForUser(vibe.userId).prefix(1)))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(appState.nameForUser(vibe.userId))
                            .font(VibeTypography.titleSmall)
                            .foregroundColor(.white)

                        Text(timeAgo(from: vibe.createdAt))
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                // Streak badge
                if let streak = appState.streak, streak.currentStreak > 0 {
                    HStack(spacing: VibeSpacing.xxxs) {
                        Text("🔥")
                            .font(.system(size: 16))
                        Text("\(streak.currentStreak)")
                            .font(VibeTypography.numericLarge)
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, VibeSpacing.sm)
                    .padding(.vertical, VibeSpacing.xs)
                    .background(Color.orange.opacity(0.8))
                    .clipShape(Capsule())
                    .scaleEffect(streakScale)
                    .onAppear {
                        withAnimation(VibeAnimation.bouncy) {
                            streakScale = 1.2
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(VibeAnimation.smooth) {
                                streakScale = 1.0
                            }
                        }
                    }
                    .onChange(of: streak.currentStreak) { _, _ in
                        withAnimation(VibeAnimation.bouncy) {
                            streakScale = 1.4
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(VibeAnimation.smooth) {
                                streakScale = 1.0
                            }
                        }
                    }
                }

                // Timer
                if currentIndex < appState.viewerVibes.count {
                    CountdownTimer(expiresAt: appState.viewerVibes[currentIndex].expiresAt)
                        .scaleEffect(0.8)
                }

                // Close button
                Button {
                    VibeHaptic.light()
                    appState.navigateToFeed()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, VibeSpacing.md)
        .padding(.top, VibeSpacing.lg)
        .padding(.bottom, VibeSpacing.sm)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.6), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
            .ignoresSafeArea(edges: .top)
        )
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var bottomBar: some View {
        VStack(spacing: VibeSpacing.lg) {
            if currentIndex < appState.viewerVibes.count {
                let vibe = appState.viewerVibes[currentIndex]

                // Existing reactions
                if !vibe.reactions.isEmpty {
                    HStack(spacing: -8) {
                        ForEach(Array(vibe.reactions.prefix(5)), id: \.userId) { reaction in
                            Text(reaction.emoji)
                                .font(.system(size: 20))
                                .padding(VibeSpacing.xs)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }

                        if vibe.reactions.count > 5 {
                            Text("+\(vibe.reactions.count - 5)")
                                .font(VibeTypography.captionSmall)
                                .foregroundColor(.white)
                                .padding(VibeSpacing.sm)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                }

                // Reaction picker
                if showReactions {
                    ReactionPicker(
                        selectedEmoji: vibe.userReaction(appState.userId)?.emoji
                    ) { emoji in
                        VibeHaptic.selection()
                        Task {
                            await appState.addReaction(to: vibe, emoji: emoji)
                        }
                        showReactions = false
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Action buttons
                HStack(spacing: VibeSpacing.xxxl) {
                    // React button
                    Button {
                        VibeHaptic.light()
                        withAnimation(VibeAnimation.bouncy) {
                            showReactions.toggle()
                        }
                    } label: {
                        VStack(spacing: VibeSpacing.xxxs) {
                            Image(systemName: vibe.userReaction(appState.userId) != nil ? "heart.fill" : "heart")
                                .font(.system(size: 22))
                                .foregroundColor(vibe.userReaction(appState.userId) != nil ? .red : .white)
                            Text("React")
                                .font(VibeTypography.captionSmall)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    // Views count
                    VStack(spacing: VibeSpacing.xxxs) {
                        HStack(spacing: VibeSpacing.xxxs) {
                            Image(systemName: "eye")
                            Text("\(vibe.viewedBy.count)")
                                .contentTransition(.numericText())
                        }
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        Text("Views")
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding(.horizontal, VibeSpacing.md)
        .padding(.bottom, VibeSpacing.xl)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func markAsViewed(at index: Int) {
        guard index < appState.viewerVibes.count else { return }
        let vibe = appState.viewerVibes[index]
        Task {
            await appState.markAsViewed(vibe)
        }
    }
}

// MARK: - Reaction Picker
struct ReactionPicker: View {
    let selectedEmoji: String?
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: VibeSpacing.sm) {
            ForEach(Reaction.availableEmojis, id: \.self) { emoji in
                Button {
                    onSelect(emoji)
                } label: {
                    Text(emoji)
                        .font(.system(size: 28))
                        .scaleEffect(selectedEmoji == emoji ? 1.3 : 1.0)
                        .padding(VibeSpacing.sm)
                        .background(
                            selectedEmoji == emoji
                                ? Color.white.opacity(0.3)
                                : Color.clear
                        )
                        .clipShape(Circle())
                }
            }
        }
        .padding(VibeSpacing.md)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

// MARK: - Photo Vibe Content
struct PhotoVibeContent: View {
    let vibe: Vibe
    @State private var loadFailed = false
    @State private var retryId = UUID()

    var body: some View {
        ZStack {
            if let mediaUrl = vibe.mediaUrl, let url = URL(string: mediaUrl) {
                if loadFailed {
                    ImageLoadErrorView {
                        loadFailed = false
                        retryId = UUID()
                    }
                } else {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            ImageLoadErrorView {
                                loadFailed = false
                                retryId = UUID()
                            }
                            .onAppear {
                                loadFailed = true
                            }
                        @unknown default:
                            ProgressView()
                        }
                    }
                    .id(retryId)
                }
            } else {
                ImageLoadErrorView(onRetry: nil)
            }
        }
    }
}

// MARK: - Video Vibe Content
struct VideoVibeContent: View {
    let vibe: Vibe
    @State private var player: AVPlayer?
    @State private var playerError: Error?
    @State private var isLoading = true
    @State private var retryCount = 0

    var body: some View {
        ZStack {
            if let mediaUrl = vibe.mediaUrl, let url = URL(string: mediaUrl) {
                if playerError != nil {
                    VideoPlaybackErrorView {
                        retryPlayback(url: url)
                    }
                } else {
                    VideoPlayer(player: player)
                        .onAppear {
                            setupPlayer(url: url)
                        }
                        .onDisappear {
                            cleanupPlayer()
                        }

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
            } else if let thumbnailUrl = vibe.thumbnailUrl, let url = URL(string: thumbnailUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        ImageLoadErrorView()
                    @unknown default:
                        ProgressView()
                    }
                }
            } else {
                VideoPlaybackErrorView(onRetry: nil)
            }
        }
    }

    private func setupPlayer(url: URL) {
        let playerItem = AVPlayerItem(url: url)

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                self.playerError = error
            }
        }

        player = AVPlayer(playerItem: playerItem)

        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { status in
                switch status {
                case .readyToPlay:
                    isLoading = false
                    player?.play()
                case .failed:
                    isLoading = false
                    playerError = playerItem.error
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func cleanupPlayer() {
        player?.pause()
        player = nil
        NotificationCenter.default.removeObserver(self)
    }

    private func retryPlayback(url: URL) {
        playerError = nil
        isLoading = true
        retryCount += 1
        cleanupPlayer()
        setupPlayer(url: url)
    }

    @State private var cancellables = Set<AnyCancellable>()
}

// MARK: - Song Vibe Content
struct SongVibeContent: View {
    let vibe: Vibe
    @State private var isPlaying = false

    var body: some View {
        ZStack {
            if let albumArt = vibe.songData?.albumArt, let url = URL(string: albumArt) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 50)
                        .overlay(Color.black.opacity(0.5))
                } placeholder: {
                    Color.green.opacity(0.3)
                }
                .ignoresSafeArea()
            }

            VStack(spacing: VibeSpacing.xl) {
                if let albumArt = vibe.songData?.albumArt, let url = URL(string: albumArt) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: VibeTheme.radiusMedium)
                            .fill(VibeTheme.surfaceOverlay)
                    }
                    .frame(width: 250, height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: VibeTheme.radiusMedium))
                    .vibeShadow(.xl)
                } else {
                    RoundedRectangle(cornerRadius: VibeTheme.radiusMedium)
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 250, height: 250)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 80))
                                .foregroundColor(.green)
                        }
                }

                VStack(spacing: VibeSpacing.sm) {
                    Text(vibe.songData?.title ?? "Unknown Song")
                        .font(VibeTypography.titleLarge)
                        .foregroundColor(.white)

                    Text(vibe.songData?.artist ?? "Unknown Artist")
                        .font(VibeTypography.bodyMedium)
                        .foregroundColor(.white.opacity(0.8))
                }

                if vibe.songData?.previewUrl != nil {
                    Button {
                        isPlaying.toggle()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

// MARK: - Battery Vibe Content
struct BatteryVibeContent: View {
    let vibe: Vibe

    private var batteryLevel: Int {
        vibe.batteryLevel ?? 0
    }

    private var batteryColor: Color {
        switch batteryLevel {
        case 0..<20: return .red
        case 20..<50: return .yellow
        default: return .green
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [batteryColor.opacity(0.3), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: VibeSpacing.xxl) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.5), lineWidth: 4)
                        .frame(width: 120, height: 200)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 40, height: 10)
                        .offset(y: -105)

                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [batteryColor, batteryColor.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 108, height: CGFloat(batteryLevel) * 1.88)
                    }
                    .frame(width: 120, height: 196)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }

                Text("\(batteryLevel)%")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())

                Text(batteryStatusText)
                    .font(VibeTypography.titleSmall)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    private var batteryStatusText: String {
        switch batteryLevel {
        case 0..<10: return "Critically low!"
        case 10..<20: return "Running low"
        case 20..<50: return "Getting there"
        case 50..<80: return "Doing good"
        case 80..<100: return "Almost full"
        default: return "Fully charged!"
        }
    }
}

// MARK: - Mood Vibe Content
struct MoodVibeContent: View {
    let vibe: Vibe
    @State private var animateEmoji = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.purple, .pink, .orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: VibeSpacing.xxl) {
                Text(vibe.mood?.emoji ?? "😊")
                    .font(.system(size: 150))
                    .scaleEffect(animateEmoji ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: animateEmoji
                    )

                if let text = vibe.mood?.text, !text.isEmpty {
                    Text(text)
                        .font(VibeTypography.displaySmall)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .onAppear {
            animateEmoji = true
        }
    }
}

// MARK: - Poll Vibe Content
struct PollVibeContent: View {
    let vibe: Vibe
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if let poll = vibe.poll {
                VStack(spacing: VibeSpacing.xl) {
                    Text(poll.question ?? "Vote")
                        .font(VibeTypography.titleLarge)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(spacing: VibeSpacing.sm) {
                        ForEach(Array(poll.options.enumerated()), id: \.element.id) { index, option in
                            PollOptionView(
                                option: option,
                                optionIndex: index,
                                poll: poll,
                                userId: appState.userId,
                                hasVoted: poll.hasVoted(userId: appState.userId)
                            ) {
                                VibeHaptic.selection()
                                Task {
                                    await appState.vote(on: vibe, optionId: option.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    Text("\(poll.totalVotes) votes")
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - Tea Vibe Content
struct TeaVibeContent: View {
    let vibe: Vibe

    var body: some View {
        ZStack {
            if let mediaUrl = vibe.mediaUrl, let url = URL(string: mediaUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .overlay(Color.black.opacity(0.3))
                } placeholder: {
                    backgroundGradient
                }
                .ignoresSafeArea()
            } else {
                backgroundGradient
                    .ignoresSafeArea()
            }

            Text(vibe.textStatus ?? "")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(VibeSpacing.xxxl)
        }
    }

    private var backgroundGradient: LinearGradient {
        switch vibe.styleName {
        case "Noir": return LinearGradient(colors: [.black, .gray], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "Fire": return LinearGradient(colors: [.orange, .red, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        default: return LinearGradient(colors: [.purple, .blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Sketch Vibe Content
struct SketchVibeContent: View {
    let vibe: Vibe

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let mediaUrl = vibe.mediaUrl, let url = URL(string: mediaUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        VStack(spacing: VibeSpacing.md) {
                            Image(systemName: "hand.draw.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.orange.opacity(0.3))
                            Text("Doodle failed to load")
                                .font(VibeTypography.bodyMedium)
                                .foregroundColor(VibeTheme.textTertiary)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                VStack(spacing: VibeSpacing.md) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.orange.opacity(0.3))
                    Text("Doodle incoming...")
                        .font(VibeTypography.bodyMedium)
                        .foregroundColor(VibeTheme.textTertiary)
                }
            }
        }
    }
}

// MARK: - ETA Vibe Content
struct ETAVibeContent: View {
    let vibe: Vibe

    var body: some View {
        ZStack {
            VibeTheme.groupedBackground.ignoresSafeArea()

            VStack(spacing: VibeSpacing.xxxl) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 300, height: 300)

                    Image(systemName: "location.north.circle.fill")
                        .font(.system(size: 150))
                        .foregroundColor(.blue)
                }

                Text(vibe.etaStatus ?? "On my way!")
                    .font(VibeTypography.displaySmall)
                    .foregroundColor(VibeTheme.textPrimary)
            }
        }
    }
}

struct PollOptionView: View {
    let option: PollOption
    let optionIndex: Int
    let poll: Poll
    let userId: String
    let hasVoted: Bool
    let onVote: () -> Void

    private var percentage: Double {
        poll.votePercentage(for: optionIndex)
    }

    private var isSelected: Bool {
        poll.votedOptionIndex(userId: userId) == optionIndex
    }

    var body: some View {
        Button(action: onVote) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: VibeTheme.radiusMedium)
                    .fill(Color.white.opacity(0.2))

                if hasVoted {
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: VibeTheme.radiusMedium)
                            .fill(isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.2))
                            .frame(width: geometry.size.width * (percentage / 100))
                    }
                }

                HStack {
                    Text(option.text)
                        .font(VibeTypography.titleSmall)
                        .foregroundColor(.white)

                    Spacer()

                    if hasVoted {
                        Text("\(Int(percentage))%")
                            .font(VibeTypography.bodyMedium)
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                    }
                }
                .padding(VibeSpacing.md)
            }
            .frame(height: 56)
        }
        .buttonStyle(.plain)
        .disabled(hasVoted)
    }
}

// MARK: - Viewer Skeleton View
struct ViewerSkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar skeleton
                VStack(spacing: VibeSpacing.sm) {
                    HStack(spacing: VibeSpacing.xxxs) {
                        ForEach(0..<4, id: \.self) { _ in
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 3)
                        }
                    }

                    HStack(spacing: VibeSpacing.sm) {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: VibeSpacing.xxxs) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 80, height: 12)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 50, height: 8)
                        }

                        Spacer()

                        RoundedRectangle(cornerRadius: VibeTheme.radiusSmall)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 60, height: 24)

                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                    }
                }
                .padding(.horizontal, VibeSpacing.md)
                .padding(.top, VibeSpacing.sm)

                Spacer()

                VStack(spacing: VibeSpacing.lg) {
                    RoundedRectangle(cornerRadius: VibeTheme.radiusMedium)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 200, height: 200)

                    RoundedRectangle(cornerRadius: VibeTheme.radiusSmall)
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 150, height: 20)
                }

                Spacer()

                VStack(spacing: VibeSpacing.lg) {
                    HStack(spacing: VibeSpacing.xxl) {
                        VStack(spacing: VibeSpacing.xxxs) {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 32, height: 32)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 40, height: 10)
                        }
                        VStack(spacing: VibeSpacing.xxxs) {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 32, height: 32)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 40, height: 10)
                        }
                    }
                }
                .padding(VibeSpacing.md)
            }
        }
        .vibeShimmer()
    }
}

#Preview {
    VibeViewerView(startIndex: 0)
        .environmentObject(AppState())
}
