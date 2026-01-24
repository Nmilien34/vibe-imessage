import SwiftUI

struct BentoDashboardView: View {
    @EnvironmentObject var appState: AppState
    
    // Columns for the Grid (1 flexible column, 1 flexible column)
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            // Background Color (Matches iMessage)
            Color(.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // 1. Header
                headerView
                
                // 2. The Bento Grid & Carousel
                ScrollView {
                    VStack(spacing: 0) {
                        LazyVGrid(columns: columns, spacing: 16) {
                            
                            // --- ROW 1: Hero Actions ---
                            
                            // Card A: Post A Vibe (Tall Card - Main Action)
                            Button {
                                openComposer(type: .video) // Opens generic camera (Photo/Video)
                            } label: {
                                VStack(alignment: .leading) {
                                    HStack { 
                                        Spacer()
                                        Image(systemName: "camera.fill")
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("Post Vibe")
                                        .font(.system(.title3, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .frame(height: 160) // Reduced from 180
                                .background(
                                    LinearGradient(gradient: Gradient(colors: [Color.pink, Color.purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .cornerRadius(20)
                                .shadow(color: Color.pink.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            
                            // Right Column (Stacked Dynamic Cards)
                            VStack(spacing: 12) {
                                ForEach(appState.topUserVibeTypes, id: \.self) { type in
                                    BentoActionCard(type: type)
                                }
                            }
                            
                            // --- ROW 2: The Daily Drop & See More ---
                            
                            // Card D: Daily Drop
                            Button {
                                openComposer(type: .dailyDrop) 
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("DAILY DROP 🎲")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white.opacity(0.7))
                                        Text("Show us your fridge")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .frame(height: 74) 
                                .background(Color.black) 
                                .cornerRadius(20)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                            }

                            // Card E: See More Vibes
                            Button {
                                appState.navigateToComposer()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("EXPLORE")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.gray)
                                        Text("More Vibes")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.primary)
                                    }
                                    Spacer()
                                    Image(systemName: "grid")
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .frame(height: 74) 
                                .background(Color.white)
                                .cornerRadius(20)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            }
                            
                        }
                        .padding()

                        // --- Active Squad Carousel (Full Width) ---
                        activeSquadCarousel
                            .padding(.vertical, 8)

                        // --- ROW 3: Squad Stats ---
                        squadStatsSection
                            .padding(.vertical, 8)
                        
                        // --- ROW 4: Group Pulse ---
                        groupPulseView
                            .padding(.vertical, 8)

                        // --- ROW 5: Past Vibes Section ---
                        pastVibesSection
                            .gridCellColumns(2)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Components
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Good Evening,")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.gray)
                Text(appState.userFirstName != nil ? appState.userFirstName! : "Vibez User")
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            Spacer()
            
            // Streak Pill
            if let streak = appState.streak {
                HStack(spacing: 4) {
                    Text("🔥")
                    Text("\(streak.currentStreak)")
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
            
            // New Updates Badge (if any)
            if appState.newVibesCount > 0 {
                Button {
                    // Open viewer with the first unseen vibe
                    if let firstUnseenVibe = appState.vibes.first(where: {
                        !appState.seenVibeIds.contains($0.id) && $0.userId != appState.userId
                    }) {
                        appState.navigateToViewer(opening: firstUnseenVibe.id)
                    }
                } label: {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Text("\(appState.newVibesCount) New Updates")
                                .fontWeight(.bold)
                                .font(.caption)
                            Text("🥳")
                        }
                        Text("Tap to view")
                            .font(.system(size: 9))
                            .opacity(0.8)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.purple.opacity(0.3), radius: 5, x: 0, y: 2)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    private var activeSquadCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recently Active")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Current user (if they posted recently)
                    let currentUserVibes = appState.vibes.filter { $0.userId == appState.userId }
                    if !currentUserVibes.isEmpty {
                        VibeRingView(
                            vibes: currentUserVibes,
                            userId: appState.userId,
                            isCurrentUser: true,
                            size: 60
                        ) {
                            if let firstVibe = currentUserVibes.first {
                                appState.navigateToViewer(opening: firstVibe.id)
                            }
                        }
                    }
                    
                    // All friends who posted (Grouped by user)
                    let groupedVibes = appState.vibesGroupedByUser()
                    ForEach(groupedVibes, id: \.first?.userId) { userVibes in
                        if let firstVibe = userVibes.first,
                           firstVibe.userId != appState.userId {
                            VibeRingView(
                                vibes: userVibes,
                                userId: firstVibe.userId,
                                isCurrentUser: false,
                                size: 60
                            ) {
                                appState.navigateToViewer(opening: firstVibe.id)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
        .padding(.top, 8)
    }

    private var groupPulseView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Group Pulse")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal)
            
            HStack(spacing: 12) {
                // Card 1: Time Capsule (Left - Wide)
                Button {
                    // Logic to play memory
                } label: {
                    ZStack(alignment: .bottomLeading) {
                        // Background Blurred Memory
                        AsyncImage(url: URL(string: "https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=400")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .blur(radius: 5)
                        .overlay(Color.black.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        
                        // Content
                        VStack(alignment: .leading, spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 0) {
                                Text("On This Day")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("1 Year Ago")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(16)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                
                // Card 2: Upcoming (Right - Fixed)
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemGray6))
                    
                    VStack(spacing: 8) {
                        Spacer()
                        Text("🎂")
                            .font(.system(size: 40))
                        Spacer()
                        VStack(spacing: 2) {
                            Text("Sarah")
                                .font(.system(size: 14, weight: .bold))
                            Text("Fri")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(.bottom, 12)
                    }
                }
                .frame(width: 100, height: 120)
            }
            .padding(.horizontal)
        }
    }
    
    private var pastVibesSection: some View {
        let userVibes = appState.vibes.filter { $0.userId == appState.userId }
        
        return VStack(alignment: .leading, spacing: 20) {
            // Headline
            HStack {
                Text("Past Vibes")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal)

            // History Grid
            if !userVibes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(userVibes) { vibe in
                             VibeGridCell(vibe: vibe, userId: appState.userId) {
                                 appState.navigateToViewer(opening: vibe.id)
                             }
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                // Placeholder if empty
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.3))
                    Text("Your vibe history will appear here")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }

    private var squadStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Squad Stats")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // 1. The MVP
                    if let (mvpId, count) = mvpData {
                        SquadStatCard(
                            title: "The MVP",
                            icon: "👑",
                            accentColor: .yellow,
                            centerContent: {
                                avatarForUser(mvpId, size: 40)
                            },
                            footerContent: {
                                Text("\(nameForUser(mvpId)) (+\(count))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                        )
                    }
                    
                    // 2. The Ghost
                    if let ghostId = ghostUserId {
                        SquadStatCard(
                            title: "The Ghost",
                            icon: "👻",
                            accentColor: .gray,
                            centerContent: {
                                avatarForUser(ghostId, size: 40, desaturated: true)
                            },
                            footerContent: {
                                Button {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    // Logic for nudge could go here
                                } label: {
                                    Text("Nudge")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                }
                            }
                        )
                    }
                    
                    // 3. Bestie Streak
                    SquadStatCard(
                        title: "Bestie Streak",
                        icon: "🔥",
                        accentColor: .orange,
                        centerContent: {
                            Text("\(bestieStreakCount)")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundColor(.orange)
                        },
                        footerContent: {
                            Text("Days w/ \(bestieName)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    )
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Squad Stats Logic
    
    private var mvpData: (String, Int)? {
        let friendsVibes = appState.vibes.filter { $0.userId != appState.userId }
        let counts = friendsVibes.reduce(into: [String: Int]()) { $0[$1.userId, default: 0] += 1 }
        guard let topParticipant = counts.max(by: { $0.value < $1.value }) else { return nil }
        return (topParticipant.key, topParticipant.value)
    }
    
    private var ghostUserId: String? {
        let friends = appState.vibesGroupedByUser()
            .compactMap { $0.first?.userId }
            .filter { $0 != appState.userId }
        
        // Find someone who hasn't posted in > 24h
        let oneDayAgo = Date().addingTimeInterval(-86400)
        return friends.first { friendId in
            let lastVibeDate = appState.vibes.filter { $0.userId == friendId }
                .map { $0.createdAt }
                .max()
            return lastVibeDate == nil || lastVibeDate! < oneDayAgo
        }
    }
    
    private var bestieStreakCount: Int {
        // Mocking for now as we don't have per-relationship streaks yet
        return 5
    }
    
    private var bestieName: String {
        // Find most frequent interactor or just use first friend
        if let mvpId = mvpData?.0 {
            return nameForUser(mvpId)
        }
        return "Mike"
    }

    private func nameForUser(_ id: String) -> String {
        // Simplified lookup
        if id == appState.userId { return "You" }
        if id.contains("friend_1") { return "Sarah" }
        if id.contains("friend_2") { return "Mike" }
        if id.contains("friend_3") { return "Alex" }
        if id.contains("friend_4") { return "Sam" }
        if id.contains("friend_5") { return "Jordan" }
        return "Friend"
    }

    private func avatarForUser(_ id: String, size: CGFloat, desaturated: Bool = false) -> some View {
        let userVibes = appState.vibes.filter { $0.userId == id }
        return Group {
            if !userVibes.isEmpty {
                VibeRingView(vibes: userVibes, userId: id, isCurrentUser: id == appState.userId, size: size, onTap: {})
                    .grayscale(desaturated ? 1.0 : 0.0)
                    .allowsHitTesting(false)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay {
                        Text(String(nameForUser(id).prefix(1)))
                            .font(.system(size: size * 0.4, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    .grayscale(desaturated ? 1.0 : 0.0)
            }
        }
    }


    // MARK: - Helpers
    
    // Helper to open composer
    private func openComposer(type: VibeType) {
        // Navigate directly to the composer with the selected type pre-set
        // POV is handled as a special case of Video in some contexts, but here we can pass type
        // If it's "POV" (which isn't a VibeType, it's Video + Locked), we might need to handle that.
        // For now, assuming VibeType maps directly.
        // If we want "POV" button to open Video + Locked, we need to pass that arg.
        // Let's check call sites.
        appState.navigateToComposer(type: type)
    }
    
    // POV Specific Helper (since POV is not a VibeType)
    private func openPOV() {
        appState.navigateToComposer(type: .video, isLocked: true)
    }
    
    private var currentBatteryLevel: Int {
        Int(UIDevice.current.batteryLevel * 100)
    }
    
    private var batteryLevelString: String {
        let level = currentBatteryLevel
        return level < 0 ? "--%" : "\(level)%"
    }
    
    private func batteryIcon(for level: Int) -> String {
        if level < 0 { return "battery.0" }
        if level < 20 { return "battery.25" }
        if level < 50 { return "battery.50" }
        if level < 80 { return "battery.75" }
        return "battery.100"
    }
}

// MARK: - Bento Action Card
struct BentoActionCard: View {
    @EnvironmentObject var appState: AppState
    let type: VibeType

    private var currentBatteryLevel: Int {
        Int(UIDevice.current.batteryLevel * 100)
    }

    private var batteryLevelString: String {
        let level = currentBatteryLevel
        return level < 0 ? "--%" : "\(level)%"
    }

    private func batteryIcon(for level: Int) -> String {
        if level < 0 { return "battery.0" }
        if level < 20 { return "battery.25" }
        if level < 50 { return "battery.50" }
        if level < 80 { return "battery.75" }
        return "battery.100"
    }

    var body: some View {
        Button {
            if type == .video {
                appState.navigateToComposer(type: .video, isLocked: true)
            } else {
                appState.navigateToComposer(type: type)
            }
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    if type == .battery {
                        Text(batteryLevelString)
                            .font(.title2)
                            .fontWeight(.heavy)
                            .foregroundColor(.green)
                    } else if type == .video {
                        Image(systemName: "eye.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: type.icon)
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text(title)
                        .fontWeight(.semibold)
                        .foregroundColor(type == .battery ? .secondary : .white)
                        .font(type == .battery ? .caption : .body)
                }
                Spacer()
                
                if type == .video {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                } else if type == .battery {
                    Image(systemName: batteryIcon(for: currentBatteryLevel))
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .padding()
            .frame(height: 74)
            .background(backgroundView)
            .cornerRadius(20)
            .shadow(color: shadowColor, radius: 5, x: 0, y: 2)
        }
    }

    private var title: String {
        switch type {
        case .video: return "POV"
        case .battery: return "Status"
        default: return type.displayName
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if type == .battery {
            Color.white
        } else if type == .video {
            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.cyan]), startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            type.color
        }
    }

    private var shadowColor: Color {
        if type == .battery {
            return Color.black.opacity(0.05)
        } else {
            return type.color.opacity(0.2)
        }
    }
}
#Preview {
    BentoDashboardView()
        .environmentObject(AppState())
}
