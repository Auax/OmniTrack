import Foundation

nonisolated struct TMDBMovieResponse: Codable, Sendable {
    let page: Int
    let results: [TMDBMovie]
    let totalPages: Int
    let totalResults: Int

    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

nonisolated struct TMDBTVResponse: Codable, Sendable {
    let page: Int
    let results: [TMDBTV]
    let totalPages: Int
    let totalResults: Int

    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

nonisolated struct TMDBMovie: Codable, Sendable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    let releaseDate: String?
    let genreIds: [Int]

    enum CodingKeys: String, CodingKey {
        case id, title, overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case releaseDate = "release_date"
        case genreIds = "genre_ids"
    }
}

nonisolated struct TMDBTV: Codable, Sendable {
    let id: Int
    let name: String
    let originalName: String?
    let originalLanguage: String?
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    let firstAirDate: String?
    let genreIds: [Int]

    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case originalName = "original_name"
        case originalLanguage = "original_language"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case firstAirDate = "first_air_date"
        case genreIds = "genre_ids"
    }
}

nonisolated struct TMDBTVDetail: Codable, Sendable {
    let id: Int
    let numberOfEpisodes: Int?
    let numberOfSeasons: Int?
    let seasons: [TMDBSeasonSummary]?

    enum CodingKeys: String, CodingKey {
        case id
        case numberOfEpisodes = "number_of_episodes"
        case numberOfSeasons = "number_of_seasons"
        case seasons
    }
}

nonisolated struct TMDBSeasonSummary: Codable, Sendable {
    let id: Int
    let seasonNumber: Int
    let name: String
    let episodeCount: Int
    let airDate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case seasonNumber = "season_number"
        case name
        case episodeCount = "episode_count"
        case airDate = "air_date"
    }
}

nonisolated struct TMDBSeasonDetail: Codable, Sendable {
    let id: Int
    let seasonNumber: Int
    let name: String
    let episodes: [TMDBEpisodeDetail]

    enum CodingKeys: String, CodingKey {
        case id
        case seasonNumber = "season_number"
        case name, episodes
    }
}

nonisolated struct TMDBEpisodeDetail: Codable, Sendable {
    let id: Int
    let episodeNumber: Int
    let seasonNumber: Int
    let name: String
    let overview: String
    let stillPath: String?
    let airDate: String?
    let runtime: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case name, overview
        case stillPath = "still_path"
        case airDate = "air_date"
        case runtime
    }
}

nonisolated struct TMDBGenreList: Codable, Sendable {
    let genres: [TMDBGenre]
}

nonisolated struct TMDBGenre: Codable, Sendable {
    let id: Int
    let name: String
}

nonisolated final class TMDBService: Sendable {
    private let apiKey: String
    private let baseURL = "https://api.themoviedb.org/3"

    init(apiKey: String = Config.TMDB_API_KEY) {
        self.apiKey = apiKey
    }

    func fetchTrendingMovies(page: Int = 1) async throws -> [TMDBMovie] {
        let url = URL(string: "\(baseURL)/trending/movie/week?api_key=\(apiKey)&language=en-US&page=\(page)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBMovieResponse.self, from: data)
        return response.results
    }

    func fetchPopularMovies(page: Int = 1) async throws -> [TMDBMovie] {
        let url = URL(string: "\(baseURL)/movie/popular?api_key=\(apiKey)&language=en-US&page=\(page)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBMovieResponse.self, from: data)
        return response.results
    }

    func fetchNowPlayingMovies(page: Int = 1) async throws -> [TMDBMovie] {
        let url = URL(string: "\(baseURL)/movie/now_playing?api_key=\(apiKey)&language=en-US&page=\(page)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBMovieResponse.self, from: data)
        return response.results
    }

    func fetchTrendingTV(page: Int = 1) async throws -> [TMDBTV] {
        let url = URL(string: "\(baseURL)/trending/tv/week?api_key=\(apiKey)&language=en-US&page=\(page)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBTVResponse.self, from: data)
        return response.results
    }

    func fetchPopularTV(page: Int = 1) async throws -> [TMDBTV] {
        let url = URL(string: "\(baseURL)/tv/popular?api_key=\(apiKey)&language=en-US&page=\(page)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBTVResponse.self, from: data)
        return response.results
    }

    func fetchOnTheAirTV(page: Int = 1) async throws -> [TMDBTV] {
        let url = URL(string: "\(baseURL)/tv/on_the_air?api_key=\(apiKey)&language=en-US&page=\(page)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBTVResponse.self, from: data)
        return response.results
    }

    func fetchAnime(page: Int = 1) async throws -> [TMDBTV] {
        let url = URL(string: "\(baseURL)/discover/tv?api_key=\(apiKey)&language=en-US&page=\(page)&with_keywords=210024&sort_by=popularity.desc")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBTVResponse.self, from: data)
        return response.results
    }

    func fetchTVDetail(id: Int) async throws -> TMDBTVDetail {
        let url = URL(string: "\(baseURL)/tv/\(id)?api_key=\(apiKey)&language=en-US")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(TMDBTVDetail.self, from: data)
    }

    func fetchSeasonDetail(tvId: Int, seasonNumber: Int) async throws -> TMDBSeasonDetail {
        let url = URL(string: "\(baseURL)/tv/\(tvId)/season/\(seasonNumber)?api_key=\(apiKey)&language=en-US")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(TMDBSeasonDetail.self, from: data)
    }

    func fetchMovieGenres() async throws -> [TMDBGenre] {
        let url = URL(string: "\(baseURL)/genre/movie/list?api_key=\(apiKey)&language=en-US")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBGenreList.self, from: data)
        return response.genres
    }

    func fetchTVGenres() async throws -> [TMDBGenre] {
        let url = URL(string: "\(baseURL)/genre/tv/list?api_key=\(apiKey)&language=en-US")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBGenreList.self, from: data)
        return response.genres
    }

    func searchMovies(query: String, page: Int = 1) async throws -> [TMDBMovie] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "\(baseURL)/search/movie?api_key=\(apiKey)&language=en-US&query=\(encoded)&page=\(page)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBMovieResponse.self, from: data)
        return response.results
    }

    func searchTV(query: String, page: Int = 1) async throws -> [TMDBTV] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "\(baseURL)/search/tv?api_key=\(apiKey)&language=en-US&query=\(encoded)&page=\(page)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBTVResponse.self, from: data)
        return response.results
    }

    func discoverMoviesByGenre(genreId: Int, page: Int = 1) async throws -> [TMDBMovie] {
        let url = URL(string: "\(baseURL)/discover/movie?api_key=\(apiKey)&language=en-US&page=\(page)&with_genres=\(genreId)&sort_by=popularity.desc")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBMovieResponse.self, from: data)
        return response.results
    }

    func discoverTVByGenre(genreId: Int, page: Int = 1) async throws -> [TMDBTV] {
        let url = URL(string: "\(baseURL)/discover/tv?api_key=\(apiKey)&language=en-US&page=\(page)&with_genres=\(genreId)&sort_by=popularity.desc")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBTVResponse.self, from: data)
        return response.results
    }

    // MARK: - IMDB Rating (via TMDB external IDs + OMDB)

    func fetchMovieExternalIds(movieId: Int) async throws -> TMDBExternalIds {
        let url = URL(string: "\(baseURL)/movie/\(movieId)/external_ids?api_key=\(apiKey)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(TMDBExternalIds.self, from: data)
    }

    func fetchTVExternalIds(tvId: Int) async throws -> TMDBExternalIds {
        let url = URL(string: "\(baseURL)/tv/\(tvId)/external_ids?api_key=\(apiKey)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(TMDBExternalIds.self, from: data)
    }

    func fetchImdbRating(imdbId: String) async throws -> Double? {
        // Uses the free OMDB API (no key required for basic info via IMDB ID)
        let url = URL(string: "https://www.omdbapi.com/?i=\(imdbId)&apikey=\(Config.OMDB_API_KEY)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OMDBResponse.self, from: data)
        if let ratingStr = response.imdbRating, let rating = Double(ratingStr) {
            return rating
        }
        return nil
    }
}

nonisolated struct TMDBExternalIds: Codable, Sendable {
    let imdbId: String?

    enum CodingKeys: String, CodingKey {
        case imdbId = "imdb_id"
    }
}

nonisolated struct OMDBResponse: Codable, Sendable {
    let imdbRating: String?

    enum CodingKeys: String, CodingKey {
        case imdbRating
    }
}
