import Foundation

struct SpotifyTrack: Identifiable, Hashable {
    let id: String
    let name: String
    let artistName: String
    let albumName: String
    let artworkURL: URL?
    let previewURL: URL?      // 30-second MP3 – always available (when non-nil)
    let durationSeconds: Double
    let popularity: Int

    init?(raw: RawTrack) {
        // Tracks without a preview URL are filtered out; we cannot play them
        // without the Spotify iOS SDK (see README for full-track workaround).
        guard let previewString = raw.preview_url,
              let previewURL = URL(string: previewString) else { return nil }

        self.id             = raw.id
        self.name           = raw.name
        self.artistName     = raw.artists.map(\.name).joined(separator: ", ")
        self.albumName      = raw.album.name
        self.artworkURL     = URL(string: raw.album.images.first?.url ?? "")
        self.previewURL     = previewURL
        self.durationSeconds = Double(raw.duration_ms) / 1000.0
        self.popularity     = raw.popularity
    }

    var formattedDuration: String {
        let mins = Int(durationSeconds) / 60
        let secs = Int(durationSeconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
