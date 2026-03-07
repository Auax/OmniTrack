import SwiftUI
import SDWebImageSwiftUI

/// Shared glass-styled media card used across Library and Home.
/// Displays a backdrop image with gradient overlay, title, and optional subtitle.
struct MediaCard: View {
    let imageURL: URL?
    let title: String
    let subtitle: String?
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    init(
        imageURL: URL?,
        title: String,
        subtitle: String? = nil,
        cardWidth: CGFloat,
        cardHeight: CGFloat = 188
    ) {
        self.imageURL = imageURL
        self.title = title
        self.subtitle = subtitle
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            WebImage(url: imageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: cardWidth, height: cardHeight, alignment: .top)
                    .clipped()
            } placeholder: {
                ShimmerView()
                    .frame(width: cardWidth, height: cardHeight)
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
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(Squircle(cornerRadius: 22))
        .overlay(
            Squircle(cornerRadius: 22)
                .stroke(.white.opacity(colorScheme == .dark ? 0.16 : 0.25), lineWidth: 1)
        )
    }
}
