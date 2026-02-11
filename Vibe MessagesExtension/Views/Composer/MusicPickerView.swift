//
//  MusicPickerView.swift
//  Vibe MessagesExtension
//
//  MusicKit-powered Apple Music catalog search.
//

import SwiftUI
import MusicKit

struct MusicPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedSong: SongData?

    @State private var searchText = ""
    @State private var searchResults: MusicItemCollection<Song> = []
    @State private var isAuthorized = false

    var body: some View {
        NavigationView {
            Group {
                if !isAuthorized {
                    VStack(spacing: VibeSpacing.lg) {
                        Image(systemName: "music.note.house")
                            .font(.system(size: 50))
                            .foregroundColor(VibeTheme.textTertiary)
                        Text("Apple Music access is required")
                            .font(VibeTypography.titleMedium)
                            .foregroundColor(VibeTheme.textPrimary)
                        Text("Allow access in Settings to search songs.")
                            .font(VibeTypography.bodyMedium)
                            .foregroundColor(VibeTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(searchResults) { song in
                        Button {
                            VibeHaptic.selection()
                            let artworkURL = song.artwork?.url(width: 300, height: 300)?.absoluteString
                            selectedSong = SongData(
                                title: song.title,
                                artist: song.artistName,
                                albumArt: artworkURL,
                                previewUrl: nil,
                                spotifyId: song.id.rawValue
                            )
                            dismiss()
                        } label: {
                            HStack(spacing: VibeSpacing.sm) {
                                if let artwork = song.artwork {
                                    AsyncImage(url: artwork.url(width: 60, height: 60)) { image in
                                        image.resizable()
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(VibeTheme.surfaceOverlay)
                                    }
                                    .frame(width: 50, height: 50)
                                    .continuousCorner(6)
                                }

                                VStack(alignment: .leading, spacing: VibeSpacing.xxxs) {
                                    Text(song.title)
                                        .font(VibeTypography.titleSmall)
                                        .foregroundColor(VibeTheme.textPrimary)
                                        .lineLimit(1)
                                    Text(song.artistName)
                                        .font(VibeTypography.bodySmall)
                                        .foregroundColor(VibeTheme.textSecondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(VibeTheme.accent)
                            }
                        }
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Search Apple Music")
                    .onChange(of: searchText) { _, newValue in
                        searchAppleMusic(term: newValue)
                    }
                }
            }
            .navigationTitle("Pick a Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                let status = await MusicAuthorization.request()
                isAuthorized = status == .authorized
            }
        }
    }

    private func searchAppleMusic(term: String) {
        guard !term.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }

        Task {
            do {
                var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
                request.limit = 25
                let response = try await request.response()
                await MainActor.run {
                    searchResults = response.songs
                }
            } catch {
                print("MusicKit search error: \(error)")
            }
        }
    }
}
