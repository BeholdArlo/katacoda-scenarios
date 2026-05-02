import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appConfig: AppConfig
    @Environment(\.dismiss) private var dismiss

    @State private var clientIDInput = ""
    @State private var showClientID  = false
    @State private var copiedSource  = false

    private let altSourceURL = "https://raw.githubusercontent.com/BeholdArlo/katacoda-scenarios/main/docs/source.json"
    private let githubURL    = "https://github.com/BeholdArlo/katacoda-scenarios"
    private let spotifyDashboard = "https://developer.spotify.com/dashboard"

    var body: some View {
        ZStack {
            DS.Color.bgGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    header
                    spotifySection
                    installSection
                    aboutSection
                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
        .onAppear { clientIDInput = appConfig.spotifyClientID }
        .preferredColorScheme(.dark)
    }

    // MARK: – Header

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.largeTitle.weight(.black))
                .neon(DS.Color.cream)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(DS.Color.cream.opacity(0.6))
            }
        }
        .padding(.top, 8)
    }

    // MARK: – Spotify

    private var spotifySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Spotify Client ID", icon: "music.note", color: DS.Color.teal)

            if appConfig.isSpotifyConfigured {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DS.Color.teal)
                        .glow(DS.Color.teal, radius: 6)
                    Text("Connected")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DS.Color.teal)
                    Spacer()
                    Button("Change") { appConfig.spotifyClientID = ""; clientIDInput = "" }
                        .font(.caption)
                        .foregroundColor(DS.Color.cream.opacity(0.5))
                }
            } else {
                clientIDField

                Button(action: openSpotifyDashboard) {
                    Label("Get free Client ID →", systemImage: "arrow.up.right.square")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(DS.Color.teal)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(DS.Color.teal.opacity(0.5), lineWidth: 1)
                        )
                }

                howToSteps
            }
        }
        .padding(20)
        .glassCard()
    }

    private var clientIDField: some View {
        HStack(spacing: 8) {
            Group {
                if showClientID {
                    TextField("Paste Client ID here", text: $clientIDInput)
                } else {
                    SecureField("Paste Client ID here", text: $clientIDInput)
                }
            }
            .font(.system(.body, design: .monospaced))
            .foregroundColor(DS.Color.cream)
            .autocapitalization(.none)
            .disableAutocorrection(true)

            Button { showClientID.toggle() } label: {
                Image(systemName: showClientID ? "eye.slash" : "eye")
                    .foregroundColor(DS.Color.cream.opacity(0.5))
            }

            Button(action: pasteClientID) {
                Text("Paste")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DS.Color.burnOrange.opacity(0.25))
                    .foregroundColor(DS.Color.burnOrange)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(clientIDInput.isEmpty ? DS.Color.glassEdge : DS.Color.teal.opacity(0.5), lineWidth: 1)
        )
        .onChange(of: clientIDInput) { _, v in
            appConfig.spotifyClientID = v.trimmingCharacters(in: .whitespaces)
        }
    }

    private var howToSteps: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(DS.Color.acidYellow)
                        .frame(width: 18, height: 18)
                        .background(DS.Color.acidYellow.opacity(0.15))
                        .clipShape(Circle())
                    Text(step)
                        .font(.caption)
                        .foregroundColor(DS.Color.cream.opacity(0.7))
                }
            }
        }
    }

    private let steps = [
        "Visit the Spotify Dashboard link above",
        "Log in and tap "Create app"",
        "Name it anything — set Redirect URI to: audiomixer://spotify-callback",
        "Copy your Client ID and paste it in the field above",
    ]

    // MARK: – Install

    private var installSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Install / Updates", icon: "arrow.down.circle", color: DS.Color.burnOrange)

            VStack(alignment: .leading, spacing: 10) {
                Text("AltStore / SideStore Source")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DS.Color.cream)

                Text("Add this URL as a Remote Source in SideStore or AltStore for one-tap installs and automatic updates.")
                    .font(.caption)
                    .foregroundColor(DS.Color.cream.opacity(0.6))

                HStack(spacing: 8) {
                    Text(altSourceURL)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(DS.Color.acidYellow.opacity(0.8))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)

                    Button(action: copySourceURL) {
                        Image(systemName: copiedSource ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(copiedSource ? DS.Color.teal : DS.Color.burnOrange)
                            .glow(copiedSource ? DS.Color.teal : .clear, radius: 6)
                            .animation(.spring(), value: copiedSource)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: – About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("About", icon: "info.circle", color: DS.Color.magenta)

            HStack {
                Text("AudioMixer").font(.subheadline.weight(.semibold)).foregroundColor(DS.Color.cream)
                Spacer()
                Text("v1.0.0").font(.caption).foregroundColor(DS.Color.cream.opacity(0.5))
            }

            Button(action: openGitHub) {
                Label("View on GitHub", systemImage: "arrow.up.right.square")
                    .font(.subheadline)
                    .foregroundColor(DS.Color.magenta)
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: – Helpers

    private func sectionLabel(_ title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.headline.weight(.bold))
            .foregroundColor(color)
            .glow(color, radius: 4)
    }

    private func pasteClientID() {
        if let str = UIPasteboard.general.string {
            clientIDInput = str.trimmingCharacters(in: .whitespaces)
        }
    }

    private func copySourceURL() {
        UIPasteboard.general.string = altSourceURL
        copiedSource = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedSource = false }
    }

    private func openSpotifyDashboard() {
        UIApplication.shared.open(URL(string: spotifyDashboard)!)
    }

    private func openGitHub() {
        UIApplication.shared.open(URL(string: githubURL)!)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppConfig())
}
