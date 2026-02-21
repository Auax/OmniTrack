import SwiftUI

struct HomeView: View {
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedFilter: MediaType? = nil
    @State private var selectedGenre: String? = nil
    @State private var sortOption: SortOption = .rating
    @State private var searchText: String = ""
    @State private var selectedItem: MediaItem?
    @State private var hasLoaded: Bool = false
    @State private var searchTask: Task<Void, Never>?

    private var activeTypes: [MediaType] {
        var types: [MediaType] = []
        if settings.showMovies { types.append(.movie) }
        if settings.showTVShows { types.append(.tvShow) }
        if settings.showAnime { types.append(.anime) }
        return types
    }

    // Items used when not searching
    private var typeFilteredMedia: [MediaItem] {
        if let filter = selectedFilter {
            return mediaService.allMedia.filter { $0.type == filter }
        }
        return mediaService.allMedia
    }

    private var availableGenres: [String] {
        Array(Set(typeFilteredMedia.flatMap { $0.genres })).sorted()
    }

    private var displayedMedia: [MediaItem] {
        // Search mode
        if !searchText.isEmpty {
            var results = mediaService.searchResults
            if let filter = selectedFilter {
                results = results.filter { $0.type == filter }
            }
            return results
        }

        // Genre selected → use genre-fetched results
        if selectedGenre != nil {
            if mediaService.isLoadingGenre { return [] }
            var items = mediaService.genreMedia
            if let filter = selectedFilter {
                items = items.filter { $0.type == filter }
            }
            switch sortOption {
            case .rating: items.sort { $0.rating > $1.rating }
            case .yearDesc: items.sort { $0.year > $1.year }
            case .yearAsc: items.sort { $0.year < $1.year }
            case .titleAZ: items.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
            }
            return items
        }

        // Default: all media
        var items = typeFilteredMedia
        switch sortOption {
        case .rating: items.sort { $0.rating > $1.rating }
        case .yearDesc: items.sort { $0.year > $1.year }
        case .yearAsc: items.sort { $0.year < $1.year }
        case .titleAZ: items.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        }
        return items
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    filterBar
                        .padding(.top, 8)
                        .padding(.bottom, 8)

                    if !searchText.isEmpty {
                        searchResultsHeader
                    } else {
                        genreFilterBar
                            .padding(.bottom, 16)
                    }

                    if mediaService.isLoading && mediaService.allMedia.isEmpty {
                        loadingView
                    } else if let error = mediaService.errorMessage, mediaService.allMedia.isEmpty {
                        errorView(error)
                    } else {
                        // Featured section (only when not searching and no genre selected)
                        if searchText.isEmpty && selectedGenre == nil {
                            featuredSections
                        }

                        // Results
                        if mediaService.isSearching || mediaService.isLoadingGenre {
                            ProgressView(mediaService.isSearching ? "Searching..." : "Loading...")
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else if !displayedMedia.isEmpty {
                            sectionHeader(
                                selectedGenre != nil ? selectedGenre! : "Discover",
                                icon: selectedGenre != nil ? "tag" : "square.grid.2x2"
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                            .padding(.top, 4)

                            LazyVStack(spacing: 10) {
                                ForEach(displayedMedia) { item in
                                    Button {
                                        selectedItem = item
                                    } label: {
                                        MediaCardView(
                                            item: item,
                                            onMarkWatched: { mediaService.markWatched(item) },
                                            onAddToQueue: { mediaService.addToQueue(item) }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        } else if !searchText.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                                .padding(.top, 40)
                        } else if selectedGenre != nil && !mediaService.isLoadingGenre {
                            ContentUnavailableView(
                                "No Results",
                                systemImage: "magnifyingglass",
                                description: Text("No content found for \(selectedGenre ?? "this genre").")
                            )
                            .padding(.top, 40)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .background(AppTheme.adaptiveBackground(colorScheme))
            .navigationTitle("OmniTrack")
            .searchable(text: $searchText, prompt: "Search any movie, show or anime...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    sortMenu
                }
            }
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
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                if newValue.isEmpty {
                    mediaService.searchResults = []
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    guard !Task.isCancelled else { return }
                    await mediaService.search(
                        query: newValue,
                        showMovies: settings.showMovies,
                        showTVShows: settings.showTVShows,
                        showAnime: settings.showAnime
                    )
                }
            }
            .onChange(of: selectedGenre) { _, newGenre in
                if let genre = newGenre {
                    Task {
                        await mediaService.discoverByGenre(
                            genreName: genre,
                            selectedFilter: selectedFilter,
                            showMovies: settings.showMovies,
                            showTVShows: settings.showTVShows,
                            showAnime: settings.showAnime
                        )
                    }
                } else {
                    mediaService.genreMedia = []
                }
            }
            .onChange(of: settings.showMovies) { _, newValue in
                if !newValue && selectedFilter == .movie { selectedFilter = nil }
                reloadContent()
            }
            .onChange(of: settings.showTVShows) { _, newValue in
                if !newValue && selectedFilter == .tvShow { selectedFilter = nil }
                reloadContent()
            }
            .onChange(of: settings.showAnime) { _, newValue in
                if !newValue && selectedFilter == .anime { selectedFilter = nil }
                reloadContent()
            }
        }
    }

    // MARK: - Featured Sections

    @ViewBuilder
    private var featuredSections: some View {
        if selectedFilter == nil {
            if !mediaService.featuredAll.isEmpty {
                featuredSection("Featured", icon: "sparkles", items: mediaService.featuredAll)
            }
        } else if selectedFilter == .movie {
            if settings.showMovies && !mediaService.featuredMovies.isEmpty {
                featuredSection("Featured Movies", icon: "film", items: mediaService.featuredMovies)
            }
        } else if selectedFilter == .tvShow {
            if settings.showTVShows && !mediaService.featuredTVShows.isEmpty {
                featuredSection("Featured TV Shows", icon: "tv", items: mediaService.featuredTVShows)
            }
        } else if selectedFilter == .anime {
            if settings.showAnime && !mediaService.featuredAnime.isEmpty {
                featuredSection("Featured Anime", icon: "sparkles.tv", items: mediaService.featuredAnime)
            }
        }
    }

    private func featuredSection(_ title: String, icon: String, items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title, icon: icon)
                .padding(.horizontal, 16)

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(items) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            FeaturedCardView(item: item)
                                .frame(width: UIScreen.main.bounds.width - 48)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 16)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Search Results Header

    private var searchResultsHeader: some View {
        Group {
            if !mediaService.searchResults.isEmpty {
                HStack {
                    Text("\(mediaService.searchResults.count) results on TMDB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                FilterChipView(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedFilter == nil,
                    action: { withAnimation(.snappy) { selectedFilter = nil; selectedGenre = nil } }
                )

                ForEach(activeTypes) { type in
                    FilterChipView(
                        title: type.rawValue,
                        icon: type.icon,
                        isSelected: selectedFilter == type,
                        action: { withAnimation(.snappy) { selectedFilter = type; selectedGenre = nil } }
                    )
                }
            }
        }
        .contentMargins(.horizontal, 16)
        .scrollIndicators(.hidden)
    }

    private var genreFilterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                if !availableGenres.isEmpty {
                    Button {
                        withAnimation(.snappy) { selectedGenre = nil }
                    } label: {
                        Text("All Genres")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedGenre == nil ? Color.primary.opacity(0.12) : Color.clear)
                            .foregroundStyle(selectedGenre == nil ? .primary : .secondary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(.primary.opacity(selectedGenre == nil ? 0 : 0.15), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    ForEach(availableGenres, id: \.self) { genre in
                        Button {
                            withAnimation(.snappy) {
                                selectedGenre = selectedGenre == genre ? nil : genre
                            }
                        } label: {
                            Text(genre)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedGenre == genre ? Color.primary.opacity(0.12) : Color.clear)
                                .foregroundStyle(selectedGenre == genre ? .primary : .secondary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(.primary.opacity(selectedGenre == genre ? 0 : 0.15), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .contentMargins(.horizontal, 16)
        .scrollIndicators(.hidden)
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach(SortOption.allCases) { option in
                Button {
                    withAnimation(.snappy) { sortOption = option }
                } label: {
                    Label(option.rawValue, systemImage: option.icon)
                }
                .disabled(sortOption == option)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.subheadline.weight(.semibold))
        }
    }

    // MARK: - Helpers

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

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
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
