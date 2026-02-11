//
//  AuraHubView.swift
//  Vibe MessagesExtension
//
//  Full Aura economy hub: balance, daily bonus, transactions, leaderboard.
//

import SwiftUI

struct AuraHubView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: AuraTab = .transactions
    @State private var isLoading = true
    @State private var dailyBonusClaimed = false
    @State private var claimAmount: Int?

    enum AuraTab: String, CaseIterable {
        case transactions = "History"
        case leaderboard = "Leaderboard"
    }

    var body: some View {
        ZStack {
            VibeTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: VibeSpacing.sectionGap) {
                    // Balance Header
                    balanceHeader

                    // Daily Bonus
                    if appState.auraStats?.dailyBonusAvailable == true && !dailyBonusClaimed {
                        dailyBonusSection
                    }

                    // Tab Picker
                    tabPicker

                    // Content
                    switch selectedTab {
                    case .transactions:
                        transactionsList
                    case .leaderboard:
                        leaderboardList
                    }
                }
                .padding(.bottom, VibeSpacing.xxxl)
            }
        }
        .overlay(alignment: .topLeading) {
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
        .task {
            async let statsTask: () = appState.loadAuraStats()
            async let transactionsTask: () = appState.loadAuraTransactions()
            async let leaderboardTask: () = appState.loadLeaderboard()
            _ = await (statsTask, transactionsTask, leaderboardTask)
            isLoading = false
        }
    }

    // MARK: - Balance Header

    private var balanceHeader: some View {
        VStack(spacing: VibeSpacing.sm) {
            Text("AURA")
                .font(VibeTypography.overline)
                .foregroundColor(.white.opacity(0.7))
                .tracking(2)

            Text("\(appState.auraBalance)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText())

            HStack(spacing: VibeSpacing.xxl) {
                if let stats = appState.auraStats {
                    HStack(spacing: VibeSpacing.xs) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                        Text("\(stats.lifetimeEarned)")
                            .font(VibeTypography.titleSmall)
                            .foregroundColor(.white)
                    }

                    HStack(spacing: VibeSpacing.xs) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.red.opacity(0.8))
                        Text("\(stats.lifetimeSpent)")
                            .font(VibeTypography.titleSmall)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VibeSpacing.xxxl)
        .padding(.top, VibeSpacing.xxxl)
        .background(VibeTheme.auraGradient)
    }

    // MARK: - Daily Bonus

    private var dailyBonusSection: some View {
        Button {
            VibeHaptic.success()
            Task {
                let response = await appState.claimDailyBonus()
                if let response, response.claimed {
                    claimAmount = response.amount
                    withAnimation(VibeAnimation.bouncy) {
                        dailyBonusClaimed = true
                    }
                }
            }
        } label: {
            HStack(spacing: VibeSpacing.md) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.yellow)
                    .symbolEffect(.bounce)

                VStack(alignment: .leading, spacing: VibeSpacing.xxxs) {
                    Text("Daily Bonus")
                        .font(VibeTypography.titleMedium)
                        .foregroundColor(VibeTheme.textPrimary)
                    Text("Claim your daily Aura reward")
                        .font(VibeTypography.bodySmall)
                        .foregroundColor(VibeTheme.textSecondary)
                }

                Spacer()

                Text("Claim")
                    .font(VibeTypography.titleSmall)
                    .foregroundColor(.white)
                    .padding(.horizontal, VibeSpacing.md)
                    .padding(.vertical, VibeSpacing.xs)
                    .background(VibeTheme.auraGradient)
                    .continuousCorner(VibeTheme.radiusMedium)
            }
            .padding(VibeSpacing.md)
            .vibeCard(radius: VibeTheme.radiusMedium)
        }
        .buttonStyle(VibePressStyle())
        .padding(.horizontal, VibeSpacing.screenHorizontal)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(AuraTab.allCases, id: \.rawValue) { tab in
                Button {
                    VibeHaptic.selection()
                    withAnimation(VibeAnimation.snappy) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(VibeTypography.titleSmall)
                        .foregroundColor(selectedTab == tab ? VibeTheme.textPrimary : VibeTheme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VibeSpacing.sm)
                        .background(selectedTab == tab ? VibeTheme.cardBackground : .clear)
                        .continuousCorner(VibeTheme.radiusSmall)
                }
            }
        }
        .padding(VibeSpacing.xxs)
        .background(VibeTheme.surfaceOverlay)
        .continuousCorner(VibeTheme.radiusMedium)
        .padding(.horizontal, VibeSpacing.screenHorizontal)
    }

    // MARK: - Transactions List

    private var transactionsList: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            Text("TRANSACTION HISTORY")
                .vibeSectionHeader()
                .padding(.horizontal, VibeSpacing.screenHorizontal)

            if appState.auraTransactions.isEmpty {
                emptyState(icon: "clock.arrow.circlepath", message: "No transactions yet")
            } else {
                VStack(spacing: 0) {
                    ForEach(appState.auraTransactions) { transaction in
                        transactionRow(transaction)

                        if transaction.id != appState.auraTransactions.last?.id {
                            Divider()
                                .padding(.leading, VibeSpacing.iconCircleSmall + VibeSpacing.md + VibeSpacing.md)
                        }
                    }
                }
                .vibeCard(radius: VibeTheme.radiusMedium)
                .padding(.horizontal, VibeSpacing.screenHorizontal)
            }
        }
    }

    private func transactionRow(_ transaction: AuraTransaction) -> some View {
        HStack(spacing: VibeSpacing.md) {
            Image(systemName: transaction.amount >= 0 ? "plus.circle.fill" : "minus.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(transaction.amount >= 0 ? .green : .red)

            VStack(alignment: .leading, spacing: VibeSpacing.xxxs) {
                Text(transaction.type.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(VibeTypography.titleSmall)
                    .foregroundColor(VibeTheme.textPrimary)
                Text(transaction.createdAt, style: .relative)
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(VibeTheme.textTertiary)
            }

            Spacer()

            Text(transaction.amount >= 0 ? "+\(transaction.amount)" : "\(transaction.amount)")
                .font(VibeTypography.numericMedium)
                .foregroundColor(transaction.amount >= 0 ? .green : .red)
        }
        .padding(VibeSpacing.md)
    }

    // MARK: - Leaderboard

    private var leaderboardList: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            Text("TOP PLAYERS")
                .vibeSectionHeader()
                .padding(.horizontal, VibeSpacing.screenHorizontal)

            if appState.leaderboard.isEmpty {
                emptyState(icon: "trophy", message: "No leaderboard data")
            } else {
                VStack(spacing: VibeSpacing.xs) {
                    ForEach(appState.leaderboard) { entry in
                        leaderboardRow(entry)
                    }
                }
                .padding(.horizontal, VibeSpacing.screenHorizontal)
            }
        }
    }

    private func leaderboardRow(_ entry: LeaderboardEntry) -> some View {
        HStack(spacing: VibeSpacing.md) {
            // Rank
            ZStack {
                Circle()
                    .fill(rankColor(entry.rank).opacity(0.15))
                    .frame(width: VibeSpacing.avatarSmall, height: VibeSpacing.avatarSmall)

                if entry.rank <= 3 {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                        .foregroundColor(rankColor(entry.rank))
                } else {
                    Text("\(entry.rank)")
                        .font(VibeTypography.titleSmall)
                        .foregroundColor(VibeTheme.textSecondary)
                }
            }

            // Name
            VStack(alignment: .leading, spacing: VibeSpacing.xxxs) {
                Text(entry.name)
                    .font(VibeTypography.titleSmall)
                    .foregroundColor(VibeTheme.textPrimary)

                HStack(spacing: VibeSpacing.xs) {
                    Text("Win: \(entry.winRate)%")
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(.green)
                    Text("Duck: \(entry.duckRate)%")
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // Aura
            HStack(spacing: VibeSpacing.xxs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                Text("\(entry.auraBalance)")
                    .font(VibeTypography.numericMedium)
            }
            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
        }
        .padding(VibeSpacing.md)
        .vibeCard(radius: VibeTheme.radiusMedium)
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.78) // Silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20) // Bronze
        default: return VibeTheme.textTertiary
        }
    }

    // MARK: - Empty State

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: VibeSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(VibeTheme.textTertiary)
            Text(message)
                .font(VibeTypography.bodyMedium)
                .foregroundColor(VibeTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VibeSpacing.xxxl)
    }
}
