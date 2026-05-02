import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appConfig: AppConfig
    @State private var page = 0

    var body: some View {
        ZStack {
            AnimatedMeshBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") { finish() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DS.Color.cream.opacity(0.55))
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                }

                // Cards
                TabView(selection: $page) {
                    WelcomeCard().tag(0)
                    YouTubeCard().tag(1)
                    SpotifyCard(onFinish: finish).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: page)

                // Page dots
                HStack(spacing: 10) {
                    ForEach(0..<3) { i in
                        GlowingDot(active: page == i, color: dotColor(i))
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func finish() { appConfig.hasLaunchedBefore = true }

    private func dotColor(_ i: Int) -> Color {
        [DS.Color.burnOrange, DS.Color.acidYellow, DS.Color.teal][i]
    }
}

// MARK: – Animated background

private struct AnimatedMeshBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            DS.Color.void
            RadialGradient(
                colors: [DS.Color.burnOrange.opacity(0.35), .clear],
                center: animate ? .topLeading : .bottomTrailing,
                startRadius: 0, endRadius: 400
            )
            RadialGradient(
                colors: [DS.Color.magenta.opacity(0.25), .clear],
                center: animate ? .bottomTrailing : .topLeading,
                startRadius: 0, endRadius: 350
            )
            RadialGradient(
                colors: [DS.Color.teal.opacity(0.2), .clear],
                center: .center,
                startRadius: 0, endRadius: 300
            )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

// MARK: – Card 1: Welcome

private struct WelcomeCard: View {
    @State private var glowPulse = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(DS.Color.burnOrange.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .blur(radius: glowPulse ? 20 : 30)
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(DS.Color.burnOrange)
                    .glow(DS.Color.burnOrange, radius: glowPulse ? 20 : 12)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }

            VStack(spacing: 12) {
                Text("AudioMixer")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .neon(DS.Color.acidYellow)

                Text("YouTube + Spotify.\nOne glorious mix.")
                    .font(.title3.weight(.medium))
                    .foregroundColor(DS.Color.cream.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            Text("Swipe to get started →")
                .font(.footnote)
                .foregroundColor(DS.Color.cream.opacity(0.4))

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: – Card 2: YouTube Setup

private struct YouTubeCard: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)
                .glow(.red, radius: 16)

            VStack(spacing: 10) {
                Text("Load any YouTube video")
                    .font(.title2.weight(.black))
                    .neon(DS.Color.cream)
                    .multilineTextAlignment(.center)

                Text("Paste any YouTube URL or 11-character video ID into the bar at the top of the mixer.")
                    .font(.body)
                    .foregroundColor(DS.Color.cream.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            // Visual example
            VStack(alignment: .leading, spacing: 8) {
                Label("Example", systemImage: "link")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(DS.Color.acidYellow.opacity(0.8))

                Text("youtube.com/watch?v=dQw4w9WgXcQ")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(DS.Color.teal.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(16)
            .glassCard(cornerRadius: 16)

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

// MARK: – Card 3: Spotify Setup

private struct SpotifyCard: View {
    let onFinish: () -> Void

    @EnvironmentObject var appConfig: AppConfig
    @State private var clientIDInput = ""

    private let dashboardURL = "https://developer.spotify.com/dashboard"

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 56))
                    .foregroundColor(DS.Color.teal)
                    .glow(DS.Color.teal, radius: 14)
                    .padding(.top, 16)

                VStack(spacing: 8) {
                    Text("Unlock Spotify Search")
                        .font(.title2.weight(.black))
                        .neon(DS.Color.cream)
                        .multilineTextAlignment(.center)

                    Text("Free. Takes 30 seconds.")
                        .font(.subheadline)
                        .foregroundColor(DS.Color.acidYellow)
                }

                stepsView

                clientIDEntryView

                VStack(spacing: 12) {
                    Button(action: finish) {
                        Text(appConfig.isSpotifyConfigured ? "Let's Mix  🎛️" : "Skip for now")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(appConfig.isSpotifyConfigured ? DS.Color.teal : DS.Color.burnOrange.opacity(0.8))
                            .foregroundColor(DS.Color.void)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .glow(appConfig.isSpotifyConfigured ? DS.Color.teal : DS.Color.burnOrange, radius: 8)
                    }

                    if appConfig.isSpotifyConfigured {
                        Button("Skip for now") { onFinish() }
                            .font(.caption)
                            .foregroundColor(DS.Color.cream.opacity(0.4))
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 28)
        }
    }

    private var stepsView: some View {
        let items = [
            ("1", "Visit Spotify Dashboard", "arrow.up.right.square", DS.Color.burnOrange),
            ("2", "Create app — set Redirect URI to: audiomixer://spotify-callback", "app.badge.plus", DS.Color.magenta),
            ("3", "Copy your Client ID", "doc.on.clipboard", DS.Color.acidYellow),
            ("4", "Paste it below", "arrow.down.doc", DS.Color.teal),
        ]
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 12) {
                    Text(item.0)
                        .font(.caption.weight(.bold))
                        .foregroundColor(item.3)
                        .frame(width: 22, height: 22)
                        .background(item.3.opacity(0.15))
                        .clipShape(Circle())

                    Text(item.1)
                        .font(.subheadline)
                        .foregroundColor(DS.Color.cream.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    private var clientIDEntryView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("Paste Client ID here", text: $clientIDInput)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(DS.Color.cream)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: clientIDInput) { _, v in
                        appConfig.spotifyClientID = v.trimmingCharacters(in: .whitespaces)
                    }

                Button(action: paste) {
                    Text("Paste")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(DS.Color.teal.opacity(0.2))
                        .foregroundColor(DS.Color.teal)
                        .clipShape(Capsule())
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(clientIDInput.isEmpty ? DS.Color.glassEdge : DS.Color.teal.opacity(0.6), lineWidth: 1)
            )

            Button(action: openDashboard) {
                Label("Open Spotify Dashboard", systemImage: "arrow.up.right.square")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(DS.Color.teal.opacity(0.8))
            }
        }
    }

    private func paste() {
        if let str = UIPasteboard.general.string {
            clientIDInput = str.trimmingCharacters(in: .whitespaces)
        }
    }

    private func openDashboard() {
        UIApplication.shared.open(URL(string: dashboardURL)!)
    }

    private func finish() {
        if !appConfig.isSpotifyConfigured { appConfig.spotifyClientID = "" }
        onFinish()
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppConfig())
}
