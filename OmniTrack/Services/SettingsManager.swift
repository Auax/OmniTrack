import SwiftUI

@Observable
class SettingsManager {
    var showMovies: Bool {
        didSet { UserDefaults.standard.set(showMovies, forKey: "showMovies") }
    }
    var showTVShows: Bool {
        didSet { UserDefaults.standard.set(showTVShows, forKey: "showTVShows") }
    }
    var showAnime: Bool {
        didSet { UserDefaults.standard.set(showAnime, forKey: "showAnime") }
    }
    var themeMode: ThemeMode {
        didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode") }
    }
    var ratingProvider: RatingProvider {
        didSet { UserDefaults.standard.set(ratingProvider.rawValue, forKey: "ratingProvider") }
    }

    var preferredColorScheme: ColorScheme? {
        switch themeMode {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "showMovies") == nil {
            defaults.set(true, forKey: "showMovies")
        }
        if defaults.object(forKey: "showTVShows") == nil {
            defaults.set(true, forKey: "showTVShows")
        }
        if defaults.object(forKey: "showAnime") == nil {
            defaults.set(true, forKey: "showAnime")
        }
        self.showMovies = defaults.bool(forKey: "showMovies")
        self.showTVShows = defaults.bool(forKey: "showTVShows")
        self.showAnime = defaults.bool(forKey: "showAnime")
        let rawTheme = defaults.string(forKey: "themeMode") ?? ThemeMode.system.rawValue
        self.themeMode = ThemeMode(rawValue: rawTheme) ?? .system
        let rawRating = defaults.string(forKey: "ratingProvider") ?? RatingProvider.imdb.rawValue
        self.ratingProvider = RatingProvider(rawValue: rawRating) ?? .imdb
    }
}

nonisolated enum ThemeMode: String, CaseIterable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

nonisolated enum RatingProvider: String, CaseIterable, Sendable, Identifiable {
    case imdb = "IMDb"
    case tmdb = "TMDB"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .imdb: "star.fill"
        case .tmdb: "star.circle.fill"
        }
    }
}

