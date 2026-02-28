import SwiftUI
import SDWebImageSwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DetailView: View {
    let item: MediaItem
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss

    @State private var seasons: [Season] = []
    @State private var isLoadingSeasons: Bool = false
    @State private var fetchError: Bool = false
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

    private enum RatingSource {
        case imdb
        case tmdb
        case aniList

        var label: String {
            switch self {
            case .imdb: "IMDb"
            case .tmdb: "TMDB"
            case .aniList: "AniList"
            }
        }

        var fallbackSymbol: String {
            switch self {
            case .imdb: "i.circle.fill"
            case .tmdb: "star.fill"
            case .aniList: "sparkles.tv"
            }
        }

        var tint: Color {
            switch self {
            case .imdb: .yellow
            case .tmdb: .yellow
            case .aniList: .pink
            }
        }

        var assetName: String {
            switch self {
            case .imdb: "rating_source_imdb"
            case .tmdb: "rating_source_tmdb"
            case .aniList: "rating_source_anilist"
            }
        }
    }

    private var ratingSource: RatingSource {
        if currentItem.isAniListAnime {
            return .aniList
        }
        switch settings.ratingProvider {
        case .imdb:
            return .imdb
        case .tmdb:
            return .tmdb
        }
    }



    private var hasEpisodesLoaded: Bool {
        seasons.contains(where: { $0.episodeCount > 0 })
    }

    private var allEpisodeKeys: [String] {
        seasons.flatMap { season in
            season.episodeCount > 0
                ? (1...season.episodeCount).map { "s\(season.seasonNumber)e\($0)" }
                : []
        }
    }

    private var episodeCardWidth: CGFloat {
        horizontalSizeClass == .regular ? 420 : 300
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
        .accessibilityLabel("Close details")
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
                providerRatingBlock

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

    private var providerRatingBlock: some View {
        HStack(spacing: 6) {
            ratingSourceIcon(for: ratingSource)
                .frame(width: 20, height: 20)
            Text(detailRatingText)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
            }
        .accessibilityLabel("Rating source: \(ratingSource.label)")
    }

    private var detailRatingText: String {
        if currentItem.isAniListAnime {
            return currentItem.formattedRating
        }
        if settings.ratingProvider == .imdb {
            if let imdb = currentItem.imdbRating {
                return String(format: "%.1f", imdb)
            }
            if mediaService.isLoadingImdbRating(currentItem.id) {
                return "..."
            }
            return "—"
        }
        return currentItem.formattedRating
    }

    @ViewBuilder
    private func ratingSourceIcon(for source: RatingSource) -> some View {
        switch source {
        case .tmdb:
            Image(systemName: "star.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.yellow)
        case .imdb, .aniList:
            #if canImport(UIKit)
            if let image = UIImage(named: source.assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                Image(systemName: source.fallbackSymbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(source.tint)
            }
            #else
            Image(systemName: source.fallbackSymbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(source.tint)
            #endif
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 12) {
            watchButtonControl

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
                .background(buttonGlassBackground(activeTint: currentItem.isInQueue ? .orange : nil))
                .foregroundStyle(currentItem.isInQueue ? .orange : .primary)
                .clipShape(Squircle(cornerRadius: 12))
            }
            .sensoryFeedback(.impact, trigger: currentItem.isInQueue)
        }
    }

    @ViewBuilder
    private var watchButtonControl: some View {
        if currentItem.hasSeasonsAndEpisodes {
            if currentItem.isWatched || currentItem.isInProgress {
                Button {
                    withAnimation(.snappy) {
                        unmarkCurrentItemWatchState()
                    }
                } label: {
                    Label(
                        currentItem.isWatched ? "Completed" : "In Progress",
                        systemImage: currentItem.isWatched ? "checkmark" : "play.circle.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(buttonGlassBackground(activeTint: currentItem.isWatched ? .green : .blue))
                    .foregroundStyle(currentItem.isWatched ? .green : .blue)
                    .clipShape(Squircle(cornerRadius: 12))
                }
                .sensoryFeedback(.impact, trigger: currentItem.isWatched || currentItem.isInProgress)
            } else {
                Menu {
                    Button {
                        withAnimation(.snappy) {
                            markCurrentItemCompleted()
                        }
                    } label: {
                        Label("Mark completed", systemImage: "checkmark.circle")
                    }

                    Button {
                        withAnimation(.snappy) {
                            mediaService.toggleInProgress(currentItem)
                        }
                    } label: {
                        Label("In progress", systemImage: "play.circle")
                    }
                } label: {
                    Label("Watch", systemImage: "eye")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(buttonGlassBackground(activeTint: nil))
                        .foregroundStyle(.primary)
                        .clipShape(Squircle(cornerRadius: 12))
                }
            }
        } else {
            Button {
                withAnimation(.snappy) {
                    mediaService.toggleWatched(currentItem)
                }
            } label: {
                Label(
                    currentItem.isWatched ? "Watched" : "Watch",
                    systemImage: currentItem.isWatched ? "checkmark" : "eye"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(buttonGlassBackground(activeTint: currentItem.isWatched ? .green : nil))
                .foregroundStyle(currentItem.isWatched ? .green : .primary)
                .clipShape(Squircle(cornerRadius: 12))
            }
            .sensoryFeedback(.impact, trigger: currentItem.isWatched)
        }
    }

    private func unmarkCurrentItemWatchState() {
        if currentItem.hasSeasonsAndEpisodes {
            if currentItem.isWatched {
                mediaService.toggleWatched(currentItem)
                return
            }
            if currentItem.isInProgress {
                if mediaService.watchedEpisodeCount(mediaId: currentItem.id) > 0 {
                    mediaService.unmarkAllEpisodesWatched(mediaId: currentItem.id)
                    if mediaService.allMedia.first(where: { $0.id == currentItem.id })?.isInProgress == true {
                        mediaService.toggleInProgress(currentItem)
                    }
                    return
                }
                mediaService.toggleInProgress(currentItem)
                return
            }
            mediaService.unmarkAllEpisodesWatched(mediaId: currentItem.id)
        } else if currentItem.isWatched {
            mediaService.toggleWatched(currentItem)
        } else if currentItem.isInProgress {
            mediaService.toggleInProgress(currentItem)
        }
    }

    private func markCurrentItemCompleted() {
        if currentItem.hasSeasonsAndEpisodes {
            if hasEpisodesLoaded && !allEpisodeKeys.isEmpty {
                mediaService.markAllEpisodesWatched(
                    mediaId: currentItem.id,
                    keys: allEpisodeKeys,
                    totalEpisodes: totalEpisodesCount
                )
            } else if let total = currentItem.totalEpisodes, total > 0 {
                let syntheticKeys = (1...total).map { "s1e\($0)" }
                mediaService.markAllEpisodesWatched(
                    mediaId: currentItem.id,
                    keys: syntheticKeys,
                    totalEpisodes: total
                )
            } else {
                mediaService.markWatched(currentItem)
            }
        } else {
            mediaService.markWatched(currentItem)
        }
    }

    private func buttonGlassBackground(activeTint: Color?) -> some View {
        Squircle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .overlay {
                Squircle(cornerRadius: 12)
                    .fill((activeTint ?? .white).opacity(activeTint == nil ? (colorScheme == .dark ? 0.10 : 0.22) : 0.18))
            }
            .overlay {
                Squircle(cornerRadius: 12)
                    .stroke(.white.opacity(colorScheme == .dark ? 0.24 : 0.40), lineWidth: 1)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.08), radius: 8, y: 3)
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressSection: some View {
        let total = totalEpisodesCount
        if total > 0 {
            VStack(alignment: .leading, spacing: 12) {
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
                        Task { await loadTVDetails() }
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

    private func seasonRow(_ season: Season) -> some View {
        let watchedCount = seasonWatchedCount(season)
        let isSeasonWatched = season.episodeCount > 0 && watchedCount >= season.episodeCount

        return VStack(alignment: .leading, spacing: 14) {
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
                        loadEpisodesForSeason(season.seasonNumber)
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
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(season.episodes) { episode in
                            episodeCard(episode)
                        }
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

    private func episodeCard(_ episode: Episode) -> some View {
    let isWatched = mediaService.isEpisodeWatched(mediaId: currentItem.id, key: episode.episodeKey)

    return Button {
        withAnimation(.snappy) {
            mediaService.toggleEpisodeWatched(
                mediaId: currentItem.id,
                key: episode.episodeKey,
                totalEpisodes: totalEpisodesCount
            )
        }
    } label: {
        // 1. Make the content your primary view
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
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        // 2. Define the exact size of the card here, and align content to the bottom
        .frame(width: episodeCardWidth, height: 190, alignment: .bottom)
        // 3. Put the image and gradients in the background
        .background(alignment: .bottom) {
            ZStack(alignment: .bottom) {
                Color(hex: currentItem.accentColorHex).opacity(0.32)

                if let url = episode.stillURL {
                    WebImage(url: url) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Gradients sit on top of the image, but behind the text
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
            }
        }
        // 4. Clip the whole thing
        .clipShape(Squircle(cornerRadius: 24))
        .overlay(
            Squircle(cornerRadius: 24)
                .stroke(.white.opacity(colorScheme == .dark ? 0.25 : 0.18), lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(isWatched ? "Unmark episode watched" : "Mark episode watched")
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

    private static let dateParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM dd yyyy"
        return formatter
    }()

    private func compactEpisodeDate(_ rawDate: String?) -> String? {
        guard let rawDate, !rawDate.isEmpty else { return nil }

        guard let date = Self.dateParser.date(from: rawDate) else { return nil }
        return Self.dateFormatter.string(from: date)
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
            fetchError = true
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
                fetchError = true
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

private struct EpisodeSkeletonCard: View {
    let width: CGFloat
    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.gray.opacity(0.2))
            .frame(width: width, height: 190)
            .opacity(isAnimating ? 0.4 : 0.8)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}
