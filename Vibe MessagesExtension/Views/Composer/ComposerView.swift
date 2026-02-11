//
//  ComposerView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI

struct ComposerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedType: VibeType?
    @State private var isLocked = false

    private var effectiveType: VibeType? {
        selectedType ?? appState.selectedVibeType
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VibeTheme.groupedBackground
                    .ignoresSafeArea()

                if let type = effectiveType {
                    typeComposer(for: type)
                        .onAppear {
                            if appState.composerIsLocked {
                                self.isLocked = true
                            }
                        }
                } else {
                    dashboardContent
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            appState.requestExpand()
        }
    }

    // MARK: - Dashboard Content

    private var dashboardContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    VibeHaptic.light()
                    appState.dismissComposer()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(VibeTheme.textSecondary)
                        .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Spacer()

                VStack(spacing: VibeSpacing.xxxs) {
                    Text("New Vibe")
                        .font(VibeTypography.titleLarge)
                        .foregroundColor(VibeTheme.textPrimary)
                    Text("choose your vibe type")
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(VibeTheme.textSecondary)
                }

                Spacer()

                // Aura balance indicator
                if appState.auraBalance > 0 {
                    HStack(spacing: VibeSpacing.xxs) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                        Text("\(appState.auraBalance)")
                            .font(VibeTypography.captionLarge)
                            .foregroundColor(VibeTheme.textPrimary)
                    }
                    .padding(.horizontal, VibeSpacing.sm)
                    .padding(.vertical, VibeSpacing.xs)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                } else {
                    Color.clear.frame(width: VibeSpacing.minTouchTarget)
                }
            }
            .padding(.horizontal, VibeSpacing.screenHorizontal)
            .padding(.top, VibeSpacing.md)
            .padding(.bottom, VibeSpacing.lg)

            ScrollView(showsIndicators: false) {
                VStack(spacing: VibeSpacing.sectionGap) {

                    // MARK: Create Section
                    VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                        Text("CREATE")
                            .vibeSectionHeader()
                            .padding(.horizontal, VibeSpacing.screenHorizontal)

                        HStack(spacing: VibeSpacing.sm) {
                            MenuCard(
                                title: "Video",
                                icon: "video.fill",
                                gradient: [.red, .pink],
                                size: .large
                            ) {
                                selectVibe(.video, locked: false)
                            }

                            MenuCard(
                                title: "Photo",
                                icon: "camera.fill",
                                gradient: [.orange, .yellow],
                                size: .large
                            ) {
                                selectVibe(.photo, locked: false)
                            }

                            MenuCard(
                                title: "POV",
                                icon: "eye.fill",
                                gradient: [.green, .teal],
                                size: .large
                            ) {
                                selectVibe(.video, locked: true)
                            }
                        }
                        .padding(.horizontal, VibeSpacing.screenHorizontal)
                    }

                    // MARK: Express Section
                    VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                        Text("EXPRESS")
                            .vibeSectionHeader()
                            .padding(.horizontal, VibeSpacing.screenHorizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: VibeSpacing.lg) {
                                ExpressItem(icon: "battery.100", label: "Battery", color: .yellow) {
                                    selectVibe(.battery)
                                }
                                ExpressItem(icon: "face.smiling", label: "Mood", color: .purple) {
                                    selectVibe(.mood)
                                }
                                ExpressItem(icon: "music.note", label: "Song", color: .green) {
                                    selectVibe(.song)
                                }
                                ExpressItem(icon: "hand.draw.fill", label: "Sketch", color: .orange) {
                                    selectVibe(.sketch)
                                }
                            }
                            .padding(.horizontal, VibeSpacing.screenHorizontal)
                        }
                    }

                    // MARK: Social Section
                    VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                        Text("SOCIAL")
                            .vibeSectionHeader()
                            .padding(.horizontal, VibeSpacing.screenHorizontal)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: VibeSpacing.sm),
                            GridItem(.flexible(), spacing: VibeSpacing.sm)
                        ], spacing: VibeSpacing.sm) {
                            CompactMenuCard(title: "Poll", icon: "chart.bar.fill", color: .blue) {
                                selectVibe(.poll)
                            }
                            CompactMenuCard(title: "Tea", icon: "cup.and.saucer.fill", color: .brown) {
                                selectVibe(.tea)
                            }
                            CompactMenuCard(title: "Parlay", icon: "dollarsign.circle.fill", color: VibeTheme.accent) {
                                selectVibe(.parlay)
                            }
                            CompactMenuCard(title: "Leak", icon: "eye.slash.fill", color: .red) {
                                selectVibe(.leak)
                            }
                            CompactMenuCard(title: "ETA", icon: "location.fill", color: .blue) {
                                selectVibe(.eta)
                            }
                            CompactMenuCard(title: "Daily Drop", icon: "die.face.5.fill", color: .pink) {
                                selectVibe(.dailyDrop)
                            }
                        }
                        .padding(.horizontal, VibeSpacing.screenHorizontal)
                    }

                    // MARK: Squad Section
                    VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                        Text("SQUAD")
                            .vibeSectionHeader()
                            .padding(.horizontal, VibeSpacing.screenHorizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: VibeSpacing.md) {
                                let groupedVibes = appState.vibesGroupedByUser(nil, includeMe: false, includeTeam: true)
                                if groupedVibes.isEmpty {
                                    Text("No squad members active yet")
                                        .font(VibeTypography.bodySmall)
                                        .foregroundColor(VibeTheme.textTertiary)
                                        .padding(.horizontal, VibeSpacing.md)
                                } else {
                                    ForEach(groupedVibes, id: \.first?.userId) { userVibes in
                                        if let firstVibe = userVibes.first {
                                            SquadMemberView(
                                                name: appState.nameForUser(firstVibe.userId),
                                                hasPosted: true,
                                                vibeType: firstVibe.type
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, VibeSpacing.screenHorizontal)
                        }
                    }
                }
                .padding(.bottom, 100)
            }

            Spacer()
        }
        .overlay(alignment: .bottom) {
            // Surprise Me FAB
            Button {
                triggerSurpriseMe()
            } label: {
                HStack(spacing: VibeSpacing.xs) {
                    Image(systemName: "dice.fill")
                        .font(.system(size: 20))
                    Text("Surprise Me")
                        .font(VibeTypography.titleSmall)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(VibeTheme.brandGradient)
                .continuousCorner(VibeTheme.radiusLarge)
                .vibeShadow(.lg)
            }
            .buttonStyle(VibePressStyle())
            .padding(.horizontal, VibeSpacing.screenHorizontal)
            .padding(.bottom, VibeSpacing.xs)
        }
    }

    // MARK: - Actions

    private func selectVibe(_ type: VibeType, locked: Bool = false) {
        VibeHaptic.selection()
        withAnimation(VibeAnimation.snappy) {
            self.selectedType = type
            self.isLocked = locked
        }
    }

    private func triggerSurpriseMe() {
        VibeHaptic.heavy()
        let options: [(VibeType, Bool)] = [
            (.video, false), (.video, true), (.battery, false),
            (.mood, false), (.poll, false), (.tea, false),
            (.leak, false), (.sketch, false), (.eta, false)
        ]
        if let random = options.randomElement() {
            selectVibe(random.0, locked: random.1)
        }
    }

    // MARK: - Type Composer Router

    @ViewBuilder
    private func typeComposer(for type: VibeType) -> some View {
        VStack(spacing: 0) {
            if type != .video && type != .photo {
                HStack {
                    Button {
                        VibeHaptic.light()
                        withAnimation(VibeAnimation.snappy) {
                            if selectedType == nil && appState.selectedVibeType != nil {
                                appState.dismissComposer()
                            } else {
                                selectedType = nil
                                appState.selectedVibeType = nil
                            }
                        }
                    } label: {
                        HStack(spacing: VibeSpacing.xxs) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                            Text("Back")
                                .font(VibeTypography.titleSmall)
                        }
                        .foregroundColor(VibeTheme.textPrimary)
                    }
                    .frame(width: 80, alignment: .leading)

                    Spacer()

                    Text(type.displayName)
                        .font(VibeTypography.titleMedium)
                        .foregroundColor(VibeTheme.textPrimary)

                    Spacer()

                    Color.clear.frame(width: 80)
                }
                .padding(.horizontal, VibeSpacing.screenHorizontal)
                .padding(.top, VibeSpacing.md)
                .padding(.bottom, VibeSpacing.md)
                .background(VibeTheme.groupedBackground)
            }

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
            case .dailyDrop:
                DailyDropComposerView(isLocked: isLocked)
            case .tea:
                TeaComposerView(isLocked: isLocked)
            case .leak:
                LeakComposerView(isLocked: isLocked)
            case .sketch:
                SketchComposerView(isLocked: isLocked)
            case .eta:
                ETAComposerView(isLocked: isLocked)
            case .parlay:
                ParlayComposerView(isLocked: isLocked)
            }
        }
    }
}

// MARK: - Menu Card (Large)

struct MenuCard: View {
    let title: String
    let icon: String
    let gradient: [Color]
    var size: CardSize = .standard
    let action: () -> Void

    enum CardSize {
        case standard, large
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: VibeSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size == .large ? VibeSpacing.iconCircleLarge : VibeSpacing.iconCircleMedium,
                               height: size == .large ? VibeSpacing.iconCircleLarge : VibeSpacing.iconCircleMedium)
                        .shadow(color: gradient.first?.opacity(0.3) ?? .clear, radius: 8, y: 4)

                    Image(systemName: icon)
                        .font(.system(size: size == .large ? 28 : 22, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(title)
                    .font(VibeTypography.captionLarge)
                    .foregroundColor(VibeTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, VibeSpacing.lg)
            .background(.ultraThinMaterial)
            .continuousCorner(VibeTheme.radiusLarge)
        }
        .buttonStyle(VibePressStyle())
    }
}

// MARK: - Express Item (Circular)

struct ExpressItem: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: VibeSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: VibeSpacing.iconCircleLarge, height: VibeSpacing.iconCircleLarge)

                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(color)
                }

                Text(label)
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(VibeTheme.textSecondary)
            }
        }
        .buttonStyle(VibePressStyle())
    }
}

// MARK: - Compact Menu Card (Social Grid)

struct CompactMenuCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VibeSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)

                Text(title)
                    .font(VibeTypography.titleSmall)
                    .foregroundColor(VibeTheme.textPrimary)

                Spacer()
            }
            .padding(.horizontal, VibeSpacing.md)
            .padding(.vertical, VibeSpacing.sm)
            .background(.ultraThinMaterial)
            .continuousCorner(VibeTheme.radiusMedium)
        }
        .buttonStyle(VibePressStyle())
    }
}

// MARK: - Squad Member

struct SquadMemberView: View {
    let name: String
    let hasPosted: Bool
    var vibeType: VibeType = .video

    var body: some View {
        VStack(spacing: VibeSpacing.xs) {
            ZStack {
                if hasPosted {
                    Circle()
                        .strokeBorder(
                            VibeTheme.brandGradient,
                            lineWidth: 3
                        )
                        .frame(width: 64, height: 64)
                } else {
                    Circle()
                        .strokeBorder(VibeTheme.divider, style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .frame(width: 64, height: 64)
                }

                Circle()
                    .fill(vibeType.color.opacity(0.15))
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: vibeType.icon)
                            .font(.system(size: 20))
                            .foregroundColor(vibeType.color)
                    )
            }

            Text(name)
                .font(VibeTypography.captionSmall)
                .foregroundColor(VibeTheme.textSecondary)
        }
    }
}

#Preview {
    ComposerView()
        .environmentObject(AppState())
}
