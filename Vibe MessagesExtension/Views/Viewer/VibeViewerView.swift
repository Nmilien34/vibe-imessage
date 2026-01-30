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
                    // Skeleton loading state
                    ViewerSkeletonView()
                } else if appState.viewerVibes.isEmpty {
                    emptyState
                } else {
                    // Main content
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

                            // Restart timer for new vibe
                            startTimer()

                            // Haptic on user change
                            if oldIndex < appState.viewerVibes.count && newIndex < appState.viewerVibes.count {
                                if appState.viewerVibes[oldIndex].userId != appState.viewerVibes[newIndex].userId {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                }
                            }
                        }

                        // Tap Navigation Overlay
                        HStack(spacing: 0) {
                            // Left side (Previous)
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    goToPrevious()
                                }

                            // Right side (Next)
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    goToNext()
                                }
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
            // Brief delay to ensure content is ready, then hide skeleton
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.2)) {
                    isInitialLoading = false
                }
                // Start auto-advance timer after loading
                startTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func goToNext() {
        if currentIndex < appState.viewerVibes.count - 1 {
            withAnimation {
                currentIndex += 1
            }
        } else {
            // End of all vibes, close viewer
            appState.navigateToFeed()
        }
    }
    
    private func goToPrevious() {
        if currentIndex > 0 {
            withAnimation {
                currentIndex -= 1
            }
        } else {
            // At start, maybe just stay or close? Instagram stays.
        }
    }

    // MARK: - Auto-Advance Timer Functions

    private func startTimer() {
        stopTimer()
        progress = 0.0

        guard currentIndex < appState.viewerVibes.count else { return }
        let vibe = appState.viewerVibes[currentIndex]

        // Determine duration based on vibe type
        let duration: Double = vibe.type == .photo ? 5.0 : 10.0
        let interval = 0.05 // Update every 50ms for smooth animation

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            progress += (interval / duration)

            if progress >= 1.0 {
                stopTimer()
                // Auto-advance to next vibe
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
            // Already viewed - full width
            return totalWidth
        } else if index == currentIndex {
            // Currently viewing - animated progress
            return totalWidth * progress
        } else {
            // Not yet viewed - empty
            return 0
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No vibes to show")
                .font(.headline)
                .foregroundColor(.gray)
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
                        } else if vibe.type == .eta {
                            ETAVibeContent(vibe: vibe)
                        } else {
                            PhotoVibeContent(vibe: vibe)
                        }
                    }
                    .transition(.opacity)
                    
                    // Text Overlay (Instagram Style)
                    if let text = vibe.textStatus, !text.isEmpty {
                        VStack {
                            Spacer()
                            Text(text)
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .shadow(radius: 4)
                            Spacer()
                        }
                        .padding(.bottom, 100)
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: vibe.isUnlocked(for: appState.userId))
            }
        }
        .scaleEffect(currentIndex == appState.viewerVibes.firstIndex(where: { $0.id == vibe.id }) ? 1.0 : 0.95)
        .opacity(currentIndex == appState.viewerVibes.firstIndex(where: { $0.id == vibe.id }) ? 1.0 : 0.7)
        .animation(.interactiveSpring(), value: currentIndex)
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
        VStack(spacing: 12) {
            // 1. Progress indicators (Full width at the very top) - Instagram style
            if !appState.viewerVibes.isEmpty {
                HStack(spacing: 4) {
                    ForEach(0..<appState.viewerVibes.count, id: \.self) { index in
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                // Background
                                Capsule()
                                    .fill(Color.white.opacity(0.3))

                                // Progress fill
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: progressWidth(for: index, totalWidth: geo.size.width))
                            }
                        }
                        .frame(height: 3)
                    }
                }
            }

            // 2. User Info & Close Button
            HStack(spacing: 12) {
                if currentIndex < appState.viewerVibes.count {
                    let vibe = appState.viewerVibes[currentIndex]
                    
                    // Profile Bubble (Simplified Avatar)
                    Circle()
                        .fill(vibe.type.color.opacity(0.3))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Text(String(nameForUser(vibe.userId).prefix(1)))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(nameForUser(vibe.userId))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(timeAgo(from: vibe.createdAt))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                // Streak (Task 9.2) - 🔥 count
                if let streak = appState.streak, streak.currentStreak > 0 {
                    HStack(spacing: 2) {
                        Text("🔥")
                            .font(.system(size: 16))
                        Text("\(streak.currentStreak)")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.8))
                    .clipShape(Capsule())
                    .scaleEffect(streakScale)
                    .onAppear {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.4, blendDuration: 0)) {
                            streakScale = 1.2
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                streakScale = 1.0
                            }
                        }
                    }
                    .onChange(of: streak.currentStreak) { _, _ in
                        // Animate on increase
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.4, blendDuration: 0)) {
                            streakScale = 1.4
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                streakScale = 1.0
                            }
                        }
                    }
                }

                // Timer (Now part of the user row)
                if currentIndex < appState.viewerVibes.count {
                    CountdownTimer(expiresAt: appState.viewerVibes[currentIndex].expiresAt)
                        .scaleEffect(0.8)
                }

                // Close button (Moved to right)
                Button {
                    appState.navigateToFeed()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
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

    private func nameForUser(_ id: String) -> String {
        if id == appState.userId { return "You" }
        if id.contains("friend_1") { return "Sarah" }
        if id.contains("friend_2") { return "Mike" }
        if id.contains("friend_3") { return "Alex" }
        if id.contains("friend_4") { return "Sam" }
        if id.contains("friend_5") { return "Jordan" }
        return "Friend"
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var bottomBar: some View {
        VStack(spacing: 16) {
            // Reactions
            if currentIndex < appState.viewerVibes.count {
                let vibe = appState.viewerVibes[currentIndex]

                // Show existing reactions
                if !vibe.reactions.isEmpty {
                    HStack(spacing: -8) {
                        ForEach(Array(vibe.reactions.prefix(5)), id: \.userId) { reaction in
                            Text(reaction.emoji)
                                .font(.title3)
                                .padding(6)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }

                        if vibe.reactions.count > 5 {
                            Text("+\(vibe.reactions.count - 5)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                }

                // Reaction picker
                if showReactions {
                    ReactionPicker(
                        selectedEmoji: vibe.userReaction(appState.userId)?.emoji
                    ) { emoji in
                        Task {
                            await appState.addReaction(to: vibe, emoji: emoji)
                        }
                        showReactions = false
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Action buttons
                HStack(spacing: 32) {
                    // React button
                    Button {
                        withAnimation(.spring()) {
                            showReactions.toggle()
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: vibe.userReaction(appState.userId) != nil ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundColor(vibe.userReaction(appState.userId) != nil ? .red : .white)
                            Text("React")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    // Views count
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "eye")
                            Text("\(vibe.viewedBy.count)")
                        }
                        .font(.title3)
                        .foregroundColor(.white)
                        Text("Views")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
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
        HStack(spacing: 12) {
            ForEach(Reaction.availableEmojis, id: \.self) { emoji in
                Button {
                    onSelect(emoji)
                } label: {
                    Text(emoji)
                        .font(.title)
                        .scaleEffect(selectedEmoji == emoji ? 1.3 : 1.0)
                        .padding(8)
                        .background(
                            selectedEmoji == emoji
                                ? Color.white.opacity(0.3)
                                : Color.clear
                        )
                        .clipShape(Circle())
                }
            }
        }
        .padding()
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
                    // Error state
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

        // Observe player item status
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

        // Observe when player is ready
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
            // Album art background
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

            VStack(spacing: 24) {
                // Album art
                if let albumArt = vibe.songData?.albumArt, let url = URL(string: albumArt) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 250, height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 20)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 250, height: 250)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 80))
                                .foregroundColor(.green)
                        }
                }

                // Song info
                VStack(spacing: 8) {
                    Text(vibe.songData?.title ?? "Unknown Song")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(vibe.songData?.artist ?? "Unknown Artist")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }

                // Play preview button (if available)
                if vibe.songData?.previewUrl != nil {
                    Button {
                        // Audio preview would go here
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
            // Animated background
            LinearGradient(
                colors: [batteryColor.opacity(0.3), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                // Battery visualization
                ZStack {
                    // Battery outline
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.5), lineWidth: 4)
                        .frame(width: 120, height: 200)

                    // Battery cap
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 40, height: 10)
                        .offset(y: -105)

                    // Battery fill
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

                // Percentage
                Text("\(batteryLevel)%")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Status text
                Text(batteryStatusText)
                    .font(.title3)
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
            // Gradient background
            LinearGradient(
                colors: [.purple, .pink, .orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                // Large emoji
                Text(vibe.mood?.emoji ?? "😊")
                    .font(.system(size: 150))
                    .scaleEffect(animateEmoji ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: animateEmoji
                    )

                // Mood text
                if let text = vibe.mood?.text, !text.isEmpty {
                    Text(text)
                        .font(.title)
                        .fontWeight(.medium)
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
            // Background
            LinearGradient(
                colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if let poll = vibe.poll {
                VStack(spacing: 24) {
                    // Question
                    Text(poll.question ?? "Vote")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Options
                    VStack(spacing: 12) {
                        ForEach(Array(poll.options.enumerated()), id: \.element.id) { index, option in
                            PollOptionView(
                                option: option,
                                optionIndex: index,
                                poll: poll,
                                userId: appState.userId,
                                hasVoted: poll.hasVoted(userId: appState.userId)
                            ) {
                                Task {
                                    await appState.vote(on: vibe, optionId: option.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Total votes
                    Text("\(poll.totalVotes) votes")
                        .font(.caption)
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
                .padding(40)
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
            
            VStack {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange.opacity(0.3))
                Text("Doodle incoming...")
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

// MARK: - ETA Vibe Content
struct ETAVibeContent: View {
    let vibe: Vibe
    
    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            
            VStack(spacing: 40) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 300, height: 300)
                    
                    Image(systemName: "location.north.circle.fill")
                        .font(.system(size: 150))
                        .foregroundColor(.blue)
                }
                
                Text(vibe.etaStatus ?? "On my way!")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
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
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.2))

                // Progress fill
                if hasVoted {
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.2))
                            .frame(width: geometry.size.width * (percentage / 100))
                    }
                }

                // Content
                HStack {
                    Text(option.text)
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    if hasVoted {
                        Text("\(Int(percentage))%")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                    }
                }
                .padding()
            }
            .frame(height: 56)
        }
        .buttonStyle(.plain)
        .disabled(hasVoted)
    }
}

// MARK: - Viewer Skeleton View (Loading Placeholder)
struct ViewerSkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar skeleton
                VStack(spacing: 12) {
                    // Progress indicators
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { _ in
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 3)
                        }
                    }

                    // User info skeleton
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 80, height: 12)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 50, height: 8)
                        }

                        Spacer()

                        // Timer skeleton
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 60, height: 24)

                        // Close button skeleton
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 28, height: 28)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)

                Spacer()

                // Content skeleton (center area)
                VStack(spacing: 16) {
                    // Main content placeholder
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 200, height: 200)

                    // Text placeholder
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 150, height: 20)
                }

                Spacer()

                // Bottom bar skeleton
                VStack(spacing: 16) {
                    // Reaction buttons skeleton
                    HStack(spacing: 32) {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 32, height: 32)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 40, height: 10)
                        }

                        VStack(spacing: 4) {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 32, height: 32)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 40, height: 10)
                        }
                    }
                }
                .padding()
            }
        }
        .opacity(isAnimating ? 0.6 : 1.0)
        .animation(
            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
            value: isAnimating
        )
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    VibeViewerView(startIndex: 0)
        .environmentObject(AppState())
}
