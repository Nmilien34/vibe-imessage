//
//  CreateChallengeSheet.swift
//  Vibe MessagesExtension
//
//  Creation flow for Bets, Callouts, Dares, and Tea Spills.
//

import SwiftUI

// MARK: - Challenge Type (local UI enum, maps to backend types)

private struct ChallengeStarter: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let template: String
    let icon: String
}

private enum SpiceLevel: String, CaseIterable {
    case chill, bold, chaos

    var label: String {
        switch self {
        case .chill: return "Chill"
        case .bold: return "Bold"
        case .chaos: return "Chaos"
        }
    }

    var subtitle: String {
        switch self {
        case .chill: return "Low risk"
        case .bold: return "More heat"
        case .chaos: return "High pressure"
        }
    }

    var icon: String {
        switch self {
        case .chill: return "leaf.fill"
        case .bold: return "flame.fill"
        case .chaos: return "bolt.fill"
        }
    }
}

private enum TeaCreationMode: String, CaseIterable {
    case quick
    case spill

    var label: String {
        switch self {
        case .quick: return "Quick Tea"
        case .spill: return "Tea Spill"
        }
    }

    var subtitle: String {
        switch self {
        case .quick: return "Fast debate take"
        case .spill: return "Mystery + reveal"
        }
    }
}

private enum TeaDebateTake: String, CaseIterable {
    case win
    case lose
    case uncertain

    var label: String {
        switch self {
        case .win: return "Will Win"
        case .lose: return "Will Lose"
        case .uncertain: return "50/50"
        }
    }

    var icon: String {
        switch self {
        case .win: return "arrow.up.circle.fill"
        case .lose: return "arrow.down.circle.fill"
        case .uncertain: return "questionmark.circle.fill"
        }
    }
}

private enum ChallengeKind: String, CaseIterable {
    case bet, callout, dare, tea

    var label: String {
        switch self {
        case .bet: return "Bet"
        case .callout: return "Callout"
        case .dare: return "Dare"
        case .tea: return "Tea"
        }
    }

    var subtitle: String {
        switch self {
        case .bet: return "I'll do X"
        case .callout: return "@said X"
        case .dare: return "Dare @them"
        case .tea: return "Spill it"
        }
    }

    var icon: String {
        switch self {
        case .bet: return "bolt.fill"
        case .callout: return "megaphone.fill"
        case .dare: return "target"
        case .tea: return "cup.and.saucer.fill"
        }
    }

    var color: Color {
        switch self {
        case .bet: return VibeTheme.warm
        case .callout: return VibeTheme.stakeNo
        case .dare: return VibeTheme.betAccent
        case .tea: return VibeTheme.accentCyan
        }
    }

    var betType: BetType? {
        switch self {
        case .bet: return .`self`
        case .callout: return .callout
        case .dare: return .dare
        case .tea: return nil
        }
    }

    var needsTarget: Bool {
        self == .callout || self == .dare
    }

    var needsStake: Bool {
        self != .tea
    }

    var placeholder: String {
        switch self {
        case .bet: return "What's the challenge? e.g. \"I'll run 5 miles this week\""
        case .callout: return "What did they say? e.g. \"Said they'd quit coffee\""
        case .dare: return "What's the dare? e.g. \"Eat a ghost pepper\""
        case .tea: return "What's the mystery? e.g. \"Who broke the vase?\""
        }
    }

    var contextTitle: String {
        switch self {
        case .bet: return "Bet on yourself"
        case .callout: return "Call someone out"
        case .dare: return "Send a dare"
        case .tea: return "Drop some tea"
        }
    }

    var contextSubtitle: String {
        switch self {
        case .bet: return "Pick a starter, make it yours, then lock in your stake."
        case .callout: return "Challenge a claim and let the squad see who follows through."
        case .dare: return "Pick a playful dare for a friend and set a timer."
        case .tea: return "Post a mystery, add options, and reveal the answer later."
        }
    }

    func starters(for spice: SpiceLevel) -> [ChallengeStarter] {
        switch self {
        case .bet:
            switch spice {
            case .chill:
                return [
                    ChallengeStarter(id: "bet_study_sprint", title: "Study Sprint", subtitle: "Lock in tonight", template: "I'll finish all my homework before 8 PM tonight.", icon: "book.fill"),
                    ChallengeStarter(id: "bet_fitness_move", title: "Fitness Move", subtitle: "Active goal", template: "I'll complete a 30 minute workout before tomorrow.", icon: "figure.run"),
                    ChallengeStarter(id: "bet_skill_grind", title: "Skill Grind", subtitle: "Practice challenge", template: "I'll practice my main skill for 45 minutes every day this week.", icon: "gamecontroller.fill")
                ]
            case .bold:
                return [
                    ChallengeStarter(id: "bet_no_phone", title: "No Phone Lock", subtitle: "Discipline run", template: "I'll stay off social apps for 3 hours tonight and post proof.", icon: "iphone.slash"),
                    ChallengeStarter(id: "bet_morning_hustle", title: "Morning Hustle", subtitle: "Wake-up race", template: "I'll be up and out of bed by 6:30 AM tomorrow.", icon: "sunrise.fill"),
                    ChallengeStarter(id: "bet_creator_mode", title: "Creator Mode", subtitle: "Post pressure", template: "I'll post one original video before the deadline, no excuses.", icon: "video.fill")
                ]
            case .chaos:
                return [
                    ChallengeStarter(id: "bet_profile_pic_risk", title: "PFP Risk", subtitle: "Reputation stake", template: "If I miss this challenge, the chat picks my profile pic for 24 hours.", icon: "person.crop.square"),
                    ChallengeStarter(id: "bet_receipt_drop", title: "Receipt Drop", subtitle: "Proof required", template: "I'll finish this challenge and drop full receipts before time is up.", icon: "doc.text.fill"),
                    ChallengeStarter(id: "bet_double_or_nothing", title: "Double Down", subtitle: "High pressure", template: "If I complete this, I double my next stake. If not, I take the L.", icon: "bolt.circle.fill")
                ]
            }
        case .callout:
            switch spice {
            case .chill:
                return [
                    ChallengeStarter(id: "callout_cap_check", title: "Cap Check", subtitle: "Did they mean it?", template: "They said they'd stay off social media for 24 hours.", icon: "megaphone.fill"),
                    ChallengeStarter(id: "callout_early_riser", title: "Early Riser", subtitle: "Morning claim", template: "They said they'll wake up before 6:30 AM tomorrow.", icon: "sunrise.fill"),
                    ChallengeStarter(id: "callout_grind_mode", title: "Grind Mode", subtitle: "Work claim", template: "They said they'll finish their full to-do list tonight.", icon: "checkmark.seal.fill")
                ]
            case .bold:
                return [
                    ChallengeStarter(id: "callout_screen_time", title: "Screen Time Claim", subtitle: "Receipt check", template: "They said their screen time was under 2 hours yesterday.", icon: "hourglass"),
                    ChallengeStarter(id: "callout_gym_claim", title: "Gym Claim", subtitle: "Follow-through test", template: "They said they'd complete a full workout today.", icon: "figure.strengthtraining.traditional"),
                    ChallengeStarter(id: "callout_confidence_claim", title: "Confidence Claim", subtitle: "No backing out", template: "They said they'd send that bold text tonight.", icon: "paperplane.fill")
                ]
            case .chaos:
                return [
                    ChallengeStarter(id: "callout_receipts", title: "Receipt Time", subtitle: "Bring proof", template: "They promised results by tonight. Receipts or it didn't happen.", icon: "camera.fill"),
                    ChallengeStarter(id: "callout_main_character", title: "Main Character Claim", subtitle: "Big talk check", template: "They said they'd carry the squad this week.", icon: "crown.fill"),
                    ChallengeStarter(id: "callout_no_ducking", title: "No Ducking", subtitle: "Pressure match", template: "They said they'd handle this challenge without ducking.", icon: "exclamationmark.triangle.fill")
                ]
            }
        case .dare:
            switch spice {
            case .chill:
                return [
                    ChallengeStarter(id: "dare_talent_show", title: "Talent Drop", subtitle: "Show your skill", template: "Post a 15 second talent clip before midnight.", icon: "music.mic"),
                    ChallengeStarter(id: "dare_confidence_check", title: "Confidence Check", subtitle: "Bold challenge", template: "Give one genuine compliment to 5 people today.", icon: "sparkles"),
                    ChallengeStarter(id: "dare_clean_room", title: "Clean Room", subtitle: "Proof challenge", template: "Clean your room and send proof before tonight.", icon: "house.fill")
                ]
            case .bold:
                return [
                    ChallengeStarter(id: "dare_hot_take_voice", title: "Hot Take Voice Note", subtitle: "No filter", template: "Drop a 20 second hot take voice note in chat before the deadline.", icon: "waveform.circle.fill"),
                    ChallengeStarter(id: "dare_rename_self", title: "Rename Risk", subtitle: "Let chat decide", template: "Let the group rename your display name for 1 hour.", icon: "square.and.pencil"),
                    ChallengeStarter(id: "dare_camera_roll", title: "Camera Roll #5", subtitle: "Random reveal", template: "Post your 5th camera roll photo and give context.", icon: "photo.stack.fill")
                ]
            case .chaos:
                return [
                    ChallengeStarter(id: "dare_roast_self", title: "Self Roast", subtitle: "Commit fully", template: "Record a 15 second roast of your own bad habit and post it.", icon: "theatermasks.fill"),
                    ChallengeStarter(id: "dare_public_prediction", title: "Public Prediction", subtitle: "Reputation on the line", template: "Make one bold prediction in chat and own the result tomorrow.", icon: "chart.line.uptrend.xyaxis"),
                    ChallengeStarter(id: "dare_live_challenge", title: "Live Challenge", subtitle: "Now or never", template: "Complete this dare in the next 30 minutes and post proof.", icon: "timer")
                ]
            }
        case .tea:
            switch spice {
            case .chill:
                return [
                    ChallengeStarter(id: "tea_school_story", title: "School Story", subtitle: "Campus mystery", template: "Who started the rumor in class today?", icon: "graduationcap.fill"),
                    ChallengeStarter(id: "tea_group_chat", title: "Group Chat Tea", subtitle: "Chat mystery", template: "Who left the group chat and came back later?", icon: "bubble.left.and.bubble.right.fill"),
                    ChallengeStarter(id: "tea_weekend_plan", title: "Weekend Tea", subtitle: "Plan mystery", template: "Who canceled plans last minute this weekend?", icon: "calendar")
                ]
            case .bold:
                return [
                    ChallengeStarter(id: "tea_read_receipt", title: "Read Receipt Tea", subtitle: "Message drama", template: "Who left someone on read the longest this week?", icon: "envelope.badge.fill"),
                    ChallengeStarter(id: "tea_hottest_take", title: "Hottest Take", subtitle: "Opinion drop", template: "Who had the wildest hot take in chat this week?", icon: "flame.fill"),
                    ChallengeStarter(id: "tea_biggest_switchup", title: "Switch-Up Alert", subtitle: "Plot twist", template: "Who switched teams the fastest this month?", icon: "arrow.triangle.2.circlepath")
                ]
            case .chaos:
                return [
                    ChallengeStarter(id: "tea_receipt_night", title: "Receipt Night", subtitle: "Drama edition", template: "Whose story needs full receipts tonight?", icon: "doc.on.doc.fill"),
                    ChallengeStarter(id: "tea_sneakiest_player", title: "Sneakiest Player", subtitle: "Expose energy", template: "Who's been playing both sides this week?", icon: "eye.fill"),
                    ChallengeStarter(id: "tea_main_character", title: "Main Character", subtitle: "Most dramatic moment", template: "Who had the most dramatic main-character moment lately?", icon: "star.fill")
                ]
            }
        }
    }
}

// MARK: - CreateChallengeSheet

struct CreateChallengeSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedKind: ChallengeKind = .bet
    @State private var selectedSpice: SpiceLevel = .bold
    @State private var descriptionText = ""
    @State private var selectedStarterId: String? = nil
    @State private var targetUserId: String? = nil
    @State private var stakeAmount: Int = 25
    @State private var deadlineHours: Double = 24

    // Tea-specific fields
    @State private var teaMode: TeaCreationMode = .quick
    @State private var teaTake: TeaDebateTake = .win
    @State private var teaLinkedBetId: String? = nil
    @State private var teaAnswer = ""
    @State private var teaOptions: [String] = ["", ""]
    @State private var newOptionText = ""

    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var eligibleTargets: [(id: String, name: String)] = []
    @State private var hasAttemptedTargetLoad = false

    private let stakeChips = [10, 25, 50, 100, 250]
    private let deadlineChips: [(String, Double)] = [
        ("1h", 1), ("4h", 4), ("12h", 12), ("24h", 24), ("48h", 48)
    ]

    private var targetUsers: [(id: String, name: String)] {
        eligibleTargets.filter { $0.id != appState.userId }
    }

    private var starterChoices: [ChallengeStarter] {
        selectedKind.starters(for: selectedSpice)
    }

    private var selectedStarter: ChallengeStarter? {
        starterChoices.first(where: { $0.id == selectedStarterId })
    }

    private let betCreationFee = 2
    private let teaCreationFee = 10

    private var isQuickTeaMode: Bool {
        selectedKind == .tea && teaMode == .quick
    }

    private var availableTeaBets: [Bet] {
        let merged = (appState.expandedBets + appState.activeBets)
            .sorted { $0.createdAt > $1.createdAt }
        var seen = Set<String>()
        return merged.filter { bet in
            guard bet.status == .active, !bet.isExpired else { return false }
            if seen.contains(bet.betId) { return false }
            seen.insert(bet.betId)
            return true
        }
    }

    private var linkedTeaBet: Bet? {
        guard let teaLinkedBetId else { return nil }
        return availableTeaBets.first(where: { $0.betId == teaLinkedBetId })
    }

    private var linkedTeaBetTitle: String {
        guard let linkedTeaBet else { return "No linked challenge" }
        let normalized = linkedTeaBet.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "Linked challenge" }
        return normalized
    }

    private var creationFee: Int {
        if isQuickTeaMode { return 0 }
        return selectedKind == .tea ? teaCreationFee : betCreationFee
    }
    private var totalCost: Int {
        selectedKind.needsStake ? creationFee + stakeAmount : creationFee
    }

    private var canSubmit: Bool {
        guard descriptionText.count > 3, !isSubmitting else { return false }
        if selectedKind.needsTarget && targetUserId == nil { return false }
        if selectedKind == .tea {
            if isQuickTeaMode { return true }
            let validOptions = teaOptions.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if teaAnswer.trimmingCharacters(in: .whitespaces).isEmpty { return false }
            if validOptions.count < 2 { return false }
        }
        return true
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: VibeSpacing.xl) {
                    // Drag handle
                    Capsule()
                        .fill(VibeTheme.divider)
                        .frame(width: 36, height: 5)
                        .padding(.top, VibeSpacing.xs)

                    // Header
                    HStack {
                        Button {
                            VibeHaptic.light()
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.backward")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(VibeTheme.textPrimary)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text("New Challenge")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(VibeTheme.textPrimary)

                        Spacer()

                        Color.clear
                            .frame(width: 32, height: 32)
                    }

                    // Type selector
                    typeSelector

                    // Context + suggested starters
                    contextCard
                    if !isQuickTeaMode {
                        spiceSelector
                        starterPicker
                    }

                    // Description
                    descriptionField

                    // Target user (callout / dare only)
                    if selectedKind.needsTarget {
                        targetSelector
                    }

                    // Tea-specific fields
                    if selectedKind == .tea {
                        teaModeSelector
                        if isQuickTeaMode {
                            quickTeaFields
                        } else {
                            teaFields
                        }
                    }

                    // Stake amount (not for tea)
                    if selectedKind.needsStake {
                        stakeSelector
                    }

                    if !isQuickTeaMode {
                        // Deadline
                        deadlineSelector

                        // Cost summary
                        costSummary
                    }

                    // Error
                    if let error = errorMessage {
                        Text(error)
                            .font(VibeTypography.captionLarge)
                            .foregroundColor(VibeTheme.stakeNo)
                            .multilineTextAlignment(.center)
                    }

                    // Submit
                    submitButton

                    Spacer(minLength: VibeSpacing.xxl)
                }
                .padding(.horizontal, VibeSpacing.screenHorizontal)
            }
            .background(VibeTheme.groupedBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                await loadEligibleTargetsIfNeeded()
            }
        }
    }

    // MARK: - Type Selector

    private var typeSelector: some View {
        Picker("Challenge type", selection: $selectedKind) {
            ForEach(ChallengeKind.allCases, id: \.rawValue) { kind in
                Text(kind.label).tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .tint(VibeTheme.betAccent)
        .onChange(of: selectedKind) { _, _ in
            VibeHaptic.selection()
            selectedStarterId = nil
            if !selectedKind.needsTarget {
                targetUserId = nil
            }
            if selectedKind != .tea {
                teaLinkedBetId = nil
            } else {
                teaMode = .quick
            }
        }
        .onChange(of: selectedSpice) { _, _ in
            VibeHaptic.selection()
            selectedStarterId = nil
        }
    }

    // MARK: - Context Card

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            HStack(spacing: VibeSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 34, height: 34)
                    Image(systemName: selectedKind.icon)
                        .font(.system(size: 16, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: VibeSpacing.xxxs) {
                    Text(selectedKind.contextTitle)
                        .font(.system(size: 16, weight: .bold))
                    Text(contextSubtitleText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: VibeSpacing.xs) {
                if isQuickTeaMode {
                    Label("Fast post", systemImage: "bolt.fill")
                    Label("Pick take", systemImage: "chart.bar.fill")
                    Label("Link challenge", systemImage: "link")
                } else {
                    Label(selectedSpice.label, systemImage: selectedSpice.icon)
                    Label("Use a starter", systemImage: "sparkles")
                    if selectedKind.needsStake {
                        Label("Add stake", systemImage: "bolt.fill")
                    }
                    Label("Set deadline", systemImage: "timer")
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(VibeSpacing.md)
        .background(
            LinearGradient(
                colors: [selectedKind.color.opacity(0.95), selectedKind.color.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: VibeTheme.radiusLarge, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .continuousCorner(VibeTheme.radiusLarge)
    }

    // MARK: - Spice Selector

    private var spiceSelector: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.xs) {
            Text("Spice level")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(VibeTheme.textSecondary)

            HStack(spacing: VibeSpacing.xs) {
                ForEach(SpiceLevel.allCases, id: \.rawValue) { level in
                    Button {
                        selectedSpice = level
                    } label: {
                        VStack(spacing: VibeSpacing.xxxs) {
                            HStack(spacing: VibeSpacing.xxs) {
                                Image(systemName: level.icon)
                                    .font(.system(size: 11, weight: .bold))
                                Text(level.label)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            Text(level.subtitle)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(selectedSpice == level ? .white.opacity(0.85) : VibeTheme.textSecondary)
                        }
                        .foregroundColor(selectedSpice == level ? .white : VibeTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VibeSpacing.xs)
                        .background(selectedSpice == level ? selectedKind.color : VibeTheme.surfaceOverlay)
                        .continuousCorner(VibeTheme.radiusMedium)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Starter Picker

    private var starterPicker: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.xs) {
            Text("Pick a \(selectedSpice.label.lowercased()) starter")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(VibeTheme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VibeSpacing.xs) {
                    Button {
                        VibeHaptic.selection()
                        useCustomDescription()
                    } label: {
                        HStack(spacing: VibeSpacing.xs) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Other")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(selectedStarterId == nil ? .white : VibeTheme.textPrimary)
                        .padding(.horizontal, VibeSpacing.sm)
                        .padding(.vertical, VibeSpacing.sm)
                        .background(selectedStarterId == nil ? selectedKind.color : VibeTheme.surfaceOverlay)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    ForEach(starterChoices) { starter in
                        Button {
                            VibeHaptic.selection()
                            applyStarter(starter)
                        } label: {
                            VStack(alignment: .leading, spacing: VibeSpacing.xxs) {
                                HStack(spacing: VibeSpacing.xxs) {
                                    Image(systemName: starter.icon)
                                        .font(.system(size: 11, weight: .bold))
                                    Text(starter.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .lineLimit(1)
                                }
                                Text(starter.subtitle)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                    .foregroundColor(
                                        selectedStarterId == starter.id
                                        ? .white.opacity(0.85)
                                        : VibeTheme.textSecondary
                                    )
                            }
                            .foregroundColor(selectedStarterId == starter.id ? .white : VibeTheme.textPrimary)
                            .frame(width: 158, alignment: .leading)
                            .padding(VibeSpacing.sm)
                            .background(
                                selectedStarterId == starter.id
                                ? selectedKind.color
                                : VibeTheme.surfaceOverlay
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: VibeTheme.radiusMedium, style: .continuous)
                                    .stroke(
                                        selectedStarterId == starter.id
                                        ? .clear
                                        : VibeTheme.divider,
                                        lineWidth: 1
                                    )
                            )
                            .continuousCorner(VibeTheme.radiusMedium)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Description Field

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.xs) {
            Text("Description")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(VibeTheme.textSecondary)

            Text(descriptionHintText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(VibeTheme.textTertiary)

            ZStack(alignment: .topLeading) {
                if descriptionText.isEmpty {
                    Text(descriptionPlaceholder)
                        .font(VibeTypography.bodyMedium)
                        .foregroundColor(VibeTheme.textQuaternary)
                        .padding(.horizontal, VibeSpacing.sm)
                        .padding(.vertical, VibeSpacing.sm)
                }

                TextEditor(text: $descriptionText)
                    .font(VibeTypography.bodyMedium)
                    .foregroundColor(VibeTheme.textPrimary)
                    .frame(minHeight: 80, maxHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, VibeSpacing.xs)
                    .padding(.vertical, VibeSpacing.xxs)
            }
            .background(VibeTheme.cardBackground)
            .continuousCorner(VibeTheme.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: VibeTheme.radiusMedium, style: .continuous)
                    .stroke(selectedStarter == nil ? VibeTheme.divider : selectedKind.color.opacity(0.45), lineWidth: 1)
            )

            HStack {
                Spacer()
                Text("\(descriptionText.count)/500")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(descriptionText.count > 500 ? VibeTheme.stakeNo : VibeTheme.textTertiary)
            }
        }
        .onChange(of: descriptionText) { _, newValue in
            if newValue.count > 500 {
                descriptionText = String(newValue.prefix(500))
            }
        }
    }

    private func applyStarter(_ starter: ChallengeStarter) {
        selectedStarterId = starter.id
        descriptionText = starter.template
    }

    private func useCustomDescription() {
        if let template = selectedStarter?.template, descriptionText == template {
            descriptionText = ""
        }
        selectedStarterId = nil
    }

    private var contextSubtitleText: String {
        if isQuickTeaMode {
            return "Drop a fast signal on who wins, so the chat can debate and adjust stakes in real time."
        }
        return selectedKind.contextSubtitle
    }

    private var descriptionHintText: String {
        if isQuickTeaMode {
            return "One line max. Fast signal that helps friends decide whether to stake up or switch sides."
        }
        return selectedStarter == nil
            ? "Write your own or pick a starter above."
            : "Starter loaded. Edit it to match your vibe."
    }

    private var descriptionPlaceholder: String {
        if isQuickTeaMode {
            return "Example: Liam looked shaky at warmup. I think he loses this."
        }
        return selectedKind.placeholder
    }

    // MARK: - Target Selector

    private var targetSelector: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.xs) {
            Text("Target")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(VibeTheme.textSecondary)

            if targetUsers.isEmpty {
                Text("No eligible targets in your network for this chat yet.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(VibeTheme.textTertiary)
                    .padding(.vertical, VibeSpacing.xs)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: VibeSpacing.xs) {
                        ForEach(targetUsers, id: \.id) { user in
                            Button {
                                VibeHaptic.selection()
                                withAnimation(VibeAnimation.snappy) {
                                    targetUserId = user.id
                                }
                            } label: {
                                HStack(spacing: VibeSpacing.xxs) {
                                    Circle()
                                        .fill(selectedKind.color.opacity(0.15))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Text(String(user.name.prefix(1)))
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(selectedKind.color)
                                        )

                                    Text("@\(user.name)")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(targetUserId == user.id ? .white : VibeTheme.textPrimary)
                                .padding(.horizontal, VibeSpacing.sm)
                                .padding(.vertical, VibeSpacing.xs)
                                .background(targetUserId == user.id ? selectedKind.color : VibeTheme.surfaceOverlay)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tea Mode

    private var teaModeSelector: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.xs) {
            Text("Tea mode")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(VibeTheme.textSecondary)

            HStack(spacing: VibeSpacing.xs) {
                ForEach(TeaCreationMode.allCases, id: \.rawValue) { mode in
                    Button {
                        VibeHaptic.selection()
                        withAnimation(VibeAnimation.snappy) {
                            teaMode = mode
                        }
                    } label: {
                        VStack(spacing: VibeSpacing.xxxs) {
                            Text(mode.label)
                                .font(.system(size: 12, weight: .semibold))
                            Text(mode.subtitle)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(teaMode == mode ? .white.opacity(0.85) : VibeTheme.textSecondary)
                        }
                        .foregroundColor(teaMode == mode ? .white : VibeTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VibeSpacing.xs)
                        .background(teaMode == mode ? VibeTheme.accentCyan : VibeTheme.surfaceOverlay)
                        .continuousCorner(VibeTheme.radiusMedium)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Quick Tea Fields

    private var quickTeaFields: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.md) {
            VStack(alignment: .leading, spacing: VibeSpacing.xs) {
                Text("Your take")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(VibeTheme.textSecondary)

                HStack(spacing: VibeSpacing.xs) {
                    ForEach(TeaDebateTake.allCases, id: \.rawValue) { take in
                        Button {
                            VibeHaptic.selection()
                            withAnimation(VibeAnimation.snappy) {
                                teaTake = take
                            }
                        } label: {
                            HStack(spacing: VibeSpacing.xxs) {
                                Image(systemName: take.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(take.label)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(teaTake == take ? .white : VibeTheme.textPrimary)
                            .padding(.horizontal, VibeSpacing.sm)
                            .padding(.vertical, VibeSpacing.xs)
                            .background(teaTake == take ? VibeTheme.accentCyan : VibeTheme.surfaceOverlay)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: VibeSpacing.xs) {
                Text("Link to challenge (optional)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(VibeTheme.textSecondary)

                Menu {
                    Button("No linked challenge") {
                        teaLinkedBetId = nil
                    }

                    if !availableTeaBets.isEmpty {
                        Divider()
                    }

                    ForEach(availableTeaBets.prefix(10), id: \.betId) { bet in
                        Button(bet.description) {
                            teaLinkedBetId = bet.betId
                        }
                    }
                } label: {
                    HStack {
                        Text(linkedTeaBetTitle)
                            .font(VibeTypography.bodySmall)
                            .foregroundColor(teaLinkedBetId == nil ? VibeTheme.textSecondary : VibeTheme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(VibeTheme.textTertiary)
                    }
                    .padding(VibeSpacing.sm)
                    .background(VibeTheme.cardBackground)
                    .continuousCorner(VibeTheme.radiusMedium)
                    .overlay(
                        RoundedRectangle(cornerRadius: VibeTheme.radiusMedium, style: .continuous)
                            .stroke(VibeTheme.divider, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Tea Spill Fields

    private var teaFields: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.md) {
            // Answer field
            VStack(alignment: .leading, spacing: VibeSpacing.xs) {
                Text("Answer (secret)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(VibeTheme.textSecondary)

                TextField("The real answer...", text: $teaAnswer)
                    .font(VibeTypography.bodyMedium)
                    .foregroundColor(VibeTheme.textPrimary)
                    .padding(VibeSpacing.sm)
                    .background(VibeTheme.cardBackground)
                    .continuousCorner(VibeTheme.radiusMedium)
                    .overlay(
                        RoundedRectangle(cornerRadius: VibeTheme.radiusMedium, style: .continuous)
                            .stroke(VibeTheme.divider, lineWidth: 1)
                    )
            }

            // Options
            VStack(alignment: .leading, spacing: VibeSpacing.xs) {
                Text("Options (2-4)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(VibeTheme.textSecondary)

                ForEach(teaOptions.indices, id: \.self) { index in
                    HStack(spacing: VibeSpacing.xs) {
                        TextField("Option \(index + 1)", text: $teaOptions[index])
                            .font(VibeTypography.bodyMedium)
                            .foregroundColor(VibeTheme.textPrimary)
                            .padding(VibeSpacing.sm)
                            .background(VibeTheme.cardBackground)
                            .continuousCorner(VibeTheme.radiusSmall)
                            .overlay(
                                RoundedRectangle(cornerRadius: VibeTheme.radiusSmall, style: .continuous)
                                    .stroke(VibeTheme.divider, lineWidth: 1)
                            )

                        if teaOptions.count > 2 {
                            Button {
                                VibeHaptic.light()
                                withAnimation(VibeAnimation.snappy) {
                                    _ = teaOptions.remove(at: index)
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(VibeTheme.stakeNo.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if teaOptions.count < 4 {
                    Button {
                        VibeHaptic.light()
                        withAnimation(VibeAnimation.snappy) {
                            teaOptions.append("")
                        }
                    } label: {
                        HStack(spacing: VibeSpacing.xxs) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("Add Option")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(VibeTheme.betAccent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Stake Selector

    private var stakeSelector: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.xs) {
            Text("Stake")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(VibeTheme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VibeSpacing.xs) {
                    ForEach(stakeChips, id: \.self) { amount in
                        Button {
                            VibeHaptic.selection()
                            withAnimation(VibeAnimation.snappy) {
                                stakeAmount = amount
                            }
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                                Text("\(amount)")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            }
                            .foregroundColor(stakeAmount == amount ? .white : VibeTheme.textPrimary)
                            .padding(.horizontal, VibeSpacing.sm)
                            .padding(.vertical, VibeSpacing.xs)
                            .background(stakeAmount == amount ? VibeTheme.betAccent : VibeTheme.surfaceOverlay)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Deadline Selector

    private var deadlineSelector: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.xs) {
            Text("Deadline")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(VibeTheme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VibeSpacing.xs) {
                    ForEach(deadlineChips, id: \.1) { chip in
                        Button {
                            VibeHaptic.selection()
                            withAnimation(VibeAnimation.snappy) {
                                deadlineHours = chip.1
                            }
                        } label: {
                            Text(chip.0)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(deadlineHours == chip.1 ? .white : VibeTheme.textPrimary)
                                .padding(.horizontal, VibeSpacing.sm)
                                .padding(.vertical, VibeSpacing.xs)
                                .background(deadlineHours == chip.1 ? VibeTheme.betAccent : VibeTheme.surfaceOverlay)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Cost Summary

    private var costSummary: some View {
        VStack(spacing: VibeSpacing.xs) {
            HStack {
                Text("Creation Fee")
                    .font(VibeTypography.captionLarge)
                    .foregroundColor(VibeTheme.textSecondary)
                Spacer()
                AuraBadge(amount: creationFee, size: .small)
            }

            if selectedKind.needsStake {
                HStack {
                    Text("Stake")
                        .font(VibeTypography.captionLarge)
                        .foregroundColor(VibeTheme.textSecondary)
                    Spacer()
                    AuraBadge(amount: stakeAmount, size: .small)
                }
            }

            Divider()

            HStack {
                Text("Total")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(VibeTheme.textPrimary)
                Spacer()
                AuraBadge(amount: totalCost, size: .regular)
            }
        }
        .padding(VibeSpacing.md)
        .background(VibeTheme.cardBackground)
        .continuousCorner(VibeTheme.radiusMedium)
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            VibeHaptic.medium()
            submit()
        } label: {
            HStack(spacing: VibeSpacing.xs) {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(submitButtonTitle)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: VibeSpacing.minTouchTarget)
            .background(canSubmit ? VibeTheme.betAccent : Color(UIColor.systemGray3))
            .continuousCorner(VibeTheme.radiusMedium)
        }
        .buttonStyle(VibePressStyle())
        .disabled(!canSubmit)
    }

    private var submitButtonTitle: String {
        if isQuickTeaMode {
            return "Post Tea Take"
        }
        return selectedKind == .tea ? "Post Tea" : "Create Challenge"
    }

    // MARK: - Submit Logic

    private func submit() {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil

        let trimmedDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let deadline = Date().addingTimeInterval(deadlineHours * 3600)

        Task {
            do {
                if selectedKind == .tea {
                    if isQuickTeaMode {
                        let contextPrefix: String
                        switch teaTake {
                        case .win:
                            contextPrefix = "☕️ Will Win"
                        case .lose:
                            contextPrefix = "☕️ Will Lose"
                        case .uncertain:
                            contextPrefix = "☕️ 50/50"
                        }

                        let linkedSegment: String
                        if let linkedTeaBet {
                            linkedSegment = " on \(appState.nameForUser(linkedTeaBet.creatorId))"
                        } else {
                            linkedSegment = ""
                        }

                        let composedTeaText = "\(contextPrefix)\(linkedSegment): \(trimmedDescription)"
                        let vibe = try await appState.createVibe(
                            type: .tea,
                            textStatus: composedTeaText,
                            styleName: "Quick",
                            isLocked: false
                        )
                        appState.sendVibeMessage(
                            vibeId: vibe.id,
                            isLocked: false,
                            vibeType: .tea,
                            contextText: composedTeaText,
                            linkedBetId: teaLinkedBetId
                        )
                    } else {
                        let validOptions = teaOptions.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                        _ = try await appState.createTeaSpill(
                            mysteryText: trimmedDescription,
                            answer: teaAnswer,
                            options: validOptions,
                            deadline: deadline
                        )
                    }
                } else if let betType = selectedKind.betType {
                    let createdBet = try await appState.createBet(
                        betType: betType,
                        description: trimmedDescription,
                        deadline: deadline,
                        initialStake: stakeAmount,
                        initialSide: .yes,
                        targetUserId: selectedKind.needsTarget ? targetUserId : nil
                    )

                    // Keep challenge creation resilient: challenge should still succeed even if bubble send fails.
                    do {
                        _ = try await appState.publishChallengeMessage(
                            bet: createdBet,
                            title: trimmedDescription,
                            amount: stakeAmount,
                            targetUserId: selectedKind.needsTarget ? targetUserId : nil
                        )
                    } catch {
                        print("CreateChallengeSheet Warning: Challenge created but failed to send iMessage bubble: \(error)")
                    }
                }
                VibeHaptic.success()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }

    // MARK: - Members

    private struct EligibleTargetUser: Decodable {
        let id: String
        let firstName: String?
        let lastName: String?
        let profilePicture: String?

        var displayName: String {
            let fullName = "\(firstName ?? "") \(lastName ?? "")".trimmingCharacters(in: .whitespaces)
            return fullName.isEmpty ? "User" : fullName
        }
    }

    private struct EligibleTargetsResponse: Decodable {
        let targets: [EligibleTargetUser]
    }

    private func mapAndApplyTargets(_ values: [(id: String, name: String)]) async {
        let filtered = values
            .filter { !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.id != appState.userId }
            .sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })

        await MainActor.run {
            eligibleTargets = filtered
            if let selected = targetUserId,
               !filtered.contains(where: { $0.id == selected }) {
                targetUserId = nil
            }
        }
    }

    private func loadEligibleTargetsIfNeeded() async {
        guard !hasAttemptedTargetLoad else { return }
        hasAttemptedTargetLoad = true
        do {
            let chatId = try await appState.awaitResolvedChatId()
            let response: EligibleTargetsResponse = try await APIClient.shared.get("/bets/chat/\(chatId)/eligible-targets")
            let mapped = response.targets.map { (id: $0.id, name: $0.displayName) }
            await mapAndApplyTargets(mapped)
        } catch {
            // Keep sheet usable even if target loading fails.
            await MainActor.run {
                eligibleTargets = []
                targetUserId = nil
            }
        }
    }
}
