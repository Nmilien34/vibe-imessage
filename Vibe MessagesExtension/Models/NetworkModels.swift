import Foundation

// MARK: - CachedUser

struct CachedUser: Codable, Identifiable, Equatable {
    let id: String
    let firstName: String?
    let lastName: String?
    let profilePicture: String?

    var displayName: String {
        let parts = [firstName, lastName].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return parts.isEmpty ? "Unknown" : parts.joined(separator: " ")
    }
}

// MARK: - AudienceGraph

struct AudienceGraph: Codable, Equatable {
    let groupUserIds: [String]
    let contactUserIds: [String]
    let mergedUserIds: [String]
}

// MARK: - NetworkUser

struct NetworkUser: Identifiable, Equatable {
    let id: String
    let user: CachedUser
    let source: String  // "group" or "contact"
}

// MARK: - Batch User Response

struct BatchUserResponse: Codable {
    let users: [CachedUser]
}
