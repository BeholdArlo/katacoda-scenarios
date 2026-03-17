#!/usr/bin/env bash
# setup.sh – Generate the Xcode project and open it.
# Requires: Homebrew, Xcode 15+

set -e

echo "==> Checking prerequisites…"

if ! command -v brew &>/dev/null; then
  echo "ERROR: Homebrew not found. Install from https://brew.sh"
  exit 1
fi

if ! command -v xcodegen &>/dev/null; then
  echo "==> Installing XcodeGen…"
  brew install xcodegen
fi

echo "==> Generating Xcode project from project.yml…"
xcodegen generate

echo ""
echo "========================================================"
echo "  NEXT STEPS"
echo "========================================================"
echo ""
echo "1. Open AudioMixerApp.xcodeproj in Xcode:"
echo "   open AudioMixerApp.xcodeproj"
echo ""
echo "2. Set your Apple Developer Team in:"
echo "   Xcode → AudioMixerApp target → Signing & Capabilities"
echo ""
echo "3. Register a Spotify application at:"
echo "   https://developer.spotify.com/dashboard"
echo "   - Set Redirect URI to:  audiomixer://spotify-callback"
echo "   - Copy your Client ID"
echo ""
echo "4. Paste your Client ID into:"
echo "   Sources/AudioMixerApp/Services/SpotifyAPIService.swift"
echo "   Line:  static let clientID = \"YOUR_SPOTIFY_CLIENT_ID\""
echo ""
echo "5. (Optional – full-track Spotify playback)"
echo "   Follow README § Full-Track Workaround to add SpotifyiOS SDK."
echo ""
echo "6. Run on a real iPhone (AVAudioEngine + WKWebView work best on device)."
echo ""
echo "========================================================"
