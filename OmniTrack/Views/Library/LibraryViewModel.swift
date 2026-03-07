import SwiftUI
import Observation

@MainActor
@Observable
final class LibraryViewModel {
    var continuePreviews: [Int: ContinueEpisodePreview] = [:]
    var previewStateKeys: [Int: String] = [:]
    var continueTargets: [Int: ContinueEpisodeTarget] = [:]
    var targetStateKeys: [Int: String] = [:]
    
    var showingContinueWatchingPage = false
    var selectedItem: MediaItem?

    private var loadingTargetIds: Set<Int> = []
    private var loadingPreviewIds: Set<Int> = []
    private var markingContinueTokens: Set<String> = []

    private let tmdbService = TMDBService()
    
    func trimContinuePreviewCache(validItems: [MediaItem]) {
        let validIds = Set(validItems.map(\.id))
        continuePreviews = continuePreviews.filter { validIds.contains($0.key) }
        previewStateKeys = previewStateKeys.filter { validIds.contains($0.key) }
        continueTargets = continueTargets.filter { validIds.contains($0.key) }
        targetStateKeys = targetStateKeys.filter { validIds.contains($0.key) }
        loadingTargetIds = loadingTargetIds.filter { validIds.contains($0) }
        loadingPreviewIds = loadingPreviewIds.filter { validIds.contains($0) }
    }

    func continuePreviewStateKey(for item: MediaItem, mediaService: MediaService) -> String {
        let watchedKeys = MediaProgressResolver
            .sortedEpisodeKeys(mediaService.watchedEpisodeKeys(mediaId: item.id))
            .joined(separator: ",")
        return "\(item.id)|\(item.isWatched)|\(item.isInProgress)|\(item.totalEpisodes ?? 0)|\(watchedKeys)"
    }

    func continueTarget(for item: MediaItem, mediaService: MediaService) -> ContinueEpisodeTarget? {
        continueTargets[item.id] ?? MediaProgressResolver.fallbackContinueTarget(
            for: item,
            watchedKeys: mediaService.watchedEpisodeKeys(mediaId: item.id),
            watchedEpisodeCount: mediaService.watchedEpisodeCount(mediaId: item.id)
        )
    }

    @MainActor
    func loadContinueTargetIfNeeded(for item: MediaItem, stateKey: String, mediaService: MediaService) async {
        if targetStateKeys[item.id] == stateKey { return }
        guard !loadingTargetIds.contains(item.id) else { return }

        loadingTargetIds.insert(item.id)
        defer { loadingTargetIds.remove(item.id) }

        let resolved = await resolveContinueTarget(for: item, mediaService: mediaService)
        if let resolved { continueTargets[item.id] = resolved }
        else { continueTargets.removeValue(forKey: item.id) }
        
        targetStateKeys[item.id] = stateKey
    }

    @MainActor
    private func resolveContinueTarget(for item: MediaItem, mediaService: MediaService) async -> ContinueEpisodeTarget? {
        guard item.hasSeasonsAndEpisodes, !item.isWatched else { return nil }

        let watchedKeys = mediaService.watchedEpisodeKeys(mediaId: item.id)
        let watchedCount = mediaService.watchedEpisodeCount(mediaId: item.id)

        if item.type == .anime && item.id >= MediaService.aniListAnimeIdOffset {
            return MediaProgressResolver.fallbackContinueTarget(
                for: item,
                watchedKeys: watchedKeys,
                watchedEpisodeCount: watchedCount
            )
        }

        do {
            let detail = try await tmdbService.fetchTVDetail(id: item.tmdbId)
            if let seasons = detail.seasons,
               let resolved = MediaProgressResolver.resolveTargetFromSeasonSummaries(
                for: item,
                seasons: seasons,
                watchedKeys: watchedKeys,
                totalEpisodesHint: detail.numberOfEpisodes
               ) {
                return resolved
            }

            if let numberOfEpisodes = detail.numberOfEpisodes, numberOfEpisodes > 0 {
                return MediaProgressResolver.fallbackContinueTarget(
                    for: item,
                    watchedKeys: watchedKeys,
                    watchedEpisodeCount: watchedCount,
                    totalEpisodesOverride: numberOfEpisodes
                )
            }
        } catch {}

        return MediaProgressResolver.fallbackContinueTarget(
            for: item,
            watchedKeys: watchedKeys,
            watchedEpisodeCount: watchedCount
        )
    }

    func previewForCard(_ item: MediaItem, mediaService: MediaService) -> ContinueEpisodePreview {
        if let existing = continuePreviews[item.id] { return existing }
        if let target = continueTarget(for: item, mediaService: mediaService) { return fallbackPreview(for: item, target: target) }

        return ContinueEpisodePreview(
            episodeTitle: item.title,
            episodeOverview: item.overview,
            metaLine: item.subtitle,
            imageURL: item.backdropURL ?? item.posterURL,
            isLastEpisode: false
        )
    }

    @MainActor
    func loadContinuePreviewIfNeeded(for item: MediaItem, previewKey: String, mediaService: MediaService) async {
        if previewStateKeys[item.id] == previewKey, continuePreviews[item.id] != nil { return }
        guard !loadingPreviewIds.contains(item.id) else { return }

        guard item.hasSeasonsAndEpisodes else {
            continuePreviews[item.id] = previewForCard(item, mediaService: mediaService)
            previewStateKeys[item.id] = previewKey
            return
        }

        guard let target = continueTarget(for: item, mediaService: mediaService) else {
            continuePreviews[item.id] = previewForCard(item, mediaService: mediaService)
            previewStateKeys[item.id] = previewKey
            return
        }

        if item.type == .anime && item.id >= MediaService.aniListAnimeIdOffset {
            continuePreviews[item.id] = fallbackPreview(for: item, target: target)
            previewStateKeys[item.id] = previewKey
            return
        }

        loadingPreviewIds.insert(item.id)
        defer { loadingPreviewIds.remove(item.id) }

        do {
            let season = try await tmdbService.fetchSeasonDetail(tvId: item.tmdbId, seasonNumber: target.episode.season)
            if let episode = season.episodes.first(where: { $0.episodeNumber == target.episode.episode }) {
                continuePreviews[item.id] = ContinueEpisodePreview(
                    episodeTitle: episode.name.isEmpty ? "Episode \(episode.episodeNumber)" : episode.name,
                    episodeOverview: episode.overview,
                    metaLine: buildMetaLine(
                        season: episode.seasonNumber,
                        episode: episode.episodeNumber,
                        airDate: episode.airDate,
                        runtime: episode.runtime
                    ),
                    imageURL: stillImageURL(from: episode.stillPath) ?? item.backdropURL ?? item.posterURL,
                    isLastEpisode: target.isLastEpisode
                )
                previewStateKeys[item.id] = previewKey
                return
            }
        } catch {}

        continuePreviews[item.id] = fallbackPreview(for: item, target: target)
        previewStateKeys[item.id] = previewKey
    }

    private func fallbackPreview(for item: MediaItem, target: ContinueEpisodeTarget) -> ContinueEpisodePreview {
        ContinueEpisodePreview(
            episodeTitle: "Episode \(target.episode.episode)",
            episodeOverview: item.overview,
            metaLine: buildMetaLine(
                season: target.episode.season,
                episode: target.episode.episode,
                airDate: nil,
                runtime: nil
            ),
            imageURL: item.backdropURL ?? item.posterURL,
            isLastEpisode: target.isLastEpisode
        )
    }

    private func buildMetaLine(season: Int, episode: Int, airDate: String?, runtime: Int?) -> String {
        var parts: [String] = ["S\(season), E\(episode)"]

        if let formattedDate = formattedEpisodeDate(airDate) { parts.append(formattedDate) }
        if let runtime, runtime > 0 { parts.append("\(runtime)m") }

        return parts.joined(separator: " • ")
    }

    private func formattedEpisodeDate(_ rawDate: String?) -> String? {
        guard let rawDate, !rawDate.isEmpty else { return nil }
        guard let date = DateFormatter.libraryDateParser.date(from: rawDate) else { return nil }
        return DateFormatter.libraryEpisodeFormatter.string(from: date)
    }

    private func stillImageURL(from path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") { return URL(string: path) }
        return URL(string: "https://image.tmdb.org/t/p/w780\(path)")
    }

    func isMarkingContinueToken(_ item: MediaItem, target: ContinueEpisodeTarget?) -> Bool {
        guard let target else { return false }
        let token = "\(item.id)|\(target.episode.rawValue)"
        return markingContinueTokens.contains(token)
    }
    
    func markContinueEpisodeWatched(item: MediaItem, target: ContinueEpisodeTarget?, mediaService: MediaService) {
        Task { @MainActor in
            let stateKey = continuePreviewStateKey(for: item, mediaService: mediaService)
            await loadContinueTargetIfNeeded(for: item, stateKey: stateKey, mediaService: mediaService)

            let resolvedTarget = continueTargets[item.id] ?? target ?? continueTarget(for: item, mediaService: mediaService)
            guard let resolvedTarget else { return }

            let token = "\(item.id)|\(resolvedTarget.episode.rawValue)"
            guard !markingContinueTokens.contains(token) else { return }

            markingContinueTokens.insert(token)
            let totalEpisodes = max(resolvedTarget.totalEpisodes, item.totalEpisodes ?? 0)

            try? await Task.sleep(for: .milliseconds(180))
            mediaService.markEpisodeWatched(
                mediaId: item.id,
                key: resolvedTarget.episode.rawValue,
                totalEpisodes: totalEpisodes
            )
            markingContinueTokens.remove(token)
        }
    }
}
