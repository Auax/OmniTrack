import SwiftUI

struct DetailSeasonsSection: View {
    let currentItem: MediaItem
    let episodeCardWidth: CGFloat
    let totalEpisodesCount: Int
    @Binding var autoFocusEpisodeKey: EpisodeKey?
    
    @Binding var seasons: [Season]
    @Binding var isLoadingSeasons: Bool
    @Binding var fetchError: Bool
    @Binding var expandedSeason: Int?
    @Binding var loadingSeasonNumbers: Set<Int>
    
    let onLoadTVDetails: () async -> Void
    let onLoadEpisodesForSeason: (Int) -> Void
    
    @Environment(MediaService.self) private var mediaService

    var body: some View {
        if currentItem.hasSeasonsAndEpisodes && !seasons.isEmpty, let selectedSeason {
            VStack(alignment: .leading, spacing: 12) {
                DetailSeasonRow(
                    season: selectedSeason,
                    currentItem: currentItem,
                    episodeCardWidth: episodeCardWidth,
                    totalEpisodesCount: totalEpisodesCount,
                    autoFocusEpisodeKey: $autoFocusEpisodeKey,
                    seasons: seasons,
                    expandedSeason: $expandedSeason,
                    loadingSeasonNumbers: $loadingSeasonNumbers,
                    fetchError: $fetchError,
                    onLoadEpisodesForSeason: onLoadEpisodesForSeason
                )
            }
            .onAppear {
                if let autoFocusEpisodeKey {
                    expandedSeason = autoFocusEpisodeKey.season
                } else if expandedSeason == nil {
                    expandedSeason = seasons.first?.seasonNumber
                }
                loadSeasonIfNeeded(expandedSeason)
            }
            .onChange(of: autoFocusEpisodeKey?.rawValue) { _, _ in
                alignToAutoFocusSeasonIfNeeded()
            }
            .onChange(of: seasons.map(\.seasonNumber)) { _, _ in
                alignToAutoFocusSeasonIfNeeded()
            }
            .onChange(of: expandedSeason) { _, newSeason in
                loadSeasonIfNeeded(newSeason)
            }
        } else if currentItem.hasSeasonsAndEpisodes && isLoadingSeasons {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading seasons...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        } else if currentItem.hasSeasonsAndEpisodes && fetchError && seasons.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Failed to load seasons.")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    Button("Retry") {
                        fetchError = false
                        Task { await onLoadTVDetails() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(currentItem.accentColor)
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var selectedSeason: Season? {
        if let expandedSeason,
           let match = seasons.first(where: { $0.seasonNumber == expandedSeason }) {
            return match
        }
        return seasons.first
    }

    private func alignToAutoFocusSeasonIfNeeded() {
        guard let autoFocusEpisodeKey else { return }
        guard seasons.contains(where: { $0.seasonNumber == autoFocusEpisodeKey.season }) else { return }

        if expandedSeason != autoFocusEpisodeKey.season {
            expandedSeason = autoFocusEpisodeKey.season
        }
        loadSeasonIfNeeded(autoFocusEpisodeKey.season)
    }

    private func loadSeasonIfNeeded(_ seasonNumber: Int?) {
        guard let seasonNumber else { return }
        guard let targetSeason = seasons.first(where: { $0.seasonNumber == seasonNumber }) else { return }
        guard targetSeason.episodes.isEmpty else { return }
        guard !loadingSeasonNumbers.contains(seasonNumber) else { return }
        onLoadEpisodesForSeason(seasonNumber)
    }

}

struct DetailSeasonRow: View {
    let season: Season
    let currentItem: MediaItem
    let episodeCardWidth: CGFloat
    let totalEpisodesCount: Int
    @Binding var autoFocusEpisodeKey: EpisodeKey?
    
    let seasons: [Season]
    @Binding var expandedSeason: Int?
    @Binding var loadingSeasonNumbers: Set<Int>
    @Binding var fetchError: Bool
    let onLoadEpisodesForSeason: (Int) -> Void

    @Environment(MediaService.self) private var mediaService

    var body: some View {
        let watchedCount = seasonWatchedCount(season)
        let isSeasonWatched = season.episodeCount > 0 && watchedCount >= season.episodeCount

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(displaySeasonTitle(season))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        Text("\(season.episodeCount) episodes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .overlay {
                    Menu {
                        ForEach(seasons) { option in
                            Button {
                                withAnimation(.snappy) {
                                    expandedSeason = option.seasonNumber
                                }
                                if option.episodes.isEmpty {
                                    onLoadEpisodesForSeason(option.seasonNumber)
                                }
                            } label: {
                                if option.seasonNumber == season.seasonNumber {
                                    Label(displaySeasonTitle(option), systemImage: "checkmark")
                                } else {
                                    Text(displaySeasonTitle(option))
                                }
                            }
                        }
                    } label: {
                        Color.clear
                            .contentShape(Rectangle())
                    }
                }

                Spacer()

                Button {
                    withAnimation(.snappy) {
                        toggleSeasonWatched(season, isSeasonWatched: isSeasonWatched)
                    }
                } label: {
                    Image(systemName: isSeasonWatched ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(isSeasonWatched ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSeasonWatched ? "Unmark season watched" : "Mark season watched")
            }

            if loadingSeasonNumbers.contains(season.seasonNumber) {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(0..<2, id: \.self) { _ in
                            EpisodeSkeletonCard(width: episodeCardWidth)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
                .padding(.bottom, 16)
                .scrollIndicators(.hidden)
            } else if fetchError && season.episodes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Failed to load episodes.")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    Button("Retry") {
                        fetchError = false
                        onLoadEpisodesForSeason(season.seasonNumber)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(currentItem.accentColor)
                }
                .padding(.vertical, 8)
            } else if season.episodes.isEmpty {
                Text("No episodes available yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(season.episodes) { episode in
                                DetailEpisodeCard(
                                    currentItem: currentItem,
                                    episode: episode,
                                    episodeCardWidth: episodeCardWidth,
                                    totalEpisodesCount: totalEpisodesCount,
                                    onToggle: {
                                        handleEpisodeToggle(episode)
                                    }
                                )
                                .id(episode.episodeKey)
                            }
                        }
                    }
                    .onAppear {
                        scrollToAutoFocusEpisode(using: proxy)
                    }
                    .onChange(of: autoFocusEpisodeKey?.rawValue) { _, _ in
                        scrollToAutoFocusEpisode(using: proxy)
                    }
                    .onChange(of: season.episodes.map(\.episodeKey)) { _, _ in
                        scrollToAutoFocusEpisode(using: proxy)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
                .padding(.bottom, 16)
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    private func seasonWatchedCount(_ season: Season) -> Int {
        let seasonPrefix = "s\(season.seasonNumber)e"
        return mediaService.watchedEpisodeKeys(mediaId: currentItem.id)
            .filter { $0.hasPrefix(seasonPrefix) }
            .count
    }

    private func toggleSeasonWatched(_ season: Season, isSeasonWatched: Bool) {
        if isSeasonWatched {
            mediaService.unmarkSeasonWatched(
                mediaId: currentItem.id,
                seasonNumber: season.seasonNumber,
                episodeCount: season.episodeCount
            )
        } else {
            mediaService.markSeasonWatched(
                mediaId: currentItem.id,
                seasonNumber: season.seasonNumber,
                episodeCount: season.episodeCount,
                totalEpisodes: totalEpisodesCount
            )
        }
    }

    private func displaySeasonTitle(_ season: Season) -> String {
        let cleaned = season.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Season \(season.seasonNumber)" : cleaned
    }

    private func handleEpisodeToggle(_ episode: Episode) {
        let wasWatched = mediaService.isEpisodeWatched(mediaId: currentItem.id, key: episode.episodeKey)

        withAnimation(.snappy) {
            mediaService.toggleEpisodeWatched(
                mediaId: currentItem.id,
                key: episode.episodeKey,
                totalEpisodes: totalEpisodesCount
            )
        }

        guard !wasWatched else { return }
        autoFocusEpisodeKey = nextUnwatchedEpisode(after: episode)
    }

    private func nextUnwatchedEpisode(after episode: Episode) -> EpisodeKey? {
        let watchedKeys = mediaService.watchedEpisodeKeys(mediaId: currentItem.id)
        let orderedSeasons = seasons.sorted { $0.seasonNumber < $1.seasonNumber }
        var passedCurrent = false

        for season in orderedSeasons where season.episodeCount > 0 {
            for episodeNumber in 1...season.episodeCount {
                let key = EpisodeKey(season: season.seasonNumber, episode: episodeNumber)
                if !passedCurrent {
                    if key.rawValue == episode.episodeKey {
                        passedCurrent = true
                    }
                    continue
                }

                if !watchedKeys.contains(key.rawValue) {
                    return key
                }
            }
        }

        return nil
    }

    private func scrollToAutoFocusEpisode(using proxy: ScrollViewProxy) {
        guard let focusEpisodeKey = autoFocusEpisodeKey else { return }
        guard focusEpisodeKey.season == season.seasonNumber else { return }

        let targetKey = focusEpisodeKey.rawValue
        guard season.episodes.contains(where: { $0.episodeKey == targetKey }) else { return }

        Task { @MainActor in
            withAnimation(.snappy) {
                proxy.scrollTo(targetKey, anchor: .center)
            }
            autoFocusEpisodeKey = nil
        }
    }
}
