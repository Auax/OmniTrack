import SwiftUI
import SDWebImageSwiftUI

struct DetailEpisodeCard: View {
    let currentItem: MediaItem
    let episode: Episode
    let episodeCardWidth: CGFloat
    let totalEpisodesCount: Int
    let onToggle: () -> Void

    @Environment(MediaService.self) private var mediaService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isWatched = mediaService.isEpisodeWatched(mediaId: currentItem.id, key: episode.episodeKey)

        Button(action: onToggle) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.name.isEmpty ? "Episode \(episode.episodeNumber)" : episode.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.9)

                    Text(episodeMetaLine)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)

                Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(isWatched ? .gray : .white.opacity(0.9))
                    .padding(.bottom, 2)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .frame(width: episodeCardWidth, height: 190, alignment: .bottom)
            .background(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    Color(hex: currentItem.accentColorHex).opacity(0.32)

                    if let url = episode.stillURL {
                        WebImage(url: url) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.black.opacity(0.15)
                        }
                        .transition(.fade(duration: 0.2))
                        .allowsHitTesting(false)
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white.opacity(0.7))
                            Text("S\(episode.seasonNumber), E\(episode.episodeNumber)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(height: 96)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: .black.opacity(0.85), location: 0.4),
                                    .init(color: .black, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.5)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                }
            }
            .clipShape(Squircle(cornerRadius: 24))
            .overlay(
                Squircle(cornerRadius: 24)
                    .stroke(.white.opacity(colorScheme == .dark ? 0.25 : 0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isWatched ? "Unmark episode watched" : "Mark episode watched")
    }

    private var episodeMetaLine: String {
        var parts: [String] = ["S\(episode.seasonNumber), E\(episode.episodeNumber)"]
        if let date = compactEpisodeDate(episode.airDate) {
            parts.append(date)
        }
        if let runtime = episode.formattedRuntime {
            parts.append(runtime)
        }
        return parts.joined(separator: " • ")
    }

    private func compactEpisodeDate(_ rawDate: String?) -> String? {
        guard let rawDate, !rawDate.isEmpty else { return nil }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: rawDate) else { return nil }
        
        let outFormatter = DateFormatter()
        outFormatter.locale = Locale(identifier: "en_US_POSIX")
        outFormatter.dateFormat = "MMM dd yyyy"
        
        return outFormatter.string(from: date)
    }
}
