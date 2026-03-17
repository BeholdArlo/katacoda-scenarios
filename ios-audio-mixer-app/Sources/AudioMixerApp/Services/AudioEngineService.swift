import AVFoundation
import Combine
import MediaPlayer

/// Core audio mixing engine.
///
/// Architecture workaround summary:
/// - YouTube audio lives inside WKWebView and cannot be captured as PCM.
///   Volume + stereo pan are controlled via injected Web Audio API JavaScript.
/// - Spotify preview audio is piped through AVAudioEngine so we get real-time
///   DSP access: per-node volume, stereo pan, and EQ.
/// - AVAudioSession category is set to `.playback` with `.mixWithOthers` so both
///   sources coexist without ducking each other.
final class AudioEngineService: ObservableObject {

    // MARK: – Published state (drives SwiftUI)

    @Published var spotifyVolume: Float = 0.5 {
        didSet { spotifyMixer.outputVolume = spotifyVolume }
    }
    @Published var spotifyPan: Float = 0.0 {
        didSet { spotifyPlayer.pan = spotifyPan }
    }
    @Published var isPlaying: Bool = false
    @Published var isLoadingPreview = false   // true during network download
    @Published var playbackError: String?
    @Published var currentTrackDuration: Double = 0
    @Published var currentPlaybackTime: Double = 0

    // MARK: – AVAudioEngine graph
    //
    //  spotifyPlayer ──► spotifyMixer ──► mainMixer ──► output
    //                        ▲
    //              volume & EQ applied here

    private let engine        = AVAudioEngine()
    private let spotifyPlayer = AVAudioPlayerNode()
    private let spotifyMixer  = AVAudioMixerNode()
    private let spotifyEQ     = AVAudioUnitEQ(numberOfBands: 3)

    // MARK: – Playback state
    private var audioFile: AVAudioFile?
    private var playbackTimer: AnyCancellable?
    private var scheduledBuffer: AVAudioPCMBuffer?
    private var currentTempURL: URL?          // deleted when a new preview loads or on stop
    private var nowPlayingTitle: String?
    private var nowPlayingArtist: String?

    deinit { playbackTimer?.cancel() }

    // MARK: – Setup

    func setup() {
        configureAudioSession()
        buildAudioGraph()
        configureDefaultEQ()
        startEngine()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .mixWithOthers lets WKWebView (YouTube) and our engine run simultaneously.
            // .allowBluetooth + .allowBluetoothA2DP ensure AirPods work for both sources.
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
            )
            try session.setActive(true)
        } catch {
            playbackError = "Audio session setup failed: \(error.localizedDescription)"
        }
    }

    private func buildAudioGraph() {
        [spotifyPlayer, spotifyMixer, spotifyEQ].forEach { engine.attach($0) }

        let format = engine.mainMixerNode.outputFormat(forBus: 0)

        engine.connect(spotifyPlayer, to: spotifyEQ,    format: format)
        engine.connect(spotifyEQ,    to: spotifyMixer,  format: format)
        engine.connect(spotifyMixer, to: engine.mainMixerNode, format: format)
    }

    private func configureDefaultEQ() {
        // Subtle warm preset – user can extend via `applyEQPreset(_:)`
        let bands = spotifyEQ.bands
        // Low shelf +2 dB @ 80 Hz
        bands[0].filterType  = .lowShelf
        bands[0].frequency   = 80
        bands[0].gain        = 2.0
        bands[0].bypass      = false
        // Mid peak +1 dB @ 2 kHz
        bands[1].filterType  = .parametric
        bands[1].frequency   = 2000
        bands[1].bandwidth   = 1.0
        bands[1].gain        = 1.0
        bands[1].bypass      = false
        // High shelf -1 dB @ 12 kHz
        bands[2].filterType  = .highShelf
        bands[2].frequency   = 12000
        bands[2].gain        = -1.0
        bands[2].bypass      = false
    }

    private func startEngine() {
        do {
            try engine.start()
        } catch {
            playbackError = "Engine start failed: \(error.localizedDescription)"
        }
    }

    // MARK: – Playback

    /// Load and schedule a remote audio URL (e.g. Spotify 30-s preview MP3).
    /// `title` and `artist` populate the lock-screen / control-center Now Playing card.
    func loadAndPlay(url: URL, title: String? = nil, artist: String? = nil) {
        stopPlayback()
        nowPlayingTitle  = title
        nowPlayingArtist = artist
        isLoadingPreview = true

        // Download to temp file so AVAudioFile can read it
        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self else { return }

            let finish = { DispatchQueue.main.async { self.isLoadingPreview = false } }

            if let error {
                DispatchQueue.main.async {
                    self.playbackError = error.localizedDescription
                    finish()
                }
                return
            }
            guard let tempURL else { finish(); return }

            // Move to stable temp path with .mp3 extension, deleting the previous one
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".mp3")
            if let old = self.currentTempURL { try? FileManager.default.removeItem(at: old) }
            try? FileManager.default.moveItem(at: tempURL, to: dest)
            self.currentTempURL = dest

            do {
                let file = try AVAudioFile(forReading: dest)
                self.audioFile = file
                let duration = Double(file.length) / file.processingFormat.sampleRate
                DispatchQueue.main.async {
                    self.currentTrackDuration = duration
                }
                self.scheduleFile(file, duration: duration)
            } catch {
                DispatchQueue.main.async { self.playbackError = error.localizedDescription }
            }
            finish()
        }
        task.resume()
    }

    private func scheduleFile(_ file: AVAudioFile, duration: Double) {
        guard engine.isRunning else { startEngine() }

        spotifyPlayer.scheduleFile(file, at: nil) { [weak self] in
            DispatchQueue.main.async {
                self?.isPlaying = false
                self?.currentPlaybackTime = 0
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            }
        }
        spotifyPlayer.play()

        DispatchQueue.main.async {
            self.isPlaying = true
            self.updateNowPlayingCenter(duration: duration)
        }
        startPlaybackTimer()
    }

    /// Registers the current track with iOS so the lock screen and control
    /// center show the correct title, artist, and scrubber position.
    private func updateNowPlayingCenter(duration: Double) {
        var info: [String: Any] = [
            MPMediaItemPropertyPlaybackDuration:      duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0.0,
            MPNowPlayingInfoPropertyPlaybackRate:     1.0,
        ]
        if let t = nowPlayingTitle  { info[MPMediaItemPropertyTitle]  = t }
        if let a = nowPlayingArtist { info[MPMediaItemPropertyArtist] = a }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func pauseResume() {
        if spotifyPlayer.isPlaying {
            spotifyPlayer.pause()
            isPlaying = false
        } else {
            spotifyPlayer.play()
            isPlaying = true
        }
    }

    func stopPlayback() {
        spotifyPlayer.stop()
        playbackTimer?.cancel()
        isPlaying = false
        currentPlaybackTime = 0
        if let old = currentTempURL {
            try? FileManager.default.removeItem(at: old)
            currentTempURL = nil
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: – Progress timer

    private func startPlaybackTimer() {
        playbackTimer?.cancel()
        playbackTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.isPlaying else { return }
                if let nodeTime = self.spotifyPlayer.lastRenderTime,
                   let playerTime = self.spotifyPlayer.playerTime(forNodeTime: nodeTime) {
                    self.currentPlaybackTime = Double(playerTime.sampleTime) / playerTime.sampleRate
                }
            }
    }

    // MARK: – EQ Presets

    enum EQPreset { case flat, bass, treble, vocal }

    func applyEQPreset(_ preset: EQPreset) {
        let bands = spotifyEQ.bands
        switch preset {
        case .flat:
            bands.forEach { $0.gain = 0 }
        case .bass:
            bands[0].gain = 6; bands[1].gain = 0; bands[2].gain = -2
        case .treble:
            bands[0].gain = -2; bands[1].gain = 0; bands[2].gain = 5
        case .vocal:
            bands[0].gain = -3; bands[1].gain = 4; bands[2].gain = 1
        }
    }
}
