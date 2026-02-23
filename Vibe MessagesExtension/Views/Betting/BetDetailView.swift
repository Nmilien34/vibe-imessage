//
//  BetDetailView.swift
//  Vibe MessagesExtension
//
//  Single bet detail with staking, participants, proofs, and resolution.
//

import SwiftUI
import UIKit

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
    @State private var resolutionPayload: ResolutionResponse?
    @State private var isLoadingResolutionPayload = false
    @State private var isVoting = false
    @State private var consensusVoteCounts: BettingService.VoteCounts?
    @State private var hasSubmittedConsensusVote = false
    @State private var proofReactionStateById: [String: BettingService.ProofReactionState] = [:]
    @State private var isReactingToProofId: String?
    @State private var lockedProofReactionIds: Set<String> = []
    @State private var showShareOptions = false
    @State private var showExternalShareSheet = false
    @State private var externalShareURL: URL?

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

                    // Loop Summary
                    lifecycleSummarySection

                    // Pot Visualization
                    if let totals {
                        potVisualization(totals)
                    }

                    // Action Section
                    if currentBet.supportsStaking && !currentBet.isExpired {
                        actionSection
                    }

                    // Participants
                    participantsList

                    // Proofs
                    if !proofs.isEmpty {
                        proofsSection
                    }

                    // Proof claim composer
                    if canCurrentUserClaimProofOutcome {
                        resolutionSection
                    }

                    if currentBet.lifecycleStatus == .pending {
                        thresholdPendingSection
                    }

                    if currentBet.lifecycleStatus == .resolving {
                        resolvingLoopSection
                    }

                    if shouldShowResolvedSummary {
                        resolvedOutcomeSection
                    }

                    if shouldShowPendingClaimSection {
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
            Button {
                VibeHaptic.medium()
                showShareOptions = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(VibeTheme.textPrimary)
                    .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(VibePressStyle())
            .padding(.trailing, VibeSpacing.screenHorizontal)
            .padding(.top, VibeSpacing.sm)
        }
        .task {
            await loadBetDetails()
        }
        .confirmationDialog("Share Challenge", isPresented: $showShareOptions, titleVisibility: .visible) {
            Button("Send in This iMessage Chat") {
                appState.sendBetMessage(bet: currentBet)
            }
            if let url = betShareURL {
                Button("Share Link Anywhere") {
                    externalShareURL = url
                    showExternalShareSheet = true
                }
                Button("Copy Link") {
                    UIPasteboard.general.string = url.absoluteString
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Share this challenge in iMessage or copy a public link for Instagram, WhatsApp, or SMS.")
        }
        .sheet(isPresented: $showExternalShareSheet, onDismiss: {
            externalShareURL = nil
        }) {
            if let externalShareURL {
                ShareActivityView(activityItems: [externalShareURL])
            } else {
                EmptyView()
            }
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
            if currentBet.betType == .callout || currentBet.betType == .dare {
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

                Image(systemName: currentBet.lifecycleStatus == .active ? "dice.fill" : statusIcon)
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
                if currentBet.lifecycleStatus == .completed || currentBet.lifecycleStatus == .ducked {
                    Text("Resolved \(currentBet.updatedAt ?? currentBet.deadline, style: .relative)")
                        .font(VibeTypography.captionSmall)
                } else if currentBet.lifecycleStatus == .resolving {
                    Text("Resolution window \(currentBet.deadline, style: .relative)")
                        .font(VibeTypography.captionSmall)
                } else if currentBet.lifecycleStatus == .pending {
                    Text("Threshold window \(currentBet.deadline, style: .relative)")
                        .font(VibeTypography.captionSmall)
                } else if currentBet.isExpired {
                    Text("Expired")
                        .font(VibeTypography.captionSmall)
                } else {
                    Text("Ends \(currentBet.deadline, style: .relative)")
                        .font(VibeTypography.captionSmall)
                }
            }
            .foregroundColor(
                currentBet.lifecycleStatus == .expired || currentBet.lifecycleStatus == .cancelled
                ? .red
                : VibeTheme.textTertiary
            )

            // Creator
            Text("Created by \(appState.nameForUser(currentBet.creatorId))")
                .font(VibeTypography.bodySmall)
                .foregroundColor(VibeTheme.textSecondary)
        }
    }

    // MARK: - Loop Summary

    private var lifecycleSummarySection: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            HStack {
                Text("LOOP STAGE")
                    .vibeSectionHeader()
                Spacer()
                Text(loopModeLabel)
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(VibeTheme.textSecondary)
                    .padding(.horizontal, VibeSpacing.xs)
                    .padding(.vertical, 2)
                    .background(VibeTheme.surfaceOverlay)
                    .clipShape(Capsule())
            }

            Text(loopStageDescription)
                .font(VibeTypography.bodySmall)
                .foregroundColor(VibeTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(VibeSpacing.lg)
        .vibeCard(radius: VibeTheme.radiusMedium)
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
                        let participantName = participant.isAnonymous == true
                            ? "Anonymous"
                            : appState.nameForUser(participant.userId)
                        HStack(spacing: VibeSpacing.md) {
                            Circle()
                                .fill(participant.side == .yes ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                .frame(width: VibeSpacing.avatarSmall, height: VibeSpacing.avatarSmall)
                                .overlay(
                                    Text(String(participantName.prefix(1)))
                                        .font(VibeTypography.titleSmall)
                                        .foregroundColor(participant.side == .yes ? .green : .red)
                                )

                            VStack(alignment: .leading, spacing: VibeSpacing.xxxs) {
                                Text(participantName)
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
                let reactionState = proofReactionStateById[proof.proofId]
                let status = reactionState?.status ?? proof.status
                let confirmations = reactionState?.confirmations ?? proof.confirmations ?? 0
                let disputes = reactionState?.disputes ?? proof.disputes ?? 0
                let disputeDeadline = reactionState?.disputeDeadline ?? proof.disputeDeadline

                VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                    HStack(spacing: VibeSpacing.md) {
                        Image(systemName: proof.mediaType == .photo ? "photo.fill" : "video.fill")
                            .font(.system(size: 20))
                            .foregroundColor(VibeTheme.accent)

                        VStack(alignment: .leading, spacing: VibeSpacing.xxxs) {
                            Text(appState.nameForUser(proof.userId))
                                .font(VibeTypography.titleSmall)
                                .foregroundColor(VibeTheme.textPrimary)

                            HStack(spacing: VibeSpacing.xs) {
                                if let status {
                                    Text(status.rawValue.capitalized)
                                        .font(VibeTypography.captionSmall)
                                        .foregroundColor(status == .confirmed ? .green : status == .disputed ? .red : .orange)
                                }

                                Text("\(confirmations) confirm • \(disputes) dispute")
                                    .font(VibeTypography.captionSmall)
                                    .foregroundColor(VibeTheme.textTertiary)
                            }
                        }

                        Spacer()

                        Text(proof.createdAt, style: .relative)
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(VibeTheme.textTertiary)
                    }

                    if let caption = proof.caption {
                        Text(caption)
                            .font(VibeTypography.bodySmall)
                            .foregroundColor(VibeTheme.textSecondary)
                    }

                    if let disputeDeadline {
                        Text("Dispute window \(disputeDeadline > Date() ? "closes" : "closed") \(disputeDeadline, style: .relative)")
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(VibeTheme.textTertiary)
                    }

                    if canCurrentUserReactToProof(
                        proof: proof,
                        status: status,
                        disputeDeadline: disputeDeadline
                    ) {
                        HStack(spacing: VibeSpacing.sm) {
                            Button {
                                VibeHaptic.success()
                                Task { await reactToProof(proof: proof, reaction: "confirm") }
                            } label: {
                                if isReactingToProofId == proof.proofId {
                                    ProgressView().tint(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, VibeSpacing.sm)
                                } else {
                                    Text("Confirm Proof")
                                        .vibeButton(.primary)
                                }
                            }
                            .buttonStyle(VibePressStyle())
                            .disabled(isReactingToProofId != nil)

                            Button {
                                VibeHaptic.warning()
                                Task { await reactToProof(proof: proof, reaction: "dispute") }
                            } label: {
                                Text("Dispute")
                                    .vibeButton(.tertiary)
                            }
                            .buttonStyle(VibePressStyle())
                            .disabled(isReactingToProofId != nil)
                        }
                    } else if lockedProofReactionIds.contains(proof.proofId) {
                        Text("Your proof reaction is already recorded.")
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(VibeTheme.textSecondary)
                    }
                }
                .padding(VibeSpacing.md)
                .vibeCard(radius: VibeTheme.radiusMedium)
            }
        }
    }

    // MARK: - Resolution

    private var resolutionSection: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            Text("SUBMIT PROOF CLAIM")
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

    private var thresholdPendingSection: some View {
        let requiredCount = requiredParticipantsToActivate
        let currentCount = participants.count
        let progress: Double = {
            guard let requiredCount, requiredCount > 0 else { return 0 }
            return min(1, Double(currentCount) / Double(requiredCount))
        }()

        return VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            Text("AWAITING PARTICIPATION")
                .vibeSectionHeader()

            if let requiredCount {
                Text("\(currentCount) of \(requiredCount) participants joined.")
                    .font(VibeTypography.bodySmall)
                    .foregroundColor(VibeTheme.textPrimary)

                ProgressView(value: progress, total: 1)
                    .tint(VibeTheme.betAccent)

                if let participationThreshold = currentBet.participationThreshold {
                    Text("Threshold set to \(Int((participationThreshold * 100).rounded()))% of the chat.")
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(VibeTheme.textSecondary)
                }
            } else {
                Text("This challenge is waiting for more stakers before it activates.")
                    .font(VibeTypography.bodySmall)
                    .foregroundColor(VibeTheme.textSecondary)
            }
        }
        .padding(VibeSpacing.lg)
        .vibeCard(radius: VibeTheme.radiusMedium)
    }

    private var resolvingLoopSection: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            Text("RESOLUTION LOOP")
                .vibeSectionHeader()

            switch effectiveResolutionType {
            case .proof:
                Text("Proof submissions are under review. Stakers can confirm or dispute during the dispute window.")
                    .font(VibeTypography.bodySmall)
                    .foregroundColor(VibeTheme.textSecondary)
            case .consensus:
                consensusResolutionSection
            case .observable:
                observableResolutionSection
            }

            if let resolutionError {
                Text(resolutionError)
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(.red)
            }
        }
        .padding(VibeSpacing.lg)
        .vibeCard(radius: VibeTheme.radiusMedium)
    }

    private var consensusResolutionSection: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            Text("Stakers vote YES or NO before the timer ends.")
                .font(VibeTypography.bodySmall)
                .foregroundColor(VibeTheme.textSecondary)

            Text("Vote window closes \(currentBet.deadline, style: .relative)")
                .font(VibeTypography.captionSmall)
                .foregroundColor(VibeTheme.textTertiary)

            if let counts = consensusVoteCounts {
                Text("Votes: \(counts.yesVotes) yes • \(counts.noVotes) no")
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(VibeTheme.textSecondary)
            }

            if isCurrentUserStaker {
                if hasSubmittedConsensusVote {
                    Text("Your vote is recorded.")
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(VibeTheme.textSecondary)
                } else {
                    HStack(spacing: VibeSpacing.sm) {
                        Button {
                            VibeHaptic.medium()
                            Task { await castConsensusVote(.yes) }
                        } label: {
                            Text(isVoting ? "Submitting..." : "Vote YES")
                                .vibeButton(.primary)
                        }
                        .buttonStyle(VibePressStyle())
                        .disabled(isVoting)

                        Button {
                            VibeHaptic.medium()
                            Task { await castConsensusVote(.no) }
                        } label: {
                            Text("Vote NO")
                                .vibeButton(.tertiary)
                        }
                        .buttonStyle(VibePressStyle())
                        .disabled(isVoting)
                    }
                }
            } else {
                Text("Only stakers can vote in consensus.")
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(VibeTheme.textSecondary)
            }
        }
    }

    private var observableResolutionSection: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            if let declaredOutcome = currentBet.observableDeclaredOutcome {
                Text("Creator declared \(declaredOutcome.rawValue.uppercased()).")
                    .font(VibeTypography.bodySmall)
                    .foregroundColor(VibeTheme.textPrimary)

                Text("Dispute window closes \(currentBet.deadline, style: .relative)")
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(VibeTheme.textTertiary)

                if let counts = consensusVoteCounts {
                    Text("Votes: \(counts.yesVotes) yes • \(counts.noVotes) no")
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(VibeTheme.textSecondary)
                }

                if isCurrentUserStaker {
                    if hasSubmittedConsensusVote {
                        Text("Your vote is recorded.")
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(VibeTheme.textSecondary)
                    } else {
                        HStack(spacing: VibeSpacing.sm) {
                            Button {
                                VibeHaptic.medium()
                                Task { await castConsensusVote(.yes) }
                            } label: {
                                Text(isVoting ? "Submitting..." : "Vote YES")
                                    .vibeButton(.primary)
                            }
                            .buttonStyle(VibePressStyle())
                            .disabled(isVoting)

                            Button {
                                VibeHaptic.medium()
                                Task { await castConsensusVote(.no) }
                            } label: {
                                Text("Vote NO")
                                    .vibeButton(.tertiary)
                            }
                            .buttonStyle(VibePressStyle())
                            .disabled(isVoting)
                        }
                    }
                } else {
                    Text("Only stakers can dispute or support this declaration.")
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(VibeTheme.textSecondary)
                }
            } else if currentBet.creatorId == appState.userId {
                Text("Declare the observable outcome to open the dispute window.")
                    .font(VibeTypography.bodySmall)
                    .foregroundColor(VibeTheme.textSecondary)

                HStack(spacing: VibeSpacing.sm) {
                    Button {
                        VibeHaptic.medium()
                        Task { await declareObservableOutcome(.yes) }
                    } label: {
                        Text(isVoting ? "Submitting..." : "Declare YES")
                            .vibeButton(.primary)
                    }
                    .buttonStyle(VibePressStyle())
                    .disabled(isVoting)

                    Button {
                        VibeHaptic.medium()
                        Task { await declareObservableOutcome(.no) }
                    } label: {
                        Text("Declare NO")
                            .vibeButton(.tertiary)
                    }
                    .buttonStyle(VibePressStyle())
                    .disabled(isVoting)
                }
            } else {
                Text("Waiting for the creator to declare an outcome.")
                    .font(VibeTypography.bodySmall)
                    .foregroundColor(VibeTheme.textSecondary)
            }
        }
    }

    private var resolvedOutcomeSection: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            Text("FINAL OUTCOME")
                .vibeSectionHeader()

            if isLoadingResolutionPayload {
                HStack(spacing: VibeSpacing.sm) {
                    ProgressView()
                        .tint(VibeTheme.accent)
                    Text("Loading payout breakdown...")
                        .font(VibeTypography.bodySmall)
                        .foregroundColor(VibeTheme.textSecondary)
                }
            } else if let payload = resolutionPayload {
                Text(payload.outcome.rawValue.uppercased())
                    .font(VibeTypography.titleMedium)
                    .foregroundColor(statusColor)

                Text("Total pot: \(payload.totalPot) Aura • \(payload.participantCount) participants")
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(VibeTheme.textSecondary)

                if !payload.winners.isEmpty {
                    VStack(alignment: .leading, spacing: VibeSpacing.xs) {
                        Text("Winners")
                            .font(VibeTypography.captionLarge)
                            .foregroundColor(.green)
                        ForEach(payload.winners) { winner in
                            payoutRow(
                                title: winner.displayName,
                                detail: "Stake \(winner.stakeAmount)",
                                amountText: "+\(winner.netGain ?? 0)"
                            )
                        }
                    }
                }

                if !payload.losers.isEmpty {
                    VStack(alignment: .leading, spacing: VibeSpacing.xs) {
                        Text("Losers")
                            .font(VibeTypography.captionLarge)
                            .foregroundColor(.red)
                        ForEach(payload.losers) { loser in
                            payoutRow(
                                title: loser.displayName,
                                detail: "Stake \(loser.stakeAmount)",
                                amountText: "\(loser.netLoss ?? 0)"
                            )
                        }
                    }
                }

                if let ducked = payload.ducked, !ducked.isEmpty {
                    VStack(alignment: .leading, spacing: VibeSpacing.xs) {
                        Text("Ducked")
                            .font(VibeTypography.captionLarge)
                            .foregroundColor(.orange)
                        ForEach(ducked) { entry in
                            payoutRow(
                                title: entry.displayName,
                                detail: "Penalty",
                                amountText: "-\(entry.penalty)"
                            )
                        }
                    }
                }
            } else {
                Text("Resolution details are unavailable right now.")
                    .font(VibeTypography.bodySmall)
                    .foregroundColor(VibeTheme.textSecondary)
            }
        }
        .padding(VibeSpacing.lg)
        .vibeCard(radius: VibeTheme.radiusMedium)
    }

    private func payoutRow(title: String, detail: String, amountText: String) -> some View {
        HStack(spacing: VibeSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VibeTypography.titleSmall)
                    .foregroundColor(VibeTheme.textPrimary)
                Text(detail)
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(VibeTheme.textSecondary)
            }
            Spacer()
            Text(amountText)
                .font(VibeTypography.numericMedium)
                .foregroundColor(VibeTheme.textPrimary)
        }
        .padding(.vertical, 2)
    }

    private var pendingResolutionSection: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            Text("PENDING CLAIM REVIEW")
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
        components.scheme = "https"
        components.host = "getvibe.app"
        components.path = "/open"
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "bet_id", value: currentBet.betId),
            URLQueryItem(name: "chat_id", value: currentBet.chatId),
            URLQueryItem(name: "type", value: "bet"),
            URLQueryItem(name: "inviter_id", value: appState.userId),
            URLQueryItem(name: "source", value: "external_share"),
            URLQueryItem(name: "timestamp", value: String(Int(Date().timeIntervalSince1970)))
        ]
        if let userFirstName = appState.userFirstName, !userFirstName.isEmpty {
            queryItems.append(URLQueryItem(name: "sender", value: userFirstName))
        }
        components.queryItems = queryItems
        return components.url
    }

    private var effectiveResolutionType: BetResolutionType {
        currentBet.resolutionType ?? .proof
    }

    private var canCurrentUserClaimProofOutcome: Bool {
        guard effectiveResolutionType == .proof else { return false }
        guard currentBet.creatorId == appState.userId else { return false }
        guard pendingClaim == nil else { return false }
        return currentBet.lifecycleStatus == .active || currentBet.lifecycleStatus == .resolving
    }

    private var shouldShowPendingClaimSection: Bool {
        currentBet.lifecycleStatus == .resolving && pendingClaim != nil
    }

    private var shouldShowResolvedSummary: Bool {
        switch currentBet.lifecycleStatus {
        case .completed, .expired, .ducked, .cancelled:
            return true
        default:
            return false
        }
    }

    private var isCurrentUserStaker: Bool {
        participants.contains { $0.userId == appState.userId }
    }

    private var requiredParticipantsToActivate: Int? {
        guard let participationThreshold = currentBet.participationThreshold else { return nil }
        let baseCount = currentBet.thresholdMemberCount ?? max(participants.count, 1)
        return max(1, Int(ceil(Double(baseCount) * participationThreshold)))
    }

    private var loopModeLabel: String {
        switch effectiveResolutionType {
        case .proof:
            return "Proof"
        case .observable:
            return "Observable"
        case .consensus:
            return "Consensus"
        }
    }

    private var loopStageDescription: String {
        switch currentBet.lifecycleStatus {
        case .pending:
            return "This challenge is waiting for enough participants before it activates."
        case .active:
            return "Staking is open. Once the timer ends, it moves into the resolution phase."
        case .resolving:
            switch effectiveResolutionType {
            case .proof:
                return "Proof claims and disputes are currently deciding the outcome."
            case .observable:
                return "Creator declaration and staker dispute votes are currently open."
            case .consensus:
                return "Stakers are currently voting YES or NO to settle this challenge."
            }
        case .completed:
            return "Challenge completed and payouts were distributed."
        case .expired:
            return "Challenge expired and remaining stakes were refunded."
        case .ducked:
            return "Challenge was marked as ducked."
        case .cancelled:
            return "Challenge was cancelled."
        }
    }

    private var statusLabel: String {
        if currentBet.lifecycleStatus == .active && currentBet.isExpired {
            return "Expired"
        }
        switch currentBet.lifecycleStatus {
        case .pending: return "Awaiting Quorum"
        case .active: return "Active"
        case .resolving: return "Resolving"
        case .completed: return "Completed"
        case .expired, .cancelled: return "Expired"
        case .ducked: return "Ducked"
        }
    }

    private var statusColor: Color {
        if currentBet.lifecycleStatus == .active && currentBet.isExpired {
            return .orange
        }
        switch currentBet.lifecycleStatus {
        case .pending: return .orange
        case .active: return .green
        case .resolving: return .purple
        case .completed: return .blue
        case .expired, .cancelled: return .orange
        case .ducked: return .gray
        }
    }

    private var statusIcon: String {
        if currentBet.lifecycleStatus == .active && currentBet.isExpired {
            return "clock.badge.exclamationmark"
        }
        switch currentBet.lifecycleStatus {
        case .pending: return "person.3.sequence.fill"
        case .active: return "dice.fill"
        case .resolving: return "hourglass.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .expired, .cancelled: return "clock.badge.exclamationmark"
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
        guard currentBet.supportsStaking, !currentBet.isExpired else { return false }
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
            self.proofReactionStateById = Dictionary(
                uniqueKeysWithValues: proofResponse.proofs.compactMap { proof in
                    guard proof.status != nil || proof.confirmations != nil || proof.disputes != nil || proof.disputeDeadline != nil else {
                        return nil
                    }

                    return (
                        proof.proofId,
                        BettingService.ProofReactionState(
                            proofId: proof.proofId,
                            status: proof.status,
                            confirmations: proof.confirmations ?? 0,
                            disputes: proof.disputes ?? 0,
                            disputeDeadline: proof.disputeDeadline
                        )
                    )
                }
            )

            let claimResponse = try await BettingService.shared.getResolutionClaim(betId: currentBet.betId)
            self.pendingClaim = claimResponse.claim
            self.pendingClaimViewer = claimResponse.viewer

            if currentBet.lifecycleStatus != .resolving {
                hasSubmittedConsensusVote = false
                consensusVoteCounts = nil
                lockedProofReactionIds = []
            }

            if shouldShowResolvedSummary {
                await loadResolutionPayload()
            } else {
                resolutionPayload = nil
                isLoadingResolutionPayload = false
            }

            let participantUserIds = participants.map { $0.userId }
            let proofUserIds = proofs.map { $0.userId }
            var combinedUserIds = participantUserIds + proofUserIds
            combinedUserIds.append(currentBet.creatorId)

            if let targetUserId = currentBet.targetUserId {
                combinedUserIds.append(targetUserId)
            }

            if let declaredBy = currentBet.observableDeclaredBy {
                combinedUserIds.append(declaredBy)
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

    private func loadResolutionPayload() async {
        isLoadingResolutionPayload = true
        defer { isLoadingResolutionPayload = false }

        do {
            resolutionPayload = try await BettingService.shared.getResolution(betId: currentBet.betId)
        } catch {
            resolutionPayload = nil
        }
    }

    private func canCurrentUserReactToProof(
        proof: BetProof,
        status: BetProofStatus?,
        disputeDeadline: Date?
    ) -> Bool {
        guard currentBet.lifecycleStatus == .resolving else { return false }
        guard isCurrentUserStaker else { return false }
        guard proof.userId != appState.userId else { return false }
        guard !lockedProofReactionIds.contains(proof.proofId) else { return false }

        if let status, status != .pending {
            return false
        }

        if let disputeDeadline, disputeDeadline <= Date() {
            return false
        }

        return true
    }

    private func reactToProof(proof: BetProof, reaction: String) async {
        guard isReactingToProofId == nil else { return }

        isReactingToProofId = proof.proofId
        resolutionError = nil

        do {
            let response: BettingService.ProofReactionCounts
            if reaction == "confirm" {
                response = try await appState.confirmBetProof(betId: currentBet.betId, proofId: proof.proofId)
            } else {
                response = try await appState.disputeBetProof(betId: currentBet.betId, proofId: proof.proofId)
            }

            proofReactionStateById[proof.proofId] = response.proof
            lockedProofReactionIds.insert(proof.proofId)
            VibeHaptic.success()
            await loadBetDetails()
        } catch {
            let message = error.localizedDescription
            resolutionError = message
            if message.lowercased().contains("already reacted") {
                lockedProofReactionIds.insert(proof.proofId)
            }
            VibeHaptic.error()
        }

        isReactingToProofId = nil
    }

    private func castConsensusVote(_ vote: BetSide) async {
        guard !isVoting else { return }

        isVoting = true
        resolutionError = nil

        do {
            let response = try await appState.voteOnBet(betId: currentBet.betId, vote: vote)
            consensusVoteCounts = response.counts
            hasSubmittedConsensusVote = true
            VibeHaptic.success()
            await loadBetDetails()
        } catch {
            let message = error.localizedDescription
            resolutionError = message
            if message.lowercased().contains("already voted") {
                hasSubmittedConsensusVote = true
            }
            VibeHaptic.error()
        }

        isVoting = false
    }

    private func declareObservableOutcome(_ outcome: BetOutcome) async {
        guard !isVoting else { return }

        isVoting = true
        resolutionError = nil

        do {
            try await appState.resolveBet(betId: currentBet.betId, outcome: outcome)
            hasSubmittedConsensusVote = false
            consensusVoteCounts = nil
            VibeHaptic.success()
            await loadBetDetails()
        } catch {
            resolutionError = error.localizedDescription
            VibeHaptic.error()
        }

        isVoting = false
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

private struct ShareActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
