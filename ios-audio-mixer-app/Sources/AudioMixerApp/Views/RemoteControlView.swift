import SwiftUI

// MARK: – Root view

/// "Remote" tab — control the **native YouTube app and Spotify app** you're
/// already logged into, and crossfade between them.
///
/// ## Audio mixing capabilities in this mode
/// | Feature            | YouTube (native app) | Spotify (App Remote)         |
/// |--------------------|---------------------|------------------------------|
/// | Volume             | Visual only*        | ✅ Independent via App Remote |
/// | Play / Pause       | Open app via URL    | ✅ In-app button              |
/// | Skip               | Open app via URL    | ✅ In-app button              |
/// | Crossfader         | Visual only*        | ✅ Fades Spotify volume        |
/// | EQ / Pan           | ❌ iOS sandbox      | ❌ iOS sandbox                |
///
/// *YouTube volume cannot be controlled from outside its process on standard iOS.
///  Use the Mixer tab (embedded WKWebView) for full volume + stereo pan control.
struct RemoteControlView: View {
    @EnvironmentObject var spotifyRemote: SpotifyRemoteService
    @EnvironmentObject var nowPlaying:    NowPlayingMonitor

    /// 0.0 = full YouTube · 0.5 = equal power · 1.0 = full Spotify
    @State private var crossfader: Double = 0.5

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Remote Control")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                capabilityBanner
                    .padding(.horizontal)

                // YouTube deck
                YouTubeAppDeck(
                    nowPlaying: nowPlaying,
                    crossfaderVolume: ytVolume(for: crossfader)
                )
                .padding(.horizontal)

                // DJ crossfader
                CrossfaderView(value: $crossfader)
                    .padding(.horizontal)
                    .onChange(of: crossfader) { _, v in applyCrossfade(v) }

                // Spotify deck
                SpotifyAppDeck()
                    .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: – Crossfade math (equal-power / constant-power law)

    /// Equal-power curve keeps perceived loudness constant across the fade.
    private func ytVolume(for x: Double) -> Double { cos(x * .pi / 2) }
    private func spVolume(for x: Double) -> Double { sin(x * .pi / 2) }

    private func applyCrossfade(_ x: Double) {
        // Spotify: set independently via App Remote
        if spotifyRemote.isConnected {
            spotifyRemote.setSpotifyVolume(spVolume(for: x))
        }
        // YouTube (native app): iOS does not allow setting another app's volume.
        // The WKWebView embedded player (Mixer tab) DOES support JS volume control —
        // crossfading with that is handled by MixerControlsView's reset button.
        // Here we show the value visually in the YouTubeAppDeck.
    }

    // MARK: – Info banner

    private var capabilityBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
                .font(.caption)
                .padding(.top, 1)
            Text("Spotify volume crossfades via App Remote. YouTube app volume is read-only on iOS — for full per-source DSP, use the **Mixer** tab's embedded player.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: – YouTube App Deck

struct YouTubeAppDeck: View {
    @ObservedObject var nowPlaying: NowPlayingMonitor
    /// Visual-only: reflects the crossfader's YouTube side (0–1).
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

    // MARK: Sub-views

    private var deckHeader: some View {
        HStack {
            Image(systemName: "play.rectangle.fill").foregroundColor(.red)
            Text("YouTube").font(.headline)
            Spacer()
            // Volume is visual-only; badge explains the limitation
            HStack(spacing: 4) {
                Image(systemName: "speaker.wave.2").font(.caption)
                Text("\(Int(crossfaderVolume * 100))%").font(.caption.monospacedDigit())
                Image(systemName: "lock.fill").font(.system(size: 9))
            }
            .foregroundColor(.secondary)
            .help("YouTube volume cannot be set from outside the app on iOS.")
        }
    }

    private func nowPlayingContent(title: String) -> some View {
        VStack(spacing: 10) {
            // Artwork + metadata
            HStack(spacing: 12) {
                artworkView
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    if let artist = nowPlaying.artist {
                        Text(artist)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text(nowPlaying.elapsedFormatted)
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            // Progress bar
            ProgressBar(ratio: nowPlaying.progressRatio, color: .red)

            // Open YouTube button
            Button {
                nowPlaying.openYouTubeApp()
            } label: {
                Label("Open YouTube App", systemImage: "arrow.up.right.square")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    private var idleContent: some View {
        VStack(spacing: 10) {
            Text("YouTube app is not playing")
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                nowPlaying.openYouTubeApp()
            } label: {
                Label("Open YouTube App", systemImage: "arrow.up.right.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Text("Play a video in the YouTube app, then come back — the mixer will detect it automatically.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var artworkView: some View {
        if let img = nowPlaying.artwork {
            Image(uiImage: img)
                .resizable().scaledToFill()
                .frame(width: 52, height: 52)
                .cornerRadius(8).clipped()
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "play.rectangle")
                        .foregroundColor(.secondary)
                )
        }
    }
}

// MARK: – Spotify App Deck

struct SpotifyAppDeck: View {
    @EnvironmentObject var spotifyRemote: SpotifyRemoteService

    var body: some View {
        VStack(spacing: 12) {
            deckHeader
            if spotifyRemote.isConnected {
                connectedContent
            } else {
                disconnectedContent
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    // MARK: Sub-views

    private var deckHeader: some View {
        HStack {
            Image(systemName: "music.note").foregroundColor(.green)
            Text("Spotify").font(.headline)
            Spacer()
            connectionBadge
        }
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
            if let track = spotifyRemote.currentTrack {
                trackRow(track)
                transportControls
                spotifyVolumeSlider
            } else {
                Text("Waiting for Spotify to start playing…")
                    .font(.caption)
                    .foregroundColor(.secondary)
                transportControls
            }

            if let err = spotifyRemote.connectionError {
                Text(err).font(.caption2).foregroundColor(.red)
            }
        }
    }

    private func trackRow(_ track: RemoteTrackInfo) -> some View {
        HStack(spacing: 12) {
            if let art = track.artwork {
                Image(uiImage: art)
                    .resizable().scaledToFill()
                    .frame(width: 52, height: 52)
                    .cornerRadius(8).clipped()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 52, height: 52)
                    .overlay(Image(systemName: "music.note").foregroundColor(.secondary))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(track.artist)
                    .font(.caption).foregroundColor(.secondary).lineLimit(1)
                Text(track.album)
                    .font(.caption2).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            Text(track.formattedDuration)
                .font(.caption2.monospacedDigit())
                .foregroundColor(.secondary)
        }
    }

    private var transportControls: some View {
        HStack(spacing: 32) {
            Button { spotifyRemote.skipPrevious() } label: {
                Image(systemName: "backward.fill").font(.title2)
            }
            .foregroundColor(.primary)

            Button { spotifyRemote.togglePlayPause() } label: {
                Image(systemName: spotifyRemote.isPlaying
                      ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.green)
            }

            Button { spotifyRemote.skipNext() } label: {
                Image(systemName: "forward.fill").font(.title2)
            }
            .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Spotify-side volume slider — changes the Spotify app's output level
    /// independently of the iOS system volume.
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
            if !spotifyRemote.isSpotifyInstalled {
                Text("Spotify app is not installed on this device.")
                    .font(.caption).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Connect to your logged-in Spotify app for full-track playback and independent volume control via the crossfader.")
                    .font(.caption).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    spotifyRemote.connectIfNeeded()
                } label: {
                    Label("Connect to Spotify App", systemImage: "link")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                if let err = spotifyRemote.connectionError {
                    Text(err).font(.caption2).foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

// MARK: – DJ Crossfader

/// Equal-power crossfader between YouTube and Spotify.
/// Moving left → YouTube at full volume, Spotify fades out.
/// Moving right → Spotify at full volume, YouTube fades out.
/// Center (0.5) → both sources at ~70% (constant-power law).
struct CrossfaderView: View {
    @Binding var value: Double   // 0 = YouTube · 1 = Spotify

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(.red).font(.caption)
                Spacer()
                Text("Crossfader")
                    .font(.headline)
                Spacer()
                Image(systemName: "music.note")
                    .foregroundColor(.green).font(.caption)
            }

            // Gradient track behind the slider
            ZStack {
                LinearGradient(
                    colors: [.red.opacity(0.35), .clear, .green.opacity(0.35)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 10)
                .cornerRadius(5)

                Slider(value: $value, in: 0...1)
                    .accentColor(.white)
            }

            HStack {
                Text("YouTube").font(.caption2).foregroundColor(.red)
                Spacer()
                if abs(value - 0.5) < 0.04 {
                    Text("50 / 50")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("Spotify").font(.caption2).foregroundColor(.green)
            }

            Button("Reset to Center") {
                withAnimation(.spring(response: 0.3)) { value = 0.5 }
            }
            .font(.caption2)
            .foregroundColor(.secondary)
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
    RemoteControlView()
        .environmentObject(SpotifyRemoteService())
        .environmentObject(NowPlayingMonitor())
}

#Preview("Crossfader") {
    CrossfaderView(value: .constant(0.5))
        .padding()
}
