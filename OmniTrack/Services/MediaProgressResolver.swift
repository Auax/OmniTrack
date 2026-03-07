import Foundation

final class MediaProgressResolver {
    
    // MARK: - EpisodeKey Parsing & Calculation
    
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
    
    // MARK: - Continue Watching Resolution
    
    static func fallbackContinueTarget(
        for item: MediaItem,
        watchedKeys: Set<String>,
        watchedEpisodeCount: Int,
        totalEpisodesOverride: Int? = nil
    ) -> ContinueEpisodeTarget? {
        guard item.hasSeasonsAndEpisodes, !item.isWatched else { return nil }

        let fallbackTotal = max(totalEpisodesOverride ?? 0, item.totalEpisodes ?? 0)
        if fallbackTotal > 0 {
            for episodeNumber in 1...fallbackTotal {
                let key = EpisodeKey(season: 1, episode: episodeNumber)
                if !watchedKeys.contains(key.rawValue) {
                    return ContinueEpisodeTarget(
                        episode: key,
                        totalEpisodes: fallbackTotal,
                        isLastEpisode: episodeNumber == fallbackTotal
                    )
                }
            }
            return nil
        }

        let nextKey = nextEpisodeKey(
            watchedKeys: watchedKeys,
            totalEpisodes: item.totalEpisodes,
            isWatched: item.isWatched
        )
        guard let parsed = nextKey.flatMap(parseEpisodeKey) else { return nil }

        let inferredTotal = max(watchedEpisodeCount + 1, 1)
        return ContinueEpisodeTarget(episode: parsed, totalEpisodes: inferredTotal, isLastEpisode: false)
    }
    
    static func resolveTargetFromSeasonSummaries(
        for item: MediaItem,
        seasons: [TMDBSeasonSummary],
        watchedKeys: Set<String>,
        totalEpisodesHint: Int?
    ) -> ContinueEpisodeTarget? {
        let sortedSeasons = seasons
            .filter { $0.seasonNumber > 0 && $0.episodeCount > 0 }
            .sorted { $0.seasonNumber < $1.seasonNumber }

        guard !sortedSeasons.isEmpty else {
            return fallbackContinueTarget(
                for: item,
                watchedKeys: watchedKeys,
                watchedEpisodeCount: watchedKeys.count,
                totalEpisodesOverride: totalEpisodesHint
            )
        }

        var firstUnwatched: EpisodeKey?
        var totalEpisodes = 0
        var unwatchedCount = 0

        for season in sortedSeasons {
            totalEpisodes += season.episodeCount
            for episodeNumber in 1...season.episodeCount {
                let key = EpisodeKey(season: season.seasonNumber, episode: episodeNumber)
                if !watchedKeys.contains(key.rawValue) {
                    unwatchedCount += 1
                    if firstUnwatched == nil { firstUnwatched = key }
                }
            }
        }

        guard let firstUnwatched else { return nil }

        let resolvedTotal = max(totalEpisodes, totalEpisodesHint ?? 0, item.totalEpisodes ?? 0, 1)
        return ContinueEpisodeTarget(
            episode: firstUnwatched,
            totalEpisodes: resolvedTotal,
            isLastEpisode: unwatchedCount == 1
        )
    }
}
