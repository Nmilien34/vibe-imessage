import SwiftUI
import PhotosUI
import UIKit

struct BentoDashboardView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            VibeTheme.groupedBackground.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // HEADER
                dashboardHeader

                // TAB CONTENT
                TabView(selection: $appState.activeTab) {
                    FeedTabView()
                        .tag(DashboardTab.feed)
                    TeaTabView()
                        .tag(DashboardTab.tea)
                    BoardTabView()
                        .tag(DashboardTab.board)
                    MeTabView()
                        .tag(DashboardTab.me)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // TAB BAR
                dashboardTabBar
            }
        }
        .task {
            async let auraTask: () = appState.loadAuraStats()
            async let profileTask: () = appState.loadCurrentUserProfile()
            await appState.loadExpandedBets()
            await appState.loadExpandedTeaSpills()
            _ = await (auraTask, profileTask)

            Task.detached(priority: .background) {
                await appState.syncContactsIfNeeded()
            }
        }
        .fullScreenCover(isPresented: $appState.shouldShowVibePicker) {
            ExploreAllVibesView()
        }
        .sheet(isPresented: $appState.showCreateSheet) {
            CreateChallengeSheet()
                .environmentObject(appState)
        }
    }

    // MARK: - Header

    private var dashboardHeader: some View {
        HStack {
            Text("Vibes")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(VibeTheme.textPrimary)

            Spacer()

            // Streak + Aura
            HStack(spacing: VibeSpacing.xs) {
                if let streak = appState.streak, streak.currentStreak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                        Text("\(streak.currentStreak)")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    }
                    .padding(.horizontal, VibeSpacing.xs)
                    .padding(.vertical, VibeSpacing.xxs)
                    .foregroundColor(VibeTheme.warm)
                    .background(VibeTheme.warmLight)
                    .clipShape(Capsule())
                }

                AuraBadge(amount: appState.auraBalance, size: .regular)

                Button {
                    VibeHaptic.medium()
                    appState.showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(VibeTheme.betAccent)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(VibeTheme.surfaceOverlay))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, VibeSpacing.screenHorizontal)
        .padding(.top, VibeSpacing.sm)
        .padding(.bottom, VibeSpacing.xs)
        .background(VibeTheme.cardBackground)
    }

    // MARK: - Tab Bar

    private var dashboardTabBar: some View {
        HStack {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                let isSelected = appState.activeTab == tab
                Button {
                    VibeHaptic.selection()
                    withAnimation(VibeAnimation.snappy) {
                        appState.activeTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                            .font(.system(size: 19, weight: isSelected ? .semibold : .regular))
                            .symbolRenderingMode(.hierarchical)
                        Text(tab.label)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    }
                    .foregroundColor(isSelected ? VibeTheme.betAccent : VibeTheme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 49)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, VibeSpacing.md)
        .padding(.top, VibeSpacing.xxs)
        .padding(.bottom, VibeSpacing.xs + 2)
        .background(VibeTheme.cardBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(VibeTheme.divider)
                .frame(height: 0.5)
        }
    }
}

// MARK: - Tab Helpers

extension DashboardTab {
    var icon: String {
        switch self {
        case .feed: return "house"
        case .tea: return "cup.and.saucer"
        case .board: return "trophy"
        case .me: return "person"
        }
    }

    var selectedIcon: String {
        switch self {
        case .feed: return "house.fill"
        case .tea: return "cup.and.saucer.fill"
        case .board: return "trophy.fill"
        case .me: return "person.fill"
        }
    }

    var label: String {
        switch self {
        case .feed: return "Feed"
        case .tea: return "Tea"
        case .board: return "Board"
        case .me: return "Me"
        }
    }
}

// =====================================================================
// MARK: - FEED TAB
// =====================================================================

struct FeedTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: VibeSpacing.md) {
                // Story row (compact, secondary)
                storyRow

                // Filter chips
                filterChips

                // Bet cards
                if appState.isLoadingBets && appState.filteredBets.isEmpty {
                    ForEach(0..<3, id: \.self) { _ in
                        CompactCardSkeleton()
                    }
                } else if appState.filteredBets.isEmpty {
                    feedEmptyState
                } else {
                    ForEach(appState.filteredBets) { bet in
                        BetCard(
                            bet: bet,
                            totals: appState.betTotalsById[bet.betId],
                            source: appState.betSourceById[bet.betId],
                            interactionStyle: .detail
                        )
                    }
                }
            }
            .padding(.horizontal, VibeSpacing.screenHorizontal)
            .padding(.bottom, VibeSpacing.xl)
        }
        .refreshable {
            await appState.loadExpandedBets()
            await appState.loadVibes()
        }
    }

    // MARK: - Story Row

    private var storyRow: some View {
        let groupedVibes = appState.storyGroupsForFeed()

        return Group {
            if !groupedVibes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: VibeSpacing.sm) {
                        ForEach(groupedVibes, id: \.first?.userId) { userVibes in
                            if let firstVibe = userVibes.first {
                                let hasUnseen = userVibes.contains { !$0.hasViewed(appState.userId) }
                                CompactStoryDot(
                                    thumbnailUrl: firstVibe.thumbnailUrl ?? firstVibe.mediaUrl,
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
                .padding(.top, VibeSpacing.xs)
            }
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        Picker("Challenge status", selection: $appState.betFilter) {
            ForEach(BetStatusFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue.capitalized)
                    .tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .tint(VibeTheme.betAccent)
        .onChange(of: appState.betFilter) { _, _ in
            VibeHaptic.selection()
        }
    }

    // MARK: - Empty State

    private var feedEmptyState: some View {
        VStack(spacing: VibeSpacing.md) {
            Image(systemName: "die.face.5.fill")
                .font(.system(size: 40))
                .foregroundColor(VibeTheme.textTertiary)
            Text("No challenges yet")
                .font(VibeTypography.titleSmall)
                .foregroundColor(VibeTheme.textSecondary)
            Text("Tap + to create the first one")
                .font(VibeTypography.captionLarge)
                .foregroundColor(VibeTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VibeSpacing.xxxl)
    }
}

// =====================================================================
// MARK: - TEA TAB
// =====================================================================

struct TeaTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: VibeSpacing.md) {
                HStack {
                    Text("Tea Spills")
                        .font(VibeTypography.titleMedium)
                        .foregroundColor(VibeTheme.textPrimary)
                    Spacer()
                }
                .padding(.top, VibeSpacing.xs)

                if appState.isLoadingTea && appState.expandedTeaSpills.isEmpty {
                    ForEach(0..<3, id: \.self) { _ in
                        CompactCardSkeleton()
                    }
                } else if appState.expandedTeaSpills.isEmpty {
                    VStack(spacing: VibeSpacing.md) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 40))
                            .foregroundColor(VibeTheme.textTertiary)
                        Text("No tea yet")
                            .font(VibeTypography.titleSmall)
                            .foregroundColor(VibeTheme.textSecondary)
                        Text("Spill some tea to get started")
                            .font(VibeTypography.captionLarge)
                            .foregroundColor(VibeTheme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VibeSpacing.xxxl)
                } else {
                    ForEach(appState.expandedTeaSpills) { tea in
                        TeaCard(tea: tea)
                    }
                }
            }
            .padding(.horizontal, VibeSpacing.screenHorizontal)
            .padding(.bottom, VibeSpacing.xl)
        }
        .refreshable {
            await appState.loadExpandedTeaSpills()
        }
    }
}

// =====================================================================
// MARK: - BOARD TAB
// =====================================================================

struct BoardTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: VibeSpacing.sm) {
                HStack {
                    Text("Leaderboard")
                        .font(VibeTypography.titleMedium)
                        .foregroundColor(VibeTheme.textPrimary)
                    Spacer()
                }
                .padding(.top, VibeSpacing.xs)

                if appState.leaderboard.isEmpty {
                    VStack(spacing: VibeSpacing.md) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 40))
                            .foregroundColor(VibeTheme.textTertiary)
                        Text("Leaderboard loading...")
                            .font(VibeTypography.bodyMedium)
                            .foregroundColor(VibeTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VibeSpacing.xxxl)
                } else {
                    ForEach(appState.leaderboard) { entry in
                        LeaderboardRow(entry: entry)
                    }
                }
            }
            .padding(.horizontal, VibeSpacing.screenHorizontal)
            .padding(.bottom, VibeSpacing.xl)
        }
        .refreshable {
            await appState.loadLeaderboard()
        }
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let entry: LeaderboardEntry

    private var rankBadge: String {
        switch entry.rank {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(entry.rank)"
        }
    }

    private var rankColor: Color {
        switch entry.rank {
        case 1, 2, 3: return VibeTheme.warm
        default: return VibeTheme.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: VibeSpacing.md) {
            // Rank
            Text(rankBadge)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(rankColor)
                .frame(width: 36)

            // Avatar
            Circle()
                .fill(rankColor.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(entry.name.prefix(1)))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(rankColor)
                )

            // Name + Win rate
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(VibeTypography.bodyMedium)
                    .foregroundColor(VibeTheme.textPrimary)
                Text("\(entry.winRate)% win rate")
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(VibeTheme.textSecondary)
            }

            Spacer()

            // Aura
            AuraBadge(amount: entry.auraBalance, size: .small)
        }
        .padding(VibeSpacing.md)
        .background(entry.rank <= 3 ? rankColor.opacity(0.05) : VibeTheme.cardBackground)
        .continuousCorner(VibeTheme.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: VibeTheme.radiusMedium, style: .continuous)
                .stroke(entry.rank == 1 ? rankColor.opacity(0.3) : .clear, lineWidth: 1)
        )
    }
}

// =====================================================================
// MARK: - ME TAB
// =====================================================================

struct MeTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var isUploadingProfilePhoto = false
    @State private var showUploadError = false
    @State private var uploadErrorMessage = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: VibeSpacing.lg) {
                HStack {
                    Button {
                        VibeHaptic.light()
                        withAnimation(VibeAnimation.snappy) {
                            appState.activeTab = .feed
                        }
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(VibeTheme.textPrimary)
                            .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, VibeSpacing.screenHorizontal)
                .padding(.top, VibeSpacing.sm)

                // Avatar + Name
                VStack(spacing: VibeSpacing.sm) {
                    profileAvatar

                    Text(appState.userFirstName ?? "User")
                        .font(VibeTypography.titleLarge)
                        .foregroundColor(VibeTheme.textPrimary)

                    AuraBadge(amount: appState.auraBalance, size: .large)
                }
                .padding(.top, VibeSpacing.lg)

                // Stats Grid (3x2)
                LazyVGrid(columns: statsColumns, spacing: VibeSpacing.xs) {
                    StatCard(title: "Vibe Score", value: "\(appState.vibeScore)", icon: "star.fill", color: .orange)
                    StatCard(title: "Win Rate", value: winRateText, icon: "chart.line.uptrend.xyaxis", color: VibeTheme.stakeYes)
                    StatCard(title: "Duck Rate", value: duckRateText, icon: "figure.run", color: VibeTheme.stakeNo)
                    StatCard(title: "Streak", value: streakText, icon: "flame.fill", color: .orange)
                    StatCard(title: "Challenges", value: "\(myChallengeCount)", icon: "flag.fill", color: VibeTheme.betAccent)
                    StatCard(title: "Tea Spills", value: "\(myTeaCount)", icon: "cup.and.saucer.fill", color: VibeTheme.warm)
                }
                .padding(.horizontal, VibeSpacing.screenHorizontal)

                // Daily Bonus
                if appState.auraStats?.dailyBonusAvailable == true {
                    Button {
                        VibeHaptic.success()
                        Task { await appState.claimDailyBonus() }
                    } label: {
                        HStack {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Daily Bonus")
                                    .font(VibeTypography.titleSmall)
                                Text("Tap to claim your Aura")
                                    .font(VibeTypography.captionSmall)
                                    .opacity(0.8)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundColor(.white)
                        .padding(VibeSpacing.md)
                        .background(VibeTheme.auraGradient)
                        .continuousCorner(VibeTheme.radiusMedium)
                    }
                    .buttonStyle(VibePressStyle())
                    .padding(.horizontal, VibeSpacing.screenHorizontal)
                }

                // Quick Links
                VStack(spacing: 0) {
                    QuickLinkRow(icon: "sparkles", title: "Aura Hub", color: Color(red: 1.0, green: 0.75, blue: 0.0)) {
                        appState.navigateToAuraHub()
                    }
                    Divider().padding(.leading, 44)

                    QuickLinkRow(icon: "list.bullet", title: "My Bets", color: VibeTheme.betAccent) {
                        appState.navigateToBetList()
                    }
                    Divider().padding(.leading, 44)

                    QuickLinkRow(icon: "person.2.fill", title: "My Network", color: VibeTheme.accent) {
                        appState.navigateToNetworkSettings()
                    }
                    Divider().padding(.leading, 44)

                    QuickLinkRow(icon: "rectangle.portrait.and.arrow.forward", title: "Sign Out", color: VibeTheme.stakeNo) {
                        appState.signOut()
                    }
                }
                .padding(.horizontal, VibeSpacing.screenHorizontal)
                .background(VibeTheme.cardBackground)
                .continuousCorner(VibeTheme.radiusMedium)
            }
            .padding(.bottom, VibeSpacing.xl)
        }
        .task {
            async let profileTask: () = appState.loadCurrentUserProfile()
            async let auraTask: () = appState.loadAuraStats()
            _ = await (profileTask, auraTask)
        }
        .onAppear {
            Task {
                await appState.loadAuraStats()
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                await uploadProfilePhoto(item: newValue)
            }
        }
        .alert("Upload failed", isPresented: $showUploadError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(uploadErrorMessage)
        }
    }

    private var winRateText: String {
        guard let entry = appState.leaderboard.first(where: { $0.id == appState.userId }) else {
            return "—"
        }
        return "\(entry.winRate)%"
    }

    private var duckRateText: String {
        guard let entry = appState.leaderboard.first(where: { $0.id == appState.userId }) else {
            return "—"
        }
        return "\(entry.duckRate)%"
    }

    private var streakText: String {
        guard let streak = appState.streak else { return "0" }
        return "\(streak.currentStreak)"
    }

    private var statsColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: VibeSpacing.xs),
            GridItem(.flexible(), spacing: VibeSpacing.xs),
            GridItem(.flexible(), spacing: VibeSpacing.xs)
        ]
    }

    private var myChallengeCount: Int {
        let ids = Set(
            appState.expandedBets
                .filter { $0.creatorId == appState.userId }
                .map(\.betId)
        )
        return ids.count
    }

    private var myTeaCount: Int {
        let ids = Set(
            appState.expandedTeaSpills
                .filter { $0.creatorId == appState.userId }
                .map(\.teaId)
        )
        return ids.count
    }

    private var profileAvatar: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .fill(VibeTheme.surfaceOverlay)

                if let urlString = appState.userProfilePictureURL,
                   let url = URL.httpURL(from: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .tint(VibeTheme.textPrimary)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            initialsAvatar
                        @unknown default:
                            initialsAvatar
                        }
                    }
                } else {
                    initialsAvatar
                }

                if isUploadingProfilePhoto {
                    Circle()
                        .fill(Color.black.opacity(0.35))
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(VibeTheme.divider, lineWidth: 1)
            )

            Button {
                showPhotoPicker = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(VibeTheme.accent)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(VibeTheme.background, lineWidth: 2)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isUploadingProfilePhoto)
        }
    }

    private var initialsAvatar: some View {
        Text(String(appState.userFirstName?.prefix(1) ?? "V").uppercased())
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(VibeTheme.textPrimary)
    }

    private func uploadProfilePhoto(item: PhotosPickerItem) async {
        isUploadingProfilePhoto = true
        defer {
            isUploadingProfilePhoto = false
            selectedPhotoItem = nil
        }

        do {
            guard let selectedData = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: selectedData),
                  let uploadData = image.jpegData(compressionQuality: 0.86) else {
                throw APIError.uploadFailed
            }
            try await appState.updateProfilePicture(imageData: uploadData, fileType: "jpg")
            VibeHaptic.success()
        } catch {
            uploadErrorMessage = "Couldn't upload your profile photo. Please try again."
            showUploadError = true
            print("MeTabView Error: Profile photo upload failed: \(error)")
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var detail: String? = nil

    var body: some View {
        VStack(spacing: VibeSpacing.xxxs) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(VibeTheme.textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(VibeTypography.captionSmall)
                .foregroundColor(VibeTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(VibeTheme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 92)
        .padding(.horizontal, VibeSpacing.xs)
        .padding(.vertical, VibeSpacing.sm)
        .background(VibeTheme.cardBackground)
        .continuousCorner(VibeTheme.radiusMedium)
    }
}

// MARK: - Quick Link Row

struct QuickLinkRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button {
            VibeHaptic.light()
            action()
        } label: {
            HStack(spacing: VibeSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 28)

                Text(title)
                    .font(VibeTypography.bodyMedium)
                    .foregroundColor(VibeTheme.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(VibeTheme.textTertiary)
            }
            .padding(VibeSpacing.md)
        }
        .buttonStyle(.plain)
    }
}

// =====================================================================
// MARK: - LEGACY COMPONENTS (kept for other views)
// =====================================================================

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
                       let url = URL.httpURL(from: thumbUrl) {
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
            ZStack(alignment: .topTrailing) {
                if let imageUrl = imageUrl, let url = URL.httpURL(from: imageUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        color.opacity(0.1)
                    }
                } else {
                    color.opacity(0.2)
                }

                if isJustIn {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(VibeTheme.warm)
                        .padding(5)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(VibeSpacing.xs)
                }
            }
            .frame(width: 170, height: 110)
            .clipShape(RoundedRectangle(cornerRadius: VibeTheme.radiusMedium, style: .continuous))

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

struct PastVibeCard: View {
    let vibe: Vibe
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                if let thumbUrl = vibe.thumbnailUrl ?? vibe.mediaUrl,
                   let url = URL.httpURL(from: thumbUrl) {
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
