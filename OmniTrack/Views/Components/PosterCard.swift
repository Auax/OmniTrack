import SwiftUI
import SDWebImageSwiftUI

struct PosterCard: View {
    let item: MediaItem
    let width: CGFloat?
    let height: CGFloat?
    let cornerRadius: CGFloat
    
    init(item: MediaItem, width: CGFloat? = nil, height: CGFloat? = nil, cornerRadius: CGFloat = 16) {
        self.item = item
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(item.accentColor.opacity(0.25))

            WebImage(url: item.posterURL ?? item.backdropURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ShimmerView()
            }
            .transition(.fade(duration: 0.2))
        }
        .frame(width: width, height: height)
        .clipShape(Squircle(cornerRadius: cornerRadius))
        .overlay(
            Squircle(cornerRadius: cornerRadius)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
    }
}
