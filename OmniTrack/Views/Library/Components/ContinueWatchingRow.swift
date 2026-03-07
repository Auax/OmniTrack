import SwiftUI
import SDWebImageSwiftUI

struct ContinueWatchingRow: View {
    let item: MediaItem
    let seriesTitle: String
    let preview: ContinueEpisodePreview
    let previewKey: String
    let nextKey: EpisodeKey?
    let isMarking: Bool
    let onMarkWatched: () -> Void
    let onTask: () async -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var rowMeta: (dateLine: String?, footerLine: String) {
        let parts = preview.metaLine
            .split(separator: "•")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let first = parts.first else {
            return (nil, "")
        }

        let dateLine: String?
        let footerParts: [String]
        if parts.count >= 3 {
            dateLine = parts[1]
            footerParts = [first, parts[2]]
        } else if parts.count == 2 {
            dateLine = nil
            footerParts = [first, parts[1]]
        } else {
            dateLine = nil
            footerParts = [first]
        }

        return (dateLine, footerParts.joined(separator: " • "))
    }

    private var overviewText: String {
        preview.episodeOverview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? item.overview
            : preview.episodeOverview
    }

    private let artworkWidth: CGFloat = 126
    private let artworkSpacing: CGFloat = 12

    var body: some View {
        Button(action: onMarkWatched) {
            VStack(alignment: .leading, spacing: 4) {
                Text(seriesTitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.leading, artworkWidth + artworkSpacing)

                HStack(alignment: .top, spacing: artworkSpacing) {
                    continueEpisodeArtwork

                    VStack(alignment: .leading, spacing: 4) {
                        Text(preview.episodeTitle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        if let dateLine = rowMeta.dateLine {
                            Text(dateLine)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.78))
                                .lineLimit(1)
                        }

                        Text(overviewText)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.64))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)

                        if !rowMeta.footerLine.isEmpty {
                            Text(rowMeta.footerLine)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.64))
                                .lineLimit(1)
                        }

                        if preview.isLastEpisode {
                            Text("Last episode")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.84))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isMarking ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(isMarking ? .white : .white.opacity(0.66))
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .disabled(nextKey == nil || isMarking)
        .task(id: previewKey) {
            await onTask()
        }
    }

    private var continueEpisodeArtwork: some View {
        WebImage(url: preview.imageURL ?? item.backdropURL ?? item.posterURL) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ShimmerView()
        }
        .transition(.fade(duration: 0.2))
        .frame(width: artworkWidth, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(colorScheme == .dark ? 0.12 : 0.22), lineWidth: 1)
        )
    }
}
