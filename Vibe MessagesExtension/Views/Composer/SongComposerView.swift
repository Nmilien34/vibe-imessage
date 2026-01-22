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
    
    // Debounce search
    let searchPublisher = PassthroughSubject<String, Never>()
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search songs, artists...", text: $searchText)
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
                        .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .padding()
            
            if let selected = selectedSong {
                // Confirmation State
                VStack(spacing: 24) {
                    Spacer()
                    
                    if let albumArt = selected.albumArt, let url = URL(string: albumArt) {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: 200, height: 200)
                        .cornerRadius(12)
                        .shadow(radius: 10)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                            .frame(width: 200, height: 200)
                            .background(Color.green.opacity(0.3))
                            .cornerRadius(12)
                    }
                    
                    VStack(spacing: 8) {
                        Text(selected.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(selected.artist)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    Button {
                        Task {
                            await shareSong(selected)
                        }
                    } label: {
                        Text("Share Song")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    Button("Choose Different Song") {
                        withAnimation {
                            selectedSong = nil
                        }
                    }
                    
                    Spacer()
                }
            } else {
                // Search Results
                if isSearching {
                    ProgressView()
                        .padding(.top, 50)
                    Spacer()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                        Text("No results found")
                            .foregroundColor(.secondary)
                            .padding(.top, 50)
                        Spacer()
                } else {
                    List(searchResults, id: \.title) { song in
                        Button {
                            withAnimation {
                                selectedSong = song
                            }
                        } label: {
                            HStack(spacing: 12) {
                                if let albumArt = song.albumArt, let url = URL(string: albumArt) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.gray.opacity(0.3)
                                    }
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(6)
                                } else {
                                    Image(systemName: "music.note")
                                        .frame(width: 50, height: 50)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(song.title)
                                        .font(.headline)
                                    Text(song.artist)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
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
            Task {
                await performSearch(query)
            }
        }
    }
    
    private func performSearch(_ query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        // Mock search for now
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        
        // Mock data
        searchResults = [
            SongData(title: "Vibe Check", artist: "The Vibes", albumArt: "https://picsum.photos/200", previewUrl: nil, spotifyId: "1"),
            SongData(title: "Coding Late", artist: "Dev Team", albumArt: "https://picsum.photos/201", previewUrl: nil, spotifyId: "2"),
            SongData(title: "Message Me", artist: "Socials", albumArt: "https://picsum.photos/202", previewUrl: nil, spotifyId: "3")
        ]
        
        isSearching = false
    }
    
    private func shareSong(_ song: SongData) async {
        do {
            try await appState.createVibe(
                type: .song,
                songData: song,
                isLocked: isLocked
            )
            appState.dismissComposer()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
