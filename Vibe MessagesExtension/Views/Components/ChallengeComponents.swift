import SwiftUI

// MARK: - Aura Badge

struct AuraBadge: View {
    let amount: Int
    var size: AuraBadgeSize = .regular

    enum AuraBadgeSize {
        case small, regular, large

        var iconSize: CGFloat {
            switch self {
            case .small: return 9
            case .regular: return 11
            case .large: return 14
            }
        }

        var font: Font {
            switch self {
            case .small: return .system(size: 11, weight: .semibold, design: .monospaced)
            case .regular: return .system(size: 13, weight: .semibold, design: .monospaced)
            case .large: return .system(size: 18, weight: .bold, design: .monospaced)
            }
        }

        var hPadding: CGFloat {
            switch self {
            case .small: return VibeSpacing.xs
            case .regular: return VibeSpacing.sm
            case .large: return VibeSpacing.md
            }
        }

        var vPadding: CGFloat {
            switch self {
            case .small: return 3
            case .regular: return VibeSpacing.xxs
            case .large: return VibeSpacing.xs
            }
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill")
                .font(.system(size: size.iconSize))
            Text("\(amount)")
                .font(size.font)
                .contentTransition(.numericText())
        }
        .foregroundColor(VibeTheme.warm)
        .padding(.horizontal, size.hPadding)
        .padding(.vertical, size.vPadding)
        .background(VibeTheme.warmLight)
        .clipShape(Capsule())
    }
}

// MARK: - Type Tag

struct TypeTag: View {
    let betType: BetType

    private var label: String {
        switch betType {
        case .`self`: return "Bet"
        case .callout: return "Callout"
        case .dare: return "Dare"
        }
    }

    private var color: Color {
        switch betType {
        case .`self`: return VibeTheme.warm
        case .callout: return VibeTheme.stakeNo
        case .dare: return VibeTheme.betAccent
        }
    }

    private var icon: String {
        switch betType {
        case .`self`: return "bolt.fill"
        case .callout: return "megaphone.fill"
        case .dare: return "target"
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(label)
                .font(.system(size: 10, weight: .semibold))
        }
            .foregroundColor(color)
            .padding(.horizontal, VibeSpacing.xs)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

// MARK: - Source Tag

struct SourceTag: View {
    let source: String

    private var label: String {
        switch source {
        case "chat_member": return "Your GC"
        case "past_connection": return "Network"
        case "contact": return "Contact"
        default: return ""
        }
    }

    private var color: Color {
        switch source {
        case "chat_member": return .teal
        case "past_connection": return .purple
        case "contact": return VibeTheme.accentBlue
        default: return VibeTheme.textTertiary
        }
    }

    var body: some View {
        if !label.isEmpty {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
                .padding(.horizontal, VibeSpacing.xs)
                .padding(.vertical, 3)
                .background(color.opacity(0.1))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Stake Bar

struct StakeBar: View {
    let yesAmount: Int
    let noAmount: Int

    private var total: Int { max(yesAmount + noAmount, 1) }
    private var yesFraction: CGFloat { CGFloat(yesAmount) / CGFloat(total) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(VibeTheme.divider)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(VibeTheme.stakeYes)
                    .frame(width: geo.size.width * yesFraction)
            }
        }
        .frame(height: 5)
    }
}

// MARK: - Countdown Badge

struct CountdownBadge: View {
    let deadline: Date

    private var timeText: String {
        let remaining = max(0, deadline.timeIntervalSinceNow)
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours >= 24 {
            return "\(hours / 24)d"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "Ended"
        }
    }

    private var isUrgent: Bool {
        deadline.timeIntervalSinceNow < 3600 && deadline.timeIntervalSinceNow > 0
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock")
                .font(.system(size: 10))
            Text(timeText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .foregroundColor(isUrgent ? VibeTheme.warm : VibeTheme.textSecondary)
        .padding(.horizontal, VibeSpacing.xs)
        .padding(.vertical, 2)
        .background(VibeTheme.surfaceOverlay)
        .clipShape(Capsule())
    }
}

// MARK: - Bet Card

enum BetCardInteractionStyle {
    case detail
    case quickStake
}

struct BetCard: View {
    @EnvironmentObject var appState: AppState
    let bet: Bet
    var totals: BetTotals? = nil
    var source: String? = nil
    var interactionStyle: BetCardInteractionStyle = .detail
    @State private var showStakeUpPrompt = false

    private var resolvedTotals: BetTotals? {
        totals ?? appState.betTotalsById[bet.betId]
    }

    private var canQuickStake: Bool {
        appState.betCanStakeById[bet.betId] ?? (bet.supportsStaking && !bet.isExpired)
    }

    private var shouldOfferStakeUpPrompt: Bool {
        guard interactionStyle == .quickStake else { return false }
        guard bet.supportsStaking, !bet.isExpired else { return false }
        guard bet.creatorId == appState.userId else { return false }
        guard canQuickStake == false else { return false }

        if let resolvedTotals {
            let participantCount = resolvedTotals.yesCount + resolvedTotals.noCount
            if participantCount > 1 { return false }
        }

        return true
    }

    private var canTapQuickStakeButton: Bool {
        canQuickStake || shouldOfferStakeUpPrompt
    }

    private var statusLabel: String {
        if bet.lifecycleStatus == .active && bet.isExpired {
            return "Expired"
        }

        switch bet.lifecycleStatus {
        case .pending: return "Waiting for Lock-Ins"
        case .active: return "Active"
        case .resolving: return "Resolving"
        case .completed: return "Completed"
        case .expired, .cancelled: return "Expired"
        case .ducked: return "Ducked"
        }
    }

    private var creatorName: String {
        appState.nameForUser(bet.creatorId)
    }

    private var creatorProfilePictureURL: String? {
        if bet.creatorId == appState.userId {
            return appState.userProfilePictureURL
        }
        return appState.userCache[bet.creatorId]?.profilePicture
    }

    private var creatorInitial: String {
        String(creatorName.prefix(1)).uppercased()
    }

    private var creatorAvatar: some View {
        ZStack {
            Circle()
                .fill(VibeTheme.betAccent.opacity(0.15))

            if let profileURL = creatorProfilePictureURL,
               let url = URL.httpURL(from: profileURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        creatorInitialFallback
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        creatorInitialFallback
                    @unknown default:
                        creatorInitialFallback
                    }
                }
            } else {
                creatorInitialFallback
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
    }

    private var creatorInitialFallback: some View {
        Text(creatorInitial)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(VibeTheme.betAccent)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                // Row 1: Creator + metadata
                HStack(spacing: VibeSpacing.xs) {
                    // Creator avatar
                    creatorAvatar

                    Text(creatorName)
                        .font(VibeTypography.captionLarge)
                        .foregroundColor(VibeTheme.textPrimary)

                    Spacer()

                    TypeTag(betType: bet.betType)
                    if let source = source {
                        SourceTag(source: source)
                    }
                    CountdownBadge(deadline: bet.deadline)
                }

                // Row 1b: Target user (callout / dare only)
                if let targetId = bet.targetUserId,
                   (bet.betType == .callout || bet.betType == .dare) {
                    let verb = bet.betType == .callout ? "calls out" : "dares"
                    HStack(spacing: VibeSpacing.xxs) {
                        Text(verb)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(VibeTheme.textTertiary)
                        Text("@\(appState.nameForUser(targetId))")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(bet.betType == .callout ? VibeTheme.stakeNo : VibeTheme.betAccent)
                    }
                }

                // Row 2: Description
                Text(bet.description)
                    .font(VibeTypography.bodyMedium)
                    .foregroundColor(VibeTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Row 3: Pot + participation metadata
                HStack(spacing: VibeSpacing.xs) {
                    let participantCount = (resolvedTotals?.yesCount ?? 0) + (resolvedTotals?.noCount ?? 0)
                    AuraBadge(amount: resolvedTotals?.totalPot ?? bet.creationCost ?? 0, size: .small)
                    Text("pool")
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(VibeTheme.textTertiary)

                    if resolvedTotals != nil {
                        Text("•")
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(VibeTheme.textTertiary)
                        Text("\(participantCount) locked in so far")
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(VibeTheme.textSecondary)
                    }

                    Spacer()

                    if bet.status != .active || bet.isExpired {
                        Text(statusLabel)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(VibeTheme.textTertiary)
                    }
                }

                if let t = resolvedTotals, (t.totalYes + t.totalNo) > 0 {
                    StakeBar(yesAmount: t.totalYes, noAmount: t.totalNo)
                }

                // Row 4: Stake buttons (only for active bets)
                if bet.supportsStaking && !bet.isExpired {
                    HStack(spacing: VibeSpacing.sm) {
                        StakeButton(label: interactionStyle == .quickStake ? "Yes" : "Join YES", color: VibeTheme.stakeYes, compactStyle: interactionStyle == .quickStake) {
                            if interactionStyle == .quickStake {
                                if canQuickStake {
                                    VibeHaptic.medium()
                                    appState.quickStake(betId: bet.betId, side: .yes)
                                } else if shouldOfferStakeUpPrompt {
                                    VibeHaptic.light()
                                    showStakeUpPrompt = true
                                }
                            } else {
                                VibeHaptic.medium()
                                appState.navigateToBetDetail(bet: bet)
                            }
                        }
                        .disabled(interactionStyle == .quickStake && !canTapQuickStakeButton)

                        StakeButton(label: interactionStyle == .quickStake ? "No" : "Join NO", color: VibeTheme.stakeNo, compactStyle: interactionStyle == .quickStake) {
                            if interactionStyle == .quickStake {
                                if canQuickStake {
                                    VibeHaptic.medium()
                                    appState.quickStake(betId: bet.betId, side: .no)
                                } else if shouldOfferStakeUpPrompt {
                                    VibeHaptic.light()
                                    showStakeUpPrompt = true
                                }
                            } else {
                                VibeHaptic.medium()
                                appState.navigateToBetDetail(bet: bet)
                            }
                        }
                        .disabled(interactionStyle == .quickStake && !canTapQuickStakeButton)
                    }
                }
            }
            .padding(VibeSpacing.md)
            .background(VibeTheme.cardBackground)
            .continuousCorner(VibeTheme.radiusMedium)
    }

    var body: some View {
        Group {
            if interactionStyle == .detail {
                Button {
                    VibeHaptic.light()
                    appState.navigateToBetDetail(bet: bet)
                } label: {
                    cardContent
                }
            } else {
                cardContent
            }
        }
        .buttonStyle(.plain)
        .alert("You're already in this challenge", isPresented: $showStakeUpPrompt) {
            Button("Boost Stake") {
                appState.navigateToBetDetail(bet: bet)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Want to add more to your stake?")
        }
    }
}

// MARK: - Stake Button

struct StakeButton: View {
    let label: String
    let color: Color
    var compactStyle: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: compactStyle ? 12 : 14, weight: .semibold))
                .foregroundColor(compactStyle ? color : .white)
                .frame(maxWidth: .infinity)
                .frame(height: compactStyle ? 30 : 36)
                .background(compactStyle ? color.opacity(0.16) : color)
                .continuousCorner(VibeTheme.radiusSmall)
        }
        .buttonStyle(VibePressStyle())
    }
}

// MARK: - Tea Card

struct TeaCard: View {
    @EnvironmentObject var appState: AppState
    let tea: TeaSpill

    var body: some View {
        Button {
            VibeHaptic.light()
            appState.navigateToTeaGuess(tea: tea)
        } label: {
            VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                // Row 1: Type + countdown (tea creator stays anonymous)
                HStack(spacing: VibeSpacing.xs) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(VibeTheme.accentCyan)

                    Text("TEA")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(VibeTheme.accentCyan)
                        .padding(.horizontal, VibeSpacing.xs)
                        .padding(.vertical, 2)
                        .background(VibeTheme.accentCyan.opacity(0.12))
                        .clipShape(Capsule())

                    Spacer()

                    CountdownBadge(deadline: tea.deadline)
                }

                // Row 2: Mystery text
                Text(tea.mysteryText)
                    .font(VibeTypography.bodyMedium)
                    .foregroundColor(VibeTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Row 3: Options count + status
                HStack {
                    HStack(spacing: 3) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 11))
                        Text("\(tea.options.count) options")
                            .font(VibeTypography.captionSmall)
                    }
                    .foregroundColor(VibeTheme.textSecondary)

                    Spacer()

                    if tea.status == .revealed {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                            Text("Revealed")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(VibeTheme.stakeYes)
                    } else if tea.status == .active && !tea.isExpired {
                        Button {
                            VibeHaptic.medium()
                            appState.navigateToTeaGuess(tea: tea)
                        } label: {
                            Text("Guess")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, VibeSpacing.md)
                                .padding(.vertical, VibeSpacing.xxs)
                                .background(VibeTheme.accentCyan)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(VibePressStyle())
                    }
                }
            }
            .padding(VibeSpacing.md)
            .background(VibeTheme.cardBackground)
            .continuousCorner(VibeTheme.radiusMedium)
        }
        .buttonStyle(.plain)
    }
}
