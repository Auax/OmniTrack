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
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .bottomLeading) {
                    WebImage(url: preview.imageURL ?? item.backdropURL ?? item.posterURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: cardWidth, height: 188, alignment: .top)
                            .clipped()
                    } placeholder: {
                        ShimmerView()
                            .frame(width: cardWidth, height: 188)
                    }
                    .transition(.fade(duration: 0.2))

                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(height: 92)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: .black.opacity(0.70), location: 0.45),
                                    .init(color: .black, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(maxHeight: .infinity, alignment: .bottom)

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.44)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(preview.episodeTitle)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(cardMetaLine)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .frame(width: cardWidth, height: 188)
                .clipShape(Squircle(cornerRadius: 22))
                .overlay(
                    Squircle(cornerRadius: 22)
                        .stroke(.white.opacity(colorScheme == .dark ? 0.16 : 0.25), lineWidth: 1)
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
