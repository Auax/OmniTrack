import SwiftUI
import SDWebImageSwiftUI

enum LibraryCollectionKind: String, Hashable {
    case watchlist
    case watched

    var title: String {
        switch self {
        case .watchlist: "Watchlist"
        case .watched: "Watched"
        }
    }

    var emptyTitle: String {
        switch self {
        case .watchlist: "Watchlist is Empty"
        case .watched: "Nothing Watched Yet"
        }
    }

    var emptyDescription: String {
        switch self {
        case .watchlist: "Add titles to watchlist and they will appear here."
        case .watched: "Mark titles as watched and they will appear here."
        }
    }

    var emptyIcon: String {
        switch self {
        case .watchlist: "bookmark"
        case .watched: "checkmark.circle"
        }
    }
}

struct LibraryCollectionRoute: Hashable {
    let type: MediaType
    let kind: LibraryCollectionKind

    var typeTitle: String {
        switch type {
        case .movie: "Movies"
        case .tvShow: "Shows"
        case .anime: "Animes"
        }
    }
}

private func libraryBackgroundGradient(_ colorScheme: ColorScheme) -> LinearGradient {
    LinearGradient(
        colors: colorScheme == .dark
        ? [Color(hex: "04101F"), Color(hex: "01050C")]
        : [Color(hex: "EFF4FA"), Color(hex: "E5ECF5")],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct LibraryCollectionPage: View {
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let route: LibraryCollectionRoute

    @State private var selectedItem: MediaItem?

    private var items: [MediaItem] {
        let source: [MediaItem]
        switch route.kind {
        case .watchlist:
            source = mediaService.queueItems.filter { $0.type == route.type && !$0.isWatched }
        case .watched:
            source = mediaService.watchedItems.filter { $0.type == route.type && $0.isWatched }
        }

        return source.sortedForLibrary()
    }

    private var gridColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        ZStack {
            libraryBackgroundGradient(colorScheme)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if items.isEmpty {
                        ContentUnavailableView(
                            route.kind.emptyTitle,
                            systemImage: route.kind.emptyIcon,
                            description: Text(route.kind.emptyDescription)
                        )
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.top, 90)
                    } else if route.kind == .watchlist {
                        LazyVStack(spacing: 12) {
                            ForEach(items) { item in
                                watchlistRow(item)
                            }
                        }
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(items) { item in
                                watchedPoster(item)
                            }
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
                circleToolbarButton(symbol: "chevron.left") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(route.kind.title)
                        .font(.headline)
                    Text(route.typeTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                circleToolbarButton(symbol: "shuffle") {}
                circleToolbarButton(symbol: "ellipsis") {}
            }
        }
        .sheet(item: $selectedItem) { item in
            DetailView(item: item)
        }
    }

    private func watchlistRow(_ item: MediaItem) -> some View {
        Button {
            selectedItem = item
        } label: {
            HStack(alignment: .top, spacing: 14) {
                PosterCard(item: item, width: 86, height: 124, cornerRadius: 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.preferredDisplayTitle(animeTitlePreference: settings.animeTitlePreference))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(formattedReleaseDate(for: item))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)

                    Text(descriptionText(for: item))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.64))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func watchedPoster(_ item: MediaItem) -> some View {
        Button {
            selectedItem = item
        } label: {
            PosterCard(item: item, cornerRadius: 18)
                .frame(maxWidth: .infinity)
                .aspectRatio(0.68, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }

    private func descriptionText(for item: MediaItem) -> String {
        let trimmedOverview = item.overview.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedOverview.isEmpty {
            return trimmedOverview
        }
        return item.subtitle
    }

    private func formattedReleaseDate(for item: MediaItem) -> String {
        if let raw = item.releaseDateString,
           let date = DateFormatter.libraryDateParser.date(from: raw) {
            return DateFormatter.libraryReleaseFormatter.string(from: date)
        }
        if item.year > 0 {
            return String(item.year)
        }
        return "Release date unavailable"
    }

    private func circleToolbarButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
    }
}
