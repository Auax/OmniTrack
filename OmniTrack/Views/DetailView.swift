import SwiftUI
import SDWebImageSwiftUI

struct DetailView: View {
    let item: MediaItem
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var seasons: [Season] = []
    @State private var isLoadingSeasons: Bool = false
    @State private var expandedSeason: Int?
    @State private var loadingSeasonNumbers: Set<Int> = []
    @State private var tvDetail: TMDBTVDetail?

    private let tmdbService = TMDBService()

    private var currentItem: MediaItem {
        mediaService.allMedia.first(where: { $0.id == item.id }) ?? item
    }

    private var totalEpisodesCount: Int {
        seasons.reduce(0) { $0 + $1.episodeCount }
    }



    private var allEpisodeKeys: [String] {
        seasons.flatMap { season in
            season.episodeCount > 0
                ? (1...season.episodeCount).map { "s\(season.seasonNumber)e\($0)" }
                : []
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroImage

                VStack(alignment: .leading, spacing: 20) {
                    titleSection
                    actionButtons
                    progressSection
                    seasonsSection
                    overviewSection
                    genresSection
                }
                .padding(20)
            }
        }
        .overlay(alignment: .topTrailing) {
            closeButton
        }
        .background(AppTheme.adaptiveBackground(colorScheme))
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .task {
            await loadTVDetails()
            if settings.ratingProvider == .imdb {
                _ = await mediaService.fetchImdbRatingForItem(currentItem)
            }
        }
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .padding(.top, 14)
        .padding(.trailing, 16)
    }

    // MARK: - Hero Image

    private var heroImage: some View {
        Color(hex: currentItem.accentColorHex).opacity(0.3)
            .frame(height: 300)
            .overlay {
                WebImage(url: currentItem.backdropURL ?? currentItem.posterURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.clear
                }
                .transition(.fade(duration: 0.2))
                .allowsHitTesting(false)
            }
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.4),
                        .init(color: AppTheme.adaptiveBackground(colorScheme), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: currentItem.type.icon)
                    .font(.subheadline)
                    .foregroundStyle(currentItem.accentColor)
                Text(currentItem.type.rawValue.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
            }

            Text(currentItem.title)
                .font(.largeTitle.bold())

            HStack(spacing: 16) {
                RatingView(item: currentItem, fontSize: 14, starSize: 14)

                if currentItem.year > 0 {
                    Text(String(currentItem.year))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let seasonCount = currentItem.totalSeasons ?? tvDetail?.numberOfSeasons {
                    Text("\(seasonCount) Season\(seasonCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) {
                    if currentItem.isWatched && currentItem.hasSeasonsAndEpisodes {
                        mediaService.unmarkAllEpisodesWatched(mediaId: currentItem.id)
                    } else if !currentItem.isWatched && currentItem.hasSeasonsAndEpisodes && !allEpisodeKeys.isEmpty {
                        mediaService.markAllEpisodesWatched(mediaId: currentItem.id, keys: allEpisodeKeys, totalEpisodes: totalEpisodesCount)
                    } else {
                        mediaService.toggleWatched(currentItem)
                    }
                }
            } label: {
                Label(
                    currentItem.isWatched ? "Watched" : "Mark Watched",
                    systemImage: currentItem.isWatched ? "checkmark.circle.fill" : "checkmark.circle"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(currentItem.isWatched ? .green.opacity(0.15) : AppTheme.adaptiveSecondary(colorScheme))
                .foregroundStyle(currentItem.isWatched ? .green : .primary)
                .clipShape(.rect(cornerRadius: 12))
            }
            .sensoryFeedback(.impact, trigger: currentItem.isWatched)

            Button {
                withAnimation(.snappy) {
                    mediaService.toggleQueue(currentItem)
                }
            } label: {
                Label(
                    currentItem.isInQueue ? "In Queue" : "Add to Queue",
                    systemImage: currentItem.isInQueue ? "bookmark.fill" : "bookmark"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(currentItem.isInQueue ? .orange.opacity(0.15) : AppTheme.adaptiveSecondary(colorScheme))
                .foregroundStyle(currentItem.isInQueue ? .orange : .primary)
                .clipShape(.rect(cornerRadius: 12))
            }
            .sensoryFeedback(.impact, trigger: currentItem.isInQueue)
        }
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressSection: some View {
        let total = totalEpisodesCount
        if total > 0 {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Progress")
                        .font(.headline)
                    Spacer()
                    Text("\(currentItem.watchedEpisodes) / \(total)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    ProgressRingView(
                        progress: Double(currentItem.watchedEpisodes) / Double(max(1, total)),
                        accentColor: currentItem.accentColor,
                        lineWidth: 6,
                        size: 64
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        progressDetail("Episodes", value: "\(currentItem.watchedEpisodes)/\(total)")
                        if let seasonCount = currentItem.totalSeasons ?? tvDetail?.numberOfSeasons {
                            progressDetail("Seasons", value: "\(seasonCount)")
                        }
                        progressDetail("Remaining", value: "\(total - currentItem.watchedEpisodes) eps")
                    }
                }
                .padding(16)
                .background(AppTheme.adaptiveSecondary(colorScheme))
                .clipShape(.rect(cornerRadius: 14))
            }
        }
    }

    private func progressDetail(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
        }
    }

    // MARK: - Seasons & Episodes

    @ViewBuilder
    private var seasonsSection: some View {
        if currentItem.hasSeasonsAndEpisodes && !seasons.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Seasons & Episodes")
                    .font(.headline)

                ForEach(seasons) { season in
                    seasonRow(season)
                }
            }
        } else if currentItem.hasSeasonsAndEpisodes && isLoadingSeasons {
            VStack(alignment: .leading, spacing: 12) {
                Text("Seasons & Episodes")
                    .font(.headline)
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading seasons...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func seasonRow(_ season: Season) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if expandedSeason == season.seasonNumber {
                        expandedSeason = nil
                    } else {
                        expandedSeason = season.seasonNumber
                        if season.episodes.isEmpty {
                            loadEpisodesForSeason(season.seasonNumber)
                        }
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(season.name)
                            .font(.subheadline.weight(.semibold))
                        Text("\(season.episodeCount) episodes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    let seasonPrefix = "s\(season.seasonNumber)e"
                    let watchedCount = mediaService.watchedEpisodeKeys(mediaId: currentItem.id)
                        .filter { $0.hasPrefix(seasonPrefix) }
                        .count
                    
                    if watchedCount > 0 {
                        Text("\(watchedCount)/\(season.episodeCount)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expandedSeason == season.seasonNumber ? 90 : 0))
                }
                .padding(14)
                .background(AppTheme.adaptiveSecondary(colorScheme))
                .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            if expandedSeason == season.seasonNumber {
                VStack(spacing: 1) {
                    if loadingSeasonNumbers.contains(season.seasonNumber) {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading episodes...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 12)
                    } else {
                        ForEach(season.episodes) { episode in
                            episodeRow(episode)
                        }
                    }
                }
                .padding(.top, 4)
                .transition(.opacity)
            }
        }
        .clipShape(.rect(cornerRadius: 12))
    }

    private func episodeRow(_ episode: Episode) -> some View {
        let isWatched = mediaService.isEpisodeWatched(mediaId: currentItem.id, key: episode.episodeKey)
        let isQueued = mediaService.isEpisodeQueued(mediaId: currentItem.id, key: episode.episodeKey)

        return HStack(spacing: 12) {
            Color(hex: currentItem.accentColorHex).opacity(0.2)
                .frame(width: 56, height: 40)
                .overlay {
                    if let url = episode.stillURL {
                        WebImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Text("\(episode.episodeNumber)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .transition(.fade(duration: 0.2))
                        .allowsHitTesting(false)
                    } else {
                        Text("\(episode.episodeNumber)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .clipShape(.rect(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text("E\(episode.episodeNumber): \(episode.name)")
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let runtime = episode.formattedRuntime {
                        Text(runtime)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    if let airDate = episode.formattedAirDate {
                        Text(airDate)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Button {
                    withAnimation(.snappy) {
                        mediaService.toggleEpisodeWatched(
                            mediaId: currentItem.id,
                            key: episode.episodeKey,
                            totalEpisodes: totalEpisodesCount
                        )
                    }
                } label: {
                    Image(systemName: isWatched ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.body)
                        .foregroundStyle(isWatched ? .green : .secondary)
                }

                Button {
                    withAnimation(.snappy) {
                        mediaService.toggleEpisodeQueued(mediaId: currentItem.id, key: episode.episodeKey)
                    }
                } label: {
                    Image(systemName: isQueued ? "bookmark.fill" : "bookmark")
                        .font(.caption)
                        .foregroundStyle(isQueued ? .orange : .secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.adaptiveCardBackground(colorScheme))
        .clipShape(.rect(cornerRadius: 8))
    }

    // MARK: - Overview & Genres

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.headline)
            Text(currentItem.overview)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
    }

    private var genresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Genres")
                .font(.headline)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(currentItem.genres, id: \.self) { genre in
                        Text(genre)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(currentItem.accentColor.opacity(0.15))
                            .foregroundStyle(currentItem.accentColor)
                            .clipShape(Capsule())
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Data Loading

    private func loadTVDetails() async {
        guard currentItem.hasSeasonsAndEpisodes else { return }
        isLoadingSeasons = true

        do {
            let detail = try await tmdbService.fetchTVDetail(id: currentItem.tmdbId)
            tvDetail = detail

            mediaService.updateMediaEpisodeInfo(
                mediaId: currentItem.id,
                totalEpisodes: detail.numberOfEpisodes ?? 0,
                totalSeasons: detail.numberOfSeasons ?? 0
            )

            if let tmdbSeasons = detail.seasons {
                seasons = tmdbSeasons
                    .filter { $0.seasonNumber > 0 }
                    .map { s in
                        Season(
                            id: s.id,
                            seasonNumber: s.seasonNumber,
                            name: s.name,
                            episodeCount: s.episodeCount,
                            episodes: []
                        )
                    }
            }
        } catch {
            // Silently fail
        }

        isLoadingSeasons = false
    }

    private func loadEpisodesForSeason(_ seasonNumber: Int) {
        guard let seasonIndex = seasons.firstIndex(where: { $0.seasonNumber == seasonNumber }),
              seasons[seasonIndex].episodes.isEmpty else { return }

        loadingSeasonNumbers.insert(seasonNumber)

        Task {
            do {
                let detail = try await tmdbService.fetchSeasonDetail(tvId: currentItem.tmdbId, seasonNumber: seasonNumber)
                let episodes = detail.episodes.map { ep in
                    Episode(
                        id: ep.id,
                        episodeNumber: ep.episodeNumber,
                        seasonNumber: ep.seasonNumber,
                        name: ep.name,
                        overview: ep.overview,
                        stillPath: ep.stillPath,
                        airDate: ep.airDate,
                        runtime: ep.runtime,
                        isWatched: mediaService.isEpisodeWatched(mediaId: currentItem.id, key: "s\(ep.seasonNumber)e\(ep.episodeNumber)"),
                        isInQueue: mediaService.isEpisodeQueued(mediaId: currentItem.id, key: "s\(ep.seasonNumber)e\(ep.episodeNumber)")
                    )
                }
                if let idx = seasons.firstIndex(where: { $0.seasonNumber == seasonNumber }) {
                    withAnimation(.snappy) {
                        seasons[idx].episodes = episodes
                    }
                }
            } catch {
                // Silently fail
            }
            loadingSeasonNumbers.remove(seasonNumber)
        }
    }
}