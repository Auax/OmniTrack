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

    private var isAniListAnimeItem: Bool {
        currentItem.type == .anime && currentItem.id >= MediaService.aniListAnimeIdOffset
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
            Text(currentItem.preferredDisplayTitle(animeTitlePreference: settings.animeTitlePreference))
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
                    currentItem.isWatched ? "Watched" : "Watch",
                    systemImage: currentItem.isWatched ? "checkmark" : "eye"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(currentItem.isWatched ? .green.opacity(0.15) : AppTheme.adaptiveSecondary(colorScheme))
                .foregroundStyle(currentItem.isWatched ? .green : .primary)
                .clipShape(Squircle(cornerRadius: 12))
            }
            .sensoryFeedback(.impact, trigger: currentItem.isWatched)

            Button {
                withAnimation(.snappy) {
                    mediaService.toggleQueue(currentItem)
                }
            } label: {
                Label(
                    currentItem.isInQueue ? "In Watchlist" : "Watchlist",
                    systemImage: currentItem.isInQueue ? "plus.circle.fill" : "plus.circle"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(currentItem.isInQueue ? .orange.opacity(0.15) : AppTheme.adaptiveSecondary(colorScheme))
                .foregroundStyle(currentItem.isInQueue ? .orange : .primary)
                .clipShape(Squircle(cornerRadius: 12))
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
                .clipShape(Squircle(cornerRadius: 14))
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
        if currentItem.hasSeasonsAndEpisodes && !seasons.isEmpty, let selectedSeason {
            VStack(alignment: .leading, spacing: 12) {
                Text("Seasons & Episodes")
                    .font(.headline)
                seasonRow(selectedSeason)
            }
            .onAppear {
                if expandedSeason == nil {
                    expandedSeason = seasons.first?.seasonNumber
                }
                if selectedSeason.episodes.isEmpty {
                    loadEpisodesForSeason(selectedSeason.seasonNumber)
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

    private var selectedSeason: Season? {
        if let expandedSeason,
           let match = seasons.first(where: { $0.seasonNumber == expandedSeason }) {
            return match
        }
        return seasons.first
    }

    private func seasonRow(_ season: Season) -> some View {
        let watchedCount = seasonWatchedCount(season)
        let isSeasonWatched = season.episodeCount > 0 && watchedCount >= season.episodeCount

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Menu {
                    ForEach(seasons) { option in
                        Button {
                            withAnimation(.snappy) {
                                expandedSeason = option.seasonNumber
                            }
                            if option.episodes.isEmpty {
                                loadEpisodesForSeason(option.seasonNumber)
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
                .buttonStyle(.plain)

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
            }

            if loadingSeasonNumbers.contains(season.seasonNumber) {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading episodes...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if season.episodes.isEmpty {
                Text("No episodes available yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(season.episodes) { episode in
                            episodeCard(episode)
                        }
                    }
                }
                .padding(.horizontal, -20)
                .padding(.leading, 16)
                .padding(.bottom, 16)
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    private func episodeCard(_ episode: Episode) -> some View {
        let isWatched = mediaService.isEpisodeWatched(mediaId: currentItem.id, key: episode.episodeKey)
        let cardWidth = max(UIScreen.main.bounds.width - 96, 280)

        return Button {
            withAnimation(.snappy) {
                mediaService.toggleEpisodeWatched(
                    mediaId: currentItem.id,
                    key: episode.episodeKey,
                    totalEpisodes: totalEpisodesCount
                )
            }
        } label: {
            ZStack(alignment: .bottomLeading) {
                Color(hex: currentItem.accentColorHex).opacity(0.32)

                if let url = episode.stillURL {
                    WebImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.black.opacity(0.15)
                    }
                    .transition(.fade(duration: 0.2))
                    .allowsHitTesting(false)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("S\(episode.seasonNumber), E\(episode.episodeNumber)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: 96)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black.opacity(0.85), location: 0.4),
                                .init(color: .black, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                LinearGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(episode.name.isEmpty ? "Episode \(episode.episodeNumber)" : episode.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.9)

                        Text(episodeMetaLine(for: episode))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(isWatched ? .gray : .white.opacity(0.9))
                        .padding(.bottom, 2)
                }
                .padding(16)
            }
            .frame(width: cardWidth, height: 190)
            .clipShape(Squircle(cornerRadius: 24))
            .overlay(
                Squircle(cornerRadius: 24)
                    .stroke(.white.opacity(colorScheme == .dark ? 0.25 : 0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

    private func episodeMetaLine(for episode: Episode) -> String {
        var parts: [String] = ["S\(episode.seasonNumber), E\(episode.episodeNumber)"]
        if let date = compactEpisodeDate(episode.airDate) {
            parts.append(date)
        }
        if let runtime = episode.formattedRuntime {
            parts.append(runtime)
        }
        return parts.joined(separator: " • ")
    }

    private func compactEpisodeDate(_ rawDate: String?) -> String? {
        guard let rawDate, !rawDate.isEmpty else { return nil }

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: rawDate) else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM dd yyyy"
        return formatter.string(from: date)
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

        if isAniListAnimeItem {
            let episodeCount = max(0, currentItem.totalEpisodes ?? 0)
            let seasonCount = max(1, currentItem.totalSeasons ?? 1)
            tvDetail = nil

            if episodeCount > 0 {
                mediaService.updateMediaEpisodeInfo(
                    mediaId: currentItem.id,
                    totalEpisodes: episodeCount,
                    totalSeasons: seasonCount
                )

                seasons = [
                    Season(
                        id: currentItem.id,
                        seasonNumber: 1,
                        name: seasonCount > 1 ? "All Seasons" : "Season 1",
                        episodeCount: episodeCount,
                        episodes: syntheticAniListEpisodes(count: episodeCount)
                    )
                ]
            } else {
                seasons = []
            }

            if expandedSeason == nil || !seasons.contains(where: { $0.seasonNumber == expandedSeason }) {
                expandedSeason = seasons.first?.seasonNumber
            }

            isLoadingSeasons = false
            return
        }

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

        if expandedSeason == nil || !seasons.contains(where: { $0.seasonNumber == expandedSeason }) {
            expandedSeason = seasons.first?.seasonNumber
        }
        if let selectedSeason, selectedSeason.episodes.isEmpty {
            loadEpisodesForSeason(selectedSeason.seasonNumber)
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

    private func syntheticAniListEpisodes(count: Int) -> [Episode] {
        guard count > 0 else { return [] }

        return (1...count).map { number in
            Episode(
                id: currentItem.id * 10_000 + number,
                episodeNumber: number,
                seasonNumber: 1,
                name: "Episode \(number)",
                overview: "",
                stillPath: nil,
                airDate: nil,
                runtime: nil,
                isWatched: mediaService.isEpisodeWatched(mediaId: currentItem.id, key: "s1e\(number)"),
                isInQueue: mediaService.isEpisodeQueued(mediaId: currentItem.id, key: "s1e\(number)")
            )
        }
    }
}
