import Foundation
import SwiftUI

struct EpisodeKey: Comparable, Hashable {
    let season: Int
    let episode: Int

    var rawValue: String {
        "s\(season)e\(episode)"
    }

    static func < (lhs: EpisodeKey, rhs: EpisodeKey) -> Bool {
        if lhs.season != rhs.season {
            return lhs.season < rhs.season
        }
        return lhs.episode < rhs.episode
    }
}

enum EpisodeProgress {
    static func parseEpisodeKey(_ key: String) -> EpisodeKey? {
        let cleaned = key.lowercased()
        let parts = cleaned.split(separator: "e")
        guard parts.count == 2 else { return nil }

        let seasonPart = parts[0]
        let episodePart = parts[1]

        guard seasonPart.first == "s",
              let season = Int(seasonPart.dropFirst()),
              let episode = Int(episodePart),
              season > 0, episode > 0 else {
            return nil
        }

        return EpisodeKey(season: season, episode: episode)
    }

    static func sortedEpisodeKeys(_ keys: Set<String>) -> [String] {
        let parsed = keys.compactMap { raw -> (key: EpisodeKey, raw: String)? in
            guard let key = parseEpisodeKey(raw) else { return nil }
            return (key, key.rawValue)
        }
        return parsed.sorted { $0.key < $1.key }.map(\.raw)
    }

    static func nextEpisodeKey(
        watchedKeys: Set<String>,
        totalEpisodes: Int?,
        isWatched: Bool
    ) -> String? {
        if isWatched {
            return nil
        }

        let parsed = watchedKeys.compactMap(parseEpisodeKey).sorted()
        if let totalEpisodes, totalEpisodes > 0, parsed.count >= totalEpisodes {
            return nil
        }

        guard !parsed.isEmpty else {
            return EpisodeKey(season: 1, episode: 1).rawValue
        }

        if parsed.first != EpisodeKey(season: 1, episode: 1) {
            return EpisodeKey(season: 1, episode: 1).rawValue
        }

        if parsed.count > 1 {
            for index in 0..<(parsed.count - 1) {
                let current = parsed[index]
                let next = parsed[index + 1]

                if current.season == next.season, next.episode > current.episode + 1 {
                    return EpisodeKey(season: current.season, episode: current.episode + 1).rawValue
                }

                if next.season > current.season + 1 {
                    return EpisodeKey(season: current.season + 1, episode: 1).rawValue
                }
            }
        }

        guard let last = parsed.last else {
            return EpisodeKey(season: 1, episode: 1).rawValue
        }

        return EpisodeKey(season: last.season, episode: last.episode + 1).rawValue
    }

    static func displayLabel(
        for rawKey: String?,
        style: EpisodeLabelStyle
    ) -> String {
        guard let rawKey,
              let key = parseEpisodeKey(rawKey) else {
            return "All Episodes"
        }

        switch style {
        case .home:
            return "Next: S\(key.season) · E\(key.episode)"
        case .library:
            return "S\(key.season):E\(key.episode)"
        }
    }
}

enum EpisodeLabelStyle {
    case home
    case library
}

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
        return URL(string: "https://image.tmdb.org/t/p/w780\(path)")
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
