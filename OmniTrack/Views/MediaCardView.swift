import SwiftUI
import SDWebImageSwiftUI

struct MediaCardView: View {
    let item: MediaItem
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings
    let onMarkWatched: () -> Void
    let onAddToQueue: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var offset: CGFloat = 0
    @State private var swipeAction: SwipeAction = .none

    private enum SwipeAction {
        case none, watched, queue
    }

    private var swipeThreshold: CGFloat { 100 }

    var body: some View {
        ZStack {
            swipeBackground

            cardContent
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            offset = value.translation.width
                            if value.translation.width > swipeThreshold {
                                swipeAction = .watched
                            } else if value.translation.width < -swipeThreshold {
                                swipeAction = .queue
                            } else {
                                swipeAction = .none
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                if swipeAction == .watched {
                                    onMarkWatched()
                                } else if swipeAction == .queue {
                                    onAddToQueue()
                                }
                                offset = 0
                                swipeAction = .none
                            }
                        }
                )
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: swipeAction)
    }

    private var swipeBackground: some View {
        HStack {
            if offset > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                    Text("Watched")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 24)
                .background(
                    Color.green.opacity(min(1, abs(offset) / swipeThreshold))
                )
            }

            Spacer()

            if offset < 0 {
                HStack(spacing: 8) {
                    Text("Queue")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 24)
                .background(
                    Color.orange.opacity(min(1, abs(offset) / swipeThreshold))
                )
            }
        }
        .clipShape(Squircle(cornerRadius: 16))
    }

    private var cardContent: some View {
        HStack(spacing: 14) {
            posterImage

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: item.type.icon)
                        .font(.caption)
                        .foregroundStyle(item.accentColor)

                    Text(item.type.rawValue.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                }

                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    ratingBadge

                    if item.totalEpisodes != nil {
                        ProgressRingView(
                            progress: item.progress,
                            accentColor: item.accentColor,
                            lineWidth: 3,
                            size: 32
                        )
                    }

                    Spacer()

                    statusIndicator
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(AppTheme.adaptiveCardBackground(colorScheme))
        .clipShape(Squircle(cornerRadius: 16))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.08), radius: 8, y: 4)
    }

    private var posterImage: some View {
        ZStack {
            LinearGradient(
                colors: [item.accentColor.opacity(0.4), item.accentColor.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            WebImage(url: item.posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                if item.posterURL == nil {
                    VStack(spacing: 4) {
                        Image(systemName: item.type.icon)
                            .font(.title)
                            .foregroundStyle(item.accentColor.opacity(0.6))
                    }
                } else {
                    ShimmerView()
                }
            }
            .transition(.fade(duration: 0.2))
            .id(item.posterURL)
            .allowsHitTesting(false)
        }
        .frame(width: 80, height: 112)
        .clipShape(Squircle(cornerRadius: 10))
    }

    private var ratingBadge: some View {
        RatingView(item: item, fontSize: 12, starSize: 10)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }

    private var statusIndicator: some View {
        Group {
            if item.isWatched {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            } else if item.isInQueue {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline)
            }
        }
    }
}
