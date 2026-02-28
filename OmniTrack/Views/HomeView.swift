import SwiftUI
import SDWebImageSwiftUI

struct HomeView: View {
    let onExplore: () -> Void
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedItem: MediaItem?
    @State private var hasLoaded: Bool = false

    init(onExplore: @escaping () -> Void = {}) {
        self.onExplore = onExplore
    }

    private var enabledTypes: Set<MediaType> {
        var types = Set<MediaType>()
        if settings.showMovies { types.insert(.movie) }
        if settings.showTVShows { types.insert(.tvShow) }
        if settings.showAnime { types.insert(.anime) }
        return types
    }

    private func isTypeEnabled(_ type: MediaType) -> Bool {
        enabledTypes.contains(type)
    }

    private var watchlistItems: [MediaItem] {
        mediaService.queueItems
            .filter { isTypeEnabled($0.type) && !$0.isWatched }
    }

    private var continueWatchingItems: [MediaItem] {
        mediaService.inProgressItemsSortedByRecentUpdate()
            .filter { item in
                guard isTypeEnabled(item.type), item.hasSeasonsAndEpisodes, !item.isWatched else {
                    return false
                }

                let watchedCount = mediaService.watchedEpisodeCount(mediaId: item.id)
                guard watchedCount > 0 else { return false }

                if let total = item.totalEpisodes, total > 0 {
                    return watchedCount < total
                }

                return true
            }
    }

    private var shouldShowInitialLoading: Bool {
        !hasLoaded && mediaService.allMedia.isEmpty && mediaService.errorMessage == nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if (mediaService.isLoading || shouldShowInitialLoading) && mediaService.allMedia.isEmpty {
                        loadingView
                    } else if let error = mediaService.errorMessage, mediaService.allMedia.isEmpty {
                        errorView(error)
                    } else {
                        if !continueWatchingItems.isEmpty {
                            carouselSection(
                                title: "Continue Watching",
                                icon: "play.circle.fill",
                                items: continueWatchingItems,
                                emptyMessage: "No in-progress titles.",
                                showsContinueActions: true
                            )
                        }

                        if watchlistItems.isEmpty {
                            if continueWatchingItems.isEmpty {
                                emptyWatchlistView
                            }
                        } else {
                            carouselSection(
                                title: "Your Watchlist",
                                icon: "bookmark.fill",
                                items: watchlistItems,
                                emptyMessage: "Your watchlist is empty."
                            )
                        }
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(AppTheme.adaptiveBackground(colorScheme))
            .navigationTitle("OmniTrack")
            .refreshable {
                await mediaService.loadContent(
                    showMovies: settings.showMovies,
                    showTVShows: settings.showTVShows,
                    showAnime: settings.showAnime
                )
            }
            .sheet(item: $selectedItem) { item in
                DetailView(item: item)
            }
            .task {
                guard !hasLoaded else { return }
                hasLoaded = true
                await mediaService.loadContent(
                    showMovies: settings.showMovies,
                    showTVShows: settings.showTVShows,
                    showAnime: settings.showAnime
                )
            }
            .onChange(of: settings.showMovies) { _, _ in reloadContent() }
            .onChange(of: settings.showTVShows) { _, _ in reloadContent() }
            .onChange(of: settings.showAnime) { _, _ in reloadContent() }
            .onChange(of: settings.animeSource) { _, _ in reloadContent() }
            .onChange(of: settings.animeTitlePreference) { _, _ in reloadContent() }
        }
    }

    private func carouselSection(
        title: String,
        icon: String,
        items: [MediaItem],
        emptyMessage: String,
        showsContinueActions: Bool = false,
        emptyActionTitle: String? = nil,
        emptyAction: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title)
                .padding(.horizontal, 16)

            if items.isEmpty {
                if let emptyActionTitle, let emptyAction {
                    ContentUnavailableView {
                        Label(title, systemImage: icon)
                    } description: {
                        Text(emptyMessage)
                    } actions: {
                        Button(emptyActionTitle) {
                            emptyAction()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ContentUnavailableView(
                        title,
                        systemImage: icon,
                        description: Text(emptyMessage)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                GeometryReader { proxy in
                    let cardWidth = max(280, min(700, proxy.size.width - 56))

                    ScrollView(.horizontal) {
                        HStack(spacing: 14) {
                            ForEach(items.prefix(12)) { item in
                                if showsContinueActions && item.hasSeasonsAndEpisodes {
                                    continueWatchingCard(item, cardWidth: cardWidth)
                                } else {
                                    Button {
                                        selectedItem = item
                                    } label: {
                                        homeGlassCard(
                                            item: item,
                                            cardWidth: cardWidth,
                                            subtitle: item.subtitle
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .contentMargins(.horizontal, 16)
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned)
                }
                .frame(height: showsContinueActions ? 270 : 220)
            }
        }
    }

    private func continueWatchingCard(_ item: MediaItem, cardWidth: CGFloat) -> some View {
        let nextKey = EpisodeProgress.nextEpisodeKey(
            watchedKeys: mediaService.watchedEpisodeKeys(mediaId: item.id),
            totalEpisodes: item.totalEpisodes,
            isWatched: item.isWatched
        )
        let label = EpisodeProgress.displayLabel(for: nextKey, style: .home)

        return VStack(alignment: .leading, spacing: 8) {
            Button {
                selectedItem = item
            } label: {
                homeGlassCard(item: item, cardWidth: cardWidth, subtitle: label)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                if let nextKey {
                    Button {
                        withAnimation(.snappy) {
                            mediaService.markEpisodeWatched(
                                mediaId: item.id,
                                key: nextKey,
                                totalEpisodes: item.totalEpisodes ?? 0
                            )
                        }
                    } label: {
                        Label("Mark Episode", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.gray)
                }

                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .frame(width: cardWidth, alignment: .leading)
    }

    private func homeGlassCard(item: MediaItem, cardWidth: CGFloat, subtitle: String?) -> some View {
        ZStack(alignment: .bottomLeading) {
            WebImage(url: item.backdropURL ?? item.posterURL) { image in
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
                Text(item.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                }
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
    }

    private var emptyWatchlistView: some View {
        ContentUnavailableView {
            Label("Nothing here yet", systemImage: "sparkles")
        } description: {
            Text("Your watchlist is feeling a bit lonely.\nExplore new titles to get started!")
        } actions: {
            Button("Explore") {
                onExplore()
            }
            .buttonStyle(.borderedProminent)
            .tint(colorScheme == .dark ? .white : .black)
            .foregroundStyle(colorScheme == .dark ? .black : .white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Unable to Load", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                reloadContent()
            }
        }
        .padding(.top, 40)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
        }
    }

    private func reloadContent() {
        Task {
            await mediaService.loadContent(
                showMovies: settings.showMovies,
                showTVShows: settings.showTVShows,
                showAnime: settings.showAnime
            )
        }
    }
}
