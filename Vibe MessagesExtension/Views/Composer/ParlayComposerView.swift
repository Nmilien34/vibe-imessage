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

    // Theme Colors
    let vibezPink = Color(red: 1.0, green: 0.2, blue: 0.6)
    let vibezPurple = Color(red: 0.6, green: 0.2, blue: 1.0)
    let bgOffWhite = Color(red: 0.96, green: 0.96, blue: 0.97)

    // State
    @State private var betTitle = ""
    @State private var selectedAmountIndex = 2
    @State private var showCustomAmountSheet = false
    @State private var customAmount = ""
    @State private var selectedFriend: String? = nil
    @State private var selectedQuickBet: String? = nil
    @State private var isSending = false

    let amounts = ["$5", "$10", "$20", "$30", "$50", "$100", "Other..."]
    let quickBets = ["Sports Game", "Weather tmrw", "Finish pizza", "FIFA match", "Who pays dinner"]
    let friends = ["Mike", "Sarah", "Jess", "Davon", "Alex"]

    var finalDisplayAmount: String {
        if amounts[selectedAmountIndex] == "Other..." {
            return customAmount.isEmpty ? "$0" : "$\(customAmount)"
        } else {
            return amounts[selectedAmountIndex]
        }
    }

    var body: some View {
        ZStack {
            bgOffWhite.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        appState.dismissComposer()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .padding(10)
                            .background(Color.white)
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text("New Parlay")
                        .font(.system(size: 20, weight: .bold, design: .rounded))

                    Spacer()

                    Text("💸")
                        .font(.title2)
                        .padding(10)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .background(bgOffWhite)

                ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // MARK: 1. The Bet Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("WHAT'S THE PARLAY?")
                            .font(.caption).bold().foregroundColor(.gray)

                        TextField("E.g., I bet I can beat you in 1v1...", text: $betTitle)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                            .font(.system(size: 16, weight: .medium, design: .rounded))

                        // Quick Bet Chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(quickBets, id: \.self) { bet in
                                    Button {
                                        betTitle = bet
                                        selectedQuickBet = bet
                                    } label: {
                                        Text(bet)
                                            .font(.system(size: 12, weight: .bold))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(Color.white)
                                            .foregroundColor(selectedQuickBet == bet ? vibezPink : .black.opacity(0.7))
                                            .cornerRadius(30)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 30)
                                                    .stroke(selectedQuickBet == bet ? vibezPink.opacity(0.3) : Color.clear, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // MARK: 2. The Wager Roller
                    VStack(spacing: 12) {
                        Text("THE WAGER")
                            .font(.caption).bold().foregroundColor(.gray)

                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white)
                                .frame(height: 180)
                                .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)

                            // Highlight bar
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [vibezPink.opacity(0.15), vibezPurple.opacity(0.15)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 40)
                                .padding(.horizontal)

                            Picker("Amount", selection: $selectedAmountIndex) {
                                ForEach(0..<amounts.count, id: \.self) { index in
                                    Text(amounts[index])
                                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                                        .foregroundColor(index == selectedAmountIndex ? vibezPink : .black)
                                        .tag(index)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 180)
                            .onChange(of: selectedAmountIndex) { _, newValue in
                                if amounts[newValue] == "Other..." {
                                    showCustomAmountSheet = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // MARK: 3. Pick Opponent
                    VStack(alignment: .leading, spacing: 12) {
                        Text("VS WHO?")
                            .font(.caption).bold().foregroundColor(.gray)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(friends, id: \.self) { friend in
                                    VStack {
                                        ZStack {
                                            if selectedFriend == friend {
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [vibezPink, vibezPurple],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .frame(width: 60, height: 60)
                                            } else {
                                                Circle()
                                                    .fill(Color.gray.opacity(0.1))
                                                    .frame(width: 60, height: 60)
                                            }

                                            Text(String(friend.prefix(1)))
                                                .font(.system(size: 24, weight: .bold))
                                                .foregroundColor(selectedFriend == friend ? .white : .gray)
                                        }
                                        Text(friend)
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(selectedFriend == friend ? vibezPink : .primary)
                                    }
                                    .onTapGesture {
                                        withAnimation(.spring()) {
                                            selectedFriend = friend
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 20)

                    // MARK: 4. Send Button
                    Button {
                        Task {
                            await sendParlay()
                        }
                    } label: {
                        HStack {
                            if isSending {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Send Parlay")
                                Spacer()
                                Text(finalDisplayAmount)
                            }
                        }
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(20)
                        .background(
                            LinearGradient(
                                colors: [vibezPink, vibezPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(24)
                        .shadow(color: vibezPink.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .disabled(betTitle.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                    .opacity(betTitle.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
                .padding(.top, 8)
            }
            }
        }
        .sheet(isPresented: $showCustomAmountSheet) {
            CustomAmountSheet(amount: $customAmount, vibezPink: vibezPink, vibezPurple: vibezPurple)
                .presentationDetents([.medium])
        }
        .onAppear {
            appState.requestExpand()
        }
    }

    private func sendParlay() async {
        let title = betTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }

        isSending = true

        do {
            let parlayRequest = CreateParlayRequest(
                title: title,
                question: nil,
                options: nil,
                amount: finalDisplayAmount,
                wager: nil,
                opponentId: nil,
                opponentName: selectedFriend
            )

            let vibe = try await appState.createVibe(
                type: .parlay,
                parlay: parlayRequest,
                isLocked: isLocked
            )

            let contextText = "\(title)|\(finalDisplayAmount)|\(selectedFriend ?? "Anyone")"
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
}

// MARK: - Custom Amount Sheet
struct CustomAmountSheet: View {
    @Binding var amount: String
    @Environment(\.dismiss) var dismiss
    let vibezPink: Color
    let vibezPurple: Color

    var body: some View {
        VStack(spacing: 20) {
            Text("Enter Amount")
                .font(.headline)
                .padding(.top, 20)

            HStack {
                Text("$")
                    .font(.title)
                    .bold()
                    .foregroundColor(.gray)
                TextField("0", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(vibezPink)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(20)
            .padding(.horizontal)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [vibezPink, vibezPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
            }
            .padding(.horizontal)

            Spacer()
        }
    }
}
