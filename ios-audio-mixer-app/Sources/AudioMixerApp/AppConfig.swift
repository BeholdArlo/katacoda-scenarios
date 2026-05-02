import Foundation
import Combine
import SwiftUI

final class AppConfig: ObservableObject {

    @Published var spotifyClientID: String {
        didSet { UserDefaults.standard.set(spotifyClientID, forKey: "spotifyClientID") }
    }

    @Published var hasLaunchedBefore: Bool {
        didSet { UserDefaults.standard.set(hasLaunchedBefore, forKey: "hasLaunchedBefore") }
    }

    init() {
        spotifyClientID  = UserDefaults.standard.string(forKey: "spotifyClientID") ?? ""
        hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
    }

    var isSpotifyConfigured: Bool {
        !spotifyClientID.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
