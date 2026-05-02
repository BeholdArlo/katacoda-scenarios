import SwiftUI
import AVFoundation

struct MixerControlsView: View {
    @EnvironmentObject var audioEngine: AudioEngineService
    @Binding var ytVolume: Double   // 0–100 for IFrame API
    @Binding var ytPan:    Double   // -1…1

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Mixer")
                            .font(.title2.weight(.black))
                            .neon(DS.Color.acidYellow)
                        Text("Volume & stereo control")
                            .font(.caption)
                            .foregroundColor(DS.Color.cream.opacity(0.45))
                    }
                    Spacer()
                    resetButton
                }

                HStack(alignment: .top, spacing: 12) {
                    ChannelStrip(
                        label:      "YouTube",
                        icon:       "play.rectangle.fill",
                        accent:     .red,
                        volume: Binding(
                            get: { ytVolume / 100.0 },
                            set: { ytVolume = $0 * 100.0 }
                        ),
                        pan:    $ytPan
                    )

                    ChannelStrip(
                        label:      "Spotify",
                        icon:       "music.note.list",
                        accent:     DS.Color.teal,
                        volume: Binding(
                            get: { Double(audioEngine.spotifyVolume) },
                            set: { audioEngine.spotifyVolume = Float($0) }
                        ),
                        pan: Binding(
                            get: { Double(audioEngine.spotifyPan) },
                            set: { audioEngine.spotifyPan = Float($0) }
                        )
                    )
                }

                EQSection()

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
    }

    private var resetButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                ytVolume  = 100
                ytPan     = 0
                audioEngine.spotifyVolume = 0.5
                audioEngine.spotifyPan    = 0
            }
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DS.Color.cream.opacity(0.6))
                .padding(8)
                .background(Color.white.opacity(0.07))
                .clipShape(Circle())
        }
    }
}

// MARK: – ChannelStrip

struct ChannelStrip: View {
    let label:  String
    let icon:   String
    let accent: Color
    @Binding var volume: Double   // 0–1
    @Binding var pan:    Double   // -1…1

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accent)
                    .glow(accent, radius: 4)
                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundColor(DS.Color.cream)
                Spacer()
                AnimatedPct(value: Int(volume * 100), color: accent)
            }

            // VU bars (respond to volume as proxy for level)
            VUMeter(level: volume, accent: accent)
                .frame(height: 10)

            // Volume
            VStack(alignment: .leading, spacing: 6) {
                Label("Volume", systemImage: "speaker.wave.2")
                    .font(.caption2)
                    .foregroundColor(DS.Color.cream.opacity(0.5))

                CustomGradientSlider(
                    value: $volume,
                    range: 0...1,
                    gradient: LinearGradient(
                        colors: [DS.Color.teal, DS.Color.acidYellow, accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    thumbColor: accent
                )
            }

            // Pan
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Pan", systemImage: "headphones")
                        .font(.caption2)
                        .foregroundColor(DS.Color.cream.opacity(0.5))
                    Spacer()
                    Text(panLabel(pan))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(DS.Color.cream.opacity(0.45))
                }
                CustomGradientSlider(
                    value: $pan,
                    range: -1...1,
                    gradient: DS.Color.panGradient,
                    thumbColor: DS.Color.cream
                )
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(accent.opacity(0.22), lineWidth: 1)
        )
    }

    private func panLabel(_ v: Double) -> String {
        if abs(v) < 0.04 { return " C  " }
        return v < 0 ? "L\(Int(abs(v)*100))" : "R\(Int(v*100))"
    }
}

// MARK: – Animated percentage readout

private struct AnimatedPct: View {
    let value: Int
    let color: Color
    @State private var displayed = 0

    var body: some View {
        Text("\(displayed)%")
            .font(.system(.caption2, design: .monospaced).weight(.bold))
            .foregroundColor(color)
            .glow(color, radius: 2)
            .onChange(of: value) { _, v in
                withAnimation(.spring(response: 0.2)) { displayed = v }
            }
            .onAppear { displayed = value }
    }
}

// MARK: – VU Meter

struct VUMeter: View {
    let level:  Double   // 0–1
    let accent: Color
    private let barCount = 14

    @State private var animated: Double = 0

    var body: some View {
        GeometryReader { geo in
            let gap  = CGFloat(2)
            let barW = (geo.size.width - gap * CGFloat(barCount - 1)) / CGFloat(barCount)
            HStack(spacing: gap) {
                ForEach(0..<barCount, id: \.self) { i in
                    let threshold = Double(i) / Double(barCount)
                    let active    = animated > threshold
                    Capsule()
                        .fill(active ? barColor(threshold) : barColor(threshold).opacity(0.1))
                        .frame(width: barW, height: geo.size.height)
                        .glow(active ? barColor(threshold).opacity(0.6) : .clear, radius: 2)
                }
            }
        }
        .onChange(of: level) { _, v in
            withAnimation(.easeOut(duration: 0.05)) { animated = v }
            // Decay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.5)) { animated = max(animated - 0.2, 0) }
            }
        }
    }

    private func barColor(_ t: Double) -> Color {
        if t > 0.85 { return DS.Color.magenta }
        if t > 0.65 { return DS.Color.acidYellow }
        return accent
    }
}

// MARK: – EQ Section

struct EQSection: View {
    @EnvironmentObject var audioEngine: AudioEngineService
    @State private var selected: AudioEngineService.EQPreset = .flat

    private let presets: [(String, AudioEngineService.EQPreset, String)] = [
        ("Flat",   .flat,   "minus.circle"),
        ("Bass",   .bass,   "waveform.path"),
        ("Treble", .treble, "waveform"),
        ("Vocal",  .vocal,  "mic.fill"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Spotify EQ Preset", systemImage: "dial.medium")
                .font(.subheadline.weight(.bold))
                .foregroundColor(DS.Color.cream.opacity(0.7))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presets, id: \.0) { name, preset, icon in
                        EQChip(
                            name: name,
                            icon: icon,
                            active: selected == preset
                        ) {
                            selected = preset
                            audioEngine.applyEQPreset(preset)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }
}

private struct EQChip: View {
    let name:   String
    let icon:   String
    let active: Bool
    let onTap:  () -> Void

    var body: some View {
        Button(action: onTap) {
            Label(name, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(active ? DS.Color.void : DS.Color.cream.opacity(0.7))
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(active ? DS.Color.burnOrange : Color.white.opacity(0.06))
                .clipShape(Capsule())
                .glow(active ? DS.Color.burnOrange : .clear, radius: 6)
                .overlay(
                    Capsule()
                        .strokeBorder(active ? .clear : DS.Color.glassEdge, lineWidth: 1)
                )
        }
        .animation(.spring(response: 0.25), value: active)
    }
}

#Preview {
    MixerControlsView(ytVolume: .constant(80), ytPan: .constant(0))
        .environmentObject(AudioEngineService())
        .background(DS.Color.bgGradient.ignoresSafeArea())
        .preferredColorScheme(.dark)
}
