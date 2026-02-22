import SwiftUI
import SDWebImageSwiftUI

struct DiscoverView: View {
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText: String = ""
    @State private var searchTask: Task<Void, Never>?

    @State private var selectedType: MediaType? = nil
    @State private var selectedCatalog: DiscoverCatalog = .popular
    @State private var selectedGenre: String? = nil
    @State private var selectedItem: MediaItem?

    private var isSearchingQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var activeTypes: [MediaType] {
        var types: [MediaType] = []
        if settings.showMovies { types.append(.movie) }
        if settings.showTVShows { types.append(.tvShow) }
        if settings.showAnime { types.append(.anime) }
        return types
    }

    var availableGenres: [String] {
        Array(Set(mediaService.genreMap.values)).sorted()
    }

    private var highlightedGenres: [String] {
        let preferred = ["Action", "Drama", "Comedy", "Animation", "Sci-Fi", "Fantasy", "Thriller", "Adventure", "Crime", "Mystery"]
        var result = preferred.filter { availableGenres.contains($0) }
        let remaining = availableGenres.filter { !result.contains($0) }
        result.append(contentsOf: remaining.prefix(max(0, 10 - result.count)))

        if let selectedGenre, !result.contains(selectedGenre) {
            result.insert(selectedGenre, at: 0)
        }

        return result
    }

    private var trendingPreviewItems: [MediaItem] {
        Array(mediaService.discoverMedia.prefix(8))
    }

    private var gridItems: [MediaItem] {
        if isSearchingQuery {
            return mediaService.discoverMedia
        }

        let remainder = Array(mediaService.discoverMedia.dropFirst(trendingPreviewItems.count))
        return remainder.isEmpty ? mediaService.discoverMedia : remainder
    }

    private var spotlightTitle: String {
        selectedCatalog == .new ? "New Releases" : "Trending Now"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        discoverContent
                    } header: {
                        stickyFilterPillsHeader
                    }
                }
            }
            .background(AppTheme.adaptiveBackground(colorScheme))
            .navigationTitle("Discover")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search any movie, show or anime..."
            )
            .sheet(item: $selectedItem) { item in
                DetailView(item: item)
            }
            .task {
                if mediaService.discoverMedia.isEmpty {
                    loadData(reset: true)
                }
            }
            .onChange(of: selectedType) { _, _ in loadData(reset: true) }
            .onChange(of: selectedCatalog) { _, _ in loadData(reset: true) }
            .onChange(of: selectedGenre) { _, _ in loadData(reset: true) }
            .onChange(of: searchText) { _, _ in
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    guard !Task.isCancelled else { return }
                    loadData(reset: true)
                }
            }
        }
    }

    private var stickyFilterPillsHeader: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    FilterChipView(
                        title: "All",
                        icon: "square.grid.2x2",
                        isSelected: selectedType == nil,
                        action: {
                            withAnimation(.snappy) {
                                selectedType = nil
                            }
                        }
                    )

                    ForEach(activeTypes) { type in
                        FilterChipView(
                            title: type.rawValue,
                            icon: type.icon,
                            isSelected: selectedType == type,
                            action: {
                                withAnimation(.snappy) {
                                    selectedType = type
                                }
                            }
                        )
                    }
                }
            }
            .contentMargins(.horizontal, 16)
            .scrollIndicators(.hidden)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    FilterChipView(
                        title: "All Genres",
                        icon: "tag",
                        isSelected: selectedGenre == nil,
                        action: {
                            withAnimation(.snappy) {
                                selectedGenre = nil
                            }
                        }
                    )

                    ForEach(highlightedGenres, id: \.self) { genre in
                        FilterChipView(
                            title: genre,
                            icon: "tag.fill",
                            isSelected: selectedGenre == genre,
                            action: {
                                withAnimation(.snappy) {
                                    selectedGenre = selectedGenre == genre ? nil : genre
                                }
                            }
                        )
                    }
                }
            }
            .contentMargins(.horizontal, 16)
            .scrollIndicators(.hidden)
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var discoverContent: some View {
        if mediaService.discoverMedia.isEmpty && mediaService.isDiscoverLoading {
            ProgressView("Loading...")
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                .padding(.bottom, 20)
        } else if mediaService.discoverMedia.isEmpty {
            ContentUnavailableView("No Results", systemImage: "magnifyingglass")
                .padding(.top, 40)
                .padding(.bottom, 20)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if !isSearchingQuery {
                    trendingSection
                }

                sectionHeader(isSearchingQuery ? "Results" : "Browse Catalog", icon: "square.grid.2x2")
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(gridItems) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            DiscoverPosterCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }

                    if mediaService.hasMoreDiscover {
                        Color.clear
                            .frame(height: 50)
                            .onAppear {
                                loadMore()
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }

    @ViewBuilder
    private var trendingSection: some View {
        if !trendingPreviewItems.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(spotlightTitle, icon: selectedCatalog == .new ? "sparkles" : "flame.fill")
                    .padding(.horizontal, 16)

                ScrollView(.horizontal) {
                    HStack(spacing: 14) {
                        ForEach(trendingPreviewItems) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                FeaturedCardView(item: item)
                                    .frame(width: UIScreen.main.bounds.width - 72)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .contentMargins(.horizontal, 16)
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
            }
            .padding(.bottom, 16)
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
        }
    }

    private func loadData(reset: Bool) {
        Task {
            let genreId = selectedGenre.flatMap { mediaService.genreIdForName($0) }
            await mediaService.loadDiscover(
                reset: reset,
                type: selectedType,
                catalog: selectedCatalog,
                genreId: genreId,
                query: searchText
            )
        }
    }

    private func loadMore() {
        Task {
            let genreId = selectedGenre.flatMap { mediaService.genreIdForName($0) }
            await mediaService.loadDiscover(
                reset: false,
                type: selectedType,
                catalog: selectedCatalog,
                genreId: genreId,
                query: searchText
            )
        }
    }
}

// MARK: - DiscoverPosterCard

struct DiscoverPosterCard: View {
    let item: MediaItem
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // Background fallback
                LinearGradient(
                    colors: [item.accentColor.opacity(0.4), item.accentColor.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                WebImage(url: item.posterURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    if item.posterURL == nil {
                        VStack(spacing: 4) {
                            Image(systemName: item.type.icon)
                                .font(.largeTitle)
                                .foregroundStyle(item.accentColor.opacity(0.7))
                        }
                    } else {
                        Color.gray.opacity(0.2)
                    }
                }
                .transition(.fade(duration: 0.2))
                .allowsHitTesting(false)

                // Gradient overlay for better text readability
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                // Rating Overlay
                RatingView(item: item, fontSize: 12, starSize: 10)
                    .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(8)
            }
        }
        .aspectRatio(2/3, contentMode: .fit)
        .clipShape(Squircle(cornerRadius: 12))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 5, y: 3)
    }
}
