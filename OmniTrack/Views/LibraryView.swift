import SwiftUI
import SDWebImageSwiftUI



private func libraryBackgroundGradient(_ colorScheme: ColorScheme) -> LinearGradient {
    LinearGradient(
        colors: colorScheme == .dark
        ? [Color(hex: "04101F"), Color(hex: "01050C")]
        : [Color(hex: "EFF4FA"), Color(hex: "E5ECF5")],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct LibraryView: View {
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedItem: MediaItem?
    @State private var showingContinueWatchingPage = false
    @State private var continuePreviews: [Int: ContinueEpisodePreview] = [:]
    @State private var previewStateKeys: [Int: String] = [:]
    @State private var continueTargets: [Int: ContinueEpisodeTarget] = [:]
    @State private var targetStateKeys: [Int: String] = [:]
    @State private var loadingTargetIds: Set<Int> = []
    @State private var loadingPreviewIds: Set<Int> = []
    @State private var markingContinueTokens: Set<String> = []

    private let tmdbService = TMDBService()

    private struct ContinueEpisodePreview {
        let episodeTitle: String
        let episodeOverview: String
        let metaLine: String
        let imageURL: URL?
        let isLastEpisode: Bool
    }

    private struct ContinueEpisodeTarget {
        let episode: EpisodeKey
        let totalEpisodes: Int
        let isLastEpisode: Bool
    }

    private var continueWatchingItems: [MediaItem] {
        mediaService.inProgressItemsSortedByRecentUpdate()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                libraryBackgroundGradient(colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        if !continueWatchingItems.isEmpty {
                            continueWatchingSection
                        }

                        mediaCategorySection(title: "Movies", type: .movie)
                        mediaCategorySection(title: "Shows", type: .tvShow)
                        mediaCategorySection(title: "Animes", type: .anime)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: LibraryCollectionRoute.self) { route in
                LibraryCollectionPage(route: route)
            }
            .navigationDestination(isPresented: $showingContinueWatchingPage) {
                continueWatchingPage
            }
            .sheet(item: $selectedItem) { item in
                DetailView(item: item)
            }
            .onChange(of: continueWatchingItems.map(\.id)) { _, _ in
                trimContinuePreviewCache()
            }
            .task {
                trimContinuePreviewCache()
                if mediaService.allMedia.isEmpty {
                    await mediaService.loadContent(
                        showMovies: settings.showMovies,
                        showTVShows: settings.showTVShows,
                        showAnime: settings.showAnime
                    )
                }
            }
            .refreshable {
                await mediaService.loadContent(
                    showMovies: settings.showMovies,
                    showTVShows: settings.showTVShows,
                    showAnime: settings.showAnime
                )
            }
        }
    }

    private var continueWatchingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                showingContinueWatchingPage = true
            } label: {
                HStack(spacing: 6) {
                    Text("Continue Watching")
                        .font(.title2.weight(.bold))

                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Text("Pick up where you left off")
                .font(.body.weight(.regular))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
                .padding(.bottom, 10)

            GeometryReader { proxy in
                let availableWidth = proxy.size.width + 32
                let cardWidth = max(235, min(500, availableWidth * 0.70))

                ScrollView(.horizontal) {
                    HStack(spacing: 14) {
                        ForEach(continueWatchingItems) { item in
                            continueWatchingCard(item, cardWidth: cardWidth)
                        }
                    }
                }
                .contentMargins(.horizontal, 16)
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
            }
            .padding(.horizontal, -16)
            .frame(height: 246)
        }
    }

    private func continueWatchingCard(_ item: MediaItem, cardWidth: CGFloat) -> some View {
        let preview = previewForCard(item)
        let seriesTitle = item.preferredDisplayTitle(animeTitlePreference: settings.animeTitlePreference)
        let previewKey = continuePreviewStateKey(for: item)
        let cardMetaLine = preview.isLastEpisode
            ? (preview.metaLine.isEmpty ? "Last episode" : "\(preview.metaLine) • Last episode")
            : preview.metaLine

        return Button {
            selectedItem = item
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .bottomLeading) {
                    WebImage(url: preview.imageURL ?? item.backdropURL ?? item.posterURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: cardWidth, height: 188, alignment: .top)
                            .clipped()
                    } placeholder: {
                        ShimmerView()
                            .frame(width: cardWidth, height: 188)
                    }
                    .transition(.fade(duration: 0.2))

                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(height: 92)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: .black.opacity(0.70), location: 0.45),
                                    .init(color: .black, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(maxHeight: .infinity, alignment: .bottom)

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.44)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(preview.episodeTitle)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(cardMetaLine)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .frame(width: cardWidth, height: 188)
                .clipShape(Squircle(cornerRadius: 22))
                .overlay(
                    Squircle(cornerRadius: 22)
                        .stroke(.white.opacity(colorScheme == .dark ? 0.16 : 0.25), lineWidth: 1)
                )

                Text(seriesTitle)
                    .font(.body.weight(.semibold))
                    .padding(.leading, 12)
                    .lineLimit(1)
            }
            .frame(width: cardWidth, alignment: .leading)
        }
        .buttonStyle(.plain)
        .task(id: previewKey) {
            await loadContinueTargetIfNeeded(for: item, stateKey: previewKey)
            await loadContinuePreviewIfNeeded(for: item, previewKey: previewKey)
        }
    }

    private var continueWatchingPage: some View {
        ZStack {
            libraryBackgroundGradient(colorScheme)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if continueWatchingItems.isEmpty {
                        ContentUnavailableView(
                            "No Episodes in Progress",
                            systemImage: "play.circle",
                            description: Text("Start watching a show or anime and it will appear here.")
                        )
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.top, 90)
                    } else {
                        ForEach(continueWatchingItems) { item in
                            continueWatchingEpisodeRow(item)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                toolbarCircleButton(symbol: "chevron.left") {
                    showingContinueWatchingPage = false
                }
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("Continue Watching")
                        .font(.headline)
                    Text("Episodes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func continueWatchingEpisodeRow(_ item: MediaItem) -> some View {
        let preview = previewForCard(item)
        let previewKey = continuePreviewStateKey(for: item)
        let seriesTitle = item.preferredDisplayTitle(animeTitlePreference: settings.animeTitlePreference)
        let target = continueTarget(for: item)
        let nextKey = target?.episode
        let token = nextKey.map { "\(item.id)|\($0.rawValue)" }
        let isMarking = token.map { markingContinueTokens.contains($0) } ?? false
        let rowMeta = continueRowMeta(from: preview.metaLine)
        let overviewText = preview.episodeOverview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? item.overview
            : preview.episodeOverview
        let artworkWidth: CGFloat = 126
        let artworkSpacing: CGFloat = 12

        return Button {
            markContinueEpisodeWatched(item: item, target: target)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(seriesTitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.leading, artworkWidth + artworkSpacing)

                HStack(alignment: .top, spacing: artworkSpacing) {
                    continueEpisodeArtwork(item: item, preview: preview)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(preview.episodeTitle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        if let dateLine = rowMeta.dateLine {
                            Text(dateLine)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.78))
                                .lineLimit(1)
                        }

                        Text(overviewText)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.64))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)

                        if !rowMeta.footerLine.isEmpty {
                            Text(rowMeta.footerLine)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.64))
                                .lineLimit(1)
                        }

                        if preview.isLastEpisode {
                            Text("Last episode")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.84))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isMarking ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(isMarking ? .white : .white.opacity(0.66))
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .disabled(nextKey == nil || isMarking)
        .task(id: previewKey) {
            await loadContinueTargetIfNeeded(for: item, stateKey: previewKey)
            await loadContinuePreviewIfNeeded(for: item, previewKey: previewKey)
        }
    }

    private func continueEpisodeArtwork(item: MediaItem, preview: ContinueEpisodePreview) -> some View {
        WebImage(url: preview.imageURL ?? item.backdropURL ?? item.posterURL) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ShimmerView()
        }
        .transition(.fade(duration: 0.2))
        .frame(width: 126, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(colorScheme == .dark ? 0.12 : 0.22), lineWidth: 1)
        )
    }

    private func markContinueEpisodeWatched(item: MediaItem, target: ContinueEpisodeTarget?) {
        Task { @MainActor in
            let stateKey = continuePreviewStateKey(for: item)
            await loadContinueTargetIfNeeded(for: item, stateKey: stateKey)

            let resolvedTarget = continueTargets[item.id] ?? target ?? continueTarget(for: item)
            guard let resolvedTarget else { return }

            let token = "\(item.id)|\(resolvedTarget.episode.rawValue)"
            guard !markingContinueTokens.contains(token) else { return }

            markingContinueTokens.insert(token)
            let totalEpisodes = max(resolvedTarget.totalEpisodes, item.totalEpisodes ?? 0)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                mediaService.markEpisodeWatched(
                    mediaId: item.id,
                    key: resolvedTarget.episode.rawValue,
                    totalEpisodes: totalEpisodes
                )
                markingContinueTokens.remove(token)
            }
        }
    }

    private func continueRowMeta(from metaLine: String) -> (dateLine: String?, footerLine: String) {
        let parts = metaLine
            .split(separator: "•")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let first = parts.first else {
            return (nil, "")
        }

        let dateLine: String?
        let footerParts: [String]
        if parts.count >= 3 {
            dateLine = parts[1]
            footerParts = [first, parts[2]]
        } else if parts.count == 2 {
            dateLine = nil
            footerParts = [first, parts[1]]
        } else {
            dateLine = nil
            footerParts = [first]
        }

        return (dateLine, footerParts.joined(separator: " • "))
    }

    private func mediaCategorySection(title: String, type: MediaType) -> some View {
        let queued = watchlistItems(for: type)
        let watched = watchedItems(for: type)

        return VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.title2.weight(.bold))
                .lineLimit(1)

            Text("\(queued.count) in watchlist, \(watched.count) watched")
                .font(.body.weight(.regular))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            HStack(spacing: 12) {
                categoryTile(
                    title: LibraryCollectionKind.watchlist.title,
                    count: queued.count,
                    icon: type.icon,
                    type: type,
                    kind: .watchlist,
                    previewItems: previewItemsForCategoryTile(
                        type: type,
                        kind: .watchlist,
                        fallbackItems: queued
                    )
                )
                categoryTile(
                    title: LibraryCollectionKind.watched.title,
                    count: watched.count,
                    icon: type.icon,
                    type: type,
                    kind: .watched,
                    previewItems: previewItemsForCategoryTile(
                        type: type,
                        kind: .watched,
                        fallbackItems: watched
                    )
                )
            }
            .padding(.top, 14)
        }
    }

    private func previewItemsForCategoryTile(
        type: MediaType,
        kind: LibraryCollectionKind,
        fallbackItems: [MediaItem]
    ) -> [MediaItem] {
        let recent: [MediaItem]
        switch kind {
        case .watchlist:
            recent = mediaService.recentQueueItems(type: type, limit: 2)
        case .watched:
            recent = mediaService.recentWatchedItems(type: type, limit: 2)
        }

        if recent.count >= 2 {
            return recent
        }

        let seenIds = Set(recent.map(\.id))
        let remainder = fallbackItems
            .reversed()
            .filter { !seenIds.contains($0.id) }

        return Array((recent + remainder).prefix(2))
    }

    private func categoryTile(
        title: String,
        count: Int,
        icon: String,
        type: MediaType,
        kind: LibraryCollectionKind,
        previewItems: [MediaItem]
    ) -> some View {
        NavigationLink(value: LibraryCollectionRoute(type: type, kind: kind)) {
            VStack(spacing: 12) {
                Spacer(minLength: 0)

                categoryArtwork(items: previewItems, fallbackIcon: icon)

                Text("\(title) \(count)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 178)
            .background {
                ZStack {
                    Squircle(cornerRadius: 24)
                        .fill(tileGradient(for: type))

                    Squircle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .opacity(colorScheme == .dark ? 0.22 : 0.55)
                }
            }
            .overlay(
                Squircle(cornerRadius: 24)
                    .stroke(.white.opacity(colorScheme == .dark ? 0.14 : 0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func categoryArtwork(items: [MediaItem], fallbackIcon: String) -> some View {
        if items.isEmpty {
            Image(systemName: fallbackIcon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white.opacity(0.25))
                .frame(height: 114)
        } else if items.count == 1, let first = items.first {
            PosterCard(item: first, width: 78, height: 112, cornerRadius: 14)
                .frame(height: 114)
        } else {
            ZStack {
                if items.indices.contains(1) {
                    PosterCard(item: items[1], width: 78, height: 112, cornerRadius: 14)
                        .rotationEffect(.degrees(8))
                        .offset(x: 20, y: 2)
                }

                PosterCard(item: items[0], width: 78, height: 112, cornerRadius: 14)
                    .rotationEffect(.degrees(-7))
                    .offset(x: -16, y: -2)
            }
            .frame(height: 114)
        }
    }



    private func tileGradient(for type: MediaType) -> LinearGradient {
        let colors: [Color]
        switch type {
        case .movie:
            colors = [Color(hex: "13263A"), Color(hex: "1D3750")]
        case .tvShow:
            colors = [Color(hex: "1A233B"), Color(hex: "24344F")]
        case .anime:
            colors = [Color(hex: "163446"), Color(hex: "1F4760")]
        }

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func watchlistItems(for type: MediaType) -> [MediaItem] {
        mediaService.queueItems.filter { $0.type == type && !$0.isWatched }.sortedForLibrary()
    }

    private func watchedItems(for type: MediaType) -> [MediaItem] {
        mediaService.watchedItems.filter { $0.type == type && $0.isWatched }.sortedForLibrary()
    }

    private func continueTarget(for item: MediaItem) -> ContinueEpisodeTarget? {
        continueTargets[item.id] ?? fallbackContinueTarget(for: item)
    }

    private func fallbackContinueTarget(
        for item: MediaItem,
        totalEpisodesOverride: Int? = nil
    ) -> ContinueEpisodeTarget? {
        guard item.hasSeasonsAndEpisodes, !item.isWatched else { return nil }

        let watchedKeys = mediaService.watchedEpisodeKeys(mediaId: item.id)
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

        let nextKey = EpisodeProgress.nextEpisodeKey(
            watchedKeys: watchedKeys,
            totalEpisodes: item.totalEpisodes,
            isWatched: item.isWatched
        )
        guard let parsed = nextKey.flatMap(EpisodeProgress.parseEpisodeKey) else { return nil }

        let inferredTotal = max(mediaService.watchedEpisodeCount(mediaId: item.id) + 1, 1)
        return ContinueEpisodeTarget(
            episode: parsed,
            totalEpisodes: inferredTotal,
            isLastEpisode: false
        )
    }

    @MainActor
    private func loadContinueTargetIfNeeded(for item: MediaItem, stateKey: String) async {
        if targetStateKeys[item.id] == stateKey {
            return
        }
        guard !loadingTargetIds.contains(item.id) else { return }

        loadingTargetIds.insert(item.id)
        defer { loadingTargetIds.remove(item.id) }

        let resolved = await resolveContinueTarget(for: item)
        if let resolved {
            continueTargets[item.id] = resolved
        } else {
            continueTargets.removeValue(forKey: item.id)
        }
        targetStateKeys[item.id] = stateKey
    }

    @MainActor
    private func resolveContinueTarget(for item: MediaItem) async -> ContinueEpisodeTarget? {
        guard item.hasSeasonsAndEpisodes, !item.isWatched else { return nil }

        if item.type == .anime && item.id >= MediaService.aniListAnimeIdOffset {
            return fallbackContinueTarget(for: item)
        }

        do {
            let detail = try await tmdbService.fetchTVDetail(id: item.tmdbId)
            if let seasons = detail.seasons,
               let resolved = resolveTargetFromSeasonSummaries(
                   for: item,
                   seasons: seasons,
                   totalEpisodesHint: detail.numberOfEpisodes
               ) {
                return resolved
            }

            if let numberOfEpisodes = detail.numberOfEpisodes, numberOfEpisodes > 0 {
                return fallbackContinueTarget(for: item, totalEpisodesOverride: numberOfEpisodes)
            }
        } catch {
            // Falls back below.
        }

        return fallbackContinueTarget(for: item)
    }

    private func resolveTargetFromSeasonSummaries(
        for item: MediaItem,
        seasons: [TMDBSeasonSummary],
        totalEpisodesHint: Int?
    ) -> ContinueEpisodeTarget? {
        let watchedKeys = mediaService.watchedEpisodeKeys(mediaId: item.id)
        let sortedSeasons = seasons
            .filter { $0.seasonNumber > 0 && $0.episodeCount > 0 }
            .sorted { $0.seasonNumber < $1.seasonNumber }

        guard !sortedSeasons.isEmpty else {
            return fallbackContinueTarget(for: item, totalEpisodesOverride: totalEpisodesHint)
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
                    if firstUnwatched == nil {
                        firstUnwatched = key
                    }
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

    private func previewForCard(_ item: MediaItem) -> ContinueEpisodePreview {
        if let existing = continuePreviews[item.id] {
            return existing
        }

        if let target = continueTarget(for: item) {
            return fallbackPreview(for: item, target: target)
        }

        return ContinueEpisodePreview(
            episodeTitle: item.title,
            episodeOverview: item.overview,
            metaLine: item.subtitle,
            imageURL: item.backdropURL ?? item.posterURL,
            isLastEpisode: false
        )
    }

    private func continuePreviewStateKey(for item: MediaItem) -> String {
        let watchedKeys = EpisodeProgress
            .sortedEpisodeKeys(mediaService.watchedEpisodeKeys(mediaId: item.id))
            .joined(separator: ",")
        return "\(item.id)|\(item.isWatched)|\(item.isInProgress)|\(item.totalEpisodes ?? 0)|\(watchedKeys)"
    }

    @MainActor
    private func loadContinuePreviewIfNeeded(for item: MediaItem, previewKey: String) async {
        if previewStateKeys[item.id] == previewKey, continuePreviews[item.id] != nil {
            return
        }
        guard !loadingPreviewIds.contains(item.id) else { return }

        guard item.hasSeasonsAndEpisodes else {
            continuePreviews[item.id] = previewForCard(item)
            previewStateKeys[item.id] = previewKey
            return
        }

        guard let target = continueTarget(for: item) else {
            continuePreviews[item.id] = previewForCard(item)
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
        } catch {
            // Fallback is handled below.
        }

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

        if let formattedDate = formattedEpisodeDate(airDate) {
            parts.append(formattedDate)
        }

        if let runtime, runtime > 0 {
            parts.append("\(runtime)m")
        }

        return parts.joined(separator: " • ")
    }

    private func formattedEpisodeDate(_ rawDate: String?) -> String? {
        guard let rawDate, !rawDate.isEmpty else { return nil }
        guard let date = DateFormatter.libraryDateParser.date(from: rawDate) else { return nil }
        return DateFormatter.libraryEpisodeFormatter.string(from: date)
    }

    private func stillImageURL(from path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        return URL(string: "https://image.tmdb.org/t/p/w780\(path)")
    }

    @MainActor
    private func trimContinuePreviewCache() {
        let validIds = Set(continueWatchingItems.map(\.id))
        continuePreviews = continuePreviews.filter { validIds.contains($0.key) }
        previewStateKeys = previewStateKeys.filter { validIds.contains($0.key) }
        continueTargets = continueTargets.filter { validIds.contains($0.key) }
        targetStateKeys = targetStateKeys.filter { validIds.contains($0.key) }
        loadingTargetIds = loadingTargetIds.filter { validIds.contains($0) }
        loadingPreviewIds = loadingPreviewIds.filter { validIds.contains($0) }
    }

    private func toolbarCircleButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
    }
}
