import Foundation
import SwiftUI

struct Season: Identifiable {
    let id: Int
    let seasonNumber: Int
    let name: String
    let episodeCount: Int
    var episodes: [Episode]
}

struct Episode: Identifiable {
    let id: Int
    let episodeNumber: Int
    let seasonNumber: Int
    let name: String
    let overview: String
    let stillPath: String?
    let airDate: String?
    let runtime: Int?
    var isWatched: Bool
    var isInQueue: Bool

    var stillURL: URL? {
        guard let path = stillPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w300\(path)")
    }

    var episodeKey: String {
        "s\(seasonNumber)e\(episodeNumber)"
    }

    var formattedRuntime: String? {
        guard let runtime, runtime > 0 else { return nil }
        return "\(runtime)m"
    }

    var formattedAirDate: String? {
        guard let airDate, !airDate.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: airDate) else { return nil }
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
