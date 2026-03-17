import SwiftUI

struct MusicSearchView: View {
    @EnvironmentObject var spotifyService: SpotifyAPIService
    @EnvironmentObject var audioEngine: AudioEngineService
    @State private var query = ""

    var body: some View {
        NavigationStack {
            Group {
                if !spotifyService.isAuthenticated {
                    spotifyLoginView
                } else {
                    trackListView
                }
            }
            .navigationTitle("Spotify")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: Binding(
                get: { spotifyService.authError != nil },
                set: { if !$0 { spotifyService.authError = nil } }
            )) {
                Button("OK", role: .cancel) { spotifyService.authError = nil }
            } message: {
                Text(spotifyService.authError ?? "")
            }
        }
    }

    // MARK: – Login prompt

    private var spotifyLoginView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Connect Spotify")
                .font(.title.bold())

            Text("Sign in with your Spotify account to search tracks and play 30-second previews. Full-track playback requires the Spotify app (see README).")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)

            Button(action: { spotifyService.authenticate() }) {
                Label("Connect with Spotify", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: – Track list

    private var trackListView: some View {
        VStack(spacing: 0) {
            // Now playing bar
            if let track = spotifyService.currentTrack {
                NowPlayingBar(track: track)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            // Search field
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search songs, artists, albums…", text: $query)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: query) { _, newValue in
                        spotifyService.search(query: newValue)
                    }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding()

            // Results
            if spotifyService.isSearching {
                ProgressView().padding()
                Spacer()
            } else if spotifyService.searchResults.isEmpty && !query.isEmpty {
                ContentUnavailableView("No results", systemImage: "music.note.slash",
                                       description: Text("No tracks found for "\(query)""))
                Spacer()
            } else {
                List(spotifyService.searchResults) { track in
                    TrackRow(track: track) {
                        spotifyService.currentTrack = track
                        if let url = track.previewURL {
                            audioEngine.loadAndPlay(url: url)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: – Track row

struct TrackRow: View {
    let track: SpotifyTrack
    let onPlay: () -> Void

    @EnvironmentObject var spotifyService: SpotifyAPIService
    @EnvironmentObject var audioEngine: AudioEngineService

    private var isCurrentTrack: Bool {
        spotifyService.currentTrack?.id == track.id
    }

    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            AsyncImage(url: track.artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color(.systemGray5)
                    .overlay(Image(systemName: "music.note").foregroundColor(.secondary))
            }
            .frame(width: 52, height: 52)
            .cornerRadius(8)
            .clipped()

            // Metadata
            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.body.weight(isCurrentTrack ? .semibold : .regular))
                    .foregroundColor(isCurrentTrack ? .green : .primary)
                    .lineLimit(1)
                Text(track.artistName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Duration + play button
            VStack(alignment: .trailing, spacing: 4) {
                Text(track.formattedDuration)
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)

                if isCurrentTrack {
                    Button { audioEngine.pauseResume() } label: {
                        Image(systemName: audioEngine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                } else {
                    Button { onPlay() } label: {
                        Image(systemName: "play.circle")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { onPlay() }
    }
}

// MARK: – Now playing bar

struct NowPlayingBar: View {
    let track: SpotifyTrack
    @EnvironmentObject var audioEngine: AudioEngineService

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: track.artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color(.systemGray5)
            }
            .frame(width: 40, height: 40)
            .cornerRadius(6)
            .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(track.artistName).font(.caption).foregroundColor(.secondary).lineLimit(1)
            }

            Spacer()

            // Progress
            Text(timeString(audioEngine.currentPlaybackTime))
                .font(.caption2.monospacedDigit())
                .foregroundColor(.secondary)

            Button { audioEngine.pauseResume() } label: {
                Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundColor(.green)
            }

            Button { audioEngine.stopPlayback() } label: {
                Image(systemName: "stop.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(12)

        // Playback progress bar
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray4)).frame(height: 3)
                let ratio = audioEngine.currentTrackDuration > 0
                    ? audioEngine.currentPlaybackTime / audioEngine.currentTrackDuration
                    : 0
                Capsule()
                    .fill(Color.green)
                    .frame(width: geo.size.width * CGFloat(min(ratio, 1.0)), height: 3)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 4)
    }

    private func timeString(_ t: Double) -> String {
        let m = Int(t) / 60; let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}
