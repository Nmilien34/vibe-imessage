//
//  VibeViewerView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI
import AVKit

struct VibeViewerView: View {
    @EnvironmentObject var appState: AppState
    let startIndex: Int

    @State private var currentIndex: Int = 0
    @State private var showReactions = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if appState.vibes.isEmpty {
                    emptyState
                } else {
                    // Main content
                    TabView(selection: $currentIndex) {
                        ForEach(Array(appState.vibes.enumerated()), id: \.element.id) { index, vibe in
                            vibeContent(vibe, geometry: geometry)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: currentIndex) { _, newIndex in
                        markAsViewed(at: newIndex)
                    }

                    // Overlay UI
                    VStack {
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
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 {
                        appState.navigateToFeed()
                    }
                    dragOffset = 0
                }
        )
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

    @ViewBuilder
    private func vibeContent(_ vibe: Vibe, geometry: GeometryProxy) -> some View {
        if vibe.isLocked && !vibe.isUnlocked(for: appState.userId) {
            LockedVibeView(vibe: vibe) {
                appState.navigateToComposer()
            }
        } else {
            switch vibe.type {
            case .photo:
                PhotoVibeContent(vibe: vibe)
            case .video:
                VideoVibeContent(vibe: vibe)
            case .song:
                SongVibeContent(vibe: vibe)
            case .battery:
                BatteryVibeContent(vibe: vibe)
            case .mood:
                MoodVibeContent(vibe: vibe)
            case .poll:
                PollVibeContent(vibe: vibe)
            }
        }
    }

    private var topBar: some View {
        HStack {
            // Close button
            Button {
                appState.navigateToFeed()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }

            Spacer()

            // Progress indicators
            if !appState.vibes.isEmpty {
                HStack(spacing: 4) {
                    ForEach(0..<appState.vibes.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentIndex ? Color.white : Color.white.opacity(0.3))
                            .frame(width: index == currentIndex ? 20 : 8, height: 4)
                            .animation(.spring(), value: currentIndex)
                    }
                }
            }

            Spacer()

            // Timer
            if currentIndex < appState.vibes.count {
                CountdownTimer(expiresAt: appState.vibes[currentIndex].expiresAt)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.black.opacity(0.5), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var bottomBar: some View {
        VStack(spacing: 16) {
            // Reactions
            if currentIndex < appState.vibes.count {
                let vibe = appState.vibes[currentIndex]

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
        .padding()
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func markAsViewed(at index: Int) {
        guard index < appState.vibes.count else { return }
        let vibe = appState.vibes[index]
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

    var body: some View {
        ZStack {
            if let mediaUrl = vibe.mediaUrl, let url = URL(string: mediaUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Video Vibe Content
struct VideoVibeContent: View {
    let vibe: Vibe
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            if let mediaUrl = vibe.mediaUrl, let url = URL(string: mediaUrl) {
                VideoPlayer(player: player)
                    .onAppear {
                        player = AVPlayer(url: url)
                        player?.play()
                    }
                    .onDisappear {
                        player?.pause()
                        player = nil
                    }
            } else if let thumbnailUrl = vibe.thumbnailUrl, let url = URL(string: thumbnailUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
            } else {
                Image(systemName: "video.slash")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            }
        }
    }
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
                    Text(poll.question)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Options
                    VStack(spacing: 12) {
                        ForEach(poll.options) { option in
                            PollOptionView(
                                option: option,
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

struct PollOptionView: View {
    let option: PollOption
    let poll: Poll
    let userId: String
    let hasVoted: Bool
    let onVote: () -> Void

    private var percentage: Double {
        poll.votePercentage(for: option.id)
    }

    private var isSelected: Bool {
        option.votes.contains(userId)
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

#Preview {
    VibeViewerView(startIndex: 0)
        .environmentObject(AppState())
}
