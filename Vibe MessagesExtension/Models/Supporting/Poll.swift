//
//  Poll.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import Foundation

struct PollOption: Codable, Equatable, Identifiable {
    let id: String
    let text: String
    var votes: [String]

    init(id: String = UUID().uuidString, text: String, votes: [String] = []) {
        self.id = id
        self.text = text
        self.votes = votes
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case text
        case votes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Handle both "_id" and "id" formats
        if let id = try? container.decode(String.self, forKey: .id) {
            self.id = id
        } else {
            self.id = UUID().uuidString
        }
        self.text = try container.decode(String.self, forKey: .text)
        self.votes = try container.decodeIfPresent([String].self, forKey: .votes) ?? []
    }
}

struct Poll: Codable, Equatable {
    let question: String
    var options: [PollOption]

    var totalVotes: Int {
        options.reduce(0) { $0 + $1.votes.count }
    }

    func hasVoted(userId: String) -> Bool {
        options.contains { $0.votes.contains(userId) }
    }

    func votedOption(userId: String) -> String? {
        options.first { $0.votes.contains(userId) }?.id
    }

    func votePercentage(for optionId: String) -> Double {
        guard totalVotes > 0 else { return 0 }
        guard let option = options.first(where: { $0.id == optionId }) else { return 0 }
        return Double(option.votes.count) / Double(totalVotes) * 100
    }
}
