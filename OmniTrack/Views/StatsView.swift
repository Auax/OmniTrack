import SwiftUI
import SDWebImageSwiftUI

struct StatsView: View {
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedItem: MediaItem?
    @State private var drillDownType: DrillDownType?
    @State private var showSettings: Bool = false

    enum DrillDownType: Hashable, Identifiable {
        case watched
        case queue
        case moviesWatched
        case moviesQueue
        case tvWatched
        case tvQueue
        case animeWatched
        case animeQueue

        var id: Int { hashValue }

        var title: String {
            switch self {
            case .watched: "All Watched"
            case .queue: "Full Queue"
            case .moviesWatched: "Movies Watched"
            case .moviesQueue: "Movies in Queue"
            case .tvWatched: "TV Shows Watched"
            case .tvQueue: "TV Shows in Queue"
            case .animeWatched: "Anime Watched"
            case .animeQueue: "Anime in Queue"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Top-level summary
                    summaryCards

                    // Category breakdowns
                    categoryBreakdowns

                    // Genre chart
                    if !mediaService.stats.genreBreakdown.isEmpty {
                        GenreDonutChart(slices: mediaService.stats.genreBreakdown)
                    }

                    // Recently watched
                    recentlyWatchedSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(AppTheme.adaptiveBackground(colorScheme))
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .accessibilityLabel("Open Settings")
                }
            }
            .sheet(item: $selectedItem) { item in
                DetailView(item: item)
            }
            .sheet(item: $drillDownType) { type in
                DrillDownListView(type: type)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        let stats = mediaService.stats
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return LazyVGrid(columns: columns, spacing: 12) {
            Button { drillDownType = .watched } label: {
                StatCardView(
                    title: "Watched",
                    value: "\(stats.totalWatched)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }
            .buttonStyle(.plain)

            Button { drillDownType = .queue } label: {
                StatCardView(
                    title: "In Queue",
                    value: "\(stats.totalInQueue)",
                    icon: "bookmark.fill",
                    color: .orange
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Category Breakdowns

    private var categoryBreakdowns: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.secondary)
                Text("By Category")
                    .font(.headline)
                Spacer()
            }

            StatCategoryRow(
                icon: "film",
                label: "Movies",
                color: .blue,
                watchedCount: mediaService.watchedItems.filter { $0.type == .movie }.count,
                queueCount: mediaService.queueItems.filter { $0.type == .movie }.count,
                onWatched: { drillDownType = .moviesWatched },
                onQueue: { drillDownType = .moviesQueue },
                colorScheme: colorScheme
            )

            StatCategoryRow(
                icon: "tv",
                label: "TV Shows",
                color: .purple,
                watchedCount: mediaService.watchedItems.filter { $0.type == .tvShow }.count,
                queueCount: mediaService.queueItems.filter { $0.type == .tvShow }.count,
                onWatched: { drillDownType = .tvWatched },
                onQueue: { drillDownType = .tvQueue },
                colorScheme: colorScheme
            )

            StatCategoryRow(
                icon: "sparkles.tv",
                label: "Anime",
                color: .pink,
                watchedCount: mediaService.watchedItems.filter { $0.type == .anime }.count,
                queueCount: mediaService.queueItems.filter { $0.type == .anime }.count,
                onWatched: { drillDownType = .animeWatched },
                onQueue: { drillDownType = .animeQueue },
                colorScheme: colorScheme
            )
        }
    }



    // MARK: - Recently Watched

    private var recentlyWatchedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                Text("Recently Watched")
                    .font(.headline)
                Spacer()
            }

            if mediaService.watchedItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "film")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("No watched titles yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(mediaService.watchedItems.prefix(8)) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                StatRecentCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .contentMargins(.horizontal, 0)
                .scrollIndicators(.hidden)
            }
        }
        .padding(.bottom, 20)
    }


}

// MARK: - Drill-Down List

struct DrillDownListView: View {
    let type: StatsView.DrillDownType
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: MediaItem?
    @State private var filterType: MediaType? = nil

    private var items: [MediaItem] {
        var base: [MediaItem]

        switch type {
        case .watched:
            base = mediaService.watchedItems
        case .queue:
            base = mediaService.queueItems
        case .moviesWatched:
            base = mediaService.watchedItems.filter { $0.type == .movie }
        case .moviesQueue:
            base = mediaService.queueItems.filter { $0.type == .movie }
        case .tvWatched:
            base = mediaService.watchedItems.filter { $0.type == .tvShow }
        case .tvQueue:
            base = mediaService.queueItems.filter { $0.type == .tvShow }
        case .animeWatched:
            base = mediaService.watchedItems.filter { $0.type == .anime }
        case .animeQueue:
            base = mediaService.queueItems.filter { $0.type == .anime }
        }

        // Apply sub-filter for the "All" drill-downs
        if let ft = filterType {
            base = base.filter { $0.type == ft }
        }

        return base.sorted { $0.effectiveRating(for: settings.ratingProvider) > $1.effectiveRating(for: settings.ratingProvider) }
    }

    private var showTypeFilter: Bool {
        type == .watched || type == .queue
    }

    private var availableTypes: [MediaType] {
        let types = Set(items.map { $0.type })
        return [.movie, .tvShow, .anime].filter { types.contains($0) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showTypeFilter && availableTypes.count > 1 {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            StatFilterChip(type: nil, label: "All", filterType: $filterType)
                            ForEach(availableTypes) { t in
                                StatFilterChip(type: t, label: t.rawValue, filterType: $filterType)
                            }
                        }
                    }
                    .contentMargins(.horizontal, 16)
                    .scrollIndicators(.hidden)
                    .padding(.vertical, 8)
                }

                if items.isEmpty {
                    ContentUnavailableView(
                        "Nothing here yet",
                        systemImage: "tray",
                        description: Text("Items will appear as you add them.")
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    List(items) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            StatDrillDownRow(item: item)
                        }
                        .listRowBackground(AppTheme.adaptiveCardBackground(colorScheme))
                    }
                    .listStyle(.plain)
                }
            }
            .background(AppTheme.adaptiveBackground(colorScheme))
            .navigationTitle(type.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedItem) { item in
                DetailView(item: item)
            }
        }
    }


}

private struct StatCategoryRow: View {
    let icon: String
    let label: String
    let color: Color
    let watchedCount: Int
    let queueCount: Int
    let onWatched: () -> Void
    let onQueue: () -> Void
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            Text(label)
                .font(.subheadline.weight(.semibold))

            Spacer()

            // Watched pill
            Button(action: onWatched) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text("\(watchedCount)")
                        .font(.caption.weight(.bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.green.opacity(0.1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // Queue pill
            Button(action: onQueue) {
                HStack(spacing: 4) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text("\(queueCount)")
                        .font(.caption.weight(.bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(AppTheme.adaptiveCardBackground(colorScheme))
        .clipShape(Squircle(cornerRadius: 14))
    }
}

private struct StatRecentCard: View {
    let item: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                LinearGradient(
                    colors: [item.accentColor.opacity(0.4), item.accentColor.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                WebImage(url: item.posterURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    if item.posterURL == nil {
                        Image(systemName: item.type.icon)
                            .font(.title2)
                            .foregroundStyle(item.accentColor.opacity(0.6))
                    } else {
                        ShimmerView()
                    }
                }
                .transition(.fade(duration: 0.2))
                .id(item.posterURL)
                .allowsHitTesting(false)
            }
            .frame(width: 110, height: 160)
            .clipShape(Squircle(cornerRadius: 10))

            Text(item.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .frame(width: 110, alignment: .leading)
        }
    }
}

private struct StatFilterChip: View {
    let type: MediaType?
    let label: String
    @Binding var filterType: MediaType?

    var body: some View {
        let isSelected = filterType == type
        Button {
            withAnimation(.snappy) { filterType = type }
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color.primary.opacity(0.12) : Color.clear)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.primary.opacity(isSelected ? 0 : 0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct StatDrillDownRow: View {
    let item: MediaItem
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        HStack(spacing: 12) {
            // Poster
            ZStack {
                LinearGradient(
                    colors: [item.accentColor.opacity(0.4), item.accentColor.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                WebImage(url: item.posterURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    if item.posterURL == nil {
                        Image(systemName: item.type.icon)
                            .font(.caption)
                            .foregroundStyle(item.accentColor.opacity(0.6))
                    } else {
                        ShimmerView()
                    }
                }
                .transition(.fade(duration: 0.2))
                .id(item.posterURL)
                .allowsHitTesting(false)
            }
            .frame(width: 44, height: 64)
            .clipShape(Squircle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    HStack(spacing: 2) {
                        Image(systemName: ratingIcon(for: item))
                            .font(.system(size: 9))
                            .foregroundStyle(ratingIconColor(for: item))
                        Text(displayRating(for: item))
                            .font(.caption2.weight(.medium))
                    }

                    if item.year > 0 {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(String(item.year))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(item.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: item.type.icon)
                .font(.caption)
                .foregroundStyle(item.accentColor)
        }
    }

    private func displayRating(for item: MediaItem) -> String {
        if item.isAniListAnime {
            return item.formattedRating
        }
        if settings.ratingProvider == .imdb, let imdb = item.imdbRating {
            return String(format: "%.1f", imdb)
        }
        return item.formattedRating
    }

    private func ratingIcon(for item: MediaItem) -> String {
        "star.fill"
    }

    private func ratingIconColor(for item: MediaItem) -> Color {
        .yellow
    }
}
