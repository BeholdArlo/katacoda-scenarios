import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioEngine:    AudioEngineService
    @EnvironmentObject var spotifyService: SpotifyAPIService
    @EnvironmentObject var spotifyRemote:  SpotifyRemoteService
    @EnvironmentObject var nowPlaying:     NowPlayingMonitor

    @Environment(\.scenePhase) private var scenePhase

    // YouTube embedded-player state (owned here, passed down to WKWebView)
    // ytVideoID persists across launches; last video the user loaded is remembered.
    @AppStorage("lastYTVideoID") private var ytVideoID = "dQw4w9WgXcQ"
    @State private var ytVolume  = 80.0   // 0–100 (IFrame API scale); also driven by crossfader
    @State private var ytPan     = 0.0    // -1 … 0 … 1
    @State private var ytPlaying = true

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // ── Embedded YouTube player (always visible) ──────────────────
            // Full DSP: volume and stereo pan via Web Audio API JS.
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
                //   • Crossfader drives ytVolume (embedded player) + Spotify App Remote volume
                //   • YouTube Now Playing info + URL-scheme open
                //   • Spotify: full transport via App Remote SDK
                RemoteControlView(ytVolume: $ytVolume)
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
        // Stop/restart Now Playing polling on app background/foreground
        .onChange(of: scenePhase) { _, phase in
            guard selectedTab == 1 else { return }
            if phase == .active  { nowPlaying.startMonitoring() }
            else                 { nowPlaying.stopMonitoring() }
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
