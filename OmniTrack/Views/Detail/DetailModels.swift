import SwiftUI

enum RatingSource {
    case imdb
    case tmdb
    case aniList

    var label: String {
        switch self {
        case .imdb: return "IMDb"
        case .tmdb: return "TMDB"
        case .aniList: return "AniList"
        }
    }

    var fallbackSymbol: String {
        switch self {
        case .imdb: return "i.circle.fill"
        case .tmdb: return "star.fill"
        case .aniList: return "sparkles.tv"
        }
    }

    var tint: Color {
        switch self {
        case .imdb: return .yellow
        case .tmdb: return .yellow
        case .aniList: return .pink
        }
    }

    var assetName: String {
        switch self {
        case .imdb: return "rating_source_imdb"
        case .tmdb: return "rating_source_tmdb"
        case .aniList: return "rating_source_anilist"
        }
    }
}
