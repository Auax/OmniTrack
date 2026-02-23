import SwiftUI

/// Reusable rating display that handles skeleton loading when IMDB is selected but not yet fetched.
struct RatingView: View {
    let item: MediaItem
    let fontSize: CGFloat
    let starSize: CGFloat
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings

    init(item: MediaItem, fontSize: CGFloat = 12, starSize: CGFloat = 10) {
        self.item = item
        self.fontSize = fontSize
        self.starSize = starSize
    }

    private var isAniListAnime: Bool {
        item.isAniListAnime
    }

    private var ratingIconName: String {
        "star.fill"
    }

    private var ratingIconColor: Color {
        .yellow
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: ratingIconName)
                .font(.system(size: starSize))
                .foregroundStyle(ratingIconColor)

            if isAniListAnime {
                Text(item.formattedRating)
                    .font(.system(size: fontSize, weight: .semibold))
            } else if settings.ratingProvider == .imdb {
                if let imdb = item.imdbRating {
                    Text(String(format: "%.1f", imdb))
                        .font(.system(size: fontSize, weight: .semibold))
                } else if mediaService.isLoadingImdbRating(item.id) {
                    // Skeleton placeholder
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 26, height: fontSize)
                        .overlay {
                            ShimmerView()
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                } else {
                    // Not loading and no IMDB rating — show dash
                    Text("—")
                        .font(.system(size: fontSize, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text(item.formattedRating)
                    .font(.system(size: fontSize, weight: .semibold))
            }
        }
        .task {
            if !isAniListAnime && settings.ratingProvider == .imdb && item.imdbRating == nil {
                _ = await mediaService.fetchImdbRatingForItem(item)
            }
        }
    }
}
