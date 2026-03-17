import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioEngine: AudioEngineService
    @EnvironmentObject var spotifyService: SpotifyAPIService

    // YouTube state (owned here, passed down)
    @State private var ytVideoID   = "dQw4w9WgXcQ"   // default: Never Gonna Give You Up
    @State private var ytVolume    = 80.0              // 0–100 (IFrame API scale)
    @State private var ytPan       = 0.0              // -1…0…1
    @State private var ytPlaying   = true

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // ── YouTube player always visible at the top ──────────────────
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
                MixerControlsView(ytVolume: $ytVolume, ytPan: $ytPan)
                    .tabItem { Label("Mixer", systemImage: "slider.horizontal.3") }
                    .tag(0)

                MusicSearchView()
                    .tabItem { Label("Music", systemImage: "music.note") }
                    .tag(1)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioEngineService())
        .environmentObject(SpotifyAPIService())
}
