import SwiftUI
import Combine

@main
struct AudioMixerApp: App {
    @StateObject private var appConfig      = AppConfig()
    @StateObject private var audioEngine    = AudioEngineService()
    @StateObject private var spotifyService = SpotifyAPIService()
    @StateObject private var spotifyRemote  = SpotifyRemoteService()
    @StateObject private var nowPlaying     = NowPlayingMonitor()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appConfig)
                .environmentObject(audioEngine)
                .environmentObject(spotifyService)
                .environmentObject(spotifyRemote)
                .environmentObject(nowPlaying)
                .onAppear {
                    audioEngine.setup()
                    wireSpotifyClientID()
                    spotifyRemote.setup()
                }
                .onOpenURL { url in
                    spotifyRemote.handleOpenURL(url)
                }
                .onReceive(appConfig.$spotifyClientID.dropFirst()) { id in
                    // User changed Client ID at runtime (Settings/Onboarding).
                    // Re-wire both services so subsequent auth uses the new value.
                    spotifyService.clientID = id
                    spotifyRemote.clientID  = id
                    if !id.trimmingCharacters(in: .whitespaces).isEmpty {
                        spotifyRemote.setup()
                    }
                }
        }
    }

    private func wireSpotifyClientID() {
        spotifyService.clientID = appConfig.spotifyClientID
        spotifyRemote.clientID  = appConfig.spotifyClientID
        spotifyService.onNeedsClientID = { /* Settings sheet opened via ContentView gear icon */ }
    }
}

// MARK: – Root: gate between onboarding and main app

struct RootView: View {
    @EnvironmentObject var appConfig: AppConfig

    var body: some View {
        if appConfig.hasLaunchedBefore {
            ContentView()
        } else {
            OnboardingView()
        }
    }
}
