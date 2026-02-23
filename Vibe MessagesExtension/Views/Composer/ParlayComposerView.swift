//
//  ParlayComposerView.swift
//  Vibe MessagesExtension
//
//  Parlay (bet/wager) creation view.
//

import SwiftUI

struct ParlayComposerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let isLocked: Bool

    private struct TargetOption: Identifiable, Hashable {
        let id: String
        let userId: String?
        let name: String
    }

    @State private var betTitle = ""
    @State private var selectedAmountIndex = 2
    @State private var showCustomAmountSheet = false
    @State private var customAmount = ""
    @State private var selectedTargetUserId: String? = nil
    @State private var selectedQuickBet: String? = nil
    @State private var isSending = false
    @State private var eligibleTargets: [(id: String, name: String)] = []
    @State private var hasAttemptedTargetLoad = false

    let amounts = ["$5", "$10", "$20", "$30", "$50", "$100", "Other..."]
    let quickBets = ["Sports Game", "Weather tmrw", "Finish pizza", "FIFA match", "Who pays dinner"]

    private var targetOptions: [TargetOption] {
        [TargetOption(id: "anyone", userId: nil, name: "Anyone")]
            + eligibleTargets.map { TargetOption(id: $0.id, userId: $0.id, name: $0.name) }
    }

    private var selectedTargetName: String {
        guard let selectedTargetUserId else { return "Anyone" }
        return targetOptions.first(where: { $0.userId == selectedTargetUserId })?.name ?? "Anyone"
    }

    var finalDisplayAmount: String {
        if amounts[selectedAmountIndex] == "Other..." {
            return customAmount.isEmpty ? "$0" : "$\(customAmount)"
        } else {
            return amounts[selectedAmountIndex]
        }
    }

    var body: some View {
        ZStack {
            VibeTheme.groupedBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        VibeHaptic.light()
                        appState.dismissComposer()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(VibeTheme.textPrimary)
                            .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text("New Parlay")
                        .font(VibeTypography.titleLarge)
                        .foregroundColor(VibeTheme.textPrimary)

                    Spacer()

                    // Aura cost indicator
                    HStack(spacing: VibeSpacing.xxs) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                        Text("\(appState.auraBalance)")
                            .font(VibeTypography.captionLarge)
                    }
                    .padding(.horizontal, VibeSpacing.sm)
                    .padding(.vertical, VibeSpacing.xs)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
                .padding(.horizontal, VibeSpacing.screenHorizontal)
                .padding(.top, VibeSpacing.lg)
                .padding(.bottom, VibeSpacing.sm)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: VibeSpacing.xl) {

                        // MARK: 1. The Bet Input
                        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                            Text("WHAT'S THE PARLAY?")
                                .vibeSectionHeader()

                            TextField("E.g., I bet I can beat you in 1v1...", text: $betTitle)
                                .font(VibeTypography.bodyLarge)
                                .padding(VibeSpacing.md)
                                .background(.ultraThinMaterial)
                                .continuousCorner(VibeTheme.radiusLarge)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: VibeSpacing.sm) {
                                    ForEach(quickBets, id: \.self) { bet in
                                        Button {
                                            VibeHaptic.selection()
                                            betTitle = bet
                                            selectedQuickBet = bet
                                        } label: {
                                            Text(bet)
                                                .font(VibeTypography.captionLarge)
                                                .padding(.horizontal, VibeSpacing.md)
                                                .padding(.vertical, VibeSpacing.sm)
                                                .background(.ultraThinMaterial)
                                                .foregroundColor(selectedQuickBet == bet ? VibeTheme.accent : VibeTheme.textPrimary)
                                                .continuousCorner(VibeTheme.radiusXL)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: VibeTheme.radiusXL, style: .continuous)
                                                        .stroke(selectedQuickBet == bet ? VibeTheme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, VibeSpacing.screenHorizontal)

                        // MARK: 2. The Wager Roller
                        VStack(spacing: VibeSpacing.sm) {
                            Text("THE WAGER")
                                .vibeSectionHeader()
                                .padding(.horizontal, VibeSpacing.screenHorizontal)

                            ZStack {
                                RoundedRectangle(cornerRadius: VibeTheme.radiusLarge, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .frame(height: 180)
                                    .vibeShadow(.sm)

                                RoundedRectangle(cornerRadius: VibeTheme.radiusMedium, style: .continuous)
                                    .fill(VibeTheme.accent.opacity(0.1))
                                    .frame(height: 40)
                                    .padding(.horizontal, VibeSpacing.md)

                                Picker("Amount", selection: $selectedAmountIndex) {
                                    ForEach(0..<amounts.count, id: \.self) { index in
                                        Text(amounts[index])
                                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                                            .foregroundColor(index == selectedAmountIndex ? VibeTheme.accent : VibeTheme.textPrimary)
                                            .tag(index)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 180)
                                .onChange(of: selectedAmountIndex) { _, newValue in
                                    VibeHaptic.selection()
                                    if amounts[newValue] == "Other..." {
                                        showCustomAmountSheet = true
                                    }
                                }
                            }
                            .padding(.horizontal, VibeSpacing.screenHorizontal)
                        }

                        // MARK: 3. Pick Opponent
                        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                            Text("VS WHO?")
                                .vibeSectionHeader()

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: VibeSpacing.md) {
                                    ForEach(targetOptions) { option in
                                        let isSelected = selectedTargetUserId == option.userId
                                        VStack(spacing: VibeSpacing.xs) {
                                            ZStack {
                                                if isSelected {
                                                    Circle()
                                                        .fill(VibeTheme.brandGradient)
                                                        .frame(width: 60, height: 60)
                                                } else {
                                                    Circle()
                                                        .fill(.ultraThinMaterial)
                                                        .frame(width: 60, height: 60)
                                                }

                                                Text(String(option.name.prefix(1)))
                                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                                    .foregroundColor(isSelected ? .white : VibeTheme.textSecondary)
                                            }
                                            Text(option.name)
                                                .font(VibeTypography.captionSmall)
                                                .foregroundColor(isSelected ? VibeTheme.accent : VibeTheme.textPrimary)
                                        }
                                        .onTapGesture {
                                            VibeHaptic.selection()
                                            withAnimation(VibeAnimation.bouncy) {
                                                selectedTargetUserId = option.userId
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, VibeSpacing.xxs)
                            }
                        }
                        .padding(.horizontal, VibeSpacing.screenHorizontal)

                        Spacer(minLength: VibeSpacing.lg)

                        // MARK: 4. Send Button
                        Button {
                            VibeHaptic.success()
                            Task { await sendParlay() }
                        } label: {
                            HStack {
                                if isSending {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Send Parlay")
                                    Spacer()
                                    Text(finalDisplayAmount)
                                }
                            }
                            .font(VibeTypography.titleMedium)
                            .foregroundColor(.white)
                            .padding(VibeSpacing.lg)
                            .background(VibeTheme.brandGradient)
                            .continuousCorner(VibeTheme.radiusLarge)
                            .vibeShadow(.lg)
                        }
                        .buttonStyle(VibePressStyle())
                        .disabled(betTitle.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                        .opacity(betTitle.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                        .padding(.horizontal, VibeSpacing.screenHorizontal)
                        .padding(.bottom, VibeSpacing.xxl)
                    }
                    .padding(.top, VibeSpacing.xs)
                }
            }
        }
        .sheet(isPresented: $showCustomAmountSheet) {
            CustomAmountSheet(amount: $customAmount)
                .presentationDetents([.medium])
        }
        .onAppear {
            appState.requestExpand()
            Task {
                await loadEligibleTargetsIfNeeded()
            }
        }
    }

    private func sendParlay() async {
        let title = betTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        isSending = true

        do {
            // Create a real challenge record first so this parlay vibe deep-links to a specific bet.
            let initialStake = max(10, Int(finalDisplayAmount.filter(\.isNumber)) ?? 25)
            let betType: BetType = selectedTargetUserId == nil ? .self : .dare
            let opponentName: String? = selectedTargetUserId == nil ? nil : selectedTargetName
            let linkedBet = try await appState.createBet(
                betType: betType,
                description: title,
                deadline: Date().addingTimeInterval(24 * 60 * 60),
                initialStake: initialStake,
                initialSide: .yes,
                targetUserId: selectedTargetUserId
            )

            let parlayRequest = CreateParlayRequest(
                title: title,
                question: nil,
                options: nil,
                betId: linkedBet.betId,
                amount: finalDisplayAmount,
                wager: nil,
                opponentId: selectedTargetUserId,
                opponentName: opponentName
            )

            let vibe = try await appState.createVibe(
                type: .parlay,
                parlay: parlayRequest,
                isLocked: isLocked
            )

            let contextText = "\(title)|\(finalDisplayAmount)|\(selectedTargetName)"
            appState.sendVibeMessage(
                vibeId: vibe.id,
                isLocked: isLocked,
                vibeType: .parlay,
                contextText: contextText
            )

            appState.dismissComposer()
        } catch {
            print("Error sending parlay: \(error)")
        }

        isSending = false
    }

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
            if let selectedTargetUserId,
               !filtered.contains(where: { $0.id == selectedTargetUserId }) {
                self.selectedTargetUserId = nil
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
            await MainActor.run {
                eligibleTargets = []
                selectedTargetUserId = nil
            }
        }
    }
}

// MARK: - Custom Amount Sheet
struct CustomAmountSheet: View {
    @Binding var amount: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: VibeSpacing.lg) {
            Text("Enter Amount")
                .font(VibeTypography.titleMedium)
                .padding(.top, VibeSpacing.lg)

            HStack {
                Text("$")
                    .font(VibeTypography.displayLarge)
                    .foregroundColor(VibeTheme.textSecondary)
                TextField("0", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(VibeTheme.accent)
            }
            .padding(VibeSpacing.md)
            .background(.ultraThinMaterial)
            .continuousCorner(VibeTheme.radiusLarge)
            .padding(.horizontal, VibeSpacing.screenHorizontal)

            Button {
                VibeHaptic.light()
                dismiss()
            } label: {
                Text("Done")
                    .vibeButton(.primary)
            }
            .buttonStyle(VibePressStyle())
            .padding(.horizontal, VibeSpacing.screenHorizontal)

            Spacer()
        }
    }
}
