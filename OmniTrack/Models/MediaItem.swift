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
    let genres: [String]
    var totalEpisodes: Int?
    var watchedEpisodes: Int
    var totalSeasons: Int?
    var isWatched: Bool
    var isInQueue: Bool
    let genreIds: [Int]
    var imdbRating: Double?

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }

    var backdropURL: URL? {
        guard let path = backdropPath else { return nil }
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
        if let imdb = imdbRating {
            return String(format: "%.1f", imdb)
        }
        return formattedRating
    }

    func effectiveRating(for provider: RatingProvider) -> Double {
        switch provider {
        case .tmdb: return rating
        case .imdb: return imdbRating ?? rating
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
