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
                            
                            // Right Column (Stacked POV & Battery)
                            VStack(spacing: 12) { // Reduced spacing from 16
                                // Card B: POV
                                Button {
                                    openPOV()
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Image(systemName: "eye.fill")
                                                .font(.title2) // Reduced font size
                                                .foregroundColor(.white)
                                            Spacer()
                                            Text("POV")
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                        }
                                        Spacer()
                                        Image(systemName: "lock.fill")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .padding()
                                    .frame(height: 74) // Reduced from 82
                                    .background(
                                        LinearGradient(gradient: Gradient(colors: [Color.blue, Color.cyan]), startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .cornerRadius(20)
                                    .shadow(color: Color.blue.opacity(0.2), radius: 5, x: 0, y: 2)
                                }
                                
                                // Card C: Battery (Live Widget)
                                Button {
                                    openComposer(type: .battery)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(batteryLevelString)
                                                .font(.title2) // Reduced font size
                                                .fontWeight(.heavy)
                                                .foregroundColor(.green)
                                            Spacer()
                                            Text("Status")
                                                .fontWeight(.semibold)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Image(systemName: batteryIcon(for: currentBatteryLevel))
                                            .foregroundColor(.gray.opacity(0.5))
                                    }
                                    .padding()
                                    .frame(height: 74) // Reduced from 82
                                    .background(Color.white)
                                    .cornerRadius(20)
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                }
                            }
                            
                            // --- ROW 2: The Daily Drop & See More ---
                            
                            // Card D: Daily Drop
                            Button {
                                openComposer(type: .poll) 
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

                        // --- ROW 4: Past Vibes Section ---
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
                Text("Vibez User") // Placeholder, could use appState.userId or "You"
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

                // 1. Most Used Row (Frequency based)
                VStack(alignment: .leading, spacing: 10) {
                    Text("MOST USED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(mostUsedVibeTypes, id: \.self) { type in
                                Button {
                                    appState.navigateToComposer(type: type)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: type.icon)
                                            .font(.system(size: 14, weight: .bold))
                                        Text(type.displayName)
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(type.color.opacity(0.1))
                                    .foregroundColor(type.color)
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // 2. Recent History Grid
                if !userVibes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("HISTORY")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
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
                }
            }
    }

    private var mostUsedVibeTypes: [VibeType] {
        let userVibes = appState.vibes.filter { $0.userId == appState.userId }
        let counts = userVibes.reduce(into: [VibeType: Int]()) { $0[$1.type, default: 0] += 1 }

        // Sort by frequency, then by display name for consistency
        return VibeType.allCases.sorted { typeA, typeB in
            let countA = counts[typeA, default: 0]
            let countB = counts[typeB, default: 0]
            if countA != countB {
                return countA > countB
            }
            return typeA.displayName < typeB.displayName
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

#Preview {
    BentoDashboardView()
        .environmentObject(AppState())
}
