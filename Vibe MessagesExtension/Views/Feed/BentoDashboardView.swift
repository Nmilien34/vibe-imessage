import SwiftUI

struct BentoDashboardView: View {
    @EnvironmentObject var appState: AppState

    // Theme Colors
    let bgOffWhite = Color(red: 0.96, green: 0.96, blue: 0.97)

    var body: some View {
        ZStack {
            // Background
            bgOffWhite.edgesIgnoringSafeArea(.all)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // ============================================
                    // MARK: PART 1 - THE UPPER SCREEN
                    // ============================================

                    UpperSectionView()

                    // ============================================
                    // MARK: PART 2 - THE LOWER SCREEN
                    // ============================================

                    LowerSectionView()

                    Spacer(minLength: 40)
                }
                .padding(.bottom, 40)
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
                Text(appState.userFirstName != nil ? appState.userFirstName! : "Vibes User")
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

// =====================================================================
// MARK: - PART 1 VIEW (UPPER SCREEN)
// =====================================================================

struct UpperSectionView: View {
    @EnvironmentObject var appState: AppState

    let vibezPink = Color(red: 1.0, green: 0.2, blue: 0.6)
    let vibezPurple = Color(red: 0.6, green: 0.2, blue: 1.0)
    let vibezCyan = Color(red: 0.2, green: 0.7, blue: 1.0)
    let vibezBlue = Color(red: 0.1, green: 0.4, blue: 0.9)

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default: return "Good Night"
        }
    }

    private var currentBatteryLevel: Int {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        return level < 0 ? 78 : Int(level * 100) // Default to 78 if unknown
    }

    var body: some View {
        VStack(spacing: 24) {

            // 1. HEADER
            HStack {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(appState.userFirstName?.prefix(1) ?? "V"))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        )
                    Text("Hi, \(appState.userFirstName ?? "Vibez")")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }

                Spacer()

                HStack(spacing: 8) {
                    // Streak Badge
                    if let streak = appState.streak, streak.currentStreak > 0 {
                        Text("🔥 \(streak.currentStreak)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.05), radius: 3)
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
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(colors: [vibezPink, vibezPurple], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)

            // 2. STORY RAIL
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // My Story (Add Button)
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .foregroundColor(.gray.opacity(0.5))
                                .frame(width: 68, height: 68)

                            // Show user's latest vibe thumbnail if exists
                            if let myVibe = appState.vibes.first(where: { $0.userId == appState.userId }),
                               let thumbUrl = myVibe.thumbnailUrl ?? myVibe.mediaUrl,
                               let url = URL(string: thumbUrl) {
                                AsyncImage(url: url) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.gray.opacity(0.2)
                                }
                                .frame(width: 62, height: 62)
                                .clipShape(Circle())
                            }

                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.white, .blue)
                                .font(.system(size: 22))
                        }
                        .onTapGesture {
                            appState.navigateToComposer(type: .video)
                        }

                        Text("My Story")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.leading)

                    // Friends' Stories
                    let groupedVibes = appState.vibesGroupedByUser()
                    ForEach(groupedVibes, id: \.first?.userId) { userVibes in
                        if let firstVibe = userVibes.first,
                           firstVibe.userId != appState.userId {
                            StoryRingItem(
                                vibes: userVibes,
                                name: nameForUser(firstVibe.userId),
                                hasUnviewed: userVibes.contains { !$0.hasViewed(appState.userId) }
                            ) {
                                appState.navigateToViewer(opening: firstVibe.id)
                            }
                        }
                    }
                }
            }

            // 3. BENTO GRID (Hero Left + Triple Stack Right)
            HStack(alignment: .top, spacing: 12) {
                // Left: Post Vibe
                Button {
                    appState.navigateToComposer(type: .video)
                } label: {
                    VStack {
                        Spacer()
                        Image(systemName: "plus")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        HStack(alignment: .bottom) {
                            Text("Post Vibe")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            Spacer()
                            if appState.newVibesCount > 0 {
                                Text("\(appState.newVibesCount) waiting")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    .padding(20)
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(colors: [vibezPink, vibezPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(24)
                    .shadow(color: vibezPink.opacity(0.3), radius: 8, y: 4)
                }

                // Right: Triple Stack
                VStack(spacing: 12) {
                    // POV (Top)
                    Button {
                        appState.navigateToComposer(type: .video, isLocked: true)
                    } label: {
                        HStack {
                            Image(systemName: "eye.fill")
                            Text("POV").bold()
                            Spacer()
                            Image(systemName: "lock.fill").opacity(0.5)
                        }
                        .padding(.horizontal)
                        .frame(height: 65)
                        .background(
                            LinearGradient(colors: [vibezCyan, vibezBlue], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }

                    // Battery (Middle)
                    Button {
                        appState.navigateToComposer(type: .battery)
                    } label: {
                        HStack {
                            Text("Battery")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(currentBatteryLevel)%")
                                .bold()
                                .foregroundColor(batteryColor)
                            Image(systemName: batteryIcon)
                                .foregroundColor(batteryColor)
                        }
                        .padding(.horizontal)
                        .frame(height: 65)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.03), radius: 3)
                    }

                    // Explore (Bottom)
                    Button {
                        appState.shouldShowVibePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "square.grid.2x2.fill")
                            Text("Explore").bold()
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        .frame(height: 65)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.03), radius: 3)
                    }
                    .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)

            // 4. DAILY DROP
            Button {
                appState.navigateToComposer(type: .dailyDrop)
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text("DAILY DROP 🎲")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.gray)
                        Text("Show us your fridge")
                            .font(.title3)
                            .bold()
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .padding(10)
                        .background(Color.white)
                        .clipShape(Circle())
                        .foregroundColor(.black)
                }
                .padding(24)
                .background(Color.black)
                .cornerRadius(24)
            }
            .padding(.horizontal)

            // 5. LEADERBOARD
            VStack(alignment: .leading) {
                Text("LEADERBOARD")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.gray)
                    .padding(.leading)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // MVP
                        if let (mvpId, count) = mvpData {
                            LeaderboardCardView(
                                emoji: "👑",
                                name: nameForUser(mvpId),
                                score: "+\(count)",
                                isMVP: true
                            )
                        }

                        // Ghost (needs nudge)
                        if let ghostId = ghostUserId {
                            LeaderboardCardView(
                                emoji: "👻",
                                name: nameForUser(ghostId),
                                score: "Nudge",
                                isMVP: false
                            )
                        }

                        // Third place or fallback
                        let thirdPlace = appState.vibesGroupedByUser()
                            .compactMap { $0.first }
                            .filter { $0.userId != appState.userId && $0.userId != mvpData?.0 && $0.userId != ghostUserId }
                            .first

                        if let third = thirdPlace {
                            let count = appState.vibes.filter { $0.userId == third.userId }.count
                            LeaderboardCardView(
                                emoji: "💅",
                                name: nameForUser(third.userId),
                                score: "+\(count)",
                                isMVP: false
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Helpers

    private var batteryColor: Color {
        switch currentBatteryLevel {
        case 0..<20: return .red
        case 20..<50: return .yellow
        default: return .green
        }
    }

    private var batteryIcon: String {
        switch currentBatteryLevel {
        case 0..<25: return "battery.25"
        case 25..<50: return "battery.50"
        case 50..<75: return "battery.75"
        default: return "battery.100"
        }
    }

    private var mvpData: (String, Int)? {
        let friendsVibes = appState.vibes.filter { $0.userId != appState.userId }
        let counts = friendsVibes.reduce(into: [String: Int]()) { $0[$1.userId, default: 0] += 1 }
        guard let top = counts.max(by: { $0.value < $1.value }) else { return nil }
        return (top.key, top.value)
    }

    private var ghostUserId: String? {
        let friends = appState.vibesGroupedByUser()
            .compactMap { $0.first?.userId }
            .filter { $0 != appState.userId }

        let oneDayAgo = Date().addingTimeInterval(-86400)
        return friends.first { friendId in
            let lastDate = appState.vibes.filter { $0.userId == friendId }.map { $0.createdAt }.max()
            return lastDate == nil || lastDate! < oneDayAgo
        }
    }

    private func nameForUser(_ id: String) -> String {
        if id == appState.userId { return "You" }
        if id == "vibe_team" { return "Vibez" }
        if id.contains("friend_1") { return "Sarah" }
        if id.contains("friend_2") { return "Mike" }
        if id.contains("friend_3") { return "Jess" }
        if id.contains("friend_4") { return "Alex" }
        if id.contains("friend_5") { return "Sam" }
        // Generate a name from the ID
        let names = ["Emma", "Liam", "Olivia", "Noah", "Ava", "Ethan", "Sophia", "Mason"]
        let index = abs(id.hashValue) % names.count
        return names[index]
    }
}

// =====================================================================
// MARK: - PART 2 VIEW (LOWER SCREEN)
// =====================================================================

struct LowerSectionView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 24) {

            // 6. VIBE WIRE (NEWS)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("VIBE WIRE")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.gray)
                    Spacer()
                    HStack(spacing: 16) {
                        Image(systemName: "arrow.left")
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.5))
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
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
                        NewsCardView(
                            tag: "TECH",
                            headline: "iPhone 17 Pro rumors heating up",
                            socialText: "1 friend shared this",
                            color: .gray
                        )
                    }
                    .padding(.horizontal)
                }
            }

            // 7. UPCOMING REMINDERS
            VStack(alignment: .leading, spacing: 12) {
                Text("UPCOMING")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.gray)
                    .padding(.leading)

                HStack(spacing: 12) {
                    ReminderCardView(
                        icon: "gift.fill",
                        title: "Sarah's B-Day",
                        subtitle: "In 2 days",
                        iconColor: .pink
                    )
                    ReminderCardView(
                        icon: "popcorn.fill",
                        title: "Movie Night",
                        subtitle: "Friday 8pm",
                        iconColor: .orange
                    )
                }
                .padding(.horizontal)
            }

            // 8. PAST VIBES (HISTORY)
            VStack(alignment: .leading, spacing: 12) {
                Text("PAST VIBES")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.gray)
                    .padding(.leading)

                let userVibes = appState.vibes.filter { $0.userId == appState.userId }

                if userVibes.isEmpty {
                    // Empty state
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    .foregroundColor(Color.gray.opacity(0.2))
                            )

                        VStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 30))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("Your past vibes will appear here")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.gray)
                            Text("Post a vibe to start your history.")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .padding(40)
                    }
                    .padding(.horizontal)
                    .frame(height: 180)
                } else {
                    // Show user's vibes in a horizontal scroll
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(userVibes.prefix(6)) { vibe in
                                PastVibeCard(vibe: vibe) {
                                    appState.navigateToViewer(opening: vibe.id)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}

// =====================================================================
// MARK: - COMPONENTS
// =====================================================================

struct StoryRingItem: View {
    let vibes: [Vibe]
    let name: String
    let hasUnviewed: Bool
    let onTap: () -> Void

    let vibezPink = Color(red: 1.0, green: 0.2, blue: 0.6)

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onTap) {
                ZStack {
                    // Gradient ring
                    Circle()
                        .strokeBorder(
                            hasUnviewed ?
                            LinearGradient(colors: [vibezPink, .orange], startPoint: .topTrailing, endPoint: .bottomLeading) :
                            LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 3
                        )
                        .frame(width: 68, height: 68)

                    // Content
                    if let firstVibe = vibes.first,
                       let thumbUrl = firstVibe.thumbnailUrl ?? firstVibe.mediaUrl,
                       let url = URL(string: thumbUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.1))
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 60, height: 60)
                    }

                    // Count badge
                    if vibes.count > 1 {
                        Text("\(vibes.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Capsule())
                            .offset(x: 22, y: -22)
                    }
                }
            }

            Text(name)
                .font(.caption)
                .bold()
        }
    }
}

struct LeaderboardCardView: View {
    var emoji: String
    var name: String
    var score: String
    var isMVP: Bool

    var body: some View {
        VStack(alignment: .leading) {
            Text(emoji)
                .font(.title)
            Spacer()
            Text(name)
                .font(.subheadline)
                .bold()
            Text(score)
                .font(.caption)
                .foregroundColor(isMVP ? .orange : .gray)
        }
        .padding(12)
        .frame(width: 100, height: 100)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isMVP ? Color.orange.opacity(0.3) : .clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.03), radius: 3)
    }
}

struct NewsCardView: View {
    var tag: String
    var headline: String
    var socialText: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(tag)
                    .font(.system(size: 9, weight: .heavy))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.25))
                    .cornerRadius(4)
                Spacer()
                Image(systemName: "bubble.right.fill")
                    .font(.caption2)
                    .opacity(0.8)
            }
            Spacer()
            Text(headline)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .lineLimit(3)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 10))
                Text(socialText)
                    .font(.system(size: 10, weight: .bold))
            }
            .opacity(0.9)
        }
        .padding(14)
        .foregroundColor(.white)
        .frame(width: 170, height: 125)
        .background(color)
        .cornerRadius(18)
        .shadow(color: color.opacity(0.3), radius: 6, y: 3)
    }
}

struct ReminderCardView: View {
    var icon: String
    var title: String
    var subtitle: String
    var iconColor: Color

    var body: some View {
        HStack {
            Circle()
                .fill(iconColor.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                )
            VStack(alignment: .leading) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
    }
}

struct PastVibeCard: View {
    let vibe: Vibe
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Thumbnail
                if let thumbUrl = vibe.thumbnailUrl ?? vibe.mediaUrl,
                   let url = URL(string: thumbUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                } else {
                    vibe.type.color.opacity(0.3)
                        .overlay(
                            Image(systemName: vibe.type.icon)
                                .font(.title)
                                .foregroundColor(.white)
                        )
                }

                // Gradient overlay
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Time info
                VStack(alignment: .leading, spacing: 2) {
                    Text(vibe.timeRemainingFormatted)
                        .font(.caption2)
                        .bold()
                    if vibe.isExpiredFromFeed == true {
                        Text("Expired")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                    }
                }
                .foregroundColor(.white)
                .padding(8)
            }
            .frame(width: 100, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 16))
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
