//
//  TeaSpillService.swift
//  Vibe MessagesExtension
//
//  Service for Tea Spill guessing game API calls.
//  Backend routes: /api/tea/*
//

import Foundation

actor TeaSpillService {
    static let shared = TeaSpillService()
    private let api = APIClient.shared

    private init() {}

    // MARK: - Create Tea Spill

    struct CreateTeaRequest: Encodable {
        let chatId: String
        let mysteryText: String
        let answer: String
        let options: [String]
        let deadline: Date
    }

    func createTeaSpill(
        chatId: String,
        mysteryText: String,
        answer: String,
        options: [String],
        deadline: Date
    ) async throws -> TeaSpill {
        let response: TeaCreateResponse = try await api.post(
            "/tea/create",
            body: CreateTeaRequest(
                chatId: chatId,
                mysteryText: mysteryText,
                answer: answer,
                options: options,
                deadline: deadline
            )
        )
        return response.tea
    }

    // MARK: - Guess on Tea Spill

    struct GuessRequest: Encodable {
        let guess: String
        let amount: Int
    }

    func guessTeaSpill(teaId: String, guess: String, amount: Int) async throws -> TeaGuess {
        let response: TeaGuessResponse = try await api.post(
            "/tea/\(teaId)/guess",
            body: GuessRequest(guess: guess, amount: amount)
        )
        return response.guess
    }

    // MARK: - Reveal Tea Spill

    func revealTeaSpill(teaId: String) async throws -> TeaRevealResponse {
        return try await api.postEmpty("/tea/\(teaId)/reveal")
    }

    // MARK: - Get Tea Spills for Chat

    func getTeaSpills(chatId: String, status: TeaSpillStatus? = nil, limit: Int = 20, offset: Int = 0) async throws -> TeaListResponse {
        var path = "/tea/chat/\(chatId)?limit=\(limit)&offset=\(offset)"
        if let status = status {
            path += "&status=\(status.rawValue)"
        }
        return try await api.get(path)
    }

    // MARK: - Get Single Tea Spill

    func getTeaSpill(teaId: String) async throws -> TeaSpill {
        return try await api.get("/tea/\(teaId)")
    }

    // MARK: - Get Guesses

    func getGuesses(teaId: String) async throws -> TeaGuessListResponse {
        return try await api.get("/tea/\(teaId)/guesses")
    }
}
