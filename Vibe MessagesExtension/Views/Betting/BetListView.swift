//
//  BetListView.swift
//  Vibe MessagesExtension
//
//  All bets with filter tabs.
//

import SwiftUI

struct BetListView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedFilter: BetStatus = .active
    @State private var allBets: [Bet] = []
    @State private var isLoading = true

    private var filteredBets: [Bet] {
        allBets.filter { displayStatus(for: $0) == selectedFilter }
    }

    var body: some View {
        ZStack {
            VibeTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        VibeHaptic.light()
                        appState.navigateToFeed()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(VibeTheme.textPrimary)
                            .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                    }

                    Spacer()

                    Text("My Bets")
                        .font(VibeTypography.titleLarge)
                        .foregroundColor(VibeTheme.textPrimary)

                    Spacer()

                    Color.clear.frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                }
                .padding(.horizontal, VibeSpacing.screenHorizontal)

                // Filter Tabs
                filterTabs
                    .padding(.top, VibeSpacing.sm)

                // Content
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(VibeTheme.accent)
                    Spacer()
                } else if filteredBets.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: VibeSpacing.sm) {
                            ForEach(filteredBets) { bet in
                                betRow(bet)
                            }
                        }
                        .padding(.horizontal, VibeSpacing.screenHorizontal)
                        .padding(.top, VibeSpacing.md)
                        .padding(.bottom, VibeSpacing.xxxl)
                    }
                }
            }
        }
        .task {
            await loadAllBets()
        }
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VibeSpacing.xs) {
                ForEach([BetStatus.active, .pendingResolution, .completed, .expired, .ducked], id: \.rawValue) { status in
                    Button {
                        VibeHaptic.selection()
                        withAnimation(VibeAnimation.snappy) {
                            selectedFilter = status
                        }
                    } label: {
                        Text(statusLabel(status))
                            .font(VibeTypography.captionLarge)
                            .foregroundColor(selectedFilter == status ? .white : VibeTheme.textSecondary)
                            .padding(.horizontal, VibeSpacing.md)
                            .padding(.vertical, VibeSpacing.xs)
                            .background(selectedFilter == status ? statusColor(status) : VibeTheme.surfaceOverlay)
                            .continuousCorner(VibeTheme.radiusMedium)
                    }
                }
            }
            .padding(.horizontal, VibeSpacing.screenHorizontal)
        }
    }

    // MARK: - Bet Row

    private func betRow(_ bet: Bet) -> some View {
        let displayStatus = displayStatus(for: bet)
        return Button {
            VibeHaptic.light()
            appState.navigateToBetDetail(bet: bet)
        } label: {
            HStack(spacing: VibeSpacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(statusColor(displayStatus).opacity(0.15))
                        .frame(width: VibeSpacing.iconCircleSmall, height: VibeSpacing.iconCircleSmall)

                    Image(systemName: "dice.fill")
                        .font(.system(size: 18))
                        .foregroundColor(statusColor(displayStatus))
                }

                // Info
                VStack(alignment: .leading, spacing: VibeSpacing.xxxs) {
                    Text(bet.description)
                        .font(VibeTypography.titleSmall)
                        .foregroundColor(VibeTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: VibeSpacing.xs) {
                        Text(bet.betType.rawValue.capitalized)
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(VibeTheme.textTertiary)

                        if displayStatus == .pendingResolution {
                            Text("•")
                                .font(VibeTypography.captionSmall)
                                .foregroundColor(VibeTheme.textTertiary)
                            Text(pendingDetailLabel(for: bet))
                                .font(VibeTypography.captionSmall)
                                .foregroundColor(.purple)
                        }

                        if !bet.isExpired && bet.status == .active {
                            Text(bet.timeRemainingFormatted)
                                .font(VibeTypography.captionSmall)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(VibeTheme.textTertiary)
            }
            .padding(VibeSpacing.md)
            .vibeCard(radius: VibeTheme.radiusMedium)
        }
        .buttonStyle(VibePressStyle())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: VibeSpacing.md) {
            Image(systemName: "dice")
                .font(.system(size: 40))
                .foregroundColor(VibeTheme.textTertiary)

            Text("No \(statusLabel(selectedFilter).lowercased()) bets")
                .font(VibeTypography.titleMedium)
                .foregroundColor(VibeTheme.textSecondary)

            Text("Bets you create or join will appear here")
                .font(VibeTypography.bodySmall)
                .foregroundColor(VibeTheme.textTertiary)
        }
    }

    // MARK: - Helpers

    private func statusColor(_ status: BetStatus) -> Color {
        switch status {
        case .active: return .green
        case .pendingResolution: return .purple
        case .completed: return .blue
        case .expired: return .orange
        case .ducked: return .gray
        }
    }

    private func statusLabel(_ status: BetStatus) -> String {
        switch status {
        case .active: return "Active"
        case .pendingResolution: return "Pending / Resolving"
        case .completed: return "Completed"
        case .expired: return "Expired"
        case .ducked: return "Ducked"
        }
    }

    private func pendingDetailLabel(for bet: Bet) -> String {
        switch bet.lifecycleStatus {
        case .pending:
            return "Awaiting quorum"
        case .resolving:
            return "Resolving"
        default:
            return "Pending"
        }
    }

    private func displayStatus(for bet: Bet) -> BetStatus {
        if bet.status == .active && bet.isExpired {
            return .expired
        }
        return bet.status
    }

    private func loadAllBets() async {
        guard let chatId = appState.currentChatId else {
            isLoading = false
            return
        }
        do {
            let response = try await BettingService.shared.getBetsForChat(chatId: chatId)
            self.allBets = response.bets
        } catch {
            print("BetListView Error: \(error)")
        }
        isLoading = false
    }
}
