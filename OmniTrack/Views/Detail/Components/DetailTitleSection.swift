import SwiftUI

struct DetailTitleSection: View {
    let item: MediaItem
    let tvDetail: TMDBTVDetail?
    let detailRatingText: String
    let ratingSource: RatingSource

    @Environment(SettingsManager.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.preferredDisplayTitle(animeTitlePreference: settings.animeTitlePreference))
                .font(.largeTitle.bold())

            HStack(spacing: 16) {
                providerRatingBlock

                if item.year > 0 {
                    Text(String(item.year))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let seasonCount = item.totalSeasons ?? tvDetail?.numberOfSeasons {
                    Text("\(seasonCount) Season\(seasonCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var providerRatingBlock: some View {
        HStack(spacing: 6) {
            ratingSourceIcon
                .frame(width: 20, height: 20)
            Text(detailRatingText)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
        }
        .accessibilityLabel("Rating source: \(ratingSource.label)")
    }

    @ViewBuilder
    private var ratingSourceIcon: some View {
        switch ratingSource {
        case .tmdb:
            Image(systemName: "star.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.yellow)
        case .imdb, .aniList:
            #if canImport(UIKit)
            if let image = UIImage(named: ratingSource.assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                Image(systemName: ratingSource.fallbackSymbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ratingSource.tint)
            }
            #else
            Image(systemName: ratingSource.fallbackSymbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(ratingSource.tint)
            #endif
        }
    }
}
