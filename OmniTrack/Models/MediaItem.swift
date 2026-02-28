import Foundation
import SwiftUI

struct MediaItem: Identifiable, Hashable {
    let id: Int
    let title: String
    let subtitle: String
    let overview: String
    let type: MediaType
    let posterPath: String?
    let backdropPath: String?
    let rating: Double
    let year: Int
    let releaseDateString: String?
    let genres: [String]
    var totalEpisodes: Int?
    var watchedEpisodes: Int
    var totalSeasons: Int?
    var isWatched: Bool
    var isInProgress: Bool
    var isInQueue: Bool
    let genreIds: [Int]
    var imdbRating: Double?
    let animeRomajiTitle: String?
    let animeEnglishTitle: String?

    init(
        id: Int,
        title: String,
        subtitle: String,
        overview: String,
        type: MediaType,
        posterPath: String?,
        backdropPath: String?,
        rating: Double,
        year: Int,
        releaseDateString: String? = nil,
        genres: [String],
        totalEpisodes: Int?,
        watchedEpisodes: Int,
        totalSeasons: Int?,
        isWatched: Bool,
        isInProgress: Bool = false,
        isInQueue: Bool,
        genreIds: [Int],
        imdbRating: Double? = nil,
        animeRomajiTitle: String? = nil,
        animeEnglishTitle: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.overview = overview
        self.type = type
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.rating = rating
        self.year = year
        self.releaseDateString = releaseDateString
        self.genres = genres
        self.totalEpisodes = totalEpisodes
        self.watchedEpisodes = watchedEpisodes
        self.totalSeasons = totalSeasons
        self.isWatched = isWatched
        self.isInProgress = isInProgress
        self.isInQueue = isInQueue
        self.genreIds = genreIds
        self.imdbRating = imdbRating
        self.animeRomajiTitle = animeRomajiTitle
        self.animeEnglishTitle = animeEnglishTitle
    }

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }

    var backdropURL: URL? {
        guard let path = backdropPath else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        return URL(string: "https://image.tmdb.org/t/p/w780\(path)")
    }

    var progress: Double {
        guard let total = totalEpisodes, total > 0 else {
            return isWatched ? 1.0 : 0.0
        }
        return Double(watchedEpisodes) / Double(total)
    }

    var accentColor: Color {
        let hash = abs(title.hashValue)
        let colors: [Color] = [
            Color(hex: "E63946"), Color(hex: "457B9D"), Color(hex: "2A9D8F"),
            Color(hex: "E9C46A"), Color(hex: "6A0572"), Color(hex: "C4A035"),
            Color(hex: "D4572A"), Color(hex: "2A6B4F"), Color(hex: "8B2C2C"),
            Color(hex: "4A2D8B"), Color(hex: "1B4D6E"), Color(hex: "B53A25")
        ]
        return colors[hash % colors.count]
    }

    var accentColorHex: String {
        let hash = abs(title.hashValue)
        let hexes = [
            "E63946", "457B9D", "2A9D8F", "E9C46A", "6A0572", "C4A035",
            "D4572A", "2A6B4F", "8B2C2C", "4A2D8B", "1B4D6E", "B53A25"
        ]
        return hexes[hash % hexes.count]
    }

    var formattedRating: String {
        String(format: "%.1f", rating)
    }

    var formattedImdbRating: String {
        if isAniListAnime {
            return formattedRating
        }
        if let imdb = imdbRating {
            return String(format: "%.1f", imdb)
        }
        return formattedRating
    }

    var isAniListAnime: Bool {
        type == .anime && id >= 1_000_000_000
    }

    var animeRatingIconColor: Color {
        guard isAniListAnime else { return .yellow }

        switch rating {
        case 8.5...:
            return Color(hex: "7DD3FC") // Highest: light blue
        case 7.0..<8.5:
            return Color(hex: "38BDF8")
        case 5.5..<7.0:
            return Color(hex: "22C55E")
        case 4.0..<5.5:
            return Color(hex: "F59E0B")
        default:
            return Color(hex: "EF4444")
        }
    }

    func preferredDisplayTitle(animeTitlePreference: AnimeTitlePreference) -> String {
        guard isAniListAnime else { return title }
        switch animeTitlePreference {
        case .romaji:
            return animeRomajiTitle ?? animeEnglishTitle ?? title
        case .translated:
            return animeEnglishTitle ?? animeRomajiTitle ?? title
        }
    }

    func effectiveRating(for provider: RatingProvider) -> Double {
        switch provider {
        case .tmdb: return rating
        case .imdb: return isAniListAnime ? rating : (imdbRating ?? rating)
        }
    }

    var tmdbId: Int {
        switch type {
        case .movie: return id
        case .tvShow, .anime: return id - 100000
        }
    }

    var hasSeasonsAndEpisodes: Bool {
        type == .tvShow || type == .anime
    }
}
