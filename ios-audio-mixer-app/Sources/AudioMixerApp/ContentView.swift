import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appConfig:     AppConfig
    @EnvironmentObject var audioEngine:   AudioEngineService
    @EnvironmentObject var spotifyService: SpotifyAPIService
    @EnvironmentObject var spotifyRemote: SpotifyRemoteService
    @EnvironmentObject var nowPlaying:    NowPlayingMonitor

    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("lastYTVideoID") private var ytVideoID = "dQw4w9WgXcQ"
    @State private var ytVolume  = 80.0
    @State private var ytPan     = 0.0
    @State private var ytPlaying = true
    @State private var selectedTab = 0
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Global background ──────────────────────────────────────────
            DS.Color.bgGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top bar ────────────────────────────────────────────────
                topBar

                // ── YouTube player (always visible) ───────────────────────
                YouTubeSection(
                    videoID:   $ytVideoID,
                    ytVolume:  $ytVolume,
                    ytPan:     $ytPan,
                    isPlaying: $ytPlaying
                )
                .frame(maxHeight: 270)
                .padding(.bottom, 8)

                // ── Tab content ────────────────────────────────────────────
                ZStack {
                    tabContent(for: 0) { MixerControlsView(ytVolume: $ytVolume, ytPan: $ytPan) }
                    tabContent(for: 1) { RemoteControlView(ytVolume: $ytVolume) }
                    tabContent(for: 2) { MusicSearchView() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // ── Custom tab bar ─────────────────────────────────────────
                customTabBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                    .padding(.top, 10)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appConfig)
        }
        .onChange(of: selectedTab) { _, tab in
            if tab == 1 {
                nowPlaying.startMonitoring()
                spotifyRemote.connectIfNeeded()
            } else {
                nowPlaying.stopMonitoring()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard selectedTab == 1 else { return }
            if phase == .active  { nowPlaying.startMonitoring() }
            else                 { nowPlaying.stopMonitoring() }
        }
    }

    // MARK: – Top bar

    private var topBar: some View {
        HStack {
            Text("AudioMixer")
                .font(.title3.weight(.black))
                .neon(DS.Color.acidYellow)

            Spacer()

            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(DS.Color.cream.opacity(0.7))
                    .glow(DS.Color.cream.opacity(0.3), radius: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    // MARK: – Tab content helper (visibility-switch avoids re-creation)

    @ViewBuilder
    private func tabContent<V: View>(for tag: Int, @ViewBuilder content: () -> V) -> some View {
        content()
            .opacity(selectedTab == tag ? 1 : 0)
            .allowsHitTesting(selectedTab == tag)
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }

    // MARK: – Custom tab bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabPill(index: 0, icon: "slider.horizontal.3", label: "Mixer",  accent: DS.Color.burnOrange)
            tabPill(index: 1, icon: "dot.radiowaves.left.and.right", label: "Remote", accent: DS.Color.magenta)
            tabPill(index: 2, icon: "music.note",          label: "Music",  accent: DS.Color.teal)
        }
        .padding(6)
        .glassCard(cornerRadius: 26)
    }

    private func tabPill(index: Int, icon: String, label: String, accent: Color) -> some View {
        let active = selectedTab == index
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = index }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                if active {
                    Text(label)
                        .font(.subheadline.weight(.bold))
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
            .foregroundColor(active ? DS.Color.void : DS.Color.cream.opacity(0.55))
            .padding(.vertical, 10)
            .padding(.horizontal, active ? 18 : 20)
            .background(active ? accent : Color.clear)
            .clipShape(Capsule())
            .glow(active ? accent : .clear, radius: active ? 8 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: active)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppConfig())
        .environmentObject(AudioEngineService())
        .environmentObject(SpotifyAPIService())
        .environmentObject(SpotifyRemoteService())
        .environmentObject(NowPlayingMonitor())
}
