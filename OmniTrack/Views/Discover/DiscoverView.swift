import SwiftUI
import SDWebImageSwiftUI

struct DiscoverView: View {
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel = DiscoverViewModel()

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
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search any movie, show or anime..."
            )
            .sheet(item: $viewModel.selectedItem) { item in
                DetailView(item: item)
            }
            .task {
                viewModel.setupSearchDebounce(mediaService: mediaService)
                if mediaService.discoverMedia.isEmpty {
                    viewModel.loadData(reset: true, mediaService: mediaService)
                }
            }
            .onChange(of: viewModel.selectedType) { _, _ in viewModel.loadData(reset: true, mediaService: mediaService) }
            .onChange(of: viewModel.selectedCatalog) { _, _ in viewModel.loadData(reset: true, mediaService: mediaService) }
            .onChange(of: viewModel.selectedGenre) { _, _ in viewModel.loadData(reset: true, mediaService: mediaService) }
            .onChange(of: settings.animeSource) { _, _ in
                viewModel.selectedGenre = nil
                viewModel.loadData(reset: true, mediaService: mediaService)
            }
            .onChange(of: settings.animeTitlePreference) { _, _ in
                viewModel.loadData(reset: true, mediaService: mediaService)
            }
        }
    }

    private var discoverControls: some View {
        VStack(spacing: 12) {
            Picker("Media Category", selection: $viewModel.selectedType) {
                Text("All").tag(nil as MediaType?)
                Text("Movies").tag(Optional(MediaType.movie))
                Text("TV Shows").tag(Optional(MediaType.tvShow))
                Text("Anime").tag(Optional(MediaType.anime))
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                Menu {
                    Button("All Genres") {
                        viewModel.selectedGenre = nil
                    }

                    ForEach(viewModel.availableGenres(mediaService: mediaService, settings: settings), id: \.self) { genre in
                        Button(genre) {
                            viewModel.selectedGenre = genre
                        }
                    }
                } label: {
                    DiscoverDropdownLabel(
                        title: viewModel.selectedGenre ?? "Genre",
                        icon: "tag"
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                Menu {
                    ForEach(DiscoverCatalog.allCases) { catalog in
                        Button(catalog.rawValue) {
                            viewModel.selectedCatalog = catalog
                        }
                    }
                } label: {
                    DiscoverDropdownLabel(
                        title: "Sort By: \(viewModel.selectedCatalog.rawValue)",
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
                if !viewModel.isSearchingQuery {
                    trendingSection
                }

                DiscoverSectionHeader(title: viewModel.isSearchingQuery ? "Results" : "Browse Catalog")
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(viewModel.gridItems(mediaService: mediaService)) { item in
                        Button {
                            viewModel.selectedItem = item
                        } label: {
                            DiscoverPosterCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }

                    if mediaService.hasMoreDiscover {
                        Color.clear
                            .frame(height: 50)
                            .onAppear {
                                viewModel.loadMore(mediaService: mediaService)
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
        let trendingPreviewItems = viewModel.trendingPreviewItems(mediaService: mediaService)
        if !trendingPreviewItems.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                DiscoverSectionHeader(title: viewModel.spotlightTitle)
                    .padding(.horizontal, 16)

                GeometryReader { proxy in
                    let cardWidth = max(280, min(700, proxy.size.width - 56))

                    ScrollView(.horizontal) {
                        HStack(spacing: 14) {
                            ForEach(trendingPreviewItems) { item in
                                Button {
                                    viewModel.selectedItem = item
                                } label: {
                                    FeaturedCardView(item: item)
                                        .frame(width: cardWidth)
                                        .overlay(
                                            Squircle(cornerRadius: 20)
                                                .stroke(.white.opacity(colorScheme == .dark ? 0.16 : 0.24), lineWidth: 1)
                                        )
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
        .overlay(
            Squircle(cornerRadius: 12)
                .stroke(.white.opacity(colorScheme == .dark ? 0.16 : 0.24), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 5, y: 3)
    }
}

private struct DiscoverDropdownLabel: View {
    let title: String
    let icon: String

    var body: some View {
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
}

private struct DiscoverSectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.title2.weight(.bold))
            Spacer()
        }
    }
}
