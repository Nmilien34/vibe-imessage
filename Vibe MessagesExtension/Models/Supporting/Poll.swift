//
//  Poll.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import Foundation

// Backend vote structure
struct PollVote: Codable, Equatable {
    let userId: String
    let optionIndex: Int
}

// Display-friendly option structure (computed from backend data)
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
        // Handle both "_id" and "id" formats, or generate one
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
    let question: String?
    var options: [PollOption]
    var votes: [PollVote]?  // Backend stores votes separately

    // Computed options with vote data merged (for display)
    var optionsWithVotes: [PollOption] {
        guard let backendVotes = votes else { return options }

        return options.enumerated().map { index, option in
            let votersForOption = backendVotes
                .filter { $0.optionIndex == index }
                .map { $0.userId }
            return PollOption(id: option.id, text: option.text, votes: votersForOption)
        }
    }

    var totalVotes: Int {
        if let backendVotes = votes {
            return backendVotes.count
        }
        return options.reduce(0) { $0 + $1.votes.count }
    }

    func hasVoted(userId: String) -> Bool {
        if let backendVotes = votes {
            return backendVotes.contains { $0.userId == userId }
        }
        return options.contains { $0.votes.contains(userId) }
    }

    func votedOptionIndex(userId: String) -> Int? {
        if let backendVotes = votes {
            return backendVotes.first { $0.userId == userId }?.optionIndex
        }
        return options.firstIndex { $0.votes.contains(userId) }
    }

    func votedOption(userId: String) -> String? {
        if let index = votedOptionIndex(userId: userId), index < options.count {
            return options[index].id
        }
        return options.first { $0.votes.contains(userId) }?.id
    }

    func votePercentage(for optionIndex: Int) -> Double {
        guard totalVotes > 0, optionIndex < options.count else { return 0 }

        if let backendVotes = votes {
            let count = backendVotes.filter { $0.optionIndex == optionIndex }.count
            return Double(count) / Double(totalVotes) * 100
        }

        return Double(options[optionIndex].votes.count) / Double(totalVotes) * 100
    }

    // Custom decoder to handle backend format (options as strings)
    enum CodingKeys: String, CodingKey {
        case question
        case options
        case votes
    }

    init(question: String?, options: [PollOption], votes: [PollVote]? = nil) {
        self.question = question
        self.options = options
        self.votes = votes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.question = try container.decodeIfPresent(String.self, forKey: .question)
        self.votes = try container.decodeIfPresent([PollVote].self, forKey: .votes)

        // Try to decode options as PollOption array first
        if let pollOptions = try? container.decode([PollOption].self, forKey: .options) {
            self.options = pollOptions
        }
        // Fall back to decoding as string array (backend format)
        else if let stringOptions = try? container.decode([String].self, forKey: .options) {
            self.options = stringOptions.enumerated().map { index, text in
                PollOption(id: String(index), text: text)
            }
        }
        else {
            self.options = []
        }
    }
}
