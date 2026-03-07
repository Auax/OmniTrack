import SwiftUI
import SDWebImageSwiftUI

// Shared function inside the Library folder scope
func libraryBackgroundGradient(_ colorScheme: ColorScheme) -> LinearGradient {
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

    @State private var viewModel = LibraryViewModel()

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

                        LibraryMediaCategorySection(title: "Movies", type: .movie)
                        LibraryMediaCategorySection(title: "Shows", type: .tvShow)
                        LibraryMediaCategorySection(title: "Animes", type: .anime)
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
            .navigationDestination(isPresented: $viewModel.showingContinueWatchingPage) {
                continueWatchingPage
            }
            .sheet(item: $viewModel.selectedItem) { item in
                DetailView(item: item)
            }
            .onChange(of: continueWatchingItems.map(\.id)) { _, _ in
                viewModel.trimContinuePreviewCache(validItems: continueWatchingItems)
            }
            .task {
                viewModel.trimContinuePreviewCache(validItems: continueWatchingItems)
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
                viewModel.showingContinueWatchingPage = true
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
                            LibraryContinueWatchingCardBuilder(
                                item: item,
                                cardWidth: cardWidth,
                                viewModel: viewModel
                            )
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
                            LibraryContinueWatchingRowBuilder(
                                item: item,
                                viewModel: viewModel
                            )
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
                LibraryToolbarCircleButton(symbol: "chevron.left") {
                    viewModel.showingContinueWatchingPage = false
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





    private func previewItemsForCategoryTile(type: MediaType, kind: LibraryCollectionKind, fallbackItems: [MediaItem]) -> [MediaItem] {
        let recent: [MediaItem]
        switch kind {
        case .watchlist:
            recent = mediaService.recentQueueItems(type: type, limit: 2)
        case .watched:
            recent = mediaService.recentWatchedItems(type: type, limit: 2)
        }

        if recent.count >= 2 { return recent }

        let seenIds = Set(recent.map(\.id))
        let remainder = fallbackItems.reversed().filter { !seenIds.contains($0.id) }
        return Array((recent + remainder).prefix(2))
    }

    private func watchlistItems(for type: MediaType) -> [MediaItem] {
        mediaService.queueItems.filter { $0.type == type && !$0.isWatched }.sortedForLibrary()
    }

    private func watchedItems(for type: MediaType) -> [MediaItem] {
        mediaService.watchedItems.filter { $0.type == type && $0.isWatched }.sortedForLibrary()
    }
}

private struct LibraryContinueWatchingCardBuilder: View {
    let item: MediaItem
    let cardWidth: CGFloat
    @Bindable var viewModel: LibraryViewModel
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        let preview = viewModel.previewForCard(item, mediaService: mediaService)
        let seriesTitle = item.preferredDisplayTitle(animeTitlePreference: settings.animeTitlePreference)
        let previewKey = viewModel.continuePreviewStateKey(for: item, mediaService: mediaService)
        let cardMetaLine = preview.isLastEpisode
            ? (preview.metaLine.isEmpty ? "Last episode" : "\(preview.metaLine) • Last episode")
            : preview.metaLine

        ContinueWatchingCard(
            item: item,
            cardWidth: cardWidth,
            preview: preview,
            seriesTitle: seriesTitle,
            cardMetaLine: cardMetaLine,
            previewKey: previewKey,
            onSelect: { viewModel.selectedItem = item },
            onTask: {
                await viewModel.loadContinueTargetIfNeeded(for: item, stateKey: previewKey, mediaService: mediaService)
                await viewModel.loadContinuePreviewIfNeeded(for: item, previewKey: previewKey, mediaService: mediaService)
            }
        )
    }
}

private struct LibraryContinueWatchingRowBuilder: View {
    let item: MediaItem
    @Bindable var viewModel: LibraryViewModel
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        let preview = viewModel.previewForCard(item, mediaService: mediaService)
        let previewKey = viewModel.continuePreviewStateKey(for: item, mediaService: mediaService)
        let seriesTitle = item.preferredDisplayTitle(animeTitlePreference: settings.animeTitlePreference)
        let target = viewModel.continueTarget(for: item, mediaService: mediaService)
        let nextKey = target?.episode
        let isMarking = viewModel.isMarkingContinueToken(item, target: target)

        ContinueWatchingRow(
            item: item,
            seriesTitle: seriesTitle,
            preview: preview,
            previewKey: previewKey,
            nextKey: nextKey,
            isMarking: isMarking,
            onMarkWatched: {
                viewModel.markContinueEpisodeWatched(item: item, target: target, mediaService: mediaService)
            },
            onTask: {
                await viewModel.loadContinueTargetIfNeeded(for: item, stateKey: previewKey, mediaService: mediaService)
                await viewModel.loadContinuePreviewIfNeeded(for: item, previewKey: previewKey, mediaService: mediaService)
            }
        )
    }
}

private struct LibraryMediaCategorySection: View {
    let title: String
    let type: MediaType
    @Environment(MediaService.self) private var mediaService

    var body: some View {
        let queued = watchlistItems(for: type)
        let watched = watchedItems(for: type)

        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.title2.weight(.bold))
                .lineLimit(1)

            Text("\(queued.count) in watchlist, \(watched.count) watched")
                .font(.body.weight(.regular))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            HStack(spacing: 12) {
                LibraryCategoryTile(
                    title: LibraryCollectionKind.watchlist.title,
                    count: queued.count,
                    icon: type.icon,
                    type: type,
                    kind: .watchlist,
                    previewItems: previewItemsForCategoryTile(type: type, kind: .watchlist, fallbackItems: queued)
                )
                LibraryCategoryTile(
                    title: LibraryCollectionKind.watched.title,
                    count: watched.count,
                    icon: type.icon,
                    type: type,
                    kind: .watched,
                    previewItems: previewItemsForCategoryTile(type: type, kind: .watched, fallbackItems: watched)
                )
            }
            .padding(.top, 14)
        }
    }

    private func previewItemsForCategoryTile(type: MediaType, kind: LibraryCollectionKind, fallbackItems: [MediaItem]) -> [MediaItem] {
        let recent: [MediaItem]
        switch kind {
        case .watchlist:
            recent = mediaService.recentQueueItems(type: type, limit: 2)
        case .watched:
            recent = mediaService.recentWatchedItems(type: type, limit: 2)
        }

        if recent.count >= 2 { return recent }

        let seenIds = Set(recent.map(\.id))
        let remainder = fallbackItems.reversed().filter { !seenIds.contains($0.id) }
        return Array((recent + remainder).prefix(2))
    }

    private func watchlistItems(for type: MediaType) -> [MediaItem] {
        mediaService.queueItems.filter { $0.type == type && !$0.isWatched }.sortedForLibrary()
    }

    private func watchedItems(for type: MediaType) -> [MediaItem] {
        mediaService.watchedItems.filter { $0.type == type && $0.isWatched }.sortedForLibrary()
    }
}

private struct LibraryToolbarCircleButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
    }
}
