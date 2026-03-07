import SwiftUI
import SDWebImageSwiftUI

struct DetailHeroSection: View {
    let item: MediaItem
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Color(hex: item.accentColorHex).opacity(0.3)
            .frame(height: 300)
            .overlay {
                WebImage(url: item.backdropURL ?? item.posterURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.clear
                }
                .transition(.fade(duration: 0.2))
                .allowsHitTesting(false)
            }
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.4),
                        .init(color: AppTheme.adaptiveBackground(colorScheme), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
    }
}
