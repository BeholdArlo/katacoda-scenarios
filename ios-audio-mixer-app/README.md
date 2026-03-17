# iOS Audio Mixer – YouTube + Spotify + Stereo Control

An iPhone/iPad app that lets you watch a YouTube video and simultaneously listen
to a Spotify track at an independently-controlled volume, with per-channel stereo
pan control for both sources.

---

## Feature Overview

| Feature | How it works |
|---|---|
| YouTube video playback | WKWebView + YouTube IFrame Player API |
| YouTube volume control | `ytPlayer.setVolume()` via JS bridge |
| YouTube stereo pan | Web Audio API `StereoPannerNode` injected into the page |
| Spotify preview playback | Spotify Web API 30-s preview MP3s → AVAudioEngine |
| Spotify volume | `AVAudioMixerNode.outputVolume` |
| Spotify stereo pan | `AVAudioPlayerNode.pan` |
| Spotify EQ | `AVAudioUnitEQ` (Flat / Bass / Treble / Vocal presets) |
| Both sources simultaneously | `AVAudioSession` category `.playback` + `.mixWithOthers` |
| OAuth (no server) | Spotify Authorization Code + PKCE via `ASWebAuthenticationSession` |
| Background audio | `UIBackgroundModes: audio` in Info.plist |

---

## Quick Start

```bash
git clone <this-repo>
cd ios-audio-mixer-app
./setup.sh          # installs XcodeGen, generates .xcodeproj
open AudioMixerApp.xcodeproj
```

Then follow the printed checklist (Team ID + Spotify Client ID).

---

## Roadblocks & Workarounds

### Roadblock 1 – YouTube audio is sandboxed inside WKWebView

iOS renders WKWebView in a separate process (`com.apple.WebKit.WebContent`).
There is no AVAudioTap or PCM capture path from outside that process.

**Workaround – Web Audio API injection**

After the IFrame Player fires `onReady`, we inject JavaScript that wires the
video element's audio through a `StereoPannerNode`:

```javascript
var audioCtx     = new AudioContext();
var src          = audioCtx.createMediaElementSource(videoElement);
var stereoPanner = audioCtx.createStereoPanner();
src.connect(stereoPanner);
stereoPanner.connect(audioCtx.destination);
```

Swift then calls `evaluateJavaScript` to update `stereoPanner.pan.value` in
real-time as the user moves the pan slider.  Volume is controlled via
`ytPlayer.setVolume(n)` (0–100 IFrame API scale).

**Result:** Full stereo pan + independent volume on YouTube with zero latency,
no audio quality loss, and fully within YouTube's ToS (we're using their
official IFrame Player API).

---

### Roadblock 2 – Spotify doesn't expose a PCM audio tap

The Spotify iOS SDK (`SpotifyiOS.framework`) remote-controls the Spotify app
but does not provide audio buffers; it is a Remote Control interface, not a
stream.

**Workaround A – 30-second preview URLs (implemented, no extra SDK)**

Every Spotify track's Web API response includes a `preview_url` – a direct
30-second MP3 hosted by Spotify.  These are publicly accessible, licensed for
playback inside apps built with the Spotify Web API, and can be fed directly
into `AVAudioEngine`:

```swift
let file = try AVAudioFile(forReading: previewURL)
spotifyPlayer.scheduleFile(file, at: nil, completionHandler: nil)
spotifyPlayer.play()
```

This gives complete DSP access: volume, stereo pan, EQ, time-stretching – all
via AVAudioEngine.

**Workaround B – Full-track playback with SpotifyiOS SDK (optional)**

For full 3-minute tracks you need the official SDK.  The trade-off: you lose
AVAudioEngine-level DSP because the Spotify app owns the audio session.

Steps to add:
1. Download `SpotifyiOS.xcframework` from
   https://github.com/spotify/ios-sdk/releases
2. Drag it into your Xcode project → Embed & Sign.
3. In `SpotifyAPIService` add:
   ```swift
   import SpotifyiOS
   let config = SPTConfiguration(clientID: Config.clientID,
                                  redirectURL: URL(string: Config.redirectURI)!)
   let sessionManager = SPTSessionManager(configuration: config, delegate: self)
   let appRemote = SPTAppRemote(configuration: config, logLevel: .debug)
   ```
4. Volume on the Spotify app side is controlled with:
   ```swift
   appRemote.playerAPI?.setVolume(50, callback: nil)
   ```
5. Our YouTube WKWebView still runs independently via `.mixWithOthers`.

The combined effect: YouTube (WKWebView, Web Audio pan) + Spotify full tracks
(SPTAppRemote volume) give you independent volume on both sources.

---

### Roadblock 3 – AVAudioSession conflict (one source ducks the other)

iOS default behaviour: a new `.playback` session ducks or interrupts existing
audio.

**Workaround:**
```swift
try session.setCategory(.playback, mode: .default,
                         options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP])
```

`.mixWithOthers` tells the system to mix our engine with whatever WKWebView is
playing instead of ducking it.  Both streams are then summed at the hardware
level with independent software volumes.

---

### Roadblock 4 – WKWebView cross-origin blocks `iframe.contentDocument`

YouTube's IFrame runs from `www.youtube.com`; the host page is also loaded with
`youtube.com` as `baseURL` so the origins match.  If they ever diverge, the
fallback path (`setupWebAudioFromWindow`) creates an `AudioContext` at the
top-level window scope which still allows pan control via the destination node.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                     AudioMixerApp                        │
│                                                          │
│  ┌──────────────────┐      ┌───────────────────────────┐ │
│  │  YouTubeSection   │      │     MusicSearchView       │ │
│  │  (WKWebView)      │      │  (Spotify Web API)        │ │
│  │                   │      │                           │ │
│  │  IFrame Player ◄──┼─JS──►  volume slider            │ │
│  │  Web Audio API    │      │  pan slider               │ │
│  │  StereoPanner     │      └──────────┬────────────────┘ │
│  └───────┬───────────┘                 │                  │
│          │                             │ preview MP3 URL   │
│          │ iOS Audio Hardware          ▼                  │
│          │ (.mixWithOthers)   ┌─────────────────────────┐ │
│          │◄───────────────────│   AudioEngineService     │ │
│          │                    │                          │ │
│          │                    │  AVAudioPlayerNode       │ │
│          │                    │    → AVAudioUnitEQ       │ │
│          │                    │    → AVAudioMixerNode    │ │
│          │                    │    → mainMixerNode       │ │
│          │                    │    → output              │ │
│          │                    └─────────────────────────┘ │
└──────────┴──────────────────────────────────────────────┘
              ↓ (both streams mixed at hardware level)
         🎧  AirPods / Speaker / Wired headphones
```

---

## File Structure

```
ios-audio-mixer-app/
├── README.md
├── project.yml                      ← XcodeGen spec
├── setup.sh                         ← one-command setup
└── Sources/
    └── AudioMixerApp/
        ├── AudioMixerApp.swift      ← @main + deep-link handler
        ├── ContentView.swift        ← root layout
        ├── Info.plist
        ├── Services/
        │   ├── AudioEngineService.swift   ← AVAudioEngine mixer
        │   └── SpotifyAPIService.swift    ← OAuth PKCE + Web API
        ├── Views/
        │   ├── YouTubePlayerView.swift    ← WKWebView + Web Audio
        │   ├── MixerControlsView.swift    ← per-channel faders
        │   └── MusicSearchView.swift      ← Spotify search + now-playing
        └── Models/
            └── SpotifyTrack.swift
```

---

## Requirements

- Xcode 15+ on macOS 13+
- iOS 16+ deployment target
- Apple Developer account (free is fine for device testing)
- Spotify account (free tier gives preview URLs; Premium enables full tracks
  via SpotifyiOS SDK)
- Internet connection (YouTube + Spotify APIs)

---

## Spotify Developer Setup (5 minutes)

1. Go to https://developer.spotify.com/dashboard → Create app
2. App name: `AudioMixer`  |  Redirect URI: `audiomixer://spotify-callback`
3. Copy **Client ID** → paste into `SpotifyAPIService.Config.clientID`
4. That's it – no client secret needed (PKCE flow).

---

## Audio Quality Notes

- **YouTube**: Web Audio API processes audio at the browser's native sample
  rate (typically 44.1 kHz or 48 kHz) before hardware output – zero quality
  degradation from the stereo pan DSP.
- **Spotify previews**: 128 kbps AAC MP3, decoded by AVAudioEngine's built-in
  converter.  The `AVAudioUnitEQ` and pan operate on the decoded PCM at full
  float32 precision.
- **Mixing**: Both streams are summed at the hardware mixer level with
  `mixWithOthers`, avoiding any double-decode or re-encoding path.

The quality is equal to or better than listening to each source natively,
because we add DSP (stereo pan + EQ) that neither YouTube nor Spotify offers
in their standalone apps.
