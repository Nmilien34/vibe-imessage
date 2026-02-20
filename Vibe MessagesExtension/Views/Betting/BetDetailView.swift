//
//  BetDetailView.swift
//  Vibe MessagesExtension
//
//  Single bet detail with staking, participants, proofs, and resolution.
//

import SwiftUI

struct BetDetailView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentBet: Bet

    @State private var participants: [BetParticipant] = []
    @State private var totals: BetTotals?
    @State private var userStake: UserStake?
    @State private var stakeTransactions: [BetStakeTransaction] = []
    @State private var proofs: [BetProof] = []

    @State private var selectedSide: BetSide = .yes
    @State private var stakeAmount: Int = 10
    @State private var isStaking = false
    @State private var stakeError: String?

    @State private var isResolving = false
    @State private var showOutcomePicker = false
    @State private var selectedResolutionOutcome: BetOutcome = .yes
    @State private var showResolutionComposer = false
    @State private var pendingClaim: ResolutionClaim?
    @State private var pendingClaimViewer: ResolutionClaimViewer?
    @State private var resolutionError: String?

    init(bet: Bet) {
        _currentBet = State(initialValue: bet)
    }

    private var stakeSliderRange: ClosedRange<Double> {
        let lower = 10.0
        // Slider with step=5 needs at least 5 points of span.
        let upper = max(lower + 5.0, Double(min(100, max(10, appState.auraBalance))))
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
                    if currentBet.status == .active {
                        actionSection
                    }

                    // Participants
                    participantsList

                    // Proofs
                    if !proofs.isEmpty {
                        proofsSection
                    }

                    // Resolution (for creator)
                    if currentBet.status == .active && currentBet.creatorId == appState.userId {
                        resolutionSection
                    }

                    if currentBet.status == .pendingResolution {
                        pendingResolutionSection
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
        .overlay(alignment: .topTrailing) {
            if let shareURL = betShareURL {
                ShareLink(
                    item: shareURL,
                    message: Text(shareMessageText)
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(VibeTheme.textPrimary)
                        .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(.trailing, VibeSpacing.screenHorizontal)
                .padding(.top, VibeSpacing.sm)
            }
        }
        .task {
            await loadBetDetails()
        }
        .confirmationDialog("Choose Resolution Outcome", isPresented: $showOutcomePicker, titleVisibility: .visible) {
            Button("YES Side Wins") {
                selectedResolutionOutcome = .yes
                showResolutionComposer = true
            }
            Button("NO Side Wins") {
                selectedResolutionOutcome = .no
                showResolutionComposer = true
            }
            if currentBet.betType == .callout {
                Button("Mark as Ducked", role: .destructive) {
                    selectedResolutionOutcome = .ducked
                    showResolutionComposer = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showResolutionComposer) {
            BetResolutionComposerView(
                bet: currentBet,
                outcome: selectedResolutionOutcome,
                onComplete: {
                    showResolutionComposer = false
                    Task {
                        await loadBetDetails()
                    }
                },
                onCancel: {
                    showResolutionComposer = false
                }
            )
            .environmentObject(appState)
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

                Image(systemName: currentBet.status == .active ? "dice.fill" : statusIcon)
                    .font(.system(size: 36))
                    .foregroundColor(statusColor)
            }
            .padding(.top, VibeSpacing.xxxl)

            // Description
            Text(currentBet.description)
                .font(VibeTypography.titleLarge)
                .foregroundColor(VibeTheme.textPrimary)
                .multilineTextAlignment(.center)

            // Meta
            HStack(spacing: VibeSpacing.lg) {
                // Status
                Text(statusLabel.uppercased())
                    .font(VibeTypography.overline)
                    .foregroundColor(.white)
                    .padding(.horizontal, VibeSpacing.sm)
                    .padding(.vertical, VibeSpacing.xxxs)
                    .background(statusColor.opacity(0.8))
                    .continuousCorner(6)

                // Type
                Text(currentBet.betType.rawValue.uppercased())
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
                if currentBet.isExpired {
                    Text("Expired")
                        .font(VibeTypography.captionSmall)
                } else {
                    Text("Ends \(currentBet.deadline, style: .relative)")
                        .font(VibeTypography.captionSmall)
                }
            }
            .foregroundColor(currentBet.isExpired ? .red : VibeTheme.textTertiary)

            // Creator
            Text("Created by \(appState.nameForUser(currentBet.creatorId))")
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
                VStack(spacing: VibeSpacing.md) {
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

                    if !stakeTransactions.isEmpty {
                        stakeActivitySection
                    }

                    if canCurrentUserRestake {
                        VStack(spacing: VibeSpacing.md) {
                            Text("ADD TO YOUR \(userStake.side.rawValue.uppercased()) STAKE")
                                .vibeSectionHeader()

                            VStack(spacing: VibeSpacing.xs) {
                                Text("\(stakeAmount) Aura")
                                    .font(VibeTypography.numericMedium)
                                    .foregroundColor(VibeTheme.textPrimary)
                                    .contentTransition(.numericText())

                                Slider(value: stakeSliderBinding, in: stakeSliderRange, step: 5)
                                    .tint(userStake.side == .yes ? .green : .red)

                                Text("Balance: \(appState.auraBalance)")
                                    .font(VibeTypography.captionSmall)
                                    .foregroundColor(VibeTheme.textTertiary)
                            }

                            Button {
                                VibeHaptic.medium()
                                Task { await placeStake(side: userStake.side) }
                            } label: {
                                HStack {
                                    if isStaking {
                                        ProgressView().tint(.white)
                                    }
                                    Text(isStaking ? "Adding..." : "Add \(stakeAmount) Aura")
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
                        Task { await placeStake(side: selectedSide) }
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

    private var stakeActivitySection: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            Text("YOUR STAKE ACTIVITY")
                .vibeSectionHeader()

            VStack(spacing: 0) {
                ForEach(Array(stakeTransactions.enumerated()), id: \.element.id) { index, transaction in
                    HStack(spacing: VibeSpacing.sm) {
                        VStack(alignment: .leading, spacing: VibeSpacing.xxxs) {
                            Text(stakeActivityLabel(for: transaction))
                                .font(VibeTypography.titleSmall)
                                .foregroundColor(VibeTheme.textPrimary)

                            Text(transaction.createdAt, style: .relative)
                                .font(VibeTypography.captionSmall)
                                .foregroundColor(VibeTheme.textTertiary)
                        }

                        Spacer()

                        Text("\(abs(transaction.amount)) Aura")
                            .font(VibeTypography.numericMedium)
                            .foregroundColor(VibeTheme.textPrimary)
                    }
                    .padding(.vertical, VibeSpacing.xs)

                    if index != stakeTransactions.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(VibeSpacing.lg)
        .vibeCard(radius: VibeTheme.radiusMedium)
    }

    private func stakeActivityLabel(for transaction: BetStakeTransaction) -> String {
        let description = transaction.description?.lowercased() ?? ""
        if description.contains("initial") {
            return "Initial stake"
        }
        if description.contains("added") {
            return "Upped stake"
        }
        return "Stake"
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

            Text("Capture or upload photo/video proof first, then request payout resolution.")
                .font(VibeTypography.bodySmall)
                .foregroundColor(VibeTheme.textSecondary)

            Button {
                VibeHaptic.medium()
                resolutionError = nil
                showOutcomePicker = true
            } label: {
                Text("Resolve with Proof")
                    .vibeButton(.primary)
            }
            .buttonStyle(VibePressStyle())
            .disabled(isResolving)

            if let resolutionError {
                Text(resolutionError)
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(.red)
            }
        }
        .padding(VibeSpacing.lg)
        .vibeCard(radius: VibeTheme.radiusMedium)
    }

    private var pendingResolutionSection: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            Text("PENDING RESOLUTION")
                .vibeSectionHeader()

            if let claim = pendingClaim {
                Text("\(appState.nameForUser(claim.proposedBy)) proposed \(claim.proposedOutcome.rawValue.uppercased()).")
                    .font(VibeTypography.bodySmall)
                    .foregroundColor(VibeTheme.textPrimary)

                Text("Auto-confirms \(claim.autoConfirmAt, style: .relative)")
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(VibeTheme.textTertiary)

                if !claim.reviewerIds.isEmpty {
                    let reviewerNames = claim.reviewerIds.map(appState.nameForUser).joined(separator: ", ")
                    Text("Reviewers: \(reviewerNames)")
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(VibeTheme.textSecondary)
                }

                if canCurrentUserReviewPendingClaim {
                    HStack(spacing: VibeSpacing.sm) {
                        Button {
                            VibeHaptic.success()
                            Task { await confirmPendingClaim() }
                        } label: {
                            Text("Confirm")
                                .vibeButton(.primary)
                        }
                        .buttonStyle(VibePressStyle())
                        .disabled(isResolving)

                        Button {
                            VibeHaptic.warning()
                            Task { await disputePendingClaim() }
                        } label: {
                            Text("Dispute")
                                .vibeButton(.tertiary)
                        }
                        .buttonStyle(VibePressStyle())
                        .disabled(isResolving)
                    }
                } else if hasCurrentUserReviewedClaim {
                    Text("Your review has been recorded.")
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(VibeTheme.textSecondary)
                } else if currentBet.creatorId == appState.userId {
                    Text("Waiting for reviewers to confirm or dispute.")
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(VibeTheme.textSecondary)
                }

                if let resolutionError {
                    Text(resolutionError)
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(.red)
                }
            } else {
                HStack(spacing: VibeSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Pending claim details are unavailable. Pull to refresh.")
                        .font(VibeTypography.bodySmall)
                        .foregroundColor(VibeTheme.textSecondary)
                }
            }
        }
        .padding(VibeSpacing.lg)
        .vibeCard(radius: VibeTheme.radiusMedium)
    }

    // MARK: - Helpers

    private var betShareURL: URL? {
        var components = URLComponents()
        components.scheme = "vibe"
        components.host = "story"
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "bet_id", value: currentBet.betId),
            URLQueryItem(name: "chat_id", value: currentBet.chatId),
            URLQueryItem(name: "type", value: "bet"),
            URLQueryItem(name: "timestamp", value: String(Int(Date().timeIntervalSince1970)))
        ]
        if let userFirstName = appState.userFirstName, !userFirstName.isEmpty {
            queryItems.append(URLQueryItem(name: "sender", value: userFirstName))
        }
        components.queryItems = queryItems
        return components.url
    }

    private var shareMessageText: String {
        "Join this bet on Vibe: \"\(currentBet.description)\""
    }

    private var statusLabel: String {
        switch currentBet.status {
        case .active: return "Active"
        case .pendingResolution: return "Pending"
        case .completed: return "Completed"
        case .expired: return "Expired"
        case .ducked: return "Ducked"
        }
    }

    private var statusColor: Color {
        switch currentBet.status {
        case .active: return .green
        case .pendingResolution: return .purple
        case .completed: return .blue
        case .expired: return .orange
        case .ducked: return .gray
        }
    }

    private var statusIcon: String {
        switch currentBet.status {
        case .active: return "dice.fill"
        case .pendingResolution: return "hourglass.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .expired: return "clock.badge.exclamationmark"
        case .ducked: return "figure.walk"
        }
    }

    private var canCurrentUserReviewPendingClaim: Bool {
        if let viewer = pendingClaimViewer {
            return viewer.canReview && !viewer.hasActed
        }
        guard let claim = pendingClaim else { return false }
        guard claim.reviewerIds.contains(appState.userId) else { return false }
        return !claim.confirmedBy.contains(appState.userId) && !claim.disputedBy.contains(appState.userId)
    }

    private var hasCurrentUserReviewedClaim: Bool {
        if let viewer = pendingClaimViewer {
            return viewer.hasActed
        }
        guard let claim = pendingClaim else { return false }
        return claim.confirmedBy.contains(appState.userId) || claim.disputedBy.contains(appState.userId)
    }

    private var canCurrentUserRestake: Bool {
        guard currentBet.status == .active, !currentBet.isExpired else { return false }
        guard currentBet.creatorId == appState.userId else { return false }
        guard userStake != nil else { return false }

        let participantIds = Set(participants.map { $0.userId })
        return participantIds.count == 1 && participantIds.contains(appState.userId)
    }

    // MARK: - Data Loading

    private func loadBetDetails() async {
        do {
            let detail = try await BettingService.shared.getBet(betId: currentBet.betId)
            self.currentBet = detail.bet
            self.participants = detail.participants
            self.totals = detail.totals
            self.userStake = detail.userStake

            if detail.userStake != nil {
                if let stakeTransactionsResponse = try? await BettingService.shared.getMyStakeTransactions(betId: currentBet.betId, limit: 100) {
                    self.stakeTransactions = stakeTransactionsResponse.transactions
                } else {
                    self.stakeTransactions = []
                }
            } else {
                self.stakeTransactions = []
            }

            let proofResponse = try await BettingService.shared.getProofs(betId: currentBet.betId)
            self.proofs = proofResponse.proofs

            let claimResponse = try await BettingService.shared.getResolutionClaim(betId: currentBet.betId)
            self.pendingClaim = claimResponse.claim
            self.pendingClaimViewer = claimResponse.viewer

            let participantUserIds = participants.map { $0.userId }
            let proofUserIds = proofs.map { $0.userId }
            var combinedUserIds = participantUserIds + proofUserIds
            combinedUserIds.append(currentBet.creatorId)

            if let targetUserId = currentBet.targetUserId {
                combinedUserIds.append(targetUserId)
            }

            if let claim = pendingClaim {
                combinedUserIds.append(claim.proposedBy)
                combinedUserIds.append(contentsOf: claim.reviewerIds)
            }

            let userIds = Set(combinedUserIds)
            await appState.loadBatchUsers(ids: Array(userIds))
        } catch {
            print("BetDetailView Error: \(error)")
        }
    }

    private func placeStake(side: BetSide) async {
        isStaking = true
        stakeError = nil
        do {
            _ = try await appState.placeBetStake(betId: currentBet.betId, side: side, amount: stakeAmount)
            await loadBetDetails()
        } catch {
            stakeError = error.localizedDescription
        }
        isStaking = false
    }

    private func confirmPendingClaim() async {
        isResolving = true
        resolutionError = nil
        do {
            _ = try await appState.confirmBetResolutionClaim(betId: currentBet.betId)
            VibeHaptic.success()
            await loadBetDetails()
        } catch {
            resolutionError = error.localizedDescription
            VibeHaptic.error()
        }
        isResolving = false
    }

    private func disputePendingClaim() async {
        isResolving = true
        resolutionError = nil
        do {
            _ = try await appState.disputeBetResolutionClaim(betId: currentBet.betId)
            VibeHaptic.success()
            await loadBetDetails()
        } catch {
            resolutionError = error.localizedDescription
            VibeHaptic.error()
        }
        isResolving = false
    }
}
