import Foundation

nonisolated struct AniListTitle: Codable, Sendable {
    let userPreferred: String?
    let english: String?
    let romaji: String?
    let native: String?
}

nonisolated struct AniListCoverImage: Codable, Sendable {
    let large: String?
    let extraLarge: String?
}

nonisolated struct AniListStartDate: Codable, Sendable {
    let year: Int?
}

nonisolated struct AniListAnime: Codable, Sendable {
    let id: Int
    let title: AniListTitle
    let description: String?
    let coverImage: AniListCoverImage?
    let bannerImage: String?
    let averageScore: Int?
    let startDate: AniListStartDate?
    let genres: [String]?
    let episodes: Int?
}

nonisolated struct AniListPageData: Codable, Sendable {
    let media: [AniListAnime]
}

nonisolated struct AniListMediaContainer: Codable, Sendable {
    let page: AniListPageData

    enum CodingKeys: String, CodingKey {
        case page = "Page"
    }
}

nonisolated struct AniListGenresContainer: Codable, Sendable {
    let genreCollection: [String]

    enum CodingKeys: String, CodingKey {
        case genreCollection = "GenreCollection"
    }
}

nonisolated struct AniListGraphQLError: Codable, Sendable {
    let message: String
}

nonisolated struct AniListGraphQLResponse<T: Codable & Sendable>: Codable, Sendable {
    let data: T?
    let errors: [AniListGraphQLError]?
}

nonisolated enum AniListSort: String, Sendable {
    case popularityDesc = "POPULARITY_DESC"
    case trendingDesc = "TRENDING_DESC"
    case startDateDesc = "START_DATE_DESC"
}

nonisolated enum AniListServiceError: Error {
    case invalidResponse
    case graphQLError(String)
}

nonisolated final class AniListService: Sendable {
    private let endpoint = URL(string: "https://graphql.anilist.co")!

    func fetchGenres() async throws -> [String] {
        let query = """
        query {
          GenreCollection
        }
        """

        let payload: AniListGraphQLResponse<AniListGenresContainer> = try await execute(query: query, variables: [:])

        if let message = payload.errors?.first?.message {
            throw AniListServiceError.graphQLError(message)
        }

        guard let genres = payload.data?.genreCollection else {
            throw AniListServiceError.invalidResponse
        }

        return genres
    }

    func fetchPopularAnime(page: Int = 1, perPage: Int = 20, genre: String? = nil) async throws -> [AniListAnime] {
        try await fetchAnime(page: page, perPage: perPage, sort: .popularityDesc, search: nil, genre: genre)
    }

    func fetchTrendingAnime(page: Int = 1, perPage: Int = 20, genre: String? = nil) async throws -> [AniListAnime] {
        try await fetchAnime(page: page, perPage: perPage, sort: .trendingDesc, search: nil, genre: genre)
    }

    func fetchNewAnime(page: Int = 1, perPage: Int = 20, genre: String? = nil) async throws -> [AniListAnime] {
        try await fetchAnime(page: page, perPage: perPage, sort: .startDateDesc, search: nil, genre: genre)
    }

    func searchAnime(query: String, page: Int = 1, perPage: Int = 20, genre: String? = nil) async throws -> [AniListAnime] {
        try await fetchAnime(page: page, perPage: perPage, sort: .popularityDesc, search: query, genre: genre)
    }

    private func fetchAnime(page: Int, perPage: Int, sort: AniListSort, search: String?, genre: String?) async throws -> [AniListAnime] {
        let query = """
        query ($page: Int!, $perPage: Int!, $search: String, $genre: String, $sort: [MediaSort!]) {
          Page(page: $page, perPage: $perPage) {
            media(type: ANIME, isAdult: false, search: $search, genre: $genre, sort: $sort) {
              id
              title {
                userPreferred
                english
                romaji
                native
              }
              description(asHtml: false)
              coverImage {
                large
                extraLarge
              }
              bannerImage
              averageScore
              startDate {
                year
              }
              genres
              episodes
            }
          }
        }
        """

        var variables: [String: Any] = [
            "page": page,
            "perPage": perPage,
            "sort": [sort.rawValue]
        ]

        if let search, !search.isEmpty {
            variables["search"] = search
        }

        if let genre, !genre.isEmpty {
            variables["genre"] = genre
        }

        let payload: AniListGraphQLResponse<AniListMediaContainer> = try await execute(query: query, variables: variables)

        if let message = payload.errors?.first?.message {
            throw AniListServiceError.graphQLError(message)
        }

        guard let media = payload.data?.page.media else {
            throw AniListServiceError.invalidResponse
        }

        return media
    }

    private func execute<T: Codable & Sendable>(query: String, variables: [String: Any]) async throws -> AniListGraphQLResponse<T> {
        let body: [String: Any] = [
            "query": query,
            "variables": variables
        ]

        let payload = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(AniListGraphQLResponse<T>.self, from: data)
    }
}
