import SwiftUI
import SDWebImageSwiftUI

struct FeaturedCardView: View {
    let item: MediaItem

    var body: some View {
        Color(hex: item.accentColorHex).opacity(0.3)
            .frame(height: 220)
            .overlay {
                WebImage(url: item.backdropURL ?? item.posterURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.clear
                }
                .transition(.fade(duration: 0.2))
                .allowsHitTesting(false)
            }
            .clipShape(Squircle(cornerRadius: 20))
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.3),
                        .init(color: .black.opacity(0.85), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(Squircle(cornerRadius: 20))
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        RatingView(item: item, fontSize: 14, starSize: 11)
                            .foregroundStyle(.white)

                        Text("·")
                            .foregroundStyle(.white.opacity(0.5))

                        Text(String(item.year))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))

                        if let total = item.totalEpisodes {
                            Text("·")
                                .foregroundStyle(.white.opacity(0.5))
                            Text("\(item.watchedEpisodes)/\(total) eps")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                .padding(20)
            }
    }
}
