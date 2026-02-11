import SwiftUI

struct BentoDashboardView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            VibeTheme.groupedBackground.edgesIgnoringSafeArea(.all)

            ScrollView(showsIndicators: false) {
                VStack(spacing: VibeSpacing.sectionGap) {
                    UpperSectionView()
                    LowerSectionView()
                    Spacer(minLength: VibeSpacing.xxxl)
                }
                .padding(.bottom, VibeSpacing.xxxl)
            }
        }
        .fullScreenCover(isPresented: $appState.shouldShowVibePicker) {
            ExploreAllVibesView()
        }
    }
}

// =====================================================================
// MARK: - UPPER SECTION
// =====================================================================

struct UpperSectionView: View {
    @EnvironmentObject var appState: AppState

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default: return "Good Night"
        }
    }

    var body: some View {
        VStack(spacing: VibeSpacing.xl) {

            // 1. HEADER — Avatar, Greeting, Aura Balance, Streak, Notifications
            headerBar

            // 2. STORY RAIL
            storyRail

            // 3. BENTO GRID
            bentoGrid

            // 4. ACTIVE GAMES STRIP (Bets + Tea)
            if !appState.activeBets.isEmpty || !appState.activeTeaSpills.isEmpty {
                activeGamesStrip
            }

            // 5. LEADERBOARD
            leaderboardSection
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            // Left: Avatar + Greeting
            HStack(spacing: VibeSpacing.sm) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [VibeTheme.accent, VibeTheme.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(appState.userFirstName?.prefix(1) ?? "V"))
                            .font(VibeTypography.titleMedium)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(VibeTypography.captionLarge)
                        .foregroundColor(VibeTheme.textSecondary)
                    Text(appState.userFirstName ?? "there")
                        .font(VibeTypography.titleLarge)
                        .foregroundColor(VibeTheme.textPrimary)
                }
            }

            Spacer()

            HStack(spacing: VibeSpacing.xs) {
                // Aura Balance Pill
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                    Text("\(appState.auraBalance)")
                        .font(VibeTypography.captionLarge)
                        .contentTransition(.numericText())
                }
                .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.0))
                .padding(.horizontal, VibeSpacing.sm)
                .padding(.vertical, VibeSpacing.xs)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())

                // Streak Badge
                if let streak = appState.streak, streak.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Text("🔥")
                        Text("\(streak.currentStreak)")
                            .font(VibeTypography.captionLarge)
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, VibeSpacing.sm)
                    .padding(.vertical, VibeSpacing.xs)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }

                // New Updates Badge
                if appState.newVibesCount > 0 {
                    Button {
                        if let firstUnseen = appState.vibes.first(where: {
                            !appState.seenVibeIds.contains($0.id) && $0.userId != appState.userId
                        }) {
                            appState.navigateToViewer(opening: firstUnseen.id)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.fill")
                            Text("\(appState.newVibesCount)")
                                .contentTransition(.numericText())
                        }
                        .font(VibeTypography.captionLarge)
                        .foregroundColor(.white)
                        .padding(.horizontal, VibeSpacing.sm)
                        .padding(.vertical, VibeSpacing.xs)
                        .background(VibeTheme.brandGradient)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, VibeSpacing.screenHorizontal)
        .padding(.top, 10)
    }

    // MARK: - Story Rail

    private var storyRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VibeSpacing.md) {
                // My Story
                myStoryRing
                    .padding(.leading, VibeSpacing.screenHorizontal)

                // Friends' Stories
                let groupedVibes = appState.vibesGroupedByUser(nil, includeMe: false)
                ForEach(groupedVibes, id: \.first?.userId) { userVibes in
                    if let firstVibe = userVibes.first {
                        StoryRingItem(
                            vibes: userVibes,
                            name: appState.nameForUser(firstVibe.userId),
                            hasUnviewed: userVibes.contains { !$0.hasViewed(appState.userId) }
                        ) {
                            VibeHaptic.light()
                            appState.navigateToViewer(opening: firstVibe.id)
                        }
                    }
                }
            }
        }
    }

    private var myStoryRing: some View {
        let myVibes = appState.vibes.filter { $0.userId == appState.userId }
        let hasMyVibes = !myVibes.isEmpty

        return VStack(spacing: VibeSpacing.xs) {
            ZStack(alignment: .bottomTrailing) {
                if hasMyVibes {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [VibeTheme.accent, VibeTheme.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: VibeSpacing.avatarLarge, height: VibeSpacing.avatarLarge)
                } else {
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundColor(VibeTheme.textTertiary)
                        .frame(width: VibeSpacing.avatarLarge, height: VibeSpacing.avatarLarge)
                }

                if let myVibe = myVibes.first,
                   let thumbUrl = myVibe.thumbnailUrl ?? myVibe.mediaUrl,
                   let url = URL(string: thumbUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(UIColor.systemGray5)
                    }
                    .frame(width: 66, height: 66)
                    .clipShape(Circle())
                }

                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.white, hasMyVibes ? VibeTheme.accent : VibeTheme.accentBlue)
                    .font(.system(size: 24))
                    .symbolEffect(.bounce, value: hasMyVibes)
            }
            .onTapGesture {
                VibeHaptic.selection()
                if hasMyVibes, let firstVibe = myVibes.first {
                    appState.navigateToViewer(opening: firstVibe.id)
                } else {
                    appState.navigateToComposer(type: .video)
                }
            }

            Text("My Vibes")
                .font(VibeTypography.captionSmall)
                .foregroundColor(hasMyVibes ? VibeTheme.textPrimary : VibeTheme.textTertiary)
        }
    }

    // MARK: - Bento Grid

    private var bentoGrid: some View {
        HStack(alignment: .top, spacing: VibeSpacing.sm) {
            // Left: Post Vibe Hero
            Button {
                VibeHaptic.medium()
                appState.navigateToComposer(type: .video)
            } label: {
                VStack {
                    Spacer()
                    Image(systemName: "plus")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    HStack(alignment: .bottom) {
                        Text("Post Vibe")
                            .font(VibeTypography.titleMedium)
                            .foregroundColor(.white)
                        Spacer()
                        if appState.newVibesCount > 0 {
                            Text("\(appState.newVibesCount) waiting")
                                .font(VibeTypography.captionSmall)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                .padding(VibeSpacing.lg)
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .background(VibeTheme.brandGradient)
                .continuousCorner(VibeTheme.radiusLarge)
                .vibeShadow(.lg)
            }

            // Right: Triple Stack
            VStack(spacing: VibeSpacing.sm) {
                // POV
                Button {
                    VibeHaptic.light()
                    appState.navigateToComposer(type: .video, isLocked: true)
                } label: {
                    HStack {
                        Image(systemName: "eye.fill")
                        Text("POV").font(VibeTypography.titleSmall)
                        Spacer()
                        Image(systemName: "lock.fill").opacity(0.5)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, VibeSpacing.md)
                    .frame(height: 65)
                    .background(
                        LinearGradient(colors: [VibeTheme.accentCyan, VibeTheme.accentBlue], startPoint: .leading, endPoint: .trailing)
                    )
                    .continuousCorner(VibeTheme.radiusMedium)
                }

                // Parlay
                Button {
                    VibeHaptic.light()
                    appState.navigateToComposer(type: .parlay)
                } label: {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(VibeTheme.accent)
                        Text("Parlay")
                            .font(VibeTypography.titleSmall)
                            .foregroundColor(VibeTheme.textPrimary)
                        Spacer()
                        Text("💸")
                    }
                    .padding(.horizontal, VibeSpacing.md)
                    .frame(height: 65)
                    .background(.ultraThinMaterial)
                    .continuousCorner(VibeTheme.radiusMedium)
                }

                // Explore
                Button {
                    VibeHaptic.light()
                    appState.shouldShowVibePicker = true
                } label: {
                    HStack {
                        Image(systemName: "square.grid.2x2.fill")
                        Text("Explore").font(VibeTypography.titleSmall)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(VibeTheme.textTertiary)
                    }
                    .foregroundColor(VibeTheme.textPrimary)
                    .padding(.horizontal, VibeSpacing.md)
                    .frame(height: 65)
                    .background(.ultraThinMaterial)
                    .continuousCorner(VibeTheme.radiusMedium)
                }
            }
        }
        .padding(.horizontal, VibeSpacing.screenHorizontal)
    }

    // MARK: - Active Games Strip

    private var activeGamesStrip: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            Text("ACTIVE GAMES")
                .vibeSectionHeader()
                .padding(.leading, VibeSpacing.screenHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VibeSpacing.sm) {
                    // Active Bets
                    ForEach(appState.activeBets.prefix(5)) { bet in
                        ActiveGameCard(
                            icon: "dice.fill",
                            iconColor: .green,
                            title: bet.description,
                            subtitle: bet.timeRemainingFormatted,
                            badge: "\(bet.creationCost ?? 10) ✨"
                        )
                    }

                    // Active Tea Spills
                    ForEach(appState.activeTeaSpills.prefix(5)) { tea in
                        ActiveGameCard(
                            icon: "cup.and.saucer.fill",
                            iconColor: .brown,
                            title: tea.mysteryText,
                            subtitle: tea.timeRemainingFormatted,
                            badge: "\(tea.options.count) options"
                        )
                    }
                }
                .padding(.horizontal, VibeSpacing.screenHorizontal)
            }
        }
    }

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            Text("LEADERBOARD")
                .vibeSectionHeader()
                .padding(.leading, VibeSpacing.screenHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VibeSpacing.sm) {
                    if !appState.leaderboard.isEmpty {
                        // Real leaderboard from Aura service
                        ForEach(appState.leaderboard.prefix(5)) { entry in
                            LeaderboardCardView(entry: entry)
                        }
                    } else {
                        // Fallback to local MVP logic
                        if let (mvpId, count) = mvpData {
                            LeaderboardCardView(
                                emoji: "👑",
                                name: appState.nameForUser(mvpId),
                                score: "+\(count)",
                                rank: 1
                            )
                        }

                        if let ghostId = ghostUserId {
                            LeaderboardCardView(
                                emoji: "👻",
                                name: appState.nameForUser(ghostId),
                                score: "Nudge",
                                rank: 0
                            )
                        }

                        let thirdPlace = appState.vibesGroupedByUser(nil)
                            .compactMap { $0.first }
                            .filter { $0.userId != appState.userId && $0.userId != mvpData?.0 && $0.userId != ghostUserId }
                            .first

                        if let third = thirdPlace {
                            let count = appState.vibes.filter { $0.userId == third.userId }.count
                            LeaderboardCardView(
                                emoji: "💅",
                                name: appState.nameForUser(third.userId),
                                score: "+\(count)",
                                rank: 3
                            )
                        }
                    }
                }
                .padding(.horizontal, VibeSpacing.screenHorizontal)
            }
        }
    }

    // MARK: - Helpers

    private var mvpData: (String, Int)? {
        let friendsVibes = appState.vibes.filter { $0.userId != appState.userId }
        let counts = friendsVibes.reduce(into: [String: Int]()) { $0[$1.userId, default: 0] += 1 }
        guard let top = counts.max(by: { $0.value < $1.value }) else { return nil }
        return (top.key, top.value)
    }

    private var ghostUserId: String? {
        let friends = appState.vibesGroupedByUser(nil)
            .compactMap { $0.first?.userId }
            .filter { $0 != appState.userId }

        let oneDayAgo = Date().addingTimeInterval(-86400)
        return friends.first { friendId in
            let lastDate = appState.vibes.filter { $0.userId == friendId }.map { $0.createdAt }.max()
            return lastDate == nil || lastDate! < oneDayAgo
        }
    }
}

// =====================================================================
// MARK: - LOWER SECTION
// =====================================================================

struct LowerSectionView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedNewsItem: NewsItem? = nil
    @State private var showAllNews = false

    var body: some View {
        VStack(spacing: VibeSpacing.sectionGap) {

            // VIBE WIRE (NEWS)
            VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                HStack {
                    Text("VIBE WIRE")
                        .vibeSectionHeader()
                    Spacer()
                    if appState.isLoadingNews {
                        ProgressView()
                            .scaleEffect(0.6)
                    }

                    if !appState.newsItems.isEmpty {
                        Button {
                            withAnimation(VibeAnimation.bouncy) {
                                showAllNews.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(showAllNews ? "Show Less" : "See More")
                                Image(systemName: showAllNews ? "chevron.up" : "chevron.down")
                            }
                            .font(VibeTypography.captionLarge)
                            .foregroundColor(VibeTheme.accentBlue)
                        }
                    }
                }
                .padding(.horizontal, VibeSpacing.screenHorizontal)

                if showAllNews {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: VibeSpacing.sm),
                        GridItem(.flexible(), spacing: VibeSpacing.sm)
                    ], spacing: VibeSpacing.sm) {
                        ForEach(appState.newsItems) { item in
                            NewsCardView(newsItem: item)
                                .onTapGesture { selectedNewsItem = item }
                        }
                    }
                    .padding(.horizontal, VibeSpacing.screenHorizontal)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: VibeSpacing.md) {
                            if appState.newsItems.isEmpty && !appState.isLoadingNews {
                                NewsCardView(
                                    tag: "VIRAL",
                                    headline: "New 'AirPods Max 2' colors just leaked",
                                    socialText: "Mike & Sarah commented",
                                    color: .blue
                                )
                                NewsCardView(
                                    tag: "MUSIC",
                                    headline: "The Weeknd drops new album",
                                    socialText: "3 friends shared this",
                                    color: .purple
                                )
                            } else {
                                ForEach(appState.newsItems) { item in
                                    NewsCardView(newsItem: item)
                                        .onTapGesture { selectedNewsItem = item }
                                }
                            }
                        }
                        .padding(.horizontal, VibeSpacing.screenHorizontal)
                    }
                }
            }
            .onAppear {
                Task { await appState.loadNews() }
            }
            .fullScreenCover(item: $selectedNewsItem) { item in
                NewsDetailView(
                    newsItem: item,
                    onBack: { selectedNewsItem = nil },
                    onShare: { appState.shareNewsInChat(item) }
                )
                .onAppear { appState.requestExpand() }
            }

            // UPCOMING REMINDERS
            UpcomingRemindersSection()

            // PAST VIBES
            VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                Text("PAST VIBES")
                    .vibeSectionHeader()
                    .padding(.leading, VibeSpacing.screenHorizontal)

                let userVibes = appState.vibes.filter { $0.userId == appState.userId }

                if userVibes.isEmpty {
                    ZStack {
                        RoundedRectangle(cornerRadius: VibeTheme.radiusLarge, style: .continuous)
                            .fill(VibeTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: VibeTheme.radiusLarge, style: .continuous)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    .foregroundColor(Color(UIColor.systemGray4))
                            )

                        VStack(spacing: VibeSpacing.sm) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 30))
                                .foregroundColor(VibeTheme.textSecondary)
                            Text("Your past vibes will appear here")
                                .font(VibeTypography.bodyMedium)
                                .foregroundColor(VibeTheme.textSecondary)
                            Text("Post a vibe to start your history.")
                                .font(VibeTypography.captionLarge)
                                .foregroundColor(VibeTheme.textTertiary)
                        }
                        .padding(VibeSpacing.xxxl)
                    }
                    .padding(.horizontal, VibeSpacing.screenHorizontal)
                    .frame(height: 180)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: VibeSpacing.sm) {
                            ForEach(userVibes.prefix(6)) { vibe in
                                PastVibeCard(vibe: vibe) {
                                    appState.navigateToViewer(opening: vibe.id)
                                }
                            }
                        }
                        .padding(.horizontal, VibeSpacing.screenHorizontal)
                    }
                }
            }
        }
    }
}

// =====================================================================
// MARK: - COMPONENTS
// =====================================================================

// MARK: - Active Game Card (NEW)

struct ActiveGameCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let badge: String

    var body: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.xs) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)
                Spacer()
                Text(badge)
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(VibeTheme.textSecondary)
            }

            Spacer()

            Text(title)
                .font(VibeTypography.captionLarge)
                .foregroundColor(VibeTheme.textPrimary)
                .lineLimit(2)

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 9))
                Text(subtitle)
                    .font(VibeTypography.captionSmall)
            }
            .foregroundColor(VibeTheme.textTertiary)
        }
        .padding(VibeSpacing.sm)
        .frame(width: 140, height: 110)
        .background(.ultraThinMaterial)
        .continuousCorner(VibeTheme.radiusMedium)
        .vibeShadow(.sm)
    }
}

// MARK: - Story Ring Item

struct StoryRingItem: View {
    let vibes: [Vibe]
    let name: String
    let hasUnviewed: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: VibeSpacing.xs) {
            Button(action: onTap) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            hasUnviewed ?
                            LinearGradient(colors: [VibeTheme.accent, .orange], startPoint: .topTrailing, endPoint: .bottomLeading) :
                            LinearGradient(colors: [Color(UIColor.systemGray4), Color(UIColor.systemGray4)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 3
                        )
                        .frame(width: VibeSpacing.avatarLarge, height: VibeSpacing.avatarLarge)

                    if let firstVibe = vibes.first,
                       let thumbUrl = firstVibe.thumbnailUrl ?? firstVibe.mediaUrl,
                       let url = URL(string: thumbUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(Color(UIColor.systemGray5))
                        }
                        .frame(width: 66, height: 66)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color(UIColor.systemGray5))
                            .frame(width: 66, height: 66)
                    }

                    if vibes.count > 1 {
                        Text("\(vibes.count)")
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial.opacity(0.8))
                            .environment(\.colorScheme, .dark)
                            .clipShape(Capsule())
                            .offset(x: 24, y: -24)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(name)
                .font(VibeTypography.captionSmall)
                .foregroundColor(hasUnviewed ? VibeTheme.textPrimary : VibeTheme.textSecondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Leaderboard Card

struct LeaderboardCardView: View {
    var emoji: String
    var name: String
    var score: String
    var rank: Int

    // Init from LeaderboardEntry (real data)
    init(entry: LeaderboardEntry) {
        let medals = ["👑", "🥈", "🥉"]
        self.emoji = entry.rank <= 3 ? medals[entry.rank - 1] : "💫"
        self.name = entry.name
        self.score = "\(entry.auraBalance) ✨"
        self.rank = entry.rank
    }

    // Init for fallback (mock data)
    init(emoji: String, name: String, score: String, rank: Int) {
        self.emoji = emoji
        self.name = name
        self.score = score
        self.rank = rank
    }

    private var accentColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)  // Gold
        case 2: return Color(UIColor.systemGray3)                 // Silver
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)    // Bronze
        default: return VibeTheme.accentBlue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.xs) {
            Text(emoji)
                .font(.system(size: 28))
            Spacer()
            Text(name)
                .font(VibeTypography.titleSmall)
                .foregroundColor(VibeTheme.textPrimary)
                .lineLimit(1)
            Text(score)
                .font(VibeTypography.captionLarge)
                .foregroundColor(rank == 1 ? accentColor : VibeTheme.textSecondary)
                .contentTransition(.numericText())
        }
        .padding(VibeSpacing.sm)
        .frame(width: 110, height: 110)
        .background(.ultraThinMaterial)
        .continuousCorner(VibeTheme.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: VibeTheme.radiusMedium, style: .continuous)
                .stroke(rank == 1 ? accentColor.opacity(0.4) : .clear, lineWidth: 2)
        )
        .vibeShadow(.sm)
    }
}

// MARK: - News Card

struct NewsCardView: View {
    var tag: String
    var headline: String
    var socialText: String
    var color: Color
    var imageUrl: String?
    var isJustIn: Bool

    init(tag: String, headline: String, socialText: String, color: Color) {
        self.tag = tag
        self.headline = headline
        self.socialText = socialText
        self.color = color
        self.imageUrl = nil
        self.isJustIn = false
    }

    init(newsItem: NewsItem) {
        self.tag = newsItem.source.uppercased().prefix(8).description
        self.headline = newsItem.headline
        self.socialText = newsItem.timeAgo
        self.color = NewsCardView.colorForBatch(newsItem.batch)
        self.imageUrl = newsItem.imageUrl
        self.isJustIn = newsItem.isJustIn
    }

    private static func colorForBatch(_ batch: String) -> Color {
        switch batch {
        case "morning": return .orange
        case "noon": return .blue
        case "evening": return .purple
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image Section
            ZStack(alignment: .topTrailing) {
                if let imageUrl = imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        color.opacity(0.1)
                    }
                } else {
                    color.opacity(0.2)
                }

                if isJustIn {
                    Text("⚡️")
                        .font(.system(size: 12))
                        .padding(5)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(VibeSpacing.xs)
                }
            }
            .frame(width: 170, height: 110)
            .clipShape(RoundedRectangle(cornerRadius: VibeTheme.radiusMedium, style: .continuous))

            // Content Section
            VStack(alignment: .leading, spacing: 6) {
                Text(tag.uppercased())
                    .font(VibeTypography.overline)
                    .foregroundColor(color)
                    .lineLimit(1)

                Text(headline)
                    .font(VibeTypography.titleSmall)
                    .foregroundColor(VibeTheme.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(socialText)
                        .font(VibeTypography.captionSmall)
                        .contentTransition(.numericText())
                }
                .foregroundColor(VibeTheme.textSecondary)
                .padding(.bottom, 2)
            }
            .padding(.top, 10)
            .padding(.horizontal, 4)
        }
        .padding(10)
        .frame(width: 170, height: 210)
        .background(.ultraThinMaterial)
        .continuousCorner(VibeTheme.radiusLarge)
        .vibeShadow(.sm)
    }
}

// MARK: - Upcoming Reminders

struct UpcomingRemindersSection: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            HStack {
                Text("UPCOMING")
                    .vibeSectionHeader()
                Spacer()
                Button {
                    VibeHaptic.light()
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white, VibeTheme.accentBlue)
                }
                .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
            }
            .padding(.horizontal, VibeSpacing.screenHorizontal)

            if appState.reminders.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: VibeSpacing.xs) {
                        Text("Nothing coming up")
                            .font(VibeTypography.bodyMedium)
                            .foregroundColor(VibeTheme.textSecondary)
                        Text("Tap + to add one")
                            .font(VibeTypography.captionLarge)
                            .foregroundColor(VibeTheme.textTertiary)
                    }
                    .padding(.vertical, VibeSpacing.xl)
                    Spacer()
                }
                .background(.ultraThinMaterial)
                .continuousCorner(VibeTheme.radiusMedium)
                .padding(.horizontal, VibeSpacing.screenHorizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: VibeSpacing.sm) {
                        ForEach(appState.reminders) { reminder in
                            ReminderCardView(
                                emoji: reminder.emoji,
                                title: reminder.title,
                                subtitle: reminder.relativeDate,
                                accentColor: reminder.type.color
                            )
                        }
                    }
                    .padding(.horizontal, VibeSpacing.screenHorizontal)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddReminderSheet()
                .environmentObject(appState)
        }
    }
}

// MARK: - Reminder Card

struct ReminderCardView: View {
    var emoji: String
    var title: String
    var subtitle: String
    var accentColor: Color

    var body: some View {
        HStack(spacing: VibeSpacing.sm) {
            Circle()
                .fill(accentColor.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(emoji).font(.system(size: 20))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VibeTypography.titleSmall)
                    .foregroundColor(VibeTheme.textPrimary)
                Text(subtitle)
                    .font(VibeTypography.captionLarge)
                    .foregroundColor(VibeTheme.textSecondary)
            }
            Spacer()
        }
        .padding(VibeSpacing.sm)
        .background(.ultraThinMaterial)
        .continuousCorner(VibeTheme.radiusMedium)
        .vibeShadow(.sm)
    }
}

// MARK: - Past Vibe Card

struct PastVibeCard: View {
    let vibe: Vibe
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                if let thumbUrl = vibe.thumbnailUrl ?? vibe.mediaUrl,
                   let url = URL(string: thumbUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(UIColor.systemGray5)
                    }
                } else {
                    vibe.type.color.opacity(0.3)
                        .overlay(
                            Image(systemName: vibe.type.icon)
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        )
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(vibe.timeRemainingFormatted)
                        .font(VibeTypography.captionSmall)
                    if vibe.isExpiredFromFeed == true {
                        Text("Expired")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                    }
                }
                .foregroundColor(.white)
                .padding(VibeSpacing.xs)
            }
            .frame(width: 100, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: VibeTheme.radiusMedium, style: .continuous))
            .vibeShadow(.sm)
        }
        .buttonStyle(.plain)
    }
}

// =====================================================================
// MARK: - EXPLORE ALL VIBES VIEW
// =====================================================================

struct ExploreAllVibesView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedVibeType: VibeType? = nil
    @State private var isLocked: Bool = false

    let vibeTypes: [(type: VibeType, title: String, icon: String, color: Color, locked: Bool)] = [
        (.video, "Video", "video.fill", .pink, false),
        (.photo, "Photo", "camera.fill", .blue, false),
        (.video, "POV", "eye.fill", .teal, true),
        (.battery, "Battery", "battery.100", .yellow, false),
        (.mood, "Mood", "face.smiling", .purple, false),
        (.poll, "Poll", "chart.bar.fill", .blue, false),
        (.tea, "Tea", "cup.and.saucer.fill", .orange, false),
        (.leak, "Leak", "lock.open.fill", .red, false),
        (.sketch, "Sketch", "hand.draw.fill", .indigo, false),
        (.eta, "ETA", "location.fill", .green, false),
        (.song, "Song", "music.note", .pink, false),
        (.dailyDrop, "Daily Drop", "die.face.5", .cyan, false),
        (.parlay, "Parlay", "dollarsign.circle.fill", .green, false),
    ]

    var body: some View {
        ZStack {
            VibeTheme.groupedBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        VibeHaptic.light()
                        appState.shouldShowVibePicker = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(VibeTypography.titleSmall)
                            .foregroundColor(VibeTheme.textPrimary)
                            .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text("Choose a Vibe")
                        .font(VibeTypography.titleLarge)

                    Spacer()

                    Color.clear
                        .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                }
                .padding(.horizontal, VibeSpacing.md)
                .padding(.top, VibeSpacing.xs)
                .padding(.bottom, VibeSpacing.sm)
                .background(VibeTheme.groupedBackground)

                // Grid
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: VibeSpacing.md),
                        GridItem(.flexible(), spacing: VibeSpacing.md),
                        GridItem(.flexible(), spacing: VibeSpacing.md)
                    ], spacing: VibeSpacing.lg) {
                        ForEach(vibeTypes, id: \.title) { item in
                            VStack(spacing: VibeSpacing.xs) {
                                Button {
                                    VibeHaptic.selection()
                                    selectVibeType(item.type, locked: item.locked)
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(item.color.opacity(0.12))
                                            .frame(width: 70, height: 70)

                                        Image(systemName: item.icon)
                                            .font(.system(size: 28))
                                            .foregroundColor(item.color)
                                    }
                                }

                                Text(item.title)
                                    .font(VibeTypography.captionLarge)
                                    .foregroundColor(VibeTheme.textPrimary)
                            }
                        }
                    }
                    .padding(.horizontal, VibeSpacing.screenHorizontal)
                    .padding(.top, VibeSpacing.lg)
                    .padding(.bottom, VibeSpacing.xxxl)
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedVibeType != nil },
            set: { if !$0 {
                selectedVibeType = nil
                appState.shouldShowVibePicker = false
            }}
        )) {
            if selectedVibeType != nil {
                ComposerViewWrapper(vibeType: selectedVibeType, isLocked: isLocked)
            }
        }
    }

    private func selectVibeType(_ type: VibeType, locked: Bool) {
        self.isLocked = locked
        selectedVibeType = type
    }
}

// MARK: - Composer Wrappers

struct ComposerViewWrapper: View {
    @EnvironmentObject var appState: AppState
    let vibeType: VibeType?
    let isLocked: Bool

    var body: some View {
        Group {
            if let type = vibeType {
                ComposerViewWithInitialType(initialType: type, initialLocked: isLocked)
            }
        }
    }
}

struct ComposerViewWithInitialType: View {
    @EnvironmentObject var appState: AppState
    let initialType: VibeType
    let initialLocked: Bool

    var body: some View {
        ComposerView()
            .onAppear {
                appState.selectedVibeType = initialType
                appState.currentDestination = .composer
            }
    }
}

// =====================================================================
// MARK: - PREVIEW
// =====================================================================

#Preview {
    BentoDashboardView()
        .environmentObject(AppState())
}
