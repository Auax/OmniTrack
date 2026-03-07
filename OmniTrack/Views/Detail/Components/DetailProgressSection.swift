import SwiftUI

struct DetailProgressSection: View {
    let currentItem: MediaItem
    let totalEpisodesCount: Int
    let tvDetail: TMDBTVDetail?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if totalEpisodesCount > 0 {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    ProgressRingView(
                        progress: Double(currentItem.watchedEpisodes) / Double(max(1, totalEpisodesCount)),
                        accentColor: currentItem.accentColor,
                        lineWidth: 6,
                        size: 64
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        DetailProgressDetailRow(label: "Episodes", value: "\(currentItem.watchedEpisodes)/\(totalEpisodesCount)")
                        if let seasonCount = currentItem.totalSeasons ?? tvDetail?.numberOfSeasons {
                            DetailProgressDetailRow(label: "Seasons", value: "\(seasonCount)")
                        }
                        DetailProgressDetailRow(label: "Remaining", value: "\(totalEpisodesCount - currentItem.watchedEpisodes) eps")
                    }
                }
                .padding(16)
                .background(AppTheme.adaptiveSecondary(colorScheme))
                .clipShape(Squircle(cornerRadius: 14))
            }
        }
    }

}

struct DetailProgressDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
        }
    }
}
