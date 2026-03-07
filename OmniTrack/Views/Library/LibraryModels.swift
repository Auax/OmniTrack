import Foundation

struct ContinueEpisodePreview: Equatable {
    let episodeTitle: String
    let episodeOverview: String
    let metaLine: String
    let imageURL: URL?
    let isLastEpisode: Bool
}

struct ContinueEpisodeTarget: Equatable {
    let episode: EpisodeKey
    let totalEpisodes: Int
    let isLastEpisode: Bool
}
