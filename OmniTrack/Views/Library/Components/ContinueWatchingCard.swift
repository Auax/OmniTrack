import SwiftUI
import SDWebImageSwiftUI

struct ContinueWatchingCard: View {
    let item: MediaItem
    let cardWidth: CGFloat
    let preview: ContinueEpisodePreview
    let seriesTitle: String
    let cardMetaLine: String
    let previewKey: String
    let onSelect: () -> Void
    let onTask: () async -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                MediaCard(
                    imageURL: preview.imageURL ?? item.backdropURL ?? item.posterURL,
                    title: preview.episodeTitle,
                    subtitle: cardMetaLine,
                    cardWidth: cardWidth
                )

                Text(seriesTitle)
                    .font(.body.weight(.semibold))
                    .padding(.leading, 12)
                    .lineLimit(1)
            }
            .frame(width: cardWidth, alignment: .leading)
        }
        .buttonStyle(.plain)
        .task(id: previewKey) {
            await onTask()
        }
    }
}
