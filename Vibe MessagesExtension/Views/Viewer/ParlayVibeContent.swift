//
//  ParlayVibeContent.swift
//  Vibe MessagesExtension
//
//  Interactive viewer for Parlay (bet) vibes.
//

import SwiftUI

struct ParlayVibeContent: View {
    let vibe: Vibe
    @EnvironmentObject var appState: AppState
    
    // Theme Colors
    let vibezPink = Color(red: 1.0, green: 0.2, blue: 0.6)
    let vibezPurple = Color(red: 0.6, green: 0.2, blue: 1.0)
    
    private var parlay: Parlay? {
        vibe.parlay
    }
    
    private var isSender: Bool {
        vibe.userId == appState.userId
    }
    
    private var isOpponent: Bool {
        // If an opponent was explicitly named, check if this user matches (future: use IDs)
        // For now, if no opponentId is set, anyone can respond except the sender
        if let opponentId = parlay?.opponentId {
            return opponentId == appState.userId
        }
        return !isSender
    }
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [Color.black, Color(red: 0.1, green: 0, blue: 0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [vibezPink.opacity(0.2), vibezPurple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    Text("💸")
                        .font(.system(size: 50))
                }
                .padding(.top, 40)
                
                // Bet Question/Title
                VStack(spacing: 12) {
                    Text(parlay?.displayTitle ?? "Friendly Bet")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if let amount = parlay?.displayAmount, !amount.isEmpty {
                        Text(amount)
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundColor(vibezPink)
                    }
                }
                
                // Status Section
                VStack(spacing: 8) {
                    if let status = parlay?.status {
                        statusBadge(for: status)
                    }
                    
                    if let opponentName = parlay?.opponentName {
                        Text("vs \(opponentName)")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                // Action Buttons (Only for the opponent and if pending)
                if parlay?.status == .pending && isOpponent {
                    VStack(spacing: 16) {
                        Button {
                            Task {
                                await appState.respondToParlay(on: vibe, status: .accepted)
                            }
                        } label: {
                            Text("Accept Bet")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    LinearGradient(
                                        colors: [vibezPink, vibezPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(20)
                        }
                        
                        Button {
                            Task {
                                await appState.respondToParlay(on: vibe, status: .declined)
                            }
                        } label: {
                            Text("Decline")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
                } else if parlay?.status == .accepted {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        Text("Bet is On!")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 60)
                } else if parlay?.status == .declined {
                    VStack(spacing: 10) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red.opacity(0.7))
                        Text("Bet Declined")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.bottom, 60)
                } else {
                    // Just wait for opponent
                    Text("Waiting for \(parlay?.opponentName ?? "opponent")...")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.bottom, 60)
                }
            }
        }
    }
    
    @ViewBuilder
    private func statusBadge(for status: ParlayStatus) -> some View {
        let color: Color = {
            switch status {
            case .pending: return .orange
            case .accepted: return .green
            case .declined: return .red
            case .settled: return .blue
            case .active: return .purple
            case .resolved: return .gray
            case .cancelled: return .gray
            }
        }()
        
        Text(status.rawValue.uppercased())
            .font(.system(size: 12, weight: .black))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.3))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
    }
}
