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

    var availableGenres: [String] {
        mediaService.discoverGenreNames(includeAniListGenres: settings.animeSource == .aniList)
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
                VStack(alignment: .leading, spacing: 0) {
                    discoverControls
                    discoverContent
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
            .onChange(of: settings.animeSource) { _, _ in
                selectedGenre = nil
                loadData(reset: true)
            }
            .onChange(of: settings.animeTitlePreference) { _, _ in
                loadData(reset: true)
            }
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

    private var discoverControls: some View {
        VStack(spacing: 12) {
            Picker("Media Category", selection: $selectedType) {
                Text("All").tag(nil as MediaType?)
                Text("Movies").tag(Optional(MediaType.movie))
                Text("TV Shows").tag(Optional(MediaType.tvShow))
                Text("Anime").tag(Optional(MediaType.anime))
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                Menu {
                    Button("All Genres") {
                        selectedGenre = nil
                    }

                    ForEach(availableGenres, id: \.self) { genre in
                        Button(genre) {
                            selectedGenre = genre
                        }
                    }
                } label: {
                    dropdownLabel(
                        title: selectedGenre ?? "Genre",
                        icon: "tag"
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                Menu {
                    ForEach(DiscoverCatalog.allCases) { catalog in
                        Button(catalog.rawValue) {
                            selectedCatalog = catalog
                        }
                    }
                } label: {
                    dropdownLabel(
                        title: "Sort By: \(selectedCatalog.rawValue)",
                        icon: "arrow.up.arrow.down"
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    private func dropdownLabel(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)

            Image(systemName: "chevron.down")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 32)
        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 32, style: .continuous))

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

                sectionHeader(isSearchingQuery ? "Results" : "Browse Catalog")
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
                sectionHeader(spotlightTitle)
                    .padding(.horizontal, 16)

                GeometryReader { proxy in
                    let cardWidth = max(280, min(700, proxy.size.width - 56))

                    ScrollView(.horizontal) {
                        HStack(spacing: 14) {
                            ForEach(trendingPreviewItems) { item in
                                Button {
                                    selectedItem = item
                                } label: {
                                    FeaturedCardView(item: item)
                                        .frame(width: cardWidth)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .contentMargins(.horizontal, 16)
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned)
                }
                .frame(height: 220)
            }
            .padding(.bottom, 28)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
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
