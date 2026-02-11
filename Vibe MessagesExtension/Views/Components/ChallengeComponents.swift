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
        .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.0))
        .padding(.horizontal, size.hPadding)
        .padding(.vertical, size.vPadding)
        .background(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.12))
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
        case .`self`: return VibeTheme.betAccent
        case .callout: return .orange
        case .dare: return VibeTheme.stakeNo
        }
    }

    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, VibeSpacing.xs)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
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
            HStack(spacing: 1) {
                // Yes side
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(VibeTheme.stakeYes)
                    .frame(width: max(geo.size.width * yesFraction, 4))

                // No side
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(VibeTheme.stakeNo)
                    .frame(width: max(geo.size.width * (1 - yesFraction), 4))
            }
        }
        .frame(height: 6)
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
        .foregroundColor(isUrgent ? .orange : VibeTheme.textSecondary)
        .padding(.horizontal, VibeSpacing.xs)
        .padding(.vertical, 2)
        .background(VibeTheme.surfaceOverlay)
        .clipShape(Capsule())
    }
}

// MARK: - Bet Card

struct BetCard: View {
    @EnvironmentObject var appState: AppState
    let bet: Bet

    var body: some View {
        Button {
            VibeHaptic.light()
            appState.navigateToBetDetail(bet: bet)
        } label: {
            VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                // Row 1: Creator + Type + Countdown
                HStack(spacing: VibeSpacing.xs) {
                    // Creator avatar
                    Circle()
                        .fill(VibeTheme.betAccent.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(String(appState.nameForUser(bet.creatorId).prefix(1)))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(VibeTheme.betAccent)
                        )

                    Text(appState.nameForUser(bet.creatorId))
                        .font(VibeTypography.captionLarge)
                        .foregroundColor(VibeTheme.textPrimary)

                    TypeTag(betType: bet.betType)

                    Spacer()

                    CountdownBadge(deadline: bet.deadline)
                }

                // Row 2: Description
                Text(bet.description)
                    .font(VibeTypography.bodyMedium)
                    .foregroundColor(VibeTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Row 3: Pot
                HStack {
                    AuraBadge(amount: bet.creationCost ?? 0, size: .small)
                    Text("pot")
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(VibeTheme.textTertiary)
                    Spacer()

                    if bet.status == .active {
                        Text("Active")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(VibeTheme.stakeYes)
                    } else {
                        Text(bet.status.rawValue.capitalized)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(VibeTheme.textTertiary)
                    }
                }

                // Row 4: Stake buttons (only for active bets)
                if bet.status == .active && !bet.isExpired {
                    HStack(spacing: VibeSpacing.sm) {
                        StakeButton(label: "Yes", color: VibeTheme.stakeYes) {
                            VibeHaptic.medium()
                            appState.navigateToBetDetail(bet: bet)
                        }

                        StakeButton(label: "No", color: VibeTheme.stakeNo) {
                            VibeHaptic.medium()
                            appState.navigateToBetDetail(bet: bet)
                        }
                    }
                }
            }
            .padding(VibeSpacing.md)
            .background(VibeTheme.cardBackground)
            .continuousCorner(VibeTheme.radiusMedium)
            .vibeShadow(.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stake Button

struct StakeButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(color)
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
                // Row 1: Tea icon + creator + countdown
                HStack(spacing: VibeSpacing.xs) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.72, green: 0.53, blue: 0.35).opacity(0.15))
                            .frame(width: 28, height: 28)
                        Text("🍵")
                            .font(.system(size: 14))
                    }

                    Text(appState.nameForUser(tea.creatorId))
                        .font(VibeTypography.captionLarge)
                        .foregroundColor(VibeTheme.textPrimary)

                    Text("TEA")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.72, green: 0.53, blue: 0.35))
                        .padding(.horizontal, VibeSpacing.xs)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.72, green: 0.53, blue: 0.35).opacity(0.12))
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
                        Image(systemName: "questionmark.circle")
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
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, VibeSpacing.md)
                                .padding(.vertical, VibeSpacing.xxs)
                                .background(VibeTheme.teaGradient)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(VibePressStyle())
                    }
                }
            }
            .padding(VibeSpacing.md)
            .background(VibeTheme.cardBackground)
            .continuousCorner(VibeTheme.radiusMedium)
            .vibeShadow(.sm)
        }
        .buttonStyle(.plain)
    }
}
