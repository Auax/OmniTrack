import SwiftUI
import Observation

@Observable
final class DetailViewModel {
    var seasons: [Season] = []
    var isLoadingSeasons: Bool = false
    var fetchError: Bool = false
    var expandedSeason: Int?
    var loadingSeasonNumbers: Set<Int> = []
    var tvDetail: TMDBTVDetail?

    private let tmdbService = TMDBService()

    var totalEpisodesCount: Int {
        seasons.reduce(0) { $0 + $1.episodeCount }
    }

    var hasEpisodesLoaded: Bool {
        seasons.contains(where: { $0.episodeCount > 0 })
    }

    var allEpisodeKeys: [String] {
        seasons.flatMap { season in
            season.episodeCount > 0
                ? (1...season.episodeCount).map { "s\(season.seasonNumber)e\($0)" }
                : []
        }
    }

    @MainActor
    func loadTVDetails(for item: MediaItem) async {
        guard item.hasSeasonsAndEpisodes else { return }
        
        if item.type == .anime && item.id >= MediaService.aniListAnimeIdOffset {
            isLoadingSeasons = false
            return
        }

        isLoadingSeasons = true
        fetchError = false

        do {
            let detail = try await tmdbService.fetchTVDetail(id: item.tmdbId)
            tvDetail = detail
            if let summaries = detail.seasons {
                let sorted = summaries
                    .filter { $0.seasonNumber > 0 && $0.episodeCount > 0 }
                    .sorted { $0.seasonNumber < $1.seasonNumber }

                seasons = sorted.map { summary in
                    Season(
                        id: summary.id,
                        seasonNumber: summary.seasonNumber,
                        name: summary.name,
                        episodeCount: summary.episodeCount,
                        episodes: []
                    )
                }
            }
        } catch {
            fetchError = true
        }

        isLoadingSeasons = false
    }

    func loadEpisodesForSeason(_ seasonNumber: Int, currentItem: MediaItem) {
        Task { @MainActor in
            guard !loadingSeasonNumbers.contains(seasonNumber) else { return }
            loadingSeasonNumbers.insert(seasonNumber)

            do {
                let seasonDetail = try await tmdbService.fetchSeasonDetail(tvId: currentItem.tmdbId, seasonNumber: seasonNumber)

                guard !Task.isCancelled else {
                    loadingSeasonNumbers.remove(seasonNumber)
                    return
                }

                let episodes: [Episode] = seasonDetail.episodes.map { ep in
                    Episode(
                        id: ep.id,
                        episodeNumber: ep.episodeNumber,
                        seasonNumber: ep.seasonNumber,
                        name: ep.name,
                        overview: ep.overview,
                        stillPath: ep.stillPath,
                        airDate: ep.airDate,
                        runtime: ep.runtime,
                        isWatched: false,
                        isInQueue: false
                    )
                }

                if let index = seasons.firstIndex(where: { $0.seasonNumber == seasonNumber }) {
                    seasons[index].episodes = episodes
                }
            } catch {
                if !Task.isCancelled {
                    fetchError = true
                }
            }

            loadingSeasonNumbers.remove(seasonNumber)
        }
    }
}
