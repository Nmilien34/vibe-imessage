//
//  SongComposerView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI
import Combine

struct SongComposerView: View {
    @EnvironmentObject var appState: AppState
    let isLocked: Bool

    @State private var searchText = ""
    @State private var searchResults: [SongData] = []
    @State private var isSearching = false
    @State private var selectedSong: SongData?
    @State private var error: String?

    let searchPublisher = PassthroughSubject<String, Never>()

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: VibeSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(VibeTheme.textSecondary)
                TextField("Search songs, artists...", text: $searchText)
                    .font(VibeTypography.bodyMedium)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, newValue in
                        searchPublisher.send(newValue)
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(VibeTheme.textSecondary)
                    }
                }
            }
            .padding(VibeSpacing.md)
            .background(.ultraThinMaterial)
            .continuousCorner(VibeTheme.radiusMedium)
            .padding(VibeSpacing.md)

            if let selected = selectedSong {
                VStack(spacing: VibeSpacing.xl) {
                    Spacer()

                    if let albumArt = selected.albumArt, let url = URL.httpURL(from: albumArt) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            VibeTheme.surfaceOverlay
                        }
                        .frame(width: 200, height: 200)
                        .continuousCorner(VibeTheme.radiusMedium)
                        .vibeShadow(.lg)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                            .frame(width: 200, height: 200)
                            .background(Color.green.opacity(0.3))
                            .continuousCorner(VibeTheme.radiusMedium)
                    }

                    VStack(spacing: VibeSpacing.xs) {
                        Text(selected.title)
                            .font(VibeTypography.titleLarge)
                            .foregroundColor(VibeTheme.textPrimary)
                        Text(selected.artist)
                            .font(VibeTypography.bodyMedium)
                            .foregroundColor(VibeTheme.textSecondary)
                    }

                    Button {
                        VibeHaptic.success()
                        Task { await shareSong(selected) }
                    } label: {
                        Text("Share Song")
                            .font(VibeTypography.titleSmall)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: VibeSpacing.minTouchTarget)
                            .background(Color.green)
                            .continuousCorner(VibeTheme.radiusMedium)
                    }
                    .buttonStyle(VibePressStyle())
                    .padding(.horizontal, VibeSpacing.screenHorizontal)

                    Button("Choose Different Song") {
                        VibeHaptic.light()
                        withAnimation(VibeAnimation.snappy) {
                            selectedSong = nil
                        }
                    }
                    .font(VibeTypography.bodyMedium)
                    .foregroundColor(VibeTheme.accent)

                    Spacer()
                }
            } else {
                if isSearching {
                    ProgressView()
                        .padding(.top, 50)
                    Spacer()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    Text("No results found")
                        .font(VibeTypography.bodyMedium)
                        .foregroundColor(VibeTheme.textSecondary)
                        .padding(.top, 50)
                    Spacer()
                } else {
                    List(searchResults, id: \.title) { song in
                        Button {
                            VibeHaptic.selection()
                            withAnimation(VibeAnimation.snappy) {
                                selectedSong = song
                            }
                        } label: {
                            HStack(spacing: VibeSpacing.sm) {
                                if let albumArt = song.albumArt, let url = URL.httpURL(from: albumArt) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        VibeTheme.surfaceOverlay
                                    }
                                    .frame(width: 50, height: 50)
                                    .continuousCorner(6)
                                } else {
                                    Image(systemName: "music.note")
                                        .frame(width: 50, height: 50)
                                        .background(Color.green.opacity(0.1))
                                        .continuousCorner(6)
                                }

                                VStack(alignment: .leading, spacing: VibeSpacing.xxxs) {
                                    Text(song.title)
                                        .font(VibeTypography.titleSmall)
                                        .foregroundColor(VibeTheme.textPrimary)
                                    Text(song.artist)
                                        .font(VibeTypography.bodySmall)
                                        .foregroundColor(VibeTheme.textSecondary)
                                }
                            }
                        }
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
        }
        .onReceive(searchPublisher.debounce(for: .milliseconds(500), scheduler: RunLoop.main)) { query in
            Task { await performSearch(query) }
        }
    }

    private func performSearch(_ query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        searchResults = [
            SongData(title: "Vibe Check", artist: "The Vibes", albumArt: "https://picsum.photos/200", previewUrl: nil, spotifyId: "1"),
            SongData(title: "Coding Late", artist: "Dev Team", albumArt: "https://picsum.photos/201", previewUrl: nil, spotifyId: "2"),
            SongData(title: "Message Me", artist: "Socials", albumArt: "https://picsum.photos/202", previewUrl: nil, spotifyId: "3")
        ]
        isSearching = false
    }

    private func shareSong(_ song: SongData) async {
        do {
            let vibe = try await appState.createVibe(
                type: .song,
                songData: song,
                isLocked: isLocked
            )
            appState.sendVibeMessage(vibeId: vibe.id, isLocked: isLocked, vibeType: .song, contextText: "\(song.title) — \(song.artist)")
            appState.dismissComposer()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
