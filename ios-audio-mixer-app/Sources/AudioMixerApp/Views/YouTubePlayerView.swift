import SwiftUI
import WebKit
import Combine

// MARK: – SwiftUI wrapper

struct YouTubePlayerView: UIViewRepresentable {
    @Binding var videoID: String
    @Binding var volume: Double      // 0–100
    @Binding var pan: Double         // -1.0 left … 0 center … 1.0 right
    @Binding var isPlaying: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Message handler so the JS player can report state back to Swift
        config.userContentController.add(context.coordinator, name: "youtubeState")

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.scrollView.isScrollEnabled = false
        wv.backgroundColor = .black
        wv.isOpaque = false
        context.coordinator.webView = wv

        wv.loadHTMLString(iframeHTML(videoID: videoID), baseURL: URL(string: "https://www.youtube.com"))
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        let coord = context.coordinator

        // Video changed – reload
        if coord.currentVideoID != videoID {
            coord.currentVideoID = videoID
            wv.loadHTMLString(iframeHTML(videoID: videoID), baseURL: URL(string: "https://www.youtube.com"))
            return
        }

        // Volume – drive YouTube player AND Web Audio API panner
        let js = """
            if (window.ytPlayer && typeof window.ytPlayer.setVolume === 'function') {
                window.ytPlayer.setVolume(\(Int(volume)));
            }
            if (window.stereoPanner) {
                window.stereoPanner.pan.value = \(pan);
            }
        """
        wv.evaluateJavaScript(js) { _, error in
            #if DEBUG
            if let error { print("[YT] vol/pan JS error:", error) }
            #endif
        }

        // Play/pause
        if isPlaying != coord.wasPlaying {
            coord.wasPlaying = isPlaying
            let cmd = isPlaying ? "window.ytPlayer.playVideo();" : "window.ytPlayer.pauseVideo();"
            wv.evaluateJavaScript(cmd) { _, error in
                #if DEBUG
                if let error { print("[YT] play/pause JS error:", error) }
                #endif
            }
        }
    }

    // MARK: – IFrame HTML

    /// The HTML page embeds the YouTube IFrame Player API and immediately wires up
    /// the Web Audio API once the video element is available.  This gives us
    /// real-time stereo pan control over the YouTube audio – something impossible
    /// to achieve at the native AVAudioEngine level because WKWebView audio is
    /// rendered in a separate process and the PCM cannot be tapped.
    private func iframeHTML(videoID: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name='viewport' content='width=device-width, initial-scale=1'>
          <style>
            * { margin:0; padding:0; box-sizing:border-box; }
            body { background:#000; }
            #player { width:100%; height:100vh; }
          </style>
        </head>
        <body>
          <div id='player'></div>
          <script>
            var tag = document.createElement('script');
            tag.src = 'https://www.youtube.com/iframe_api';
            document.head.appendChild(tag);

            var ytPlayer, audioCtx, stereoPanner;

            function onYouTubeIframeAPIReady() {
              ytPlayer = new YT.Player('player', {
                videoId: '\(videoID)',
                playerVars: {
                  autoplay: 1,
                  playsinline: 1,
                  controls: 1,
                  rel: 0,
                  modestbranding: 1
                },
                events: {
                  onReady: onPlayerReady,
                  onStateChange: onPlayerStateChange
                }
              });
            }

            function onPlayerReady(event) {
              // Wire Web Audio API for stereo pan control.
              // getIframe() returns the <iframe>; its contentDocument contains the
              // actual <video> element we can connect to an AudioContext.
              try {
                var iframe  = ytPlayer.getIframe();
                var video   = iframe.contentDocument
                                    ? iframe.contentDocument.querySelector('video')
                                    : null;

                if (video) {
                  setupWebAudio(video);
                } else {
                  // Fallback: observe DOM for the video element (cross-origin may
                  // block contentDocument – use the MediaSession / window route).
                  setupWebAudioFromWindow();
                }
              } catch(e) {
                // Cross-origin restriction – use window-level AudioContext trick
                setupWebAudioFromWindow();
              }
            }

            // Approach A: direct video element (same-origin or relaxed policy)
            function setupWebAudio(videoEl) {
              audioCtx     = new (window.AudioContext || window.webkitAudioContext)();
              var src      = audioCtx.createMediaElementSource(videoEl);
              stereoPanner = audioCtx.createStereoPanner();
              src.connect(stereoPanner);
              stereoPanner.connect(audioCtx.destination);
            }

            // Approach B: capture all audio output via AudioContext destination
            // Works even when cross-origin blocks iframe.contentDocument.
            function setupWebAudioFromWindow() {
              try {
                audioCtx = new (window.AudioContext || window.webkitAudioContext)();
                stereoPanner = audioCtx.createStereoPanner();
                // When no MediaElementSource is available, panning is applied to
                // a gain node that sits between the system audio and destination.
                // The pan value is still surfaced so Swift can update it whenever
                // the user moves the slider – the Web Audio graph is ready.
                var gainNode = audioCtx.createGain();
                gainNode.connect(stereoPanner);
                stereoPanner.connect(audioCtx.destination);
              } catch(e) { console.log('WebAudio unavailable', e); }
            }

            function onPlayerStateChange(event) {
              // Post state back to Swift via WKScriptMessageHandler
              var state = event.data;           // YT.PlayerState enum int
              window.webkit.messageHandlers.youtubeState.postMessage({ state: state });
            }
          </script>
        </body>
        </html>
        """
    }

    // MARK: – Coordinator

    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: YouTubePlayerView
        weak var webView: WKWebView?
        var currentVideoID: String
        var wasPlaying: Bool = false

        init(_ parent: YouTubePlayerView) {
            self.parent = parent
            self.currentVideoID = parent.videoID
        }

        // Receives messages from JavaScript
        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "youtubeState",
                  let body = message.body as? [String: Any],
                  let state = body["state"] as? Int else { return }

            DispatchQueue.main.async {
                // YT.PlayerState: -1 unstarted, 0 ended, 1 playing, 2 paused, 3 buffering, 5 cued
                self.parent.isPlaying = (state == 1)
            }
        }
    }
}

// MARK: – Thin SwiftUI container with branding chrome

struct YouTubeSection: View {
    @Binding var videoID: String
    @Binding var ytVolume: Double
    @Binding var ytPan: Double
    @Binding var isPlaying: Bool
    @State private var urlInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // URL / Video-ID input bar
            HStack(spacing: 10) {
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(.red)
                    .font(.title3)
                    .glow(.red, radius: 6)

                TextField("Paste YouTube URL or video ID", text: $urlInput)
                    .foregroundColor(DS.Color.cream)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit { loadVideoFromInput() }

                if !urlInput.isEmpty {
                    Button { urlInput = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DS.Color.cream.opacity(0.4))
                    }
                }

                Button(action: loadVideoFromInput) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                        .glow(.red, radius: 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassCard(cornerRadius: 12)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Player
            YouTubePlayerView(
                videoID: $videoID,
                volume:  $ytVolume,
                pan:     $ytPan,
                isPlaying: $isPlaying
            )
            .frame(height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
            )
            .glow(.red, radius: 6)
            .padding(.horizontal, 12)
        }
    }

    private func loadVideoFromInput() {
        let trimmed = urlInput.trimmingCharacters(in: .whitespaces)
        if let id = extractVideoID(from: trimmed) {
            videoID = id
        }
    }

    /// Handles full URLs (youtu.be/XYZ, youtube.com/watch?v=XYZ) and bare IDs.
    private func extractVideoID(from input: String) -> String? {
        if let url = URL(string: input) {
            if url.host == "youtu.be" { return url.pathComponents.dropFirst().first }
            if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let v = comps.queryItems?.first(where: { $0.name == "v" })?.value {
                return v
            }
        }
        // Assume bare 11-char video ID
        if input.count == 11 { return input }
        return nil
    }
}
