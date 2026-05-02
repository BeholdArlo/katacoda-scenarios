import SwiftUI

struct MusicSearchView: View {
    @EnvironmentObject var appConfig:      AppConfig
    @EnvironmentObject var spotifyService: SpotifyAPIService
    @EnvironmentObject var audioEngine:    AudioEngineService
    @State private var query       = ""
    @State private var searchFocus = false

    var body: some View {
        VStack(spacing: 0) {
            if !appConfig.isSpotifyConfigured {
                SpotifySetupCard()
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                Spacer()
            } else if !spotifyService.isAuthenticated {
                connectView
            } else {
                trackListView
            }
        }
        .alert("Error", isPresented: Binding(
            get: { spotifyService.authError != nil },
            set: { if !$0 { spotifyService.authError = nil } }
        )) {
            Button("OK", role: .cancel) { spotifyService.authError = nil }
        } message: {
            Text(spotifyService.authError ?? "")
        }
    }

    // MARK: – Connect prompt

    private var connectView: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(DS.Color.teal)
                .glow(DS.Color.teal, radius: 20)

            VStack(spacing: 10) {
                Text("Connect Spotify")
                    .font(.title2.weight(.black))
                    .neon(DS.Color.cream)

                Text("Sign in to search tracks and play 30-second previews.")
                    .font(.subheadline)
                    .foregroundColor(DS.Color.cream.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button { spotifyService.authenticate() } label: {
                Label("Connect with Spotify", systemImage: "arrow.right.circle.fill")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(DS.Color.void)
                    .background(DS.Color.teal)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .glow(DS.Color.teal, radius: 10)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: – Track list

    private var trackListView: some View {
        VStack(spacing: 0) {
            if let track = spotifyService.currentTrack {
                NowPlayingBar(track: track)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(searchFocus ? DS.Color.acidYellow : DS.Color.cream.opacity(0.4))
                    .glow(searchFocus ? DS.Color.acidYellow : .clear, radius: 4)

                TextField("Search songs, artists…", text: $query)
                    .foregroundColor(DS.Color.cream)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit { spotifyService.search(query: query) }
                    .onChange(of: query) { _, v in spotifyService.search(query: v) }
                    .onTapGesture { searchFocus = true }

                if !query.isEmpty {
                    Button {
                        query = ""
                        searchFocus = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DS.Color.cream.opacity(0.4))
                    }
                }
            }
            .padding(12)
            .glassCard(cornerRadius: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(searchFocus ? DS.Color.teal.opacity(0.5) : DS.Color.glassEdge, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .animation(.easeInOut(duration: 0.2), value: searchFocus)

            // Results
            if spotifyService.isSearching {
                ShimmerTrackList()
            } else if spotifyService.searchResults.isEmpty && !query.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "music.note.slash")
                        .font(.system(size: 40))
                        .foregroundColor(DS.Color.cream.opacity(0.2))
                    Text("No results for "\(query)"")
                        .font(.subheadline)
                        .foregroundColor(DS.Color.cream.opacity(0.4))
                    Spacer()
                }
            } else {
                List(spotifyService.searchResults) { track in
                    TrackRow(track: track) {
                        spotifyService.currentTrack = track
                        if let url = track.previewURL {
                            audioEngine.loadAndPlay(url: url,
                                                    title: track.name,
                                                    artist: track.artistName)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

// MARK: – Spotify setup card (when no client ID configured)

private struct SpotifySetupCard: View {
    @EnvironmentObject var appConfig: AppConfig
    @State private var clientID = ""
    private let dashboardURL = "https://developer.spotify.com/dashboard"

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "key.fill")
                    .font(.title3)
                    .foregroundColor(DS.Color.burnOrange)
                    .glow(DS.Color.burnOrange, radius: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("30-Second Spotify Setup")
                        .font(.headline.weight(.bold))
                        .foregroundColor(DS.Color.cream)
                    Text("Free • No credit card • One time only")
                        .font(.caption)
                        .foregroundColor(DS.Color.cream.opacity(0.55))
                }
                Spacer()
            }

            HStack(spacing: 8) {
                TextField("Paste Client ID", text: $clientID)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(DS.Color.cream)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: clientID) { _, v in
                        appConfig.spotifyClientID = v.trimmingCharacters(in: .whitespaces)
                    }

                Button {
                    if let str = UIPasteboard.general.string {
                        clientID = str.trimmingCharacters(in: .whitespaces)
                    }
                } label: {
                    Text("Paste")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(DS.Color.burnOrange.opacity(0.2))
                        .foregroundColor(DS.Color.burnOrange)
                        .clipShape(Capsule())
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {
                UIApplication.shared.open(URL(string: dashboardURL)!)
            } label: {
                Label("Get free Client ID →", systemImage: "arrow.up.right.square")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DS.Color.teal)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 18)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(DS.Color.burnOrange.opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: – Track row

struct TrackRow: View {
    let track:  SpotifyTrack
    let onPlay: () -> Void

    @EnvironmentObject var spotifyService: SpotifyAPIService
    @EnvironmentObject var audioEngine:    AudioEngineService
    private var isCurrent: Bool { spotifyService.currentTrack?.id == track.id }

    private var artTint: Color {
        let palette: [Color] = [DS.Color.teal, DS.Color.burnOrange, DS.Color.magenta, DS.Color.acidYellow]
        return palette[abs(track.id.hashValue) % palette.count]
    }

    var body: some View {
        HStack(spacing: 12) {
            // Artwork with per-track accent glow
            AsyncImage(url: track.artworkURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .failure, .empty:
                    DS.Color.deepViolet
                        .overlay(Image(systemName: "music.note").foregroundColor(DS.Color.cream.opacity(0.3)))
                @unknown default:
                    Color.clear
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isCurrent ? artTint : Color.clear, lineWidth: 2)
            )
            .glow(isCurrent ? artTint : .clear, radius: 6)

            // Metadata
            VStack(alignment: .leading, spacing: 3) {
                Text(track.name)
                    .font(.subheadline.weight(isCurrent ? .bold : .regular))
                    .foregroundColor(isCurrent ? artTint : DS.Color.cream)
                    .glow(isCurrent ? artTint : .clear, radius: 2)
                    .lineLimit(1)
                Text(track.artistName)
                    .font(.caption)
                    .foregroundColor(DS.Color.cream.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(track.formattedDuration)
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(DS.Color.cream.opacity(0.4))

                if isCurrent && audioEngine.isLoadingPreview {
                    ProgressView()
                        .tint(DS.Color.teal)
                        .frame(width: 28, height: 28)
                } else if isCurrent {
                    Button { audioEngine.pauseResume() } label: {
                        Image(systemName: audioEngine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(DS.Color.teal)
                            .glow(DS.Color.teal, radius: 6)
                    }
                } else {
                    Button { onPlay() } label: {
                        Image(systemName: "play.circle")
                            .font(.title2)
                            .foregroundColor(DS.Color.cream.opacity(0.4))
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .glassCard(cornerRadius: 14)
        .contentShape(Rectangle())
        .onTapGesture { if !audioEngine.isLoadingPreview { onPlay() } }
    }

}

// MARK: – Now playing bar

struct NowPlayingBar: View {
    let track: SpotifyTrack
    @EnvironmentObject var audioEngine: AudioEngineService
    @State private var wavePhase = false

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: track.artworkURL) { phase in
                if case .success(let img) = phase {
                    img.resizable().scaledToFill()
                } else {
                    DS.Color.deepViolet
                }
            }
            .frame(width: 38, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name).font(.subheadline.weight(.semibold)).lineLimit(1).foregroundColor(DS.Color.cream)
                Text(track.artistName).font(.caption).foregroundColor(DS.Color.cream.opacity(0.5)).lineLimit(1)
            }

            Spacer()

            // Animated waveform
            WaveformIndicator(playing: audioEngine.isPlaying)

            Button { audioEngine.pauseResume() } label: {
                Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3).foregroundColor(DS.Color.teal).glow(DS.Color.teal, radius: 6)
            }

            Button { audioEngine.stopPlayback() } label: {
                Image(systemName: "stop.fill")
                    .font(.title3).foregroundColor(DS.Color.cream.opacity(0.5))
            }
        }
        .padding(10)
        .glassCard(cornerRadius: 14)
        .overlay(
            // Playback progress underline
            GeometryReader { geo in
                let ratio = audioEngine.currentTrackDuration > 0
                    ? audioEngine.currentPlaybackTime / audioEngine.currentTrackDuration : 0
                VStack {
                    Spacer()
                    Capsule()
                        .fill(DS.Color.teal)
                        .frame(width: geo.size.width * CGFloat(min(ratio, 1)), height: 3)
                        .glow(DS.Color.teal, radius: 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
    }
}

// MARK: – Waveform animation

private struct WaveformIndicator: View {
    let playing: Bool
    @State private var phase = false

    private let heights: [CGFloat] = [6, 12, 8, 14, 10]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(heights.indices, id: \.self) { i in
                Capsule()
                    .fill(DS.Color.teal)
                    .frame(width: 3, height: playing ? heights[i] : 4)
                    .animation(
                        playing ? .easeInOut(duration: 0.35).repeatForever().delay(Double(i) * 0.07) : .default,
                        value: playing
                    )
            }
        }
        .glow(DS.Color.teal, radius: 3)
    }
}

// MARK: – Shimmer track list

private struct ShimmerTrackList: View {
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8).frame(width: 50, height: 50)
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4).frame(height: 12)
                        RoundedRectangle(cornerRadius: 4).frame(width: 100, height: 10)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .foregroundColor(DS.Color.deepViolet)
                .glassCard(cornerRadius: 14)
                .shimmer()
                .padding(.horizontal, 16)
            }
            Spacer()
        }
        .padding(.top, 8)
    }
}

#Preview {
    MusicSearchView()
        .environmentObject(AppConfig())
        .environmentObject(SpotifyAPIService())
        .environmentObject(AudioEngineService())
        .background(DS.Color.bgGradient.ignoresSafeArea())
        .preferredColorScheme(.dark)
}
