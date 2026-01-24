//
//  SongData.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import Foundation

struct SongData: Codable, Equatable, Identifiable {
    var id: String {
        return spotifyId ?? (title + artist)
    }
    let title: String
    let artist: String
    let albumArt: String?
    let previewUrl: String?
    let spotifyId: String?

    enum CodingKeys: String, CodingKey {
        case title
        case artist
        case albumArt
        case previewUrl
        case spotifyId
    }
}
