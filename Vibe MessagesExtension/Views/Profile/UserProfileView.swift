//
//  UserProfileView.swift
//  Vibe MessagesExtension
//
//  User profile with stats, Aura balance, and daily bonus.
//

import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading = true
    @State private var dailyBonusClaimed = false
    @State private var claimAmount: Int?
    @State private var showClaimAnimation = false

    var body: some View {
        ZStack {
            VibeTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: VibeSpacing.sectionGap) {
                    // Header
                    headerSection

                    // Aura Balance Card
                    auraBalanceCard

                    // Daily Bonus
                    if appState.auraStats?.dailyBonusAvailable == true && !dailyBonusClaimed {
                        dailyBonusCard
                    }

                    // Stats Grid
                    statsGrid

                    // Quick Links
                    quickLinks

                    // Sign Out
                    signOutButton
                }
                .padding(.horizontal, VibeSpacing.screenHorizontal)
                .padding(.bottom, VibeSpacing.xxxl)
            }
        }
        .overlay(alignment: .topLeading) {
            backButton
        }
        .task {
            await appState.loadAuraStats()
            isLoading = false
        }
    }

    // MARK: - Back Button

    private var backButton: some View {
        Button {
            VibeHaptic.light()
            appState.navigateToFeed()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(VibeTheme.textPrimary)
                .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .padding(.leading, VibeSpacing.screenHorizontal)
        .padding(.top, VibeSpacing.sm)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: VibeSpacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(VibeTheme.brandGradient)
                    .frame(width: VibeSpacing.avatarXL, height: VibeSpacing.avatarXL)

                Text(String(appState.userFirstName?.prefix(1) ?? "?"))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .vibeShadow(.lg)

            VStack(spacing: VibeSpacing.xs) {
                Text(appState.userFirstName ?? "Vibe User")
                    .font(VibeTypography.displayMedium)
                    .foregroundColor(VibeTheme.textPrimary)

                Text("@\(appState.userId.prefix(12))")
                    .font(VibeTypography.bodyMedium)
                    .foregroundColor(VibeTheme.textSecondary)
            }
        }
        .padding(.top, VibeSpacing.xxxl + VibeSpacing.xl)
    }

    // MARK: - Aura Balance Card

    private var auraBalanceCard: some View {
        VStack(spacing: VibeSpacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                Text("AURA BALANCE")
                    .font(VibeTypography.overline)
            }
            .foregroundColor(.white.opacity(0.8))

            Text("\(appState.auraBalance)")
                .font(VibeTypography.numericLarge)
                .foregroundColor(.white)
                .contentTransition(.numericText())

            if let stats = appState.auraStats {
                HStack(spacing: VibeSpacing.xl) {
                    VStack(spacing: VibeSpacing.xxxs) {
                        Text("\(stats.lifetimeEarned)")
                            .font(VibeTypography.numericMedium)
                            .foregroundColor(.white)
                        Text("Earned")
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Rectangle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 1, height: 30)

                    VStack(spacing: VibeSpacing.xxxs) {
                        Text("\(stats.lifetimeSpent)")
                            .font(VibeTypography.numericMedium)
                            .foregroundColor(.white)
                        Text("Spent")
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(VibeSpacing.xl)
        .background(VibeTheme.auraGradient)
        .continuousCorner(VibeTheme.radiusLarge)
        .vibeShadow(.lg)
    }

    // MARK: - Daily Bonus Card

    private var dailyBonusCard: some View {
        Button {
            VibeHaptic.success()
            Task {
                let response = await appState.claimDailyBonus()
                if let response, response.claimed {
                    claimAmount = response.amount
                    withAnimation(VibeAnimation.bouncy) {
                        dailyBonusClaimed = true
                        showClaimAnimation = true
                    }
                }
            }
        } label: {
            HStack(spacing: VibeSpacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: VibeSpacing.iconCircleSmall, height: VibeSpacing.iconCircleSmall)
                    Image(systemName: "gift.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.yellow)
                        .symbolEffect(.bounce)
                }

                VStack(alignment: .leading, spacing: VibeSpacing.xxxs) {
                    Text("Daily Bonus Available!")
                        .font(VibeTypography.titleSmall)
                        .foregroundColor(VibeTheme.textPrimary)
                    Text("Tap to claim your daily Aura")
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(VibeTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(VibeTheme.textTertiary)
            }
            .padding(VibeSpacing.md)
            .vibeGlassCard(radius: VibeTheme.radiusMedium)
        }
        .buttonStyle(VibePressStyle())
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            Text("STATS")
                .vibeSectionHeader()

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: VibeSpacing.sm),
                GridItem(.flexible(), spacing: VibeSpacing.sm)
            ], spacing: VibeSpacing.sm) {
                statCard(
                    icon: "flame.fill",
                    value: "\(appState.vibes.filter { $0.userId == appState.userId }.count)",
                    label: "Vibes Posted",
                    color: .orange
                )
                statCard(
                    icon: "trophy.fill",
                    value: "\(appState.activeBets.count)",
                    label: "Active Bets",
                    color: .green
                )
                statCard(
                    icon: "star.fill",
                    value: "\(appState.vibeScore)",
                    label: "Vibe Score",
                    color: .purple
                )
                statCard(
                    icon: "cup.and.saucer.fill",
                    value: "\(appState.activeTeaSpills.count)",
                    label: "Active Tea",
                    color: .brown
                )
            }
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: VibeSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)

            Text(value)
                .font(VibeTypography.displaySmall)
                .foregroundColor(VibeTheme.textPrimary)

            Text(label)
                .font(VibeTypography.captionSmall)
                .foregroundColor(VibeTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(VibeSpacing.md)
        .vibeCard(radius: VibeTheme.radiusMedium)
    }

    // MARK: - Quick Links

    private var quickLinks: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            Text("QUICK LINKS")
                .vibeSectionHeader()

            VStack(spacing: 0) {
                quickLinkRow(icon: "sparkles", title: "Aura Hub", subtitle: "Economy & leaderboard") {
                    appState.navigateToAuraHub()
                }

                Divider().padding(.leading, VibeSpacing.iconCircleSmall + VibeSpacing.md)

                quickLinkRow(icon: "dice.fill", title: "My Bets", subtitle: "View all bets") {
                    appState.navigateToBetList()
                }
            }
            .vibeCard(radius: VibeTheme.radiusMedium)
        }
    }

    private func quickLinkRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button {
            VibeHaptic.light()
            action()
        } label: {
            HStack(spacing: VibeSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(VibeTheme.accent)
                    .frame(width: VibeSpacing.iconCircleSmall, height: VibeSpacing.iconCircleSmall)
                    .background(VibeTheme.accent.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: VibeSpacing.xxxs) {
                    Text(title)
                        .font(VibeTypography.titleSmall)
                        .foregroundColor(VibeTheme.textPrimary)
                    Text(subtitle)
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(VibeTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(VibeTheme.textTertiary)
            }
            .padding(VibeSpacing.md)
        }
        .buttonStyle(VibePressStyle())
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button {
            VibeHaptic.warning()
            UserDefaults.standard.removeObject(forKey: "vibeUserId")
            UserDefaults.standard.removeObject(forKey: "vibeAuthToken")
            UserDefaults.standard.removeObject(forKey: "vibeUserFirstName")
            appState.isAuthenticated = false
            appState.userId = "anonymous"
            appState.userFirstName = nil
            appState.navigateToFeed()
        } label: {
            Text("Sign Out")
                .font(VibeTypography.titleSmall)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .frame(height: VibeSpacing.minTouchTarget)
                .background(Color.red.opacity(0.1))
                .continuousCorner(VibeTheme.radiusMedium)
        }
        .buttonStyle(VibePressStyle())
    }
}
