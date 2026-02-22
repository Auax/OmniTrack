import SwiftUI

struct ProfileView: View {
    @Environment(MediaService.self) private var mediaService
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedItem: MediaItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader

                    statsGrid

                    if !mediaService.stats.genreBreakdown.isEmpty {
                        GenreDonutChart(slices: mediaService.stats.genreBreakdown)
                    }

                    recentlyWatchedSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(AppTheme.adaptiveBackground(colorScheme))
            .navigationTitle("Profile")
            .sheet(item: $selectedItem) { item in
                DetailView(item: item)
            }
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("My Profile")
                    .font(.title3.bold())

                Text("\(mediaService.watchedItems.count) titles watched")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(AppTheme.adaptiveCardBackground(colorScheme))
        .clipShape(Squircle(cornerRadius: 16))
    }

    private var statsGrid: some View {
        let stats = mediaService.stats
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return LazyVGrid(columns: columns, spacing: 12) {
            StatCardView(
                title: "Watched",
                value: "\(stats.totalWatched)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            StatCardView(
                title: "In Queue",
                value: "\(stats.totalInQueue)",
                icon: "bookmark.fill",
                color: .orange
            )
            StatCardView(
                title: "Movies",
                value: "\(stats.movieCount)",
                icon: "film",
                color: .blue
            )
            StatCardView(
                title: "TV Shows",
                value: "\(stats.tvShowCount)",
                icon: "tv",
                color: .purple
            )
        }
    }

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
                                recentCard(item)
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

    private func recentCard(_ item: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                LinearGradient(
                    colors: [item.accentColor.opacity(0.4), item.accentColor.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Text(item.title)
                    .font(.system(size: 10, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(item.accentColor.opacity(0.25))
                    .padding(4)

                AsyncImage(url: item.posterURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: item.type.icon)
                            .font(.title2)
                            .foregroundStyle(item.accentColor.opacity(0.6))
                    case .empty:
                        ShimmerView()
                    @unknown default:
                        EmptyView()
                    }
                }
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
