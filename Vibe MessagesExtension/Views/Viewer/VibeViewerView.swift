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
    @State private var isHoldingStory = false

    // In-story stake flow (half sheet)
    @State private var showStakeSheet = false
    @State private var isResolvingStakeBet = false
    @State private var stakeTargetBet: Bet?
    @State private var stakeSourceVibe: Vibe?
    @State private var selectedStakeSide: BetSide = .yes
    @State private var stakeAmount: Int = 25
    @State private var isSubmittingStake = false
    @State private var stakeError: String?
    @State private var stakeResolutionSession = UUID()
    @State private var showJoinRequestPrompt = false
    @State private var pendingJoinChatId: String?
    @State private var pendingJoinBetId: String?
    @State private var isSubmittingJoinRequest = false

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
                                .onLongPressGesture(
                                    minimumDuration: 0.01,
                                    maximumDistance: .infinity,
                                    pressing: { isPressing in
                                        if isPressing {
                                            pauseForHold()
                                        } else {
                                            resumeAfterHold()
                                        }
                                    },
                                    perform: {}
                                )

                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { goToNext() }
                                .onLongPressGesture(
                                    minimumDuration: 0.01,
                                    maximumDistance: .infinity,
                                    pressing: { isPressing in
                                        if isPressing {
                                            pauseForHold()
                                        } else {
                                            resumeAfterHold()
                                        }
                                    },
                                    perform: {}
                                )
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
            .offset(y: dragOffset)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height < -80,
                           let vibe = currentVibe,
                           vibe.type == .parlay {
                            Task {
                                await openStakeSheet(for: vibe)
                            }
                            return
                        }

                        if value.translation.height > 120 {
                            appState.navigateToFeed()
                        } else {
                            withAnimation(VibeAnimation.snappy) {
                                dragOffset = 0
                            }
                        }
                    }
            )
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
            isHoldingStory = false
            stopTimer()
        }
        .sheet(isPresented: $showStakeSheet) {
            StoryStakeSheet(
                bet: stakeTargetBet,
                challengeTitle: stakeSourceVibe?.parlay?.title ?? stakeSourceVibe?.textStatus,
                allowStarterMode: canStartTutorialChallenge(from: stakeSourceVibe),
                auraBalance: max(0, appState.auraBalance),
                selectedSide: $selectedStakeSide,
                amount: $stakeAmount,
                isResolvingBet: isResolvingStakeBet,
                isSubmitting: isSubmittingStake,
                errorText: stakeError,
                onStake: {
                    Task { await submitStakeFromSheet() }
                },
                onSeeMyBets: {
                    showStakeSheet = false
                    appState.navigateToBetList()
                }
            )
            .presentationDetents([.fraction(0.5), .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: showStakeSheet) { _, isPresented in
            if isPresented {
                pauseForHold()
            } else if case .viewer = appState.currentDestination {
                resumeAfterHold()
            }
        }
        .alert("You're not in this challenge chat", isPresented: $showJoinRequestPrompt) {
            Button("No", role: .cancel) {
                clearPendingJoinRequest()
            }
            Button(isSubmittingJoinRequest ? "Requesting..." : "Yes, Request Join") {
                Task { await submitJoinRequest() }
            }
            .disabled(isSubmittingJoinRequest)
        } message: {
            Text("Would you like to request to join? Chat members will see your request and can add you or start a new group chat with you.")
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

    private func startTimer(resetProgress: Bool = true) {
        stopTimer()
        if resetProgress {
            progress = 0.0
        }

        guard currentIndex < appState.viewerVibes.count else { return }

        let duration: Double = 5.0
        let interval = 0.05

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            if isHoldingStory { return }
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

    private func pauseForHold() {
        guard !isHoldingStory else { return }
        isHoldingStory = true
        stopTimer()
    }

    private func resumeAfterHold() {
        guard isHoldingStory else { return }
        isHoldingStory = false
        startTimer(resetProgress: false)
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

    private var currentVibe: Vibe? {
        guard currentIndex < appState.viewerVibes.count else { return nil }
        return appState.viewerVibes[currentIndex]
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
                    if shouldShowTextOverlay(for: vibe), let text = vibe.textStatus, !text.isEmpty {
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
            if let song = vibe.songData, let previewUrl = song.previewUrl, let url = URL.httpURL(from: previewUrl) {
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
                        .frame(height: 2)
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
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(appState.nameForUser(vibe.userId))
                            .font(VibeTypography.titleSmall)
                            .foregroundColor(.white)

                        Text(timeAgo(from: vibe.createdAt))
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(.white.opacity(0.7))

                        if let context = storyContextLabel(for: vibe) {
                            Text(context)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                // Streak badge
                if let streak = appState.streak, streak.currentStreak > 0 {
                    HStack(spacing: VibeSpacing.xxxs) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("\(streak.currentStreak)")
                            .font(VibeTypography.numericMedium)
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, VibeSpacing.sm)
                    .padding(.vertical, VibeSpacing.xs)
                    .background(Color.white.opacity(0.2))
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
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.white)
                        .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
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
                HStack(spacing: VibeSpacing.md) {
                    Button {
                        VibeHaptic.light()
                        withAnimation(VibeAnimation.bouncy) {
                            showReactions.toggle()
                        }
                    } label: {
                        HStack(spacing: VibeSpacing.xxs) {
                            Image(systemName: vibe.userReaction(appState.userId) != nil ? "heart.fill" : "heart")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(vibe.userReaction(appState.userId) != nil ? .red : .white)
                            Text("React")
                                .font(VibeTypography.captionLarge)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, VibeSpacing.sm)
                        .padding(.vertical, VibeSpacing.xs)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }

                    if vibe.type == .parlay {
                        Button {
                            VibeHaptic.medium()
                            Task {
                                await openStakeSheet(for: vibe)
                            }
                        } label: {
                            HStack(spacing: VibeSpacing.xxs) {
                                Image(systemName: "dollarsign.circle.fill")
                                Text("Join & Stake")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, VibeSpacing.sm)
                            .padding(.vertical, VibeSpacing.xs)
                            .background(VibeTheme.betAccent.opacity(0.85))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    } else if vibe.type == .tea {
                        Button {
                            VibeHaptic.medium()
                            appState.navigateToComposer(type: .tea)
                        } label: {
                            HStack(spacing: VibeSpacing.xxs) {
                                Image(systemName: "quote.bubble.fill")
                                Text("Drop Tea")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, VibeSpacing.sm)
                            .padding(.vertical, VibeSpacing.xs)
                            .background(VibeTheme.accentSecondary.opacity(0.85))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Views count
                        HStack(spacing: VibeSpacing.xxs) {
                            Image(systemName: "eye.fill")
                            Text("\(vibe.viewedBy.count)")
                                .contentTransition(.numericText())
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, VibeSpacing.sm)
                        .padding(.vertical, VibeSpacing.xs)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
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

    @MainActor
    private func openStakeSheet(for vibe: Vibe) async {
        showReactions = false
        stakeError = nil
        isSubmittingStake = false
        selectedStakeSide = .yes
        stakeTargetBet = nil
        stakeSourceVibe = vibe

        // Keep join/stake tied to the same Aura source as profile by refreshing before render.
        if appState.isAuthenticated {
            async let profileTask: () = appState.loadCurrentUserProfile()
            async let auraTask: () = appState.loadAuraStats()
            _ = await (profileTask, auraTask)
        }

        let minimumStake = 10
        let stakeCap = 100
        let balance = min(max(0, appState.auraBalance), stakeCap)
        stakeAmount = balance >= minimumStake ? min(25, balance) : balance
        showStakeSheet = true

        stakeResolutionSession = UUID()
        let session = stakeResolutionSession
        let isTutorial = canStartTutorialChallenge(from: vibe)

        // Tutorial starter flow should never block on remote bet lookup.
        isResolvingStakeBet = !isTutorial
        if isTutorial {
            stakeError = nil
        }

        Task {
            let resolved = await appState.resolveBetForStory(vibe)
            await MainActor.run {
                guard showStakeSheet, stakeResolutionSession == session else { return }
                stakeTargetBet = resolved
                isResolvingStakeBet = false

                if resolved == nil && !isTutorial {
                    stakeError = "No active bet found from this story yet."
                }
            }
        }

        // Hard-stop loader even if upstream resolution hangs.
        let timeoutNs: UInt64 = isTutorial ? 2_000_000_000 : 8_000_000_000
        Task {
            try? await Task.sleep(nanoseconds: timeoutNs)
            await MainActor.run {
                guard showStakeSheet, stakeResolutionSession == session, isResolvingStakeBet else { return }
                isResolvingStakeBet = false
                if stakeTargetBet == nil && !isTutorial {
                    stakeError = "No active bet found from this story yet."
                }
            }
        }
    }

    @MainActor
    private func submitStakeFromSheet() async {
        let minimumStake = 10
        let stakeCap = 100
        let availableBalance = min(max(0, appState.auraBalance), stakeCap)
        guard availableBalance >= minimumStake else {
            stakeError = "Need at least \(minimumStake) Aura to join."
            return
        }
        let clampedAmount = min(max(stakeAmount, minimumStake), availableBalance)
        stakeAmount = clampedAmount

        isSubmittingStake = true
        stakeError = nil

        if let bet = stakeTargetBet {
            if bet.status != .active || bet.isExpired {
                isSubmittingStake = false
                stakeError = "This challenge is closed. Posted \(relativeDateString(from: bet.createdAt)); closed \(absoluteDateString(from: bet.deadline))."
                return
            }

            let targetChatId = bet.chatId.trimmingCharacters(in: .whitespacesAndNewlines)
            if !targetChatId.isEmpty {
                if let hasAccess = await appState.hasAccessToChat(targetChatId), !hasAccess {
                    isSubmittingStake = false
                    presentJoinRequestPrompt(chatId: targetChatId, betId: bet.betId)
                    return
                }
            }

            do {
                _ = try await appState.placeBetStake(
                    betId: bet.betId,
                    side: selectedStakeSide,
                    amount: clampedAmount
                )
                isSubmittingStake = false
                showStakeSheet = false
                stakeResolutionSession = UUID()
                VibeHaptic.success()
            } catch {
                isSubmittingStake = false
                if isChatAccessError(error), !targetChatId.isEmpty {
                    presentJoinRequestPrompt(chatId: targetChatId, betId: bet.betId)
                    return
                }
                stakeError = friendlyStakeErrorMessage(for: error, bet: bet)
            }
            return
        }

        guard let sourceVibe = stakeSourceVibe, canStartTutorialChallenge(from: sourceVibe) else {
            isSubmittingStake = false
            return
        }

        let challengeText = (sourceVibe.parlay?.title ?? sourceVibe.parlay?.question ?? sourceVibe.textStatus ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !challengeText.isEmpty else {
            isSubmittingStake = false
            stakeError = "Couldn't start challenge from this story."
            return
        }

        do {
            _ = try await appState.createBet(
                betType: .self,
                description: challengeText,
                deadline: Date().addingTimeInterval(24 * 60 * 60),
                initialStake: stakeAmount,
                initialSide: selectedStakeSide
            )
            isSubmittingStake = false
            showStakeSheet = false
            stakeResolutionSession = UUID()
            VibeHaptic.success()
        } catch {
            isSubmittingStake = false
            stakeError = friendlyStakeErrorMessage(for: error)
        }
    }

    private func canStartTutorialChallenge(from vibe: Vibe?) -> Bool {
        guard let vibe else { return false }
        return vibe.type == .parlay && vibe.userId == "vibe_team"
    }

    private func isChatAccessError(_ error: Error) -> Bool {
        let description = error.localizedDescription.lowercased()
        return description.contains("must be in this chat")
            || description.contains("not in this chat")
            || description.contains("do not have access to this bet")
            || description.contains("you are not in this chat")
    }

    private func friendlyStakeErrorMessage(for error: Error) -> String {
        friendlyStakeErrorMessage(for: error, bet: nil)
    }

    private func friendlyStakeErrorMessage(for error: Error, bet: Bet?) -> String {
        let description = error.localizedDescription.lowercased()

        if description.contains("deadline has passed")
            || description.contains("cannot stake on")
            || description.contains("expired")
            || description.contains("completed")
            || description.contains("ducked") {
            if let bet {
                return "This challenge is closed. Posted \(relativeDateString(from: bet.createdAt)); closed \(absoluteDateString(from: bet.deadline))."
            }
            return "This challenge is closed."
        }

        if description.contains("already staked") {
            return "You've already joined this challenge."
        }

        if description.contains("insufficient aura") || description.contains("bankrupt") {
            return "Not enough Aura to join this challenge."
        }

        return "Couldn't join this challenge right now. Try again."
    }

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func absoluteDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func presentJoinRequestPrompt(chatId: String, betId: String?) {
        pendingJoinChatId = chatId
        pendingJoinBetId = betId
        showJoinRequestPrompt = true
    }

    private func clearPendingJoinRequest() {
        pendingJoinChatId = nil
        pendingJoinBetId = nil
        isSubmittingJoinRequest = false
    }

    @MainActor
    private func submitJoinRequest() async {
        guard let chatId = pendingJoinChatId, !chatId.isEmpty else {
            stakeError = "Couldn't request access because this challenge has no chat id."
            clearPendingJoinRequest()
            return
        }

        isSubmittingJoinRequest = true

        let displayName = appState.userFirstName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let requester = (displayName?.isEmpty == false ? displayName! : "A user")
        let reason = "\(requester) is trying to join this challenge. If you want to let them in, add them to this chat or start a new group chat with them."

        do {
            let message = try await appState.requestJoinChallengeChat(
                chatId: chatId,
                betId: pendingJoinBetId,
                reason: reason
            )
            stakeError = message
            VibeHaptic.success()
        } catch {
            stakeError = error.localizedDescription
        }

        clearPendingJoinRequest()
    }

    private func shouldShowTextOverlay(for vibe: Vibe) -> Bool {
        switch vibe.type {
        case .parlay, .tea:
            return false
        default:
            return true
        }
    }

    private func storyContextLabel(for vibe: Vibe) -> String? {
        if vibe.userId == "vibe_team" {
            switch vibe.id {
            case "team_welcome":
                return "intro vibe"
            case "team_tutorial_2":
                return "social vibe"
            case "team_tutorial_3":
                return vibe.parlay?.betId?.isEmpty == false ? "bet vibe linked" : "bet vibe"
            case "team_tutorial_4":
                return "tea vibe"
            default:
                break
            }
        }

        switch vibe.type {
        case .parlay:
            return vibe.parlay?.betId != nil ? "bet vibe linked" : "bet vibe"
        case .tea:
            return "tea vibe"
        default:
            return nil
        }
    }
}

// MARK: - Story Stake Sheet
struct StoryStakeSheet: View {
    let bet: Bet?
    let challengeTitle: String?
    let allowStarterMode: Bool
    let auraBalance: Int
    @Binding var selectedSide: BetSide
    @Binding var amount: Int
    let isResolvingBet: Bool
    let isSubmitting: Bool
    let errorText: String?
    let onStake: () -> Void
    let onSeeMyBets: () -> Void

    private let minimumStake = 10
    private let maximumStakeCap = 100

    private var maximumStake: Int {
        min(max(0, auraBalance), maximumStakeCap)
    }

    private var canStakeAtAll: Bool {
        maximumStake >= minimumStake
    }

    private var sliderRange: ClosedRange<Double> {
        Double(minimumStake)...Double(maximumStake)
    }

    private var shouldShowSlider: Bool {
        canStakeAtAll && maximumStake > minimumStake
    }

    private var sliderStep: Double {
        // Keep fine-grained control for most balances and avoid giant jumps at high balances.
        maximumStake <= 2_000 ? 1 : (maximumStake <= 10_000 ? 5 : 10)
    }

    private var canStake: Bool {
        if let bet {
            return !isResolvingBet
                && !isSubmitting
                && canStakeAtAll
        }

        return allowStarterMode
            && !isResolvingBet
            && !isSubmitting
            && canStakeAtAll
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.lg) {
            Text("Join Challenge")
                .font(VibeTypography.titleMedium)
                .foregroundColor(VibeTheme.textPrimary)

            if isResolvingBet {
                HStack(spacing: VibeSpacing.sm) {
                    ProgressView()
                    Text("Loading challenge...")
                        .font(VibeTypography.bodySmall)
                        .foregroundColor(VibeTheme.textSecondary)
                }
                .padding(.vertical, VibeSpacing.sm)
            } else if let bet {
                Text(bet.description)
                    .font(VibeTypography.bodyMedium)
                    .foregroundColor(VibeTheme.textPrimary)

                Text(challengeTimingLine(for: bet))
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(VibeTheme.textSecondary)

                HStack(spacing: VibeSpacing.sm) {
                    sideButton(.yes)
                    sideButton(.no)
                }

                VStack(alignment: .leading, spacing: VibeSpacing.xs) {
                    Text("Stake: \(amount) Aura")
                        .font(VibeTypography.titleSmall)
                        .foregroundColor(VibeTheme.textPrimary)
                        .contentTransition(.numericText())

                    if shouldShowSlider {
                        Slider(
                            value: sliderValueBinding,
                            in: sliderRange,
                            step: sliderStep
                        )
                        .tint(selectedSide == .yes ? .green : .red)
                        quickStakeChips
                    } else if canStakeAtAll {
                        Text("Stake fixed at \(minimumStake) Aura")
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(VibeTheme.textTertiary)
                    } else {
                        Text("Need at least \(minimumStake) Aura to join.")
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(VibeTheme.textTertiary)
                    }

                    Text("Balance: \(auraBalance) Aura")
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(VibeTheme.textTertiary)
                }
            } else if allowStarterMode, let challengeTitle, !challengeTitle.isEmpty {
                Text(challengeTitle)
                    .font(VibeTypography.bodyMedium)
                    .foregroundColor(VibeTheme.textPrimary)

                VStack(alignment: .leading, spacing: VibeSpacing.xs) {
                    Text("Stake: \(amount) Aura")
                        .font(VibeTypography.titleSmall)
                        .foregroundColor(VibeTheme.textPrimary)
                        .contentTransition(.numericText())

                    if shouldShowSlider {
                        Slider(
                            value: sliderValueBinding,
                            in: sliderRange,
                            step: sliderStep
                        )
                        .tint(selectedSide == .yes ? .green : .red)
                        quickStakeChips
                    } else if canStakeAtAll {
                        Text("Stake fixed at \(minimumStake) Aura")
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(VibeTheme.textTertiary)
                    } else {
                        Text("Need at least \(minimumStake) Aura to join.")
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(VibeTheme.textTertiary)
                    }

                    Text("Balance: \(auraBalance) Aura")
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(VibeTheme.textTertiary)
                }
            } else {
                Text("No active challenge is linked to this story yet.")
                    .font(VibeTypography.bodySmall)
                    .foregroundColor(VibeTheme.textSecondary)
            }

            if let errorText, !errorText.isEmpty {
                Text(errorText)
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(.red)
            }

            Button(action: onStake) {
                HStack(spacing: VibeSpacing.xs) {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    }
                    Text(isSubmitting ? "Joining..." : (bet == nil && allowStarterMode ? "Start & Stake" : "Join & Stake"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, VibeSpacing.sm)
                .foregroundColor(.white)
                .background(VibeTheme.betAccent)
                .continuousCorner(VibeTheme.radiusMedium)
            }
            .buttonStyle(VibePressStyle())
            .disabled(!canStake)
            .opacity(canStake ? 1 : 0.5)

            Button(action: onSeeMyBets) {
                Text("See My Bets")
                    .font(VibeTypography.bodyMedium)
                    .foregroundColor(VibeTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VibeSpacing.sm)
                    .background(VibeTheme.surfaceOverlay)
                    .continuousCorner(VibeTheme.radiusMedium)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, VibeSpacing.screenHorizontal)
        .padding(.top, VibeSpacing.md)
        .padding(.bottom, VibeSpacing.xl)
        .onAppear {
            clampAmountIntoAllowedRange()
        }
        .onChange(of: auraBalance) { _, _ in
            clampAmountIntoAllowedRange()
        }
        .onChange(of: amount) { _, _ in
            clampAmountIntoAllowedRange()
        }
    }

    private func sideButton(_ side: BetSide) -> some View {
        let isSelected = selectedSide == side
        let tint: Color = side == .yes ? .green : .red
        return Button {
            selectedSide = side
            VibeHaptic.selection()
        } label: {
            Text(side.rawValue.uppercased())
                .font(VibeTypography.captionLarge)
                .foregroundColor(isSelected ? .white : VibeTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, VibeSpacing.sm)
                .background(isSelected ? tint : VibeTheme.surfaceOverlay)
                .continuousCorner(VibeTheme.radiusMedium)
        }
        .buttonStyle(.plain)
    }

    private var sliderValueBinding: Binding<Double> {
        Binding(
            get: {
                guard canStakeAtAll else { return Double(maximumStake) }
                return Double(amount).clamped(to: sliderRange)
            },
            set: { newValue in
                guard canStakeAtAll else {
                    amount = maximumStake
                    return
                }
                amount = Int(newValue.clamped(to: sliderRange))
            }
        )
    }

    @ViewBuilder
    private var quickStakeChips: some View {
        if quickStakeAmounts.count > 1 {
            HStack(spacing: VibeSpacing.xs) {
                ForEach(Array(quickStakeAmounts.enumerated()), id: \.element) { index, quickAmount in
                    let isSelected = amount == quickAmount
                    Button {
                        amount = quickAmount
                        VibeHaptic.selection()
                    } label: {
                        Text(quickStakeLabel(for: quickAmount, index: index))
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(isSelected ? .white : VibeTheme.textPrimary)
                            .padding(.horizontal, VibeSpacing.xs)
                            .padding(.vertical, VibeSpacing.xxxs)
                            .background(isSelected ? VibeTheme.betAccent : VibeTheme.surfaceOverlay)
                            .continuousCorner(VibeTheme.radiusSmall)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, VibeSpacing.xxxs)
        }
    }

    private var quickStakeAmounts: [Int] {
        guard canStakeAtAll else { return [] }
        var values = [minimumStake]

        for ratio in [0.25, 0.5, 0.75] {
            let scaled = Double(maximumStake) * ratio
            let rounded = Int((scaled / sliderStep).rounded() * sliderStep)
            values.append(clampedStake(rounded))
        }

        values.append(maximumStake)
        let deduped = Array(Set(values)).sorted()
        return deduped.filter { $0 >= minimumStake && $0 <= maximumStake }
    }

    private func quickStakeLabel(for value: Int, index: Int) -> String {
        if index == 0 { return "Min" }
        if index == quickStakeAmounts.count - 1 { return "Max" }
        return "\(value)"
    }

    private func clampedStake(_ value: Int) -> Int {
        guard canStakeAtAll else { return maximumStake }
        return value.clamped(to: minimumStake...maximumStake)
    }

    private func clampAmountIntoAllowedRange() {
        let clamped = clampedStake(amount)
        if amount != clamped {
            amount = clamped
        }
    }

    private func challengeTimingLine(for bet: Bet) -> String {
        let posted = relativeDateString(from: bet.createdAt)
        let closes = absoluteDateString(from: bet.deadline)
        if bet.isExpired || bet.status != .active {
            return "Posted \(posted) • Closed \(closes)"
        }
        return "Posted \(posted) • Closes \(closes)"
    }

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func absoluteDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
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
            if let mediaUrl = vibe.mediaUrl, let url = URL.httpURL(from: mediaUrl) {
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
            if let mediaUrl = vibe.mediaUrl, let url = URL.httpURL(from: mediaUrl) {
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
            } else if let thumbnailUrl = vibe.thumbnailUrl, let url = URL.httpURL(from: thumbnailUrl) {
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
            if let albumArt = vibe.songData?.albumArt, let url = URL.httpURL(from: albumArt) {
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
                if let albumArt = vibe.songData?.albumArt, let url = URL.httpURL(from: albumArt) {
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
            if let mediaUrl = vibe.mediaUrl, let url = URL.httpURL(from: mediaUrl) {
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

            if let mediaUrl = vibe.mediaUrl, let url = URL.httpURL(from: mediaUrl) {
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
