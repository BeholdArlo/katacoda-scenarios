import SwiftUI

// MARK: – Root view

/// "Remote" tab — control the native YouTube app and Spotify app you're
/// already logged into, and crossfade between them.
///
/// Crossfader behaviour:
///   Left  (0.0) → embedded YouTube at full volume, Spotify silent
///   Center(0.5) → both sources at ~70% (equal-power law)
///   Right (1.0) → Spotify at full volume, YouTube silent
///
/// The YouTube side drives the **embedded WKWebView player** (always visible
/// at the top of the screen) via the `ytVolume` binding, giving real JS-level
/// volume control.  The Spotify side calls `setVolume()` on the App Remote,
/// controlling the Spotify app's output independently of system volume.
struct RemoteControlView: View {
    @EnvironmentObject var spotifyRemote: SpotifyRemoteService
    @EnvironmentObject var nowPlaying:    NowPlayingMonitor

    /// Controls the embedded WKWebView YouTube player volume (0–100).
    @Binding var ytVolume: Double

    /// 0.0 = full YouTube · 0.5 = equal power · 1.0 = full Spotify
    @State private var crossfader: Double = 0.5

    /// Shown once; dismissed permanently via AppStorage.
    @AppStorage("remoteCapBannerDismissed") private var bannerDismissed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Remote Control")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                if !bannerDismissed { capabilityBanner.padding(.horizontal) }

                // YouTube embedded-player deck
                YouTubeAppDeck(
                    nowPlaying: nowPlaying,
                    crossfaderVolume: ytCurve(crossfader)   // real volume, 0–1
                )
                .padding(.horizontal)

                // DJ crossfader
                CrossfaderView(value: $crossfader)
                    .padding(.horizontal)
                    .onChange(of: crossfader, applyCrossfade)

                // Spotify app deck
                SpotifyAppDeck()
                    .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: – Equal-power crossfade

    /// cos curve: 1.0 → ~0.707 → 0.0  (YouTube side)
    private func ytCurve(_ x: Double) -> Double { cos(x * .pi / 2) }
    /// sin curve: 0.0 → ~0.707 → 1.0  (Spotify side)
    private func spCurve(_ x: Double) -> Double { sin(x * .pi / 2) }

    private func applyCrossfade(_ old: Double, _ x: Double) {
        // YouTube: drives the always-visible embedded WKWebView player
        ytVolume = 100 * ytCurve(x)
        // Spotify: drives the Spotify app's own volume via App Remote API
        if spotifyRemote.isConnected {
            spotifyRemote.setSpotifyVolume(spCurve(x))
        }
    }

    // MARK: – One-time capability banner

    private var capabilityBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue).font(.caption).padding(.top, 1)
            Text("Crossfader controls the **embedded player** (YouTube) and Spotify's own volume via App Remote. For EQ and stereo pan, use the Mixer tab.")
                .font(.caption).foregroundColor(.secondary)
            Spacer()
            Button { bannerDismissed = true } label: {
                Image(systemName: "xmark").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: – YouTube App Deck

struct YouTubeAppDeck: View {
    @ObservedObject var nowPlaying: NowPlayingMonitor
    /// Actual crossfader gain for this channel (0–1). Now real, not visual-only.
    let crossfaderVolume: Double

    var body: some View {
        VStack(spacing: 12) {
            deckHeader
            if nowPlaying.isActive, let title = nowPlaying.title {
                nowPlayingContent(title: title)
            } else {
                idleContent
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var deckHeader: some View {
        HStack {
            Image(systemName: "play.rectangle.fill").foregroundColor(.red)
            Text("YouTube").font(.headline)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "speaker.wave.2").font(.caption)
                Text("\(Int(crossfaderVolume * 100))%").font(.caption.monospacedDigit())
            }
            .foregroundColor(.secondary)
        }
    }

    private func nowPlayingContent(title: String) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                artworkView
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold)).lineLimit(2)
                    if let artist = nowPlaying.artist {
                        Text(artist).font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                Text(nowPlaying.elapsedFormatted)
                    .font(.caption2.monospacedDigit()).foregroundColor(.secondary)
            }
            ProgressBar(ratio: nowPlaying.progressRatio, color: .red)
            Button {
                nowPlaying.openYouTubeApp()
            } label: {
                Label("Open YouTube App", systemImage: "arrow.up.right.square")
                    .font(.caption).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).tint(.red)
        }
    }

    private var idleContent: some View {
        VStack(spacing: 10) {
            Text("YouTube app is not playing")
                .font(.caption).foregroundColor(.secondary)
            Button { nowPlaying.openYouTubeApp() } label: {
                Label("Open YouTube App", systemImage: "arrow.up.right.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).tint(.red)
            Text("Start a video in the YouTube app — this deck detects it automatically.")
                .font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
    }

    @ViewBuilder private var artworkView: some View {
        if let img = nowPlaying.artwork {
            Image(uiImage: img).resizable().scaledToFill()
                .frame(width: 52, height: 52).cornerRadius(8).clipped()
        } else {
            RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5))
                .frame(width: 52, height: 52)
                .overlay(Image(systemName: "play.rectangle").foregroundColor(.secondary))
        }
    }
}

// MARK: – Spotify App Deck

struct SpotifyAppDeck: View {
    @EnvironmentObject var spotifyRemote: SpotifyRemoteService

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "music.note").foregroundColor(.green)
                Text("Spotify").font(.headline)
                Spacer()
                connectionBadge
            }
            if spotifyRemote.isConnected { connectedContent } else { disconnectedContent }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var connectionBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(spotifyRemote.isConnected ? Color.green : Color(.systemGray3))
                .frame(width: 8, height: 8)
            Text(spotifyRemote.isConnected ? "Connected" : "Disconnected")
                .font(.caption)
                .foregroundColor(spotifyRemote.isConnected ? .green : .secondary)
        }
    }

    private var connectedContent: some View {
        VStack(spacing: 12) {
            if let track = spotifyRemote.currentTrack { trackRow(track) }
            else { Text("Waiting for Spotify to start…").font(.caption).foregroundColor(.secondary) }
            transportControls
            spotifyVolumeSlider
            if let err = spotifyRemote.connectionError {
                Text(err).font(.caption2).foregroundColor(.red)
            }
        }
    }

    private func trackRow(_ track: RemoteTrackInfo) -> some View {
        HStack(spacing: 12) {
            Group {
                if let art = track.artwork {
                    Image(uiImage: art).resizable().scaledToFill()
                } else {
                    Color(.systemGray5).overlay(Image(systemName: "music.note").foregroundColor(.secondary))
                }
            }
            .frame(width: 52, height: 52).cornerRadius(8).clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(track.artist).font(.caption).foregroundColor(.secondary).lineLimit(1)
                Text(track.album).font(.caption2).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            Text(track.formattedDuration).font(.caption2.monospacedDigit()).foregroundColor(.secondary)
        }
    }

    private var transportControls: some View {
        HStack(spacing: 32) {
            Button { spotifyRemote.skipPrevious() } label: {
                Image(systemName: "backward.fill").font(.title2)
            }
            .foregroundColor(.primary)
            Button { spotifyRemote.togglePlayPause() } label: {
                Image(systemName: spotifyRemote.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44)).foregroundColor(.green)
            }
            Button { spotifyRemote.skipNext() } label: {
                Image(systemName: "forward.fill").font(.title2)
            }
            .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Independent Spotify volume — does not affect system volume.
    private var spotifyVolumeSlider: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Spotify Volume", systemImage: "speaker.wave.2")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("\(Int(spotifyRemote.spotifyVolume * 100))%")
                    .font(.caption.monospacedDigit()).foregroundColor(.secondary)
            }
            Slider(
                value: Binding(
                    get: { spotifyRemote.spotifyVolume },
                    set: { spotifyRemote.setSpotifyVolume($0) }
                ),
                in: 0...1
            )
            .accentColor(.green)
        }
    }

    private var disconnectedContent: some View {
        VStack(spacing: 10) {
            Text(spotifyRemote.isSpotifyInstalled
                 ? "Connect to your logged-in Spotify app for full-track playback and crossfader control."
                 : "Spotify app is not installed on this device.")
                .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
            if spotifyRemote.isSpotifyInstalled {
                Button { spotifyRemote.connectIfNeeded() } label: {
                    Label("Connect to Spotify App", systemImage: "link")
                        .frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent).tint(.green)
            }
            if let err = spotifyRemote.connectionError {
                Text(err).font(.caption2).foregroundColor(.red).multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: – DJ Crossfader

struct CrossfaderView: View {
    @Binding var value: Double   // 0 = YouTube · 1 = Spotify

    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    @State private var didCenterSnap = false

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "play.rectangle.fill").foregroundColor(.red).font(.caption)
                Spacer()
                Text("Crossfader").font(.headline)
                Spacer()
                Image(systemName: "music.note").foregroundColor(.green).font(.caption)
            }

            ZStack {
                LinearGradient(
                    colors: [.red.opacity(0.35), .clear, .green.opacity(0.35)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 10).cornerRadius(5)

                Slider(value: $value, in: 0...1)
                    .accentColor(.white)
                    .onChange(of: value) { _, v in
                        // Haptic snap when crossing the centre point
                        let nearCenter = abs(v - 0.5) < 0.02
                        if nearCenter && !didCenterSnap {
                            haptic.impactOccurred()
                            didCenterSnap = true
                        } else if !nearCenter {
                            didCenterSnap = false
                        }
                    }
            }

            HStack {
                Text("YouTube").font(.caption2).foregroundColor(.red)
                Spacer()
                if abs(value - 0.5) < 0.04 {
                    Text("50 / 50").font(.caption2.bold()).foregroundColor(.secondary)
                }
                Spacer()
                Text("Spotify").font(.caption2).foregroundColor(.green)
            }

            Button("Reset to Center") {
                withAnimation(.spring(response: 0.3)) { value = 0.5 }
            }
            .font(.caption2).foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: – Shared progress bar

struct ProgressBar: View {
    let ratio: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray4)).frame(height: 3)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(ratio), height: 3)
            }
        }
        .frame(height: 3)
    }
}

// MARK: – Previews

#Preview("Remote Control") {
    RemoteControlView(ytVolume: .constant(80))
        .environmentObject(SpotifyRemoteService())
        .environmentObject(NowPlayingMonitor())
}

#Preview("Crossfader") {
    CrossfaderView(value: .constant(0.5)).padding()
}
