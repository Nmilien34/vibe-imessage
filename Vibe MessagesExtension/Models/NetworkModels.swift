import Foundation

// MARK: - CachedUser

struct CachedUser: Codable, Identifiable, Equatable {
    let id: String
    let firstName: String?
    let lastName: String?
    let profilePicture: String?

    private func cleanedNamePart(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        let normalized = trimmed.lowercased()
        if normalized == "user"
            || normalized == "vibe user"
            || normalized == "unknown"
            || normalized == "unknown user"
            || normalized == "anonymous"
            || normalized == "anon" {
            return nil
        }

        return trimmed
    }

    var displayName: String {
        let parts = [cleanedNamePart(firstName), cleanedNamePart(lastName)].compactMap { $0 }
        return parts.isEmpty ? "Vibe User" : parts.joined(separator: " ")
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
