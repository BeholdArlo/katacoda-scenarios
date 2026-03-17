import SwiftUI

@main
struct AudioMixerApp: App {
    @StateObject private var audioEngine    = AudioEngineService()
    @StateObject private var spotifyService = SpotifyAPIService()
    /// Spotify iOS SDK App Remote — connects to the installed, logged-in Spotify app.
    @StateObject private var spotifyRemote  = SpotifyRemoteService()
    /// Monitors iOS system Now Playing center for YouTube app detection.
    @StateObject private var nowPlaying     = NowPlayingMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioEngine)
                .environmentObject(spotifyService)
                .environmentObject(spotifyRemote)
                .environmentObject(nowPlaying)
                .onAppear {
                    audioEngine.setup()
                    spotifyRemote.setup()
                }
                .onOpenURL { url in
                    // Handles both:
                    //   1. Spotify Web API OAuth PKCE callback (SpotifyAPIService)
                    //   2. Spotify App Remote handshake token (SpotifyRemoteService)
                    spotifyRemote.handleOpenURL(url)
                }
        }
    }
}
