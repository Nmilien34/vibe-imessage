//
//  BetDetailView.swift
//  Vibe MessagesExtension
//
//  Single bet detail with staking, participants, proofs, and resolution.
//

import SwiftUI

struct BetDetailView: View {
    @EnvironmentObject var appState: AppState
    let bet: Bet

    @State private var participants: [BetParticipant] = []
    @State private var totals: BetTotals?
    @State private var userStake: UserStake?
    @State private var proofs: [BetProof] = []
    @State private var isLoading = true

    @State private var selectedSide: BetSide = .yes
    @State private var stakeAmount: Int = 10
    @State private var isStaking = false
    @State private var showStakeSheet = false
    @State private var stakeError: String?

    @State private var isResolving = false

    private var stakeSliderRange: ClosedRange<Double> {
        let lower = 5.0
        // Slider with step=5 needs at least 5 points of span.
        let upper = max(lower + 5.0, Double(min(100, max(5, appState.auraBalance))))
        return lower...upper
    }

    private var stakeSliderBinding: Binding<Double> {
        Binding(
            get: {
                min(max(Double(stakeAmount), stakeSliderRange.lowerBound), stakeSliderRange.upperBound)
            },
            set: { newValue in
                let clamped = min(max(newValue, stakeSliderRange.lowerBound), stakeSliderRange.upperBound)
                stakeAmount = Int(clamped)
            }
        )
    }

    var body: some View {
        ZStack {
            VibeTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: VibeSpacing.sectionGap) {
                    // Header
                    betHeader

                    // Pot Visualization
                    if let totals {
                        potVisualization(totals)
                    }

                    // Action Section
                    if bet.status == .active {
                        actionSection
                    }

                    // Participants
                    participantsList

                    // Proofs
                    if !proofs.isEmpty {
                        proofsSection
                    }

                    // Resolution (for creator)
                    if bet.status == .active && bet.creatorId == appState.userId {
                        resolutionSection
                    }
                }
                .padding(.horizontal, VibeSpacing.screenHorizontal)
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
            await loadBetDetails()
        }
    }

    // MARK: - Header

    private var betHeader: some View {
        VStack(spacing: VibeSpacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: VibeSpacing.iconCircleLarge, height: VibeSpacing.iconCircleLarge)

                Image(systemName: bet.status == .active ? "dice.fill" : statusIcon)
                    .font(.system(size: 36))
                    .foregroundColor(statusColor)
            }
            .padding(.top, VibeSpacing.xxxl)

            // Description
            Text(bet.description)
                .font(VibeTypography.titleLarge)
                .foregroundColor(VibeTheme.textPrimary)
                .multilineTextAlignment(.center)

            // Meta
            HStack(spacing: VibeSpacing.lg) {
                // Status
                Text(bet.status.rawValue.uppercased())
                    .font(VibeTypography.overline)
                    .foregroundColor(.white)
                    .padding(.horizontal, VibeSpacing.sm)
                    .padding(.vertical, VibeSpacing.xxxs)
                    .background(statusColor.opacity(0.8))
                    .continuousCorner(6)

                // Type
                Text(bet.betType.rawValue.uppercased())
                    .font(VibeTypography.overline)
                    .foregroundColor(VibeTheme.textSecondary)
                    .padding(.horizontal, VibeSpacing.sm)
                    .padding(.vertical, VibeSpacing.xxxs)
                    .background(VibeTheme.surfaceOverlay)
                    .continuousCorner(6)
            }

            // Deadline
            HStack(spacing: VibeSpacing.xs) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                if bet.isExpired {
                    Text("Expired")
                        .font(VibeTypography.captionSmall)
                } else {
                    Text("Ends \(bet.deadline, style: .relative)")
                        .font(VibeTypography.captionSmall)
                }
            }
            .foregroundColor(bet.isExpired ? .red : VibeTheme.textTertiary)

            // Creator
            Text("Created by \(appState.nameForUser(bet.creatorId))")
                .font(VibeTypography.bodySmall)
                .foregroundColor(VibeTheme.textSecondary)
        }
    }

    // MARK: - Pot Visualization

    private func potVisualization(_ totals: BetTotals) -> some View {
        VStack(spacing: VibeSpacing.md) {
            Text("POT")
                .vibeSectionHeader()

            // Total pot
            HStack(spacing: VibeSpacing.xs) {
                Image(systemName: "sparkles")
                Text("\(totals.totalPot)")
                    .contentTransition(.numericText())
            }
            .font(VibeTypography.displayMedium)
            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))

            // Yes vs No bar
            GeometryReader { geo in
                let yesWidth = totals.totalPot > 0
                    ? CGFloat(totals.totalYes) / CGFloat(totals.totalPot) * geo.size.width
                    : geo.size.width / 2

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: max(yesWidth, 2))

                    Rectangle()
                        .fill(Color.red)
                        .frame(width: max(geo.size.width - yesWidth, 2))
                }
                .continuousCorner(4)
            }
            .frame(height: 12)

            // Labels
            HStack {
                VStack(alignment: .leading, spacing: VibeSpacing.xxxs) {
                    Text("YES (\(totals.yesCount))")
                        .font(VibeTypography.overline)
                        .foregroundColor(.green)
                    Text("\(totals.totalYes) Aura")
                        .font(VibeTypography.titleSmall)
                        .foregroundColor(VibeTheme.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: VibeSpacing.xxxs) {
                    Text("NO (\(totals.noCount))")
                        .font(VibeTypography.overline)
                        .foregroundColor(.red)
                    Text("\(totals.totalNo) Aura")
                        .font(VibeTypography.titleSmall)
                        .foregroundColor(VibeTheme.textPrimary)
                }
            }
        }
        .padding(VibeSpacing.lg)
        .vibeCard(radius: VibeTheme.radiusMedium)
    }

    // MARK: - Action Section

    private var actionSection: some View {
        VStack(spacing: VibeSpacing.md) {
            if let userStake {
                // Already staked
                HStack(spacing: VibeSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("You staked \(userStake.amount) Aura on \(userStake.side.rawValue.uppercased())")
                        .font(VibeTypography.titleSmall)
                        .foregroundColor(VibeTheme.textPrimary)
                }
                .padding(VibeSpacing.md)
                .frame(maxWidth: .infinity)
                .vibeCard(radius: VibeTheme.radiusMedium)
            } else {
                // Stake UI
                VStack(spacing: VibeSpacing.md) {
                    Text("PLACE YOUR STAKE")
                        .vibeSectionHeader()

                    // Side picker
                    HStack(spacing: VibeSpacing.sm) {
                        sideButton(.yes)
                        sideButton(.no)
                    }

                    // Amount
                    VStack(spacing: VibeSpacing.xs) {
                        Text("\(stakeAmount) Aura")
                            .font(VibeTypography.numericMedium)
                            .foregroundColor(VibeTheme.textPrimary)
                            .contentTransition(.numericText())

                        Slider(value: stakeSliderBinding, in: stakeSliderRange, step: 5)
                        .tint(selectedSide == .yes ? .green : .red)

                        Text("Balance: \(appState.auraBalance)")
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(VibeTheme.textTertiary)
                    }

                    // Stake button
                    Button {
                        VibeHaptic.medium()
                        Task { await placeStake() }
                    } label: {
                        HStack {
                            if isStaking {
                                ProgressView().tint(.white)
                            }
                            Text(isStaking ? "Staking..." : "Stake \(stakeAmount) Aura")
                        }
                        .vibeButton(.primary)
                    }
                    .buttonStyle(VibePressStyle())
                    .disabled(isStaking || appState.auraBalance < stakeAmount)

                    if let stakeError {
                        Text(stakeError)
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(.red)
                    }
                }
                .padding(VibeSpacing.lg)
                .vibeCard(radius: VibeTheme.radiusMedium)
            }
        }
    }

    private func sideButton(_ side: BetSide) -> some View {
        Button {
            VibeHaptic.selection()
            withAnimation(VibeAnimation.snappy) {
                selectedSide = side
            }
        } label: {
            Text(side.rawValue.uppercased())
                .font(VibeTypography.titleMedium)
                .foregroundColor(selectedSide == side ? .white : (side == .yes ? .green : .red))
                .frame(maxWidth: .infinity)
                .padding(.vertical, VibeSpacing.sm)
                .background(selectedSide == side ? (side == .yes ? Color.green : Color.red) : .clear)
                .continuousCorner(VibeTheme.radiusSmall)
                .overlay(
                    RoundedRectangle(cornerRadius: VibeTheme.radiusSmall, style: .continuous)
                        .stroke(side == .yes ? Color.green : Color.red, lineWidth: 1.5)
                )
        }
        .buttonStyle(VibePressStyle())
    }

    // MARK: - Participants

    private var participantsList: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            Text("PARTICIPANTS")
                .vibeSectionHeader()

            if participants.isEmpty {
                Text("No stakes yet")
                    .font(VibeTypography.bodyMedium)
                    .foregroundColor(VibeTheme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VibeSpacing.xl)
            } else {
                VStack(spacing: 0) {
                    ForEach(participants) { participant in
                        HStack(spacing: VibeSpacing.md) {
                            Circle()
                                .fill(participant.side == .yes ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                .frame(width: VibeSpacing.avatarSmall, height: VibeSpacing.avatarSmall)
                                .overlay(
                                    Text(String(appState.nameForUser(participant.userId).prefix(1)))
                                        .font(VibeTypography.titleSmall)
                                        .foregroundColor(participant.side == .yes ? .green : .red)
                                )

                            VStack(alignment: .leading, spacing: VibeSpacing.xxxs) {
                                Text(appState.nameForUser(participant.userId))
                                    .font(VibeTypography.titleSmall)
                                    .foregroundColor(VibeTheme.textPrimary)
                                Text(participant.side.rawValue.uppercased())
                                    .font(VibeTypography.overline)
                                    .foregroundColor(participant.side == .yes ? .green : .red)
                            }

                            Spacer()

                            Text("\(participant.amount)")
                                .font(VibeTypography.numericMedium)
                                .foregroundColor(VibeTheme.textPrimary)
                        }
                        .padding(VibeSpacing.md)

                        if participant.id != participants.last?.id {
                            Divider()
                                .padding(.leading, VibeSpacing.avatarSmall + VibeSpacing.md + VibeSpacing.md)
                        }
                    }
                }
                .vibeCard(radius: VibeTheme.radiusMedium)
            }
        }
    }

    // MARK: - Proofs

    private var proofsSection: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            Text("PROOF")
                .vibeSectionHeader()

            ForEach(proofs) { proof in
                HStack(spacing: VibeSpacing.md) {
                    Image(systemName: proof.mediaType == .photo ? "photo.fill" : "video.fill")
                        .font(.system(size: 20))
                        .foregroundColor(VibeTheme.accent)

                    VStack(alignment: .leading, spacing: VibeSpacing.xxxs) {
                        Text(appState.nameForUser(proof.userId))
                            .font(VibeTypography.titleSmall)
                            .foregroundColor(VibeTheme.textPrimary)
                        if let caption = proof.caption {
                            Text(caption)
                                .font(VibeTypography.bodySmall)
                                .foregroundColor(VibeTheme.textSecondary)
                        }
                    }

                    Spacer()

                    Text(proof.createdAt, style: .relative)
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(VibeTheme.textTertiary)
                }
                .padding(VibeSpacing.md)
                .vibeCard(radius: VibeTheme.radiusMedium)
            }
        }
    }

    // MARK: - Resolution

    private var resolutionSection: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            Text("RESOLVE BET")
                .vibeSectionHeader()

            HStack(spacing: VibeSpacing.sm) {
                resolveButton(outcome: .yes, label: "YES Won", color: .green)
                resolveButton(outcome: .no, label: "NO Won", color: .red)
            }

            Button {
                VibeHaptic.warning()
                Task { await resolve(outcome: .ducked) }
            } label: {
                Text("Mark as Ducked")
                    .vibeButton(.tertiary)
            }
            .buttonStyle(VibePressStyle())
        }
        .padding(VibeSpacing.lg)
        .vibeCard(radius: VibeTheme.radiusMedium)
    }

    private func resolveButton(outcome: BetOutcome, label: String, color: Color) -> some View {
        Button {
            VibeHaptic.medium()
            Task { await resolve(outcome: outcome) }
        } label: {
            Text(label)
                .font(VibeTypography.titleSmall)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: VibeSpacing.minTouchTarget)
                .background(color)
                .continuousCorner(VibeTheme.radiusMedium)
        }
        .buttonStyle(VibePressStyle())
        .disabled(isResolving)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch bet.status {
        case .active: return .green
        case .completed: return .blue
        case .expired: return .orange
        case .ducked: return .gray
        }
    }

    private var statusIcon: String {
        switch bet.status {
        case .active: return "dice.fill"
        case .completed: return "checkmark.circle.fill"
        case .expired: return "clock.badge.exclamationmark"
        case .ducked: return "figure.walk"
        }
    }

    // MARK: - Data Loading

    private func loadBetDetails() async {
        do {
            let detail = try await BettingService.shared.getBet(betId: bet.betId)
            self.participants = detail.participants
            self.totals = detail.totals
            self.userStake = detail.userStake

            let proofResponse = try await BettingService.shared.getProofs(betId: bet.betId)
            self.proofs = proofResponse.proofs
        } catch {
            print("BetDetailView Error: \(error)")
        }
        isLoading = false
    }

    private func placeStake() async {
        isStaking = true
        stakeError = nil
        do {
            let participant = try await appState.placeBetStake(betId: bet.betId, side: selectedSide, amount: stakeAmount)
            participants.append(participant)
            userStake = UserStake(participantId: participant.participantId, side: participant.side, amount: participant.amount, createdAt: participant.createdAt)
            await loadBetDetails()
        } catch {
            stakeError = error.localizedDescription
        }
        isStaking = false
    }

    private func resolve(outcome: BetOutcome) async {
        isResolving = true
        do {
            try await appState.resolveBet(betId: bet.betId, outcome: outcome)
            VibeHaptic.success()
            appState.navigateToFeed()
        } catch {
            VibeHaptic.error()
        }
        isResolving = false
    }
}
