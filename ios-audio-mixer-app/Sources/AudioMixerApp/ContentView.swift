import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioEngine:    AudioEngineService
    @EnvironmentObject var spotifyService: SpotifyAPIService
    @EnvironmentObject var spotifyRemote:  SpotifyRemoteService
    @EnvironmentObject var nowPlaying:     NowPlayingMonitor

    // YouTube embedded-player state (owned here, passed down to WKWebView)
    @State private var ytVideoID   = "dQw4w9WgXcQ"   // default: Never Gonna Give You Up
    @State private var ytVolume    = 80.0              // 0–100 (IFrame API scale)
    @State private var ytPan       = 0.0               // -1 … 0 … 1
    @State private var ytPlaying   = true

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // ── Embedded YouTube player (always visible) ──────────────────
            // Full DSP: volume and stereo pan controlled via Web Audio API JS.
            YouTubeSection(
                videoID:   $ytVideoID,
                ytVolume:  $ytVolume,
                ytPan:     $ytPan,
                isPlaying: $ytPlaying
            )
            .frame(maxHeight: 280)

            Divider()

            // ── Bottom tab area ───────────────────────────────────────────
            TabView(selection: $selectedTab) {

                // Tab 0 – Embedded mixer: full DSP (volume + stereo pan)
                MixerControlsView(ytVolume: $ytVolume, ytPan: $ytPan)
                    .tabItem { Label("Mixer", systemImage: "slider.horizontal.3") }
                    .tag(0)

                // Tab 1 – Remote: control native YouTube & Spotify apps
                //   • YouTube: Now Playing info + URL-scheme to open app
                //   • Spotify: full transport + independent volume via App Remote
                //   • Crossfader: equal-power fade across both sources
                RemoteControlView()
                    .tabItem { Label("Remote", systemImage: "dot.radiowaves.left.and.right") }
                    .tag(1)

                // Tab 2 – Search & 30-sec preview via Spotify Web API + AVAudioEngine
                MusicSearchView()
                    .tabItem { Label("Music", systemImage: "music.note") }
                    .tag(2)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: selectedTab) { _, tab in
            if tab == 1 {
                nowPlaying.startMonitoring()
                spotifyRemote.connectIfNeeded()
            } else {
                nowPlaying.stopMonitoring()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioEngineService())
        .environmentObject(SpotifyAPIService())
        .environmentObject(SpotifyRemoteService())
        .environmentObject(NowPlayingMonitor())
}
