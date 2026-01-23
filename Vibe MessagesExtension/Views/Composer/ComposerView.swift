//
//  ComposerView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI

// MARK: - Mock Data
struct Friend: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String // System image for now, or asset
    let hasPosted: Bool
    
    // Gradient for the ring if posted
    var ringColors: [Color] {
        if hasPosted {
            return [.red, .orange, .pink, .purple, .blue]
        } else {
            return [.gray.opacity(0.3)]
        }
    }
}

struct ComposerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    
    @State private var selectedType: VibeType?
    @State private var isLocked = false
    
    // Sync with AppState when view appears or updates
    private var effectiveType: VibeType? {
        selectedType ?? appState.selectedVibeType
    }
    
    // Mock Data for Squad
    let squad: [Friend] = [
        Friend(name: "Sarah", imageName: "person.crop.circle.fill", hasPosted: true),
        Friend(name: "Mike", imageName: "person.crop.circle", hasPosted: false),
        Friend(name: "Jessica", imageName: "person.crop.circle.fill", hasPosted: true),
        Friend(name: "David", imageName: "person.crop.circle", hasPosted: false),
        Friend(name: "Emma", imageName: "person.crop.circle.fill", hasPosted: true)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(uiColor: .systemGroupedBackground) // Or systemBackground depending on preference, spec said "standard Materials"
                    .ignoresSafeArea()
                
                if let type = effectiveType {
                    typeComposer(for: type)
                        .onAppear {
                            // Sync locked state from AppState if we just arrived
                            if appState.composerIsLocked {
                                self.isLocked = true
                            }
                        }
                } else {
                    dashboardContent
                }
            }
            .navigationBarHidden(true) // We building a custom header
        }
    }

    private var dashboardContent: some View {
        VStack(spacing: 0) {
            // 1. HEADER
            HStack {
                Button {
                    appState.dismissComposer()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("New Vibez")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Profile settings placeholder
                Button {
                    // Action for profile
                } label: {
                    Image(systemName: "person.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 24)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // 2. ACTION GRID
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        // Row 1
                        MenuCard(
                            title: "Video",
                            icon: "video.fill",
                            gradient: [.red, .pink]
                        ) {
                            selectVibe(.video, locked: false)
                        }
                        
                        MenuCard(
                            title: "POV",
                            icon: "eye.fill",
                            gradient: [.green, .teal]
                        ) {
                            selectVibe(.video, locked: true) // POV is Video + Locked
                        }
                        
                        // Row 2
                        MenuCard(
                            title: "Battery",
                            icon: "battery.100",
                            gradient: [.yellow, .orange]
                        ) {
                            selectVibe(.battery)
                        }
                        
                        MenuCard(
                            title: "Mood",
                            icon: "face.smiling",
                            gradient: [.purple, .pink]
                        ) {
                            selectVibe(.mood)
                        }
                        
                        // Row 3 (Single Item centered logic handled by grid automatically if count is odd? No, need to be explicit or use span)
                        // Spec says "Row 3 Left: Poll", which implies a 5th item.
                        MenuCard(
                            title: "Poll",
                            icon: "chart.bar.fill",
                            gradient: [.blue, .cyan]
                        ) {
                            selectVibe(.poll)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 3. SQUAD ROW
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Squad")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(squad) { friend in
                                    SquadMemberView(friend: friend)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 100) // Space for Anchor button
            }
            
            Spacer()
        }
        .overlay(alignment: .bottom) {
            // 4. ANCHOR BUTTON
            Button {
                triggerSurpriseMe()
            } label: {
                HStack {
                    Text("Surprise Me")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                    Text("🎲")
                        .font(.title3)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(
                    LinearGradient(
                        colors: [.pink, .purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .purple.opacity(0.4), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal)
            .padding(.bottom, 0) // SafeArea ignored by container? No we need to handle safe area manually or stick to it.
        }
    }
    
    private func selectVibe(_ type: VibeType, locked: Bool = false) {
        withAnimation {
            self.selectedType = type
            self.isLocked = locked
        }
    }
    
    private func triggerSurpriseMe() {
        let options: [(VibeType, Bool)] = [
            (.video, false), // Video
            (.video, true),  // POV
            (.battery, false),
            (.mood, false),
            (.poll, false)
        ]
        
        if let random = options.randomElement() {
            selectVibe(random.0, locked: random.1)
        }
    }

    @ViewBuilder
    private func typeComposer(for type: VibeType) -> some View {
        VStack(spacing: 0) {
            // ARCADE HEADER
            HStack {
                Button {
                    withAnimation {
                        selectedType = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                        Text("Back")
                            .font(.headline)
                    }
                    .foregroundColor(.primary)
                }
                .frame(width: 80, alignment: .leading) // Fixed width for balance

                Spacer()

                Text(type.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                // Balance the header
                Color.clear
                    .frame(width: 80)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 16)
            .background(Color(uiColor: .systemGroupedBackground)) 

            // COMPOSER CONTENT
            switch type {
            case .video, .photo:
                VideoComposerView(isLocked: isLocked)
            case .song:
                SongComposerView(isLocked: isLocked)
            case .battery:
                BatteryComposerView(isLocked: isLocked)
            case .mood:
                MoodComposerView(isLocked: isLocked)
            case .poll:
                PollComposerView(isLocked: isLocked)
            }
        }
    }
}

// MARK: - Subviews

struct MenuCard: View {
    let title: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 12) {
                // Icon Circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // Label
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(colorScheme == .dark ? Color(uiColor: .systemGray6) : .white)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct SquadMemberView: View {
    let friend: Friend
    
    var body: some View {
        VStack(spacing: 8) {
            // Avatar with ring
            ZStack {
                if friend.hasPosted {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: friend.ringColors,
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 64, height: 64)
                } else {
                    Circle()
                        .strokeBorder(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .frame(width: 64, height: 64)
                }
                
                Image(systemName: friend.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 54, height: 54)
                    .clipShape(Circle())
                    .saturation(friend.hasPosted ? 1.0 : 0.0)
            }
            
            Text(friend.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    ComposerView()
        .environmentObject(AppState())
}
