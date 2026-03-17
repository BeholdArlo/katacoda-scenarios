import Foundation
import UIKit
import Combine

// ─────────────────────────────────────────────────────────────────────────────
// DEPENDENCY: Add the Spotify iOS SDK via Swift Package Manager.
//
//   In Xcode → File → Add Packages:
//     https://github.com/spotify/ios-sdk
//     Product: SpotifyiOS
//
//   In project.yml (XcodeGen) add under `packages:` and target `dependencies:`
//     packages:
//       SpotifyiOS:
//         url: https://github.com/spotify/ios-sdk
//         from: "1.2.3"
//     targets:
//       AudioMixerApp:
//         dependencies:
//           - package: SpotifyiOS
//             product: SpotifyiOS
// ─────────────────────────────────────────────────────────────────────────────
import SpotifyiOS

/// Connects to the **installed, already-logged-in Spotify app** via the
/// Spotify iOS SDK App Remote.
///
/// ## Why use this instead of the Web API?
/// - Plays **full tracks** from the user's own library (no 30-sec preview limit)
/// - Controls the Spotify app the user is already logged into — no second login
/// - `setVolume(_:)` adjusts Spotify's playback volume **independently of system
///   volume**, which is what makes the crossfader work
/// - Real-time player state: current track, artwork, position, shuffle/repeat
///
/// ## What this cannot do (iOS sandbox)
/// - Route Spotify audio through AVAudioEngine (audio stays in Spotify process)
/// - Apply per-band EQ or stereo pan to Spotify's audio stream
///   → use the embedded Spotify preview mode (AVAudioEngine) when DSP is needed
///
/// ## Connection flow
/// 1. Call `setup()` once on app launch
/// 2. Call `connectIfNeeded()` when the app foregrounds or the Remote tab opens
/// 3. Pass every URL in `onOpenURL { url in spotifyRemote.handleOpenURL(url) }`
///    so the SDK can extract the handshake token from the Spotify callback
@MainActor
final class SpotifyRemoteService: NSObject, ObservableObject {

    // MARK: – Published state

    @Published var isConnected       = false
    @Published var isSpotifyInstalled = false
    @Published var currentTrack: RemoteTrackInfo?
    @Published var isPlaying         = false
    @Published var playbackPosition: Double = 0   // seconds
    /// Spotify-side volume (0–1), independent of iOS system volume.
    @Published var spotifyVolume: Double = 1.0
    @Published var connectionError: String?

    // MARK: – Private

    private var appRemote: SPTAppRemote?

    // MARK: – Lifecycle

    func setup() {
        isSpotifyInstalled = UIApplication.shared.canOpenURL(URL(string: "spotify://")!)

        let config = SPTConfiguration(
            clientID: SpotifyAPIService.Config.clientID,
            redirectURL: URL(string: SpotifyAPIService.Config.redirectURI)!
        )
        // Empty playURI = reconnect without forcing a new track to play
        config.playURI = ""

        appRemote = SPTAppRemote(configuration: config, logLevel: .none)
        appRemote?.delegate = self
    }

    /// Call when the app becomes active (ScenePhase == .active) or when the
    /// Remote tab is selected.  If Spotify is already running it will reconnect
    /// silently.  If not running it opens Spotify for authorization.
    func connectIfNeeded() {
        guard let appRemote, !appRemote.isConnected else { return }
        // `authorizeAndPlayURI` handles both first-time auth and re-connection.
        appRemote.authorizeAndPlayURI("", asRadio: false)
    }

    func disconnect() {
        appRemote?.disconnect()
    }

    /// Pass the URL received in `onOpenURL` so the SDK can complete the
    /// OAuth / App Remote handshake.  Returns whether the URL was handled.
    @discardableResult
    func handleOpenURL(_ url: URL) -> Bool {
        appRemote?.open(url) ?? false
    }

    // MARK: – Playback control

    /// Play a track, album, playlist, or artist by Spotify URI.
    /// e.g. `"spotify:track:4iV5W9uYEdYUVa79Axb7Rh"`
    func play(uri: String) {
        appRemote?.playerAPI?.play(uri, callback: errHandler("play"))
    }

    func pause()  { appRemote?.playerAPI?.pause(errHandler("pause")) }
    func resume() { appRemote?.playerAPI?.resume(errHandler("resume")) }

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func skipNext()     { appRemote?.playerAPI?.skip(toNext: errHandler("next")) }
    func skipPrevious() { appRemote?.playerAPI?.skip(toPrevious: errHandler("prev")) }

    /// Seek to a position in seconds.
    func seek(to seconds: Double) {
        appRemote?.playerAPI?.seek(toPosition: Int(seconds * 1000),
                                   callback: errHandler("seek"))
    }

    /// Set the Spotify app's playback volume 0–1, **independently of system
    /// volume**.  This is the key capability powering the crossfader: you can
    /// fade Spotify down while the YouTube side fades up without touching the
    /// device volume rocker.
    func setSpotifyVolume(_ v: Double) {
        let clamped = max(0, min(1, v))
        spotifyVolume = clamped
        appRemote?.playerAPI?.setVolume(Int(clamped * 100),
                                        callback: errHandler("volume"))
    }

    // MARK: – Helpers

    private func errHandler(_ op: String) -> SPTAppRemoteCallback {
        { _, error in
            if let error {
                DispatchQueue.main.async {
                    self.connectionError = "\(op): \(error.localizedDescription)"
                }
            }
        }
    }

    private func subscribeToPlayerState() {
        appRemote?.playerAPI?.delegate = self
        appRemote?.playerAPI?.subscribe(toPlayerState: errHandler("subscribe"))
    }
}

// MARK: – SPTAppRemoteDelegate

extension SpotifyRemoteService: SPTAppRemoteDelegate {
    nonisolated func appRemoteDidEstablishConnection(_ remote: SPTAppRemote) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionError = nil
            self.subscribeToPlayerState()
        }
    }

    nonisolated func appRemote(_ remote: SPTAppRemote,
                               didFailConnectionAttemptWithError error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionError = error?.localizedDescription
                ?? "Could not connect to Spotify"
        }
    }

    nonisolated func appRemote(_ remote: SPTAppRemote,
                               didDisconnectWithError error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = false
            if let error { self.connectionError = error.localizedDescription }
        }
    }
}

// MARK: – SPTAppRemotePlayerStateDelegate

extension SpotifyRemoteService: SPTAppRemotePlayerStateDelegate {
    nonisolated func playerStateDidChange(_ state: SPTAppRemotePlayerState) {
        DispatchQueue.main.async {
            self.isPlaying        = !state.isPaused
            self.playbackPosition = Double(state.playbackPosition) / 1000.0

            let t = state.track
            self.currentTrack = RemoteTrackInfo(
                uri:        t.uri,
                name:       t.name,
                artist:     t.artist.name,
                album:      t.album.name,
                durationMs: Int(t.duration)
            )
            self.fetchArtwork(for: t)
        }
    }

    private func fetchArtwork(for track: SPTAppRemoteTrack) {
        appRemote?.imageAPI?.fetchImage(
            forItem: track,
            with: CGSize(width: 120, height: 120)
        ) { [weak self] result, _ in
            guard let image = result as? UIImage else { return }
            DispatchQueue.main.async { self?.currentTrack?.artwork = image }
        }
    }
}

// MARK: – Data model

struct RemoteTrackInfo {
    let uri: String
    let name: String
    let artist: String
    let album: String
    let durationMs: Int
    var artwork: UIImage?

    var durationSeconds: Double { Double(durationMs) / 1000.0 }

    var formattedDuration: String {
        let m = Int(durationSeconds) / 60
        let s = Int(durationSeconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
