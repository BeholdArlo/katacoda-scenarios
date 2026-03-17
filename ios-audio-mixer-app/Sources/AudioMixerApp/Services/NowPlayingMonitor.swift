import Foundation
import MediaPlayer
import UIKit
import Combine

/// Monitors the iOS system Now Playing center to detect what the **YouTube app**
/// (or any other audio app) is currently playing, and provides URL-scheme
/// commands to open those apps from the mixer UI.
///
/// ## How it works
/// When an app registers as the Now Playing source (YouTube, Podcasts, etc.),
/// iOS exposes the current track metadata via `MPNowPlayingInfoCenter`.  Your
/// app can read this at any time without special entitlements.
///
/// There is no push notification for Now Playing changes from external apps,
/// so this service polls every second — the CPU cost is negligible.
///
/// ## Capabilities for the YouTube app
///   ✅ Read title, channel name, artwork, elapsed time, duration
///   ✅ Open the YouTube app at a specific video via URL scheme
///   ✅ Display a live "now playing" deck in the mixer UI
///   ❌ Set YouTube volume independently (only system volume is shared)
///   ❌ Apply EQ or stereo pan to YouTube's audio stream (iOS sandbox)
///   ❌ Programmatically send play/pause without user interaction
///
/// ## For full DSP mixing
/// Keep the YouTube deck in WKWebView mode (the Mixer tab) — that gives you
/// full Web Audio API volume and stereo pan control from within your app.
/// The Remote tab is for controlling the native YouTube / Spotify apps side-by-side.
@MainActor
final class NowPlayingMonitor: ObservableObject {

    // MARK: – Published state

    @Published var title:    String?
    @Published var artist:   String?    // channel name for YouTube
    @Published var artwork:  UIImage?
    @Published var duration: Double = 0
    @Published var elapsed:  Double = 0
    @Published var isActive  = false   // true when any external app owns Now Playing

    // Derived
    var progressRatio: Double {
        guard duration > 0 else { return 0 }
        return min(elapsed / duration, 1.0)
    }
    var elapsedFormatted:  String { formatTime(elapsed) }
    var durationFormatted: String { formatTime(duration) }

    // MARK: – Private

    private var timer: AnyCancellable?

    // MARK: – Lifecycle

    func startMonitoring() {
        guard timer == nil else { return }
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.poll() }
    }

    func stopMonitoring() {
        timer?.cancel()
        timer = nil
    }

    // MARK: – Poll

    private func poll() {
        guard let info = MPNowPlayingInfoCenter.default().nowPlayingInfo else {
            if isActive { isActive = false }
            return
        }

        title    = info[MPMediaItemPropertyTitle]  as? String
        artist   = info[MPMediaItemPropertyArtist] as? String
        duration = info[MPMediaItemPropertyPlaybackDuration] as? Double ?? 0
        elapsed  = info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double ?? 0

        if let mpArt = info[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork {
            artwork = mpArt.image(at: CGSize(width: 120, height: 120))
        }

        if !isActive { isActive = true }
    }

    // MARK: – URL-scheme control for YouTube

    /// Opens the YouTube app.  If `videoID` is provided, jumps directly to
    /// that video — e.g. after the user picks one to mix with Spotify.
    ///
    /// Falls back to the YouTube website in Safari when the app isn't installed.
    func openYouTubeApp(videoID: String? = nil) {
        let scheme = videoID.map { "youtube://www.youtube.com/watch?v=\($0)" }
                     ?? "youtube://"

        if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            let web = videoID.map { "https://www.youtube.com/watch?v=\($0)" }
                      ?? "https://www.youtube.com"
            UIApplication.shared.open(URL(string: web)!)
        }
    }

    /// `true` when the YouTube app is installed (canOpenURL requires
    /// `youtube` in LSApplicationQueriesSchemes in Info.plist).
    var isYouTubeInstalled: Bool {
        UIApplication.shared.canOpenURL(URL(string: "youtube://")!)
    }

    // MARK: – Helpers

    private func formatTime(_ t: Double) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}
