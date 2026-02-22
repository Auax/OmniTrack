import SwiftUI
import SDWebImageSwiftUI
import SDWebImageSwiftUI

struct LibraryView: View {
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: LibraryTab = .queue
    @State private var selectedItem: MediaItem?
    @State private var sortOption: SortOption = .defaultOrder
    @State private var selectedGenre: String? = nil
    @State private var selectedType: MediaType? = nil
    @State private var expandedItems: Set<Int> = []
    @State private var searchText: String = ""

    enum LibraryTab: String, CaseIterable {
        case queue = "Queue"
        case watched = "Watched"

        var emptyIcon: String {
            switch self {
            case .queue: "bookmark"
            case .watched: "checkmark.circle"
            }
        }

        var emptyTitle: String {
            switch self {
            case .queue: "Your Queue is Empty"
            case .watched: "Nothing Watched Yet"
            }
        }

        var emptyDescription: String {
            switch self {
            case .queue: "Swipe left on any title or tap Add to Queue to save it here."
            case .watched: "Mark titles as watched to keep track of what you've seen."
            }
        }
    }

    private var baseItems: [MediaItem] {
        selectedTab == .queue ? mediaService.queueItems : mediaService.watchedItems
    }

    private var availableTypes: [MediaType] {
        let types = Set(baseItems.map { $0.type })
        return [.movie, .tvShow, .anime].filter { types.contains($0) }
    }

    private var availableGenres: [String] {
        let filtered = selectedType != nil ? baseItems.filter { $0.type == selectedType } : baseItems
        return Array(Set(filtered.flatMap { $0.genres })).sorted()
    }

    private var currentItems: [MediaItem] {
        var items = baseItems
        if !searchText.isEmpty {
            items = items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        if let type = selectedType {
            items = items.filter { $0.type == type }
        }
        if let genre = selectedGenre {
            items = items.filter { $0.genres.contains(genre) }
        }
        switch sortOption {
        case .defaultOrder: break
        case .rating: items.sort { $0.effectiveRating(for: settings.ratingProvider) > $1.effectiveRating(for: settings.ratingProvider) }
        case .yearDesc: items.sort { $0.year > $1.year }
        case .yearAsc: items.sort { $0.year < $1.year }
        case .titleAZ: items.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        }
        return items
    }

    var body: some View {
        NavigationStack {
            Group {
                if currentItems.isEmpty {
                    ContentUnavailableView(
                        selectedTab.emptyTitle,
                        systemImage: selectedTab.emptyIcon,
                        description: Text(selectedTab.emptyDescription)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(currentItems) { item in
                                VStack(spacing: 0) {
                                    Button {
                                        selectedItem = item
                                    } label: {
                                        libraryCard(item)
                                    }
                                    .buttonStyle(.plain)

                                    if item.hasSeasonsAndEpisodes {
                                        episodeSection(item)
                                    }
                                }
                                .background(AppTheme.adaptiveCardBackground(colorScheme))
                                .clipShape(.rect(cornerRadius: 16))
                                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 6, y: 3)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                tabSelector
            }
            .background(AppTheme.adaptiveBackground(colorScheme))
            .navigationTitle("Library")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search Library"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    sortMenu
                }
            }
            .sheet(item: $selectedItem) { item in
                DetailView(item: item)
            }
            .onChange(of: selectedTab) { _, _ in
                selectedGenre = nil
                selectedType = nil
                expandedItems = []
                searchText = ""
            }
        }
    }

    private var tabSelector: some View {
        Picker("", selection: $selectedTab) {
            ForEach(LibraryTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Filter Menu

    private var filterMenu: some View {
        Menu {
            if availableTypes.count > 1 {
                Section("Type") {
                    Button {
                        withAnimation(.snappy) { selectedType = nil; selectedGenre = nil }
                    } label: {
                        Label("All Types", systemImage: selectedType == nil ? "checkmark" : "")
                    }
                    
                    ForEach(availableTypes) { type in
                        Button {
                            withAnimation(.snappy) { selectedType = type; selectedGenre = nil }
                        } label: {
                            Label(type.rawValue, systemImage: selectedType == type ? "checkmark" : "")
                        }
                    }
                }
            }

            if !availableGenres.isEmpty {
                Section("Genre") {
                    Button {
                        withAnimation(.snappy) { selectedGenre = nil }
                    } label: {
                        Label("All Genres", systemImage: selectedGenre == nil ? "checkmark" : "")
                    }
                    
                    ForEach(availableGenres, id: \.self) { genre in
                        Button {
                            withAnimation(.snappy) { selectedGenre = selectedGenre == genre ? nil : genre }
                        } label: {
                            Label(genre, systemImage: selectedGenre == genre ? "checkmark" : "")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: selectedType != nil || selectedGenre != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selectedType != nil || selectedGenre != nil ? Color.accentColor : Color.primary)
                .padding(8)
                .contentShape(Rectangle())
        }
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
                .padding(8)
                .contentShape(Rectangle())
        }
    }

    // MARK: - Library Card

    private func libraryCard(_ item: MediaItem) -> some View {
        HStack(spacing: 14) {
            // Poster image with graceful fallback
            posterImage(item)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: item.type.icon)
                        .font(.caption2)
                        .foregroundStyle(item.accentColor)
                    Text(item.type.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                }

                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)

                // "Next Up" for queue + episodic content
                if selectedTab == .queue && item.hasSeasonsAndEpisodes {
                    nextUpBadge(item)
                } else {
                    ratingRow(item)

                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Episode progress for series
                if item.hasSeasonsAndEpisodes {
                    episodeProgressBadge(item)
                }

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            actionButtons(item)
        }
        .padding(12)
    }

    // MARK: - Graceful Poster Image

    private func posterImage(_ item: MediaItem) -> some View {
        ZStack {
            // Gradient background fallback
            LinearGradient(
                colors: [item.accentColor.opacity(0.4), item.accentColor.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            WebImage(url: item.posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                if item.posterURL == nil {
                    // Stylized fallback
                    VStack(spacing: 4) {
                        Image(systemName: item.type.icon)
                            .font(.title2)
                            .foregroundStyle(item.accentColor.opacity(0.7))
                    }
                } else {
                    // Skeleton shimmer
                    ShimmerView()
                }
            }
            .transition(.fade(duration: 0.2))
            .id(item.posterURL)
            .allowsHitTesting(false)
        }
        .frame(width: 70, height: 100)
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Next Up Badge

    @ViewBuilder
    private func nextUpBadge(_ item: MediaItem) -> some View {
        let nextEp = nextUpEpisode(for: item)
        HStack(spacing: 5) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.blue)
            Text("Next Up:")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.blue)
            Text(nextEp)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.blue.opacity(0.08))
        .clipShape(Capsule())
    }

    private func nextUpEpisode(for item: MediaItem) -> String {
        let watchedKeys = mediaService.watchedEpisodeKeys(mediaId: item.id)
        if watchedKeys.isEmpty {
            return "S1:E1"
        }

        // Parse all watched episode keys to find the latest
        var maxSeason = 1
        var maxEpisode = 0
        for key in watchedKeys {
            let parsed = parseEpisodeKey(key)
            if parsed.season > maxSeason || (parsed.season == maxSeason && parsed.episode > maxEpisode) {
                maxSeason = parsed.season
                maxEpisode = parsed.episode
            }
        }

        return "S\(maxSeason):E\(maxEpisode + 1)"
    }

    // MARK: - Rating

    private func ratingRow(_ item: MediaItem) -> some View {
        RatingView(item: item, fontSize: 12, starSize: 10)
    }

    // MARK: - Episode Progress Badge

    @ViewBuilder
    private func episodeProgressBadge(_ item: MediaItem) -> some View {
        let watchedCount = mediaService.watchedEpisodeCount(mediaId: item.id)
        let queuedCount = mediaService.queuedEpisodeCount(mediaId: item.id)

        if watchedCount > 0 || queuedCount > 0 {
            HStack(spacing: 8) {
                if watchedCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("\(watchedCount) ep")
                    }
                    .font(.system(size: 10, weight: .medium))
                }
                if queuedCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(.orange)
                        Text("\(queuedCount) ep")
                    }
                    .font(.system(size: 10, weight: .medium))
                }
                if let total = item.totalEpisodes, total > 0 {
                    Text("/ \(total)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Episode Section

    @ViewBuilder
    private func episodeSection(_ item: MediaItem) -> some View {
        let episodeKeys = selectedTab == .queue
            ? mediaService.queuedEpisodeKeys(mediaId: item.id)
            : mediaService.watchedEpisodeKeys(mediaId: item.id)

        if !episodeKeys.isEmpty {
            VStack(spacing: 0) {
                Divider()
                    .padding(.horizontal, 12)

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if expandedItems.contains(item.id) {
                            expandedItems.remove(item.id)
                        } else {
                            expandedItems.insert(item.id)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: selectedTab == .queue ? "bookmark.fill" : "checkmark.circle.fill")
                            .foregroundStyle(selectedTab == .queue ? .orange : .green)
                            .font(.caption)

                        Text("\(episodeKeys.count) episode\(episodeKeys.count == 1 ? "" : "s") \(selectedTab == .queue ? "in queue" : "watched")")
                            .font(.caption.weight(.medium))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(expandedItems.contains(item.id) ? 90 : 0))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expandedItems.contains(item.id) {
                    VStack(spacing: 1) {
                        ForEach(episodeKeys.sorted(), id: \.self) { key in
                            episodeActionRow(item: item, key: key)
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Episode Action Row

    private func episodeActionRow(item: MediaItem, key: String) -> some View {
        let parsed = parseEpisodeKey(key)
        let totalEpisodes = item.totalEpisodes ?? 0

        return HStack(spacing: 10) {
            Image(systemName: "play.rectangle.fill")
                .font(.caption)
                .foregroundStyle(item.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text("Season \(parsed.season), Episode \(parsed.episode)")
                    .font(.caption.weight(.medium))
                Text(key)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if selectedTab == .queue {
                Button {
                    withAnimation(.snappy) {
                        mediaService.markEpisodeWatched(
                            mediaId: item.id,
                            key: key,
                            totalEpisodes: totalEpisodes
                        )
                    }
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.body)
                        .foregroundStyle(.green)
                }

                Button {
                    withAnimation(.snappy) {
                        mediaService.removeEpisodeFromQueue(
                            mediaId: item.id,
                            key: key
                        )
                    }
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    withAnimation(.snappy) {
                        mediaService.toggleEpisodeWatched(
                            mediaId: item.id,
                            key: key,
                            totalEpisodes: totalEpisodes
                        )
                    }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.adaptiveSecondary(colorScheme))
        .clipShape(.rect(cornerRadius: 8))
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
    }

    // MARK: - Action Buttons

    private func actionButtons(_ item: MediaItem) -> some View {
        VStack(spacing: 8) {
            if selectedTab == .queue {
                if item.hasSeasonsAndEpisodes {
                    // For episodic queue items: mark next episode watched
                    Button {
                        withAnimation(.snappy) {
                            let nextKey = nextUpEpisodeKey(for: item)
                            mediaService.markEpisodeWatched(
                                mediaId: item.id,
                                key: nextKey,
                                totalEpisodes: item.totalEpisodes ?? 0
                            )
                        }
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.title3)
                            .foregroundStyle(.green)
                    }
                } else if item.isInQueue {
                    Button {
                        withAnimation(.snappy) { mediaService.markWatched(item) }
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.title3)
                            .foregroundStyle(.green)
                    }
                }

                Button {
                    withAnimation(.snappy) { mediaService.toggleQueue(item) }
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            } else {
                if item.isWatched {
                    Button {
                        withAnimation(.snappy) { mediaService.toggleWatched(item) }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                    }
                }

                Button {
                    withAnimation(.snappy) { mediaService.addToQueue(item) }
                } label: {
                    Image(systemName: "bookmark")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func nextUpEpisodeKey(for item: MediaItem) -> String {
        let watchedKeys = mediaService.watchedEpisodeKeys(mediaId: item.id)
        if watchedKeys.isEmpty {
            return "s1e1"
        }

        var maxSeason = 1
        var maxEpisode = 0
        for key in watchedKeys {
            let parsed = parseEpisodeKey(key)
            if parsed.season > maxSeason || (parsed.season == maxSeason && parsed.episode > maxEpisode) {
                maxSeason = parsed.season
                maxEpisode = parsed.episode
            }
        }
        return "s\(maxSeason)e\(maxEpisode + 1)"
    }

    private func parseEpisodeKey(_ key: String) -> (season: Int, episode: Int) {
        let cleaned = key.lowercased()
        let parts = cleaned.split(separator: "e")
        if parts.count == 2,
           let season = Int(parts[0].dropFirst()),
           let episode = Int(parts[1]) {
            return (season, episode)
        }
        return (0, 0)
    }
}

// MARK: - Shimmer View

struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                stops: [
                    .init(color: .clear, location: phase - 0.3),
                    .init(color: .white.opacity(0.3), location: phase),
                    .init(color: .clear, location: phase + 0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 2
                }
            }
        }
    }
}
