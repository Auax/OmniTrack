import Foundation

nonisolated enum MediaType: String, Codable, Sendable, CaseIterable, Identifiable, Hashable {
    case movie = "Movies"
    case tvShow = "TV Shows"
    case anime = "Anime"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .movie: "film"
        case .tvShow: "tv"
        case .anime: "sparkles.tv"
        }
    }
}

nonisolated enum SortOption: String, CaseIterable, Sendable, Identifiable {
    case defaultOrder = "Default"
    case rating = "Rating"
    case yearDesc = "Newest First"
    case yearAsc = "Oldest First"
    case titleAZ = "Title A-Z"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .defaultOrder: "flame.fill"
        case .rating: "star.fill"
        case .yearDesc: "calendar.badge.clock"
        case .yearAsc: "calendar"
        case .titleAZ: "textformat.abc"
        }
    }
}
