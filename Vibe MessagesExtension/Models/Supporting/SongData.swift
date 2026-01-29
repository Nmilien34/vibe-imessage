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
    let spotifyUrl: String?
    let appleMusicUrl: String?

    enum CodingKeys: String, CodingKey {
        case title
        case artist
        case albumArt
        case previewUrl
        case spotifyId
        case spotifyUrl
        case appleMusicUrl
    }

    init(title: String, artist: String, albumArt: String? = nil, previewUrl: String? = nil, spotifyId: String? = nil, spotifyUrl: String? = nil, appleMusicUrl: String? = nil) {
        self.title = title
        self.artist = artist
        self.albumArt = albumArt
        self.previewUrl = previewUrl
        self.spotifyId = spotifyId
        self.spotifyUrl = spotifyUrl
        self.appleMusicUrl = appleMusicUrl
    }
}
