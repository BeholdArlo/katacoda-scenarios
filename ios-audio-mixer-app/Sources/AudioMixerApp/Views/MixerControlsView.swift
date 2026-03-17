import SwiftUI

// MARK: – Reusable channel strip

struct ChannelStrip: View {
    let label: String
    let color: Color
    let icon: String
    @Binding var volume: Double   // 0–1
    @Binding var pan: Double      // -1…0…1

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(label)
                    .font(.headline)
                Spacer()
                Text("\(Int(volume * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            // Volume fader
            VStack(alignment: .leading, spacing: 4) {
                Label("Volume", systemImage: "speaker.wave.2")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $volume, in: 0...1) {
                    Text("Volume")
                } minimumValueLabel: {
                    Image(systemName: "speaker").font(.caption)
                } maximumValueLabel: {
                    Image(systemName: "speaker.wave.3").font(.caption)
                }
                .accentColor(color)
            }

            // Pan / stereo control
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("Pan", systemImage: "headphones")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(panLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                // Custom stereo pan slider with L/C/R markers
                ZStack(alignment: .top) {
                    Slider(value: $pan, in: -1...1) {
                        Text("Pan")
                    }
                    .accentColor(color)

                    // Center detent visual indicator
                    if abs(pan) < 0.05 {
                        Rectangle()
                            .fill(color.opacity(0.6))
                            .frame(width: 2, height: 8)
                            .offset(y: -2)
                    }
                }

                HStack {
                    Text("L").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("C").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("R").font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var panLabel: String {
        if abs(pan) < 0.02 { return "Center" }
        let pct = Int(abs(pan) * 100)
        return pan < 0 ? "L\(pct)" : "R\(pct)"
    }
}

// MARK: – EQ Preset Picker

struct EQPresetPicker: View {
    @EnvironmentObject var audioEngine: AudioEngineService
    @State private var selected: AudioEngineService.EQPreset = .flat

    private let presets: [(String, AudioEngineService.EQPreset)] = [
        ("Flat",   .flat),
        ("Bass",   .bass),
        ("Treble", .treble),
        ("Vocal",  .vocal),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Spotify EQ Preset", systemImage: "waveform.path.ecg")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(presets, id: \.0) { name, preset in
                    Button(name) {
                        selected = preset
                        audioEngine.applyEQPreset(preset)
                    }
                    .buttonStyle(.bordered)
                    .tint(selected == preset ? .green : .secondary)
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: – Master mixer view combining both channels

struct MixerControlsView: View {
    // YouTube (JS-controlled)
    @Binding var ytVolume: Double      // 0–100 (for IFrame API)
    @Binding var ytPan: Double         // -1…1 (for Web Audio API)

    // Spotify (AVAudioEngine-controlled)
    @EnvironmentObject var audioEngine: AudioEngineService

    // Normalised binding wrappers
    private var ytVolumeNorm: Binding<Double> {
        Binding(get: { ytVolume / 100 }, set: { ytVolume = $0 * 100 })
    }
    private var spotifyVolumeNorm: Binding<Double> {
        Binding(
            get: { Double(audioEngine.spotifyVolume) },
            set: { audioEngine.spotifyVolume = Float($0) }
        )
    }
    private var spotifyPanNorm: Binding<Double> {
        Binding(
            get: { Double(audioEngine.spotifyPan) },
            set: { audioEngine.spotifyPan = Float($0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Mixer")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                // YouTube channel
                ChannelStrip(
                    label:  "YouTube",
                    color:  .red,
                    icon:   "play.rectangle.fill",
                    volume: ytVolumeNorm,
                    pan:    $ytPan
                )
                .padding(.horizontal)

                // Spotify channel
                ChannelStrip(
                    label:  "Spotify",
                    color:  .green,
                    icon:   "music.note",
                    volume: spotifyVolumeNorm,
                    pan:    spotifyPanNorm
                )
                .padding(.horizontal)

                // EQ for Spotify track
                EQPresetPicker()
                    .padding(.horizontal)

                // Quick-reset button
                Button {
                    withAnimation {
                        ytVolume  = 100
                        ytPan     = 0
                        audioEngine.spotifyVolume = 0.5
                        audioEngine.spotifyPan    = 0
                    }
                } label: {
                    Label("Reset All", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
    }
}
