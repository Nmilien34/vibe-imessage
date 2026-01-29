//
//  Parlay.swift
//  Vibe MessagesExtension
//
//  Parlay (bet/wager) data model for friendly bets.
//

import Foundation

struct Parlay: Codable, Equatable {
    let title: String
    let amount: String
    let opponentId: String?
    let opponentName: String?
    var status: ParlayStatus

    enum ParlayStatus: String, Codable {
        case pending    // Waiting for opponent to accept
        case accepted   // Both parties agreed
        case declined   // Opponent declined
        case settled    // Bet resolved (winner determined)
    }
}

struct CreateParlayRequest: Codable {
    let title: String
    let amount: String
    let opponentId: String?
    let opponentName: String?
}
