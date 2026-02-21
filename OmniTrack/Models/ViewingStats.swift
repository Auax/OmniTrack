import Foundation

struct ViewingStats {
    let totalWatched: Int
    let totalInQueue: Int
    let movieCount: Int
    let tvShowCount: Int
    let animeCount: Int
    let hoursWatched: Double
    let weeklyActivity: [DayActivity]
    let genreBreakdown: [GenreSlice]
}

struct DayActivity: Identifiable {
    let id: UUID = UUID()
    let day: String
    let count: Int
}

struct GenreSlice: Identifiable {
    let id: UUID = UUID()
    let name: String
    let count: Int
    let color: String
}
