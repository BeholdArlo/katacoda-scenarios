import SwiftUI

// MARK: – Root view

struct RemoteControlView: View {
    @EnvironmentObject var spotifyRemote: SpotifyRemoteService
    @EnvironmentObject var nowPlaying:    NowPlayingMonitor

    @Binding var ytVolume: Double

    @State private var crossfader: Double = 0.5
    @AppStorage("remoteCapBannerDismissed") private var bannerDismissed = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Remote")
                            .font(.title2.weight(.black))
                            .neon(DS.Color.acidYellow)
                        Text("Control YouTube & Spotify apps")
                            .font(.caption)
                            .foregroundColor(DS.Color.cream.opacity(0.45))
                    }
                    Spacer()
                }

                if !bannerDismissed { infoBanner }

                YouTubeAppDeck(
                    nowPlaying: nowPlaying,
                    crossfaderVolume: ytCurve(crossfader)
                )

                CrossfaderView(value: $crossfader)
                    .onChange(of: crossfader, applyCrossfade)

                SpotifyAppDeck()

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
    }

    // MARK: – Equal-power curves

    private func ytCurve(_ x: Double) -> Double { cos(x * .pi / 2) }
    private func spCurve(_ x: Double) -> Double { sin(x * .pi / 2) }

    private func applyCrossfade(_ old: Double, _ x: Double) {
        ytVolume = 100 * ytCurve(x)
        if spotifyRemote.isConnected { spotifyRemote.setSpotifyVolume(spCurve(x)) }
    }

    // MARK: – Info banner

    private var infoBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(DS.Color.acidYellow)
                .glow(DS.Color.acidYellow, radius: 4)
                .font(.caption)
                .padding(.top, 1)
            Text("Crossfader controls the embedded YouTube player and Spotify's own volume via App Remote. Use the Mixer tab for EQ and stereo pan.")
                .font(.caption)
                .foregroundColor(DS.Color.cream.opacity(0.7))
            Spacer()
            Button { bannerDismissed = true } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(DS.Color.cream.opacity(0.4))
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 12)
    }
}

// MARK: – YouTube App Deck

struct YouTubeAppDeck: View {
    @ObservedObject var nowPlaying: NowPlayingMonitor
    let crossfaderVolume: Double

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(.red)
                    .glow(.red, radius: 6)
                Text("YouTube")
                    .font(.headline.weight(.bold))
                    .foregroundColor(DS.Color.cream)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2")
                        .font(.caption)
                    Text("\(Int(crossfaderVolume * 100))%")
                        .font(.caption.monospacedDigit())
                }
                .foregroundColor(DS.Color.cream.opacity(0.5))
            }

            if nowPlaying.isActive, let title = nowPlaying.title {
                nowPlayingContent(title: title)
            } else {
                idleContent
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.red.opacity(0.25), lineWidth: 1)
        )
    }

    private func nowPlayingContent(title: String) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                artworkView
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DS.Color.cream)
                        .lineLimit(2)
                    if let artist = nowPlaying.artist {
                        Text(artist)
                            .font(.caption)
                            .foregroundColor(DS.Color.cream.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text(nowPlaying.elapsedFormatted)
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(DS.Color.cream.opacity(0.4))
            }

            ProgressBar(ratio: nowPlaying.progressRatio, color: .red)

            Button { nowPlaying.openYouTubeApp() } label: {
                Label("Open YouTube App", systemImage: "arrow.up.right.square")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundColor(.red)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.red.opacity(0.4), lineWidth: 1)
                    )
            }
        }
    }

    private var idleContent: some View {
        VStack(spacing: 10) {
            Text("YouTube app is not playing")
                .font(.caption)
                .foregroundColor(DS.Color.cream.opacity(0.4))
            Button { nowPlaying.openYouTubeApp() } label: {
                Label("Open YouTube App", systemImage: "arrow.up.right.square")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundColor(.red)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.red.opacity(0.4), lineWidth: 1)
                    )
            }
            Text("Start a video in the YouTube app — this deck detects it automatically.")
                .font(.caption2)
                .foregroundColor(DS.Color.cream.opacity(0.35))
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder private var artworkView: some View {
        if let img = nowPlaying.artwork {
            Image(uiImage: img)
                .resizable().scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .glow(.red, radius: 4)
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DS.Color.deepViolet)
                .frame(width: 52, height: 52)
                .overlay(Image(systemName: "play.rectangle").foregroundColor(DS.Color.cream.opacity(0.3)))
        }
    }
}

// MARK: – Spotify App Deck

struct SpotifyAppDeck: View {
    @EnvironmentObject var spotifyRemote: SpotifyRemoteService

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .foregroundColor(DS.Color.teal)
                    .glow(DS.Color.teal, radius: 6)
                Text("Spotify")
                    .font(.headline.weight(.bold))
                    .foregroundColor(DS.Color.cream)
                Spacer()
                connectionBadge
            }

            if spotifyRemote.isConnected { connectedContent } else { disconnectedContent }
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(DS.Color.teal.opacity(0.25), lineWidth: 1)
        )
    }

    private var connectionBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(spotifyRemote.isConnected ? DS.Color.teal : DS.Color.cream.opacity(0.2))
                .frame(width: 7, height: 7)
                .glow(spotifyRemote.isConnected ? DS.Color.teal : .clear, radius: 4)
            Text(spotifyRemote.isConnected ? "Connected" : "Disconnected")
                .font(.caption)
                .foregroundColor(spotifyRemote.isConnected ? DS.Color.teal : DS.Color.cream.opacity(0.4))
        }
    }

    private var connectedContent: some View {
        VStack(spacing: 12) {
            if let track = spotifyRemote.currentTrack { trackRow(track) }
            else {
                Text("Waiting for Spotify to start…")
                    .font(.caption)
                    .foregroundColor(DS.Color.cream.opacity(0.4))
            }
            transportControls
            spotifyVolumeSlider
            if let err = spotifyRemote.connectionError {
                Text(err).font(.caption2).foregroundColor(DS.Color.magenta)
            }
        }
    }

    private func trackRow(_ track: RemoteTrackInfo) -> some View {
        HStack(spacing: 12) {
            Group {
                if let art = track.artwork {
                    Image(uiImage: art).resizable().scaledToFill()
                } else {
                    DS.Color.deepViolet
                        .overlay(Image(systemName: "music.note").foregroundColor(DS.Color.cream.opacity(0.3)))
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .glow(DS.Color.teal, radius: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DS.Color.cream)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.caption)
                    .foregroundColor(DS.Color.cream.opacity(0.5))
                    .lineLimit(1)
                Text(track.album)
                    .font(.caption2)
                    .foregroundColor(DS.Color.cream.opacity(0.35))
                    .lineLimit(1)
            }
            Spacer()
            Text(track.formattedDuration)
                .font(.caption2.monospacedDigit())
                .foregroundColor(DS.Color.cream.opacity(0.4))
        }
    }

    private var transportControls: some View {
        HStack(spacing: 36) {
            transportButton(icon: "backward.fill") { spotifyRemote.skipPrevious() }

            Button { spotifyRemote.togglePlayPause() } label: {
                Image(systemName: spotifyRemote.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 46))
                    .foregroundColor(DS.Color.teal)
                    .glow(DS.Color.teal, radius: 10)
            }

            transportButton(icon: "forward.fill") { spotifyRemote.skipNext() }
        }
        .frame(maxWidth: .infinity)
    }

    private func transportButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(DS.Color.cream.opacity(0.8))
                .padding(10)
                .background(Color.white.opacity(0.07))
                .clipShape(Circle())
        }
    }

    private var spotifyVolumeSlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Spotify Volume", systemImage: "speaker.wave.2")
                    .font(.caption2)
                    .foregroundColor(DS.Color.cream.opacity(0.5))
                Spacer()
                Text("\(Int(spotifyRemote.spotifyVolume * 100))%")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(DS.Color.teal)
            }
            CustomGradientSlider(
                value: Binding(
                    get: { spotifyRemote.spotifyVolume },
                    set: { spotifyRemote.setSpotifyVolume($0) }
                ),
                range: 0...1,
                gradient: LinearGradient(colors: [DS.Color.deepViolet, DS.Color.teal], startPoint: .leading, endPoint: .trailing),
                thumbColor: DS.Color.teal
            )
        }
    }

    private var disconnectedContent: some View {
        VStack(spacing: 12) {
            Text(spotifyRemote.isSpotifyInstalled
                 ? "Connect to your logged-in Spotify app for full-track playback and crossfader control."
                 : "Spotify app is not installed on this device.")
                .font(.caption)
                .foregroundColor(DS.Color.cream.opacity(0.55))
                .multilineTextAlignment(.center)

            if spotifyRemote.isSpotifyInstalled {
                Button { spotifyRemote.connectIfNeeded() } label: {
                    Label("Connect to Spotify App", systemImage: "link")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(DS.Color.void)
                        .background(DS.Color.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .glow(DS.Color.teal, radius: 8)
                }
            }
            if let err = spotifyRemote.connectionError {
                Text(err).font(.caption2).foregroundColor(DS.Color.magenta).multilineTextAlignment(.center)
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
        VStack(spacing: 14) {
            // Labels row
            HStack {
                Label("YouTube", systemImage: "play.rectangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.red)
                    .glow(.red, radius: 3)
                Spacer()
                Text("Crossfader")
                    .font(.headline.weight(.bold))
                    .foregroundColor(DS.Color.cream)
                Spacer()
                Label("Spotify", systemImage: "music.note.list")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(DS.Color.teal)
                    .glow(DS.Color.teal, radius: 3)
            }

            // Custom gradient track + thumb
            CrossfaderTrack(value: $value, didCenterSnap: $didCenterSnap, haptic: haptic)

            // Volume readouts
            HStack {
                Text("YT \(Int(cos(value * .pi / 2) * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.red.opacity(0.7))
                Spacer()
                if abs(value - 0.5) < 0.04 {
                    Text("50 / 50")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(DS.Color.acidYellow)
                        .glow(DS.Color.acidYellow, radius: 4)
                }
                Spacer()
                Text("SP \(Int(sin(value * .pi / 2) * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(DS.Color.teal.opacity(0.7))
            }

            Button("Reset to Center") {
                withAnimation(.spring(response: 0.3)) { value = 0.5 }
            }
            .font(.caption)
            .foregroundColor(DS.Color.cream.opacity(0.4))
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(DS.Color.acidYellow.opacity(0.15), lineWidth: 1)
        )
    }
}

private struct CrossfaderTrack: View {
    @Binding var value: Double
    @Binding var didCenterSnap: Bool
    let haptic: UIImpactFeedbackGenerator

    private let trackH: CGFloat = 8
    private let thumbS: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let usable = geo.size.width - thumbS
            let thumbX = thumbS / 2 + CGFloat(value) * usable

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.35), DS.Color.cream.opacity(0.15), DS.Color.teal.opacity(0.35)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: trackH)

                // Center notch
                Capsule()
                    .fill(DS.Color.acidYellow.opacity(0.5))
                    .frame(width: 2, height: trackH * 1.5)
                    .offset(x: geo.size.width / 2 - 1)

                // Thumb
                Circle()
                    .fill(DS.Color.cream)
                    .frame(width: thumbS, height: thumbS)
                    .glow(abs(value - 0.5) < 0.04 ? DS.Color.acidYellow : DS.Color.cream.opacity(0.5), radius: 8)
                    .offset(x: thumbX - thumbS / 2)
            }
            .frame(height: thumbS)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let raw = Double((drag.location.x - thumbS / 2) / usable)
                        var snapped = raw.clamped(to: 0...1)
                        // Center snap at ±2%
                        if abs(snapped - 0.5) < 0.02 {
                            snapped = 0.5
                            if !didCenterSnap { haptic.impactOccurred(); didCenterSnap = true }
                        } else {
                            didCenterSnap = false
                        }
                        value = snapped
                    }
            )
        }
        .frame(height: thumbS)
    }
}

// MARK: – Progress bar (reused by YouTube deck)

struct ProgressBar: View {
    let ratio: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 3)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(min(ratio, 1)), height: 3)
                    .glow(color, radius: 3)
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
        .background(DS.Color.bgGradient.ignoresSafeArea())
        .preferredColorScheme(.dark)
}
