//
//  Parlay.swift
//  Vibe MessagesExtension
//
//  Parlay (bet/wager) data model for friendly bets.
//

import Foundation

enum ParlayStatus: String, Codable {
    case pending    // Waiting for opponent to accept
    case accepted   // Both parties agreed
    case declined   // Opponent declined
    case settled    // Bet resolved (winner determined)
    case active     // Bet is active/in progress
    case resolved   // Bet has been resolved
    case cancelled  // Bet was cancelled
}

struct ParlayVote: Codable, Equatable {
    let oderId: String
    let optionIndex: Int
}

struct Parlay: Codable, Equatable {
    // Core fields
    let title: String?
    let question: String?
    let options: [String]?

    // Bet fields
    let amount: String?
    let wager: String?

    // Opponent fields
    let opponentId: String?
    let opponentName: String?

    // Status and timing
    var status: ParlayStatus?
    let expiresAt: Date?

    // Voting/results
    let votes: [ParlayVote]?
    let winnersReceived: [String]?

    // Computed display properties
    var displayTitle: String {
        title ?? question ?? "Parlay"
    }

    var displayAmount: String {
        amount ?? wager ?? ""
    }
}

struct CreateParlayRequest: Codable {
    let title: String?
    let question: String?
    let options: [String]?
    let amount: String?
    let wager: String?
    let opponentId: String?
    let opponentName: String?
}
