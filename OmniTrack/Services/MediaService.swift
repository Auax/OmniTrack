import Foundation

@MainActor
@Observable
class MediaService {
    static let aniListAnimeIdOffset: Int = 1_000_000_000
    static let aniListMergedSeriesIdOffset: Int = 1_500_000_000

    var allMedia: [MediaItem] = []
    var featuredMovies: [MediaItem] = []
    var featuredTVShows: [MediaItem] = []
    var featuredAnime: [MediaItem] = []
    var searchResults: [MediaItem] = []
    var isLoading: Bool = false
    var isSearching: Bool = false
    var errorMessage: String?
    var genreMedia: [MediaItem] = []
    var isLoadingGenre: Bool = false
    
    // MARK: - Discover State
    var discoverMedia: [MediaItem] = []
    var isDiscoverLoading: Bool = false
    var currentDiscoverPage: Int = 1
    var hasMoreDiscover: Bool = true
    
    var isLoadingMore: Bool = false
    private var currentMoviePage: Int = 1
    private var currentTVPage: Int = 1
    private var currentAnimePage: Int = 1
    private var hasMoreMovies: Bool = true
    private var hasMoreTV: Bool = true
    private var hasMoreAnime: Bool = true

    private let tmdbService = TMDBService()
    private let aniListService = AniListService()
    private let aniListGenreBaseId: Int = 1_000_000
    private var aniListGenreIdMap: [String: Int] = [:]
    var genreMap: [Int: String] = [:]
    private var watchedIds: Set<Int> = []
    private var inProgressIds: Set<Int> = []
    private var queueIds: Set<Int> = []
    private var watchedAddedOrder: [Int] = []
    private var queueAddedOrder: [Int] = []
    private var inProgressUpdatedOrder: [Int] = []
    var episodeWatchedMap: [Int: Set<String>] = [:]
    var episodeQueueMap: [Int: Set<String>] = [:]
    private var genreMediaCache: [String: (items: [MediaItem], date: Date)] = [:]
    private var watchedDates: [String] = [] // ISO date strings when items were watched
    init() {
        loadUserData()
        loadEpisodeData()
        loadWatchedDates()
    }

    // MARK: - Computed Collections

    var featuredAll: [MediaItem] {
        let combined = (featuredMovies + featuredTVShows + featuredAnime)
            .sorted { $0.rating > $1.rating }
        // Take top items interleaved for variety
        var seen = Set<Int>()
        var result: [MediaItem] = []
        for item in combined {
            if !seen.contains(item.id) {
                seen.insert(item.id)
                result.append(item)
                if result.count >= 8 { break }
            }
        }
        return result
    }

    var queueItems: [MediaItem] {
        let episodeQueued = allMedia.filter { item in
            !(episodeQueueMap[item.id]?.isEmpty ?? true) && !item.isInQueue
        }
        let directQueue = allMedia.filter { $0.isInQueue }
        let combined = directQueue + episodeQueued.filter { item in
            !directQueue.contains(where: { $0.id == item.id })
        }
        return combined
    }

    var watchedItems: [MediaItem] {
        let episodeWatched = allMedia.filter { item in
            !(episodeWatchedMap[item.id]?.isEmpty ?? true) && !item.isWatched
        }
        let directWatched = allMedia.filter { $0.isWatched }
        let combined = directWatched + episodeWatched.filter { item in
            !directWatched.contains(where: { $0.id == item.id })
        }
        return combined
    }

    var inProgressItems: [MediaItem] {
        allMedia.filter { $0.isInProgress && !$0.isWatched }
    }

    func inProgressItemsSortedByRecentUpdate() -> [MediaItem] {
        var ordered: [MediaItem] = []
        var seen: Set<Int> = []

        for id in inProgressUpdatedOrder.reversed() {
            guard !seen.contains(id) else { continue }
            guard let item = allMedia.first(where: { $0.id == id }) else { continue }
            guard item.isInProgress, !item.isWatched else { continue }
            seen.insert(id)
            ordered.append(item)
        }

        let fallback = inProgressItems
            .filter { !seen.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.hasSeasonsAndEpisodes != rhs.hasSeasonsAndEpisodes {
                    return lhs.hasSeasonsAndEpisodes
                }
                let lhsCount = watchedEpisodeCount(mediaId: lhs.id)
                let rhsCount = watchedEpisodeCount(mediaId: rhs.id)
                if lhsCount != rhsCount {
                    return lhsCount > rhsCount
                }
                if lhs.year != rhs.year {
                    return lhs.year > rhs.year
                }
                return lhs.title.localizedCompare(rhs.title) == .orderedAscending
            }

        return ordered + fallback
    }

    func recentQueueItems(type: MediaType, limit: Int) -> [MediaItem] {
        let ordered = recentItems(
            from: queueAddedOrder,
            type: type,
            limit: limit
        ) { item in
            !item.isWatched && (item.isInQueue || !(episodeQueueMap[item.id]?.isEmpty ?? true))
        }

        if ordered.count >= limit {
            return ordered
        }

        let seenIds = Set(ordered.map(\.id))
        let fallback = Array(
            queueItems
                .filter { $0.type == type && !$0.isWatched && !seenIds.contains($0.id) }
                .suffix(max(0, limit - ordered.count))
                .reversed()
        )

        return ordered + fallback
    }

    func recentWatchedItems(type: MediaType, limit: Int) -> [MediaItem] {
        let ordered = recentItems(
            from: watchedAddedOrder,
            type: type,
            limit: limit
        ) { item in
            item.isWatched
        }

        if ordered.count >= limit {
            return ordered
        }

        let seenIds = Set(ordered.map(\.id))
        let fallback = Array(
            watchedItems
                .filter { $0.type == type && $0.isWatched && !seenIds.contains($0.id) }
                .suffix(max(0, limit - ordered.count))
                .reversed()
        )

        return ordered + fallback
    }

    var stats: ViewingStats {
        let watched = watchedItems
        let queued = queueItems
        let genreCounts = watched.reduce(into: [String: Int]()) { result, item in
            for genre in item.genres {
                result[genre, default: 0] += 1
            }
        }
        let genreColors = ["E63946", "457B9D", "2A9D8F", "E9C46A", "6A0572", "C4A035", "D4572A", "8B2C2C"]
        let genreSlices = genreCounts.sorted { $0.value > $1.value }.prefix(5).enumerated().map { index, entry in
            GenreSlice(name: entry.key, count: entry.value, color: genreColors[index % genreColors.count])
        }
        return ViewingStats(
            totalWatched: watched.count,
            totalInQueue: queued.count,
            movieCount: watched.filter { $0.type == .movie }.count,
            tvShowCount: watched.filter { $0.type == .tvShow }.count,
            animeCount: watched.filter { $0.type == .anime }.count,
            hoursWatched: Double(watched.count) * 2.1,
            weeklyActivity: computeWeeklyActivity(),
            genreBreakdown: genreSlices
        )
    }

    private func aniListGenreId(for name: String) -> Int {
        if let existing = aniListGenreIdMap[name] {
            return existing
        }

        let nextId = aniListGenreBaseId + aniListGenreIdMap.count + 1
        aniListGenreIdMap[name] = nextId
        genreMap[nextId] = name
        return nextId
    }

    private func ensureAniListGenresLoaded() async {
        guard aniListGenreIdMap.isEmpty else { return }
        guard let genres = try? await aniListService.fetchGenres() else { return }
        for genre in genres {
            _ = aniListGenreId(for: genre)
        }
    }

    private func genreName(for id: Int?) -> String? {
        guard let id else { return nil }
        return genreMap[id]
    }

    func discoverGenreNames(includeAniListGenres: Bool) -> [String] {
        let filteredGenres = genreMap.filter { key, _ in
            includeAniListGenres || key < aniListGenreBaseId
        }
        return Array(Set(filteredGenres.values)).sorted()
    }

    private func tmdbGenreId(from id: Int?) -> Int? {
        guard let id, id < aniListGenreBaseId else { return nil }
        return id
    }

    private func isLikelyAnimeTV(_ tv: TMDBTV) -> Bool {
        guard tv.genreIds.contains(16) else { return false }
        if tv.originalLanguage?.lowercased() == "ja" {
            return true
        }
        let combinedTitle = "\(tv.name) \(tv.originalName ?? "")"
        return containsJapaneseCharacters(in: combinedTitle)
    }

    private func filterTVShowsExcludingAnime(_ shows: [TMDBTV]) -> [TMDBTV] {
        shows.filter { !isLikelyAnimeTV($0) }
    }

    private func filterAnimeTVShows(_ shows: [TMDBTV]) -> [TMDBTV] {
        shows.filter { isLikelyAnimeTV($0) }
    }

    private func containsJapaneseCharacters(in text: String) -> Bool {
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x3040...0x30FF, 0x31F0...0x31FF, 0x3400...0x4DBF, 0x4E00...0x9FFF:
                return true
            default:
                continue
            }
        }
        return false
    }

    private var animeTitlePreference: AnimeTitlePreference {
        let raw = UserDefaults.standard.string(forKey: "animeTitlePreference") ?? AnimeTitlePreference.romaji.rawValue
        return AnimeTitlePreference(rawValue: raw) ?? .romaji
    }

    private var animeSource: AnimeSource {
        let raw = UserDefaults.standard.string(forKey: "animeSource") ?? AnimeSource.aniList.rawValue
        return AnimeSource(rawValue: raw) ?? .aniList
    }

    private var usesAniListAnimeSource: Bool {
        animeSource == .aniList
    }

    private func mapTmdbAnimeCollection(_ animeShows: [TMDBTV]) -> [MediaItem] {
        animeShows.map { mapTV($0, type: .anime) }
    }

    private func fetchTmdbAnime(page: Int, catalog: DiscoverCatalog, genreId: Int? = nil) async throws -> [TMDBTV] {
        switch catalog {
        case .popular:
            return try await tmdbService.fetchAnime(page: page, sortBy: "popularity.desc", genreId: genreId)
        case .new:
            return try await tmdbService.fetchAnime(page: page, sortBy: "first_air_date.desc", genreId: genreId)
        case .featured:
            return try await tmdbService.fetchAnime(page: page, sortBy: "vote_average.desc", genreId: genreId)
        }
    }

    private func canonicalAniListTitle(_ anime: AniListAnime) -> String {
        anime.title.english
            ?? anime.title.romaji
            ?? anime.title.userPreferred
            ?? anime.title.native
            ?? "Unknown Anime"
    }

    private func displayAniListTitle(_ anime: AniListAnime) -> String {
        switch animeTitlePreference {
        case .romaji:
            return anime.title.romaji
                ?? anime.title.userPreferred
                ?? anime.title.english
                ?? anime.title.native
                ?? "Unknown Anime"
        case .translated:
            return anime.title.english
                ?? anime.title.userPreferred
                ?? anime.title.romaji
                ?? anime.title.native
                ?? "Unknown Anime"
        }
    }

    private func preferredAniListTitle(
        in entries: [AniListAnime],
        selector: (AniListTitle) -> String?
    ) -> String? {
        let candidates = entries
            .compactMap { selector($0.title)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return candidates.first(where: { !isSeasonTaggedAniListTitle($0) }) ?? candidates.first
    }

    private func normalizedAniListSeriesKey(from title: String) -> String {
        var normalized = title.lowercased()
        normalized = normalized.replacingOccurrences(of: "\\([^\\)]*\\)", with: " ", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "\\[[^\\]]*\\]", with: " ", options: .regularExpression)

        let cleanupPatterns = [
            "\\bseason\\s*\\d+\\b",
            "\\b\\d+(st|nd|rd|th)\\s+season\\b",
            "\\bpart\\s*\\d+\\b",
            "\\bcour\\s*\\d+\\b",
            "\\bfinal\\s+season\\b",
            "\\bfinal\\b"
        ]

        for pattern in cleanupPatterns {
            normalized = normalized.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }

        normalized = normalized.replacingOccurrences(of: "\\b(ii|iii|iv|v|vi|vii|viii|ix|x)\\b$", with: " ", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "\\b\\d+\\b$", with: " ", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "[\\-_:~]", with: " ", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.isEmpty ? title.lowercased() : normalized
    }

    private func isSeasonTaggedAniListTitle(_ title: String) -> Bool {
        let pattern = "(?i)\\b(season\\s*\\d+|\\d+(st|nd|rd|th)\\s+season|part\\s*\\d+|cour\\s*\\d+|final\\s+season)\\b"
        return title.range(of: pattern, options: .regularExpression) != nil
    }

    private func stableSeriesHash(for key: String) -> Int {
        var hash: UInt64 = 1469598103934665603
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return Int(hash % 400_000_000)
    }

    private func cleanedAniListDescription(_ raw: String?) -> String {
        guard var text = raw, !text.isEmpty else { return "" }

        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        let entities: [String: String] = [
            "&amp;": "&",
            "&quot;": "\"",
            "&#39;": "'",
            "&lt;": "<",
            "&gt;": ">",
            "&nbsp;": " "
        ]

        for (entity, value) in entities {
            text = text.replacingOccurrences(of: entity, with: value)
        }

        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func mapAniListAnimeCollection(_ animeList: [AniListAnime]) -> [MediaItem] {
        guard !animeList.isEmpty else { return [] }

        let indexed = Array(animeList.enumerated())
        let grouped = Dictionary(grouping: indexed) { pair in
            normalizedAniListSeriesKey(from: canonicalAniListTitle(pair.element))
        }

        let mapped: [(index: Int, item: MediaItem)] = grouped.map { seriesKey, entries in
            let sortedEntries = entries.sorted { $0.offset < $1.offset }
            let animeEntries = sortedEntries.map(\.element)
            let firstIndex = sortedEntries.first?.offset ?? Int.max
            return (firstIndex, mapAniListSeries(entries: animeEntries, seriesKey: seriesKey))
        }

        return mapped
            .sorted { $0.index < $1.index }
            .map(\.item)
    }

    private func mapAniListSeries(entries: [AniListAnime], seriesKey: String) -> MediaItem {
        let dedupedEntries = Array(Dictionary(grouping: entries, by: \.id).compactMapValues(\.first).values)
        let sortedEntries = dedupedEntries.sorted { lhs, rhs in
            let lhsYear = lhs.startDate?.year ?? Int.max
            let rhsYear = rhs.startDate?.year ?? Int.max
            if lhsYear != rhsYear {
                return lhsYear < rhsYear
            }
            return canonicalAniListTitle(lhs) < canonicalAniListTitle(rhs)
        }

        let representative = sortedEntries.first ?? entries[0]

        let preferredRomajiTitle = preferredAniListTitle(in: sortedEntries) { $0.romaji }
            ?? preferredAniListTitle(in: sortedEntries) { $0.userPreferred }
            ?? preferredAniListTitle(in: sortedEntries) { $0.native }

        let preferredEnglishTitle = preferredAniListTitle(in: sortedEntries) { $0.english }
            ?? preferredAniListTitle(in: sortedEntries) { $0.userPreferred }
            ?? preferredAniListTitle(in: sortedEntries) { $0.native }

        let preferredTitle: String
        switch animeTitlePreference {
        case .romaji:
            preferredTitle = preferredRomajiTitle ?? preferredEnglishTitle ?? displayAniListTitle(representative)
        case .translated:
            preferredTitle = preferredEnglishTitle ?? preferredRomajiTitle ?? displayAniListTitle(representative)
        }

        let allGenres = Set(dedupedEntries.flatMap { $0.genres ?? [] })
        let genres = allGenres.sorted()
        let genreIds = genres.map { aniListGenreId(for: $0) }
        let genreSummary = genres.prefix(2).joined(separator: ", ")

        let years = dedupedEntries.compactMap { $0.startDate?.year }.filter { $0 > 0 }
        let year = years.min() ?? 0
        let subtitleParts: [String] = [
            year > 0 ? String(year) : "",
            genreSummary
        ].filter { !$0.isEmpty }

        let ratings = dedupedEntries.compactMap { anime -> Double? in
            guard let score = anime.averageScore, score > 0 else { return nil }
            return Double(score) / 10.0
        }
        let averageRating = ratings.isEmpty
            ? Double(representative.averageScore ?? 0) / 10.0
            : ratings.reduce(0, +) / Double(ratings.count)

        let cleanedDescriptions = dedupedEntries
            .map { cleanedAniListDescription($0.description) }
            .filter { !$0.isEmpty }
        let overview = cleanedDescriptions.max(by: { $0.count < $1.count }) ?? ""

        let totalEpisodesCount = dedupedEntries.compactMap(\.episodes).reduce(0, +)
        let totalEpisodes = totalEpisodesCount > 0 ? totalEpisodesCount : nil
        let totalSeasons = max(1, dedupedEntries.count)

        let posterPath = sortedEntries.compactMap { anime in
            anime.coverImage?.extraLarge ?? anime.coverImage?.large
        }.first
        let backdropPath = sortedEntries.compactMap(\.bannerImage).first

        let mergedId = Self.aniListMergedSeriesIdOffset + stableSeriesHash(for: seriesKey)

        return MediaItem(
            id: mergedId,
            title: preferredTitle,
            subtitle: subtitleParts.isEmpty ? "Anime" : subtitleParts.joined(separator: " · "),
            overview: overview,
            type: .anime,
            posterPath: posterPath,
            backdropPath: backdropPath,
            rating: averageRating,
            year: year,
            releaseDateString: year > 0 ? "\(year)-01-01" : nil,
            genres: genres,
            totalEpisodes: totalEpisodes,
            watchedEpisodes: 0,
            totalSeasons: totalSeasons,
            isWatched: false,
            isInQueue: false,
            genreIds: genreIds,
            imdbRating: nil,
            animeRomajiTitle: preferredRomajiTitle,
            animeEnglishTitle: preferredEnglishTitle
        )
    }

    // MARK: - Content Loading

    func loadContent(showMovies: Bool, showTVShows: Bool, showAnime: Bool) async {
        isLoading = true
        errorMessage = nil

        currentMoviePage = 1
        currentTVPage = 1
        currentAnimePage = 1
        hasMoreMovies = true
        hasMoreTV = true
        hasMoreAnime = true

        do {
            if genreMap.isEmpty {
                async let movieGenres = tmdbService.fetchMovieGenres()
                async let tvGenres = tmdbService.fetchTVGenres()
                let (mg, tg) = try await (movieGenres, tvGenres)
                for g in mg { genreMap[g.id] = g.name }
                for g in tg { genreMap[g.id] = g.name }
            }

            if showAnime && usesAniListAnimeSource {
                await ensureAniListGenresLoaded()
            }

            var items: [MediaItem] = []
            var fMovies: [MediaItem] = []
            var fTV: [MediaItem] = []
            var fAnime: [MediaItem] = []

            if showMovies {
                async let trending = tmdbService.fetchTrendingMovies()
                async let popular = tmdbService.fetchPopularMovies()
                let (trendingMovies, popularMovies) = try await (trending, popular)
                fMovies = trendingMovies.prefix(5).map { mapMovie($0) }
                items.append(contentsOf: popularMovies.map { mapMovie($0) })
            }

            if showTVShows {
                async let trending = tmdbService.fetchTrendingTV()
                async let popular = tmdbService.fetchPopularTV()
                let (trendingTV, popularTV) = try await (trending, popular)
                let trendingTVShows = filterTVShowsExcludingAnime(trendingTV)
                let popularTVShows = filterTVShowsExcludingAnime(popularTV)
                fTV = trendingTVShows.prefix(5).map { mapTV($0, type: .tvShow) }
                items.append(contentsOf: popularTVShows.map { mapTV($0, type: .tvShow) })
            }

            if showAnime {
                do {
                    if usesAniListAnimeSource {
                        async let trendingAnime = aniListService.fetchTrendingAnime()
                        async let popularAnime = aniListService.fetchPopularAnime()
                        let (trendingList, popularList) = try await (trendingAnime, popularAnime)
                        fAnime = Array(mapAniListAnimeCollection(trendingList).prefix(5))
                        items.append(contentsOf: mapAniListAnimeCollection(popularList))
                    } else {
                        async let featuredAnimeList = fetchTmdbAnime(page: 1, catalog: .featured)
                        async let popularAnimeList = fetchTmdbAnime(page: 1, catalog: .popular)
                        let (featuredList, popularList) = try await (featuredAnimeList, popularAnimeList)
                        fAnime = Array(mapTmdbAnimeCollection(featuredList).prefix(5))
                        items.append(contentsOf: mapTmdbAnimeCollection(popularList))
                    }
                } catch {
                    fAnime = []
                }
            }

            let uniqueItems = Dictionary(grouping: items, by: \.id).compactMapValues(\.first).values
            allMedia = Array(uniqueItems).sorted { $0.rating > $1.rating }

            featuredMovies = Dictionary(grouping: fMovies, by: \.id).compactMapValues(\.first).values.sorted { $0.rating > $1.rating }
            featuredTVShows = Dictionary(grouping: fTV, by: \.id).compactMapValues(\.first).values.sorted { $0.rating > $1.rating }
            featuredAnime = Dictionary(grouping: fAnime, by: \.id).compactMapValues(\.first).values.sorted { $0.rating > $1.rating }

            applyUserData()
            applyEpisodeCounts()
        } catch {
            errorMessage = "Failed to load content. Please check your connection."
        }

        isLoading = false
    }

    func loadMoreContent(showMovies: Bool, showTVShows: Bool, showAnime: Bool) async {
        guard !isLoadingMore, !isLoading else { return }
        if !hasMoreMovies && !hasMoreTV && !hasMoreAnime { return }
        
        isLoadingMore = true
        
        do {
            var newItems: [MediaItem] = []
            
            if showMovies && hasMoreMovies {
                currentMoviePage += 1
                let movies = try await tmdbService.fetchPopularMovies(page: currentMoviePage)
                if movies.isEmpty { hasMoreMovies = false }
                newItems.append(contentsOf: movies.map { mapMovie($0) })
            }
            
            if showTVShows && hasMoreTV {
                currentTVPage += 1
                let tvShows = try await tmdbService.fetchPopularTV(page: currentTVPage)
                if tvShows.isEmpty { hasMoreTV = false }
                let filteredTVShows = filterTVShowsExcludingAnime(tvShows)
                newItems.append(contentsOf: filteredTVShows.map { mapTV($0, type: .tvShow) })
            }
            
            if showAnime && hasMoreAnime {
                currentAnimePage += 1
                if usesAniListAnimeSource {
                    if let animeList = try? await aniListService.fetchPopularAnime(page: currentAnimePage) {
                        if animeList.isEmpty { hasMoreAnime = false }
                        newItems.append(contentsOf: mapAniListAnimeCollection(animeList))
                    } else {
                        hasMoreAnime = false
                    }
                } else {
                    if let animeList = try? await fetchTmdbAnime(page: currentAnimePage, catalog: .popular) {
                        if animeList.isEmpty { hasMoreAnime = false }
                        newItems.append(contentsOf: mapTmdbAnimeCollection(animeList))
                    } else {
                        hasMoreAnime = false
                    }
                }
            }
            
            let combinedItems = allMedia + newItems
            let uniqueItems = Dictionary(grouping: combinedItems, by: \.id).compactMapValues(\.first).values
            allMedia = Array(uniqueItems).sorted { $0.rating > $1.rating }
            
            applyUserData()
            applyEpisodeCounts()
        } catch {
            // Revert page increments on failure
            if showMovies { currentMoviePage = max(1, currentMoviePage - 1) }
            if showTVShows { currentTVPage = max(1, currentTVPage - 1) }
            if showAnime { currentAnimePage = max(1, currentAnimePage - 1) }
        }
        
        isLoadingMore = false
    }

    // MARK: - Search

    func search(query: String, showMovies: Bool, showTVShows: Bool, showAnime: Bool) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        do {
            // Ensure genre map is loaded
            if genreMap.isEmpty {
                async let movieGenres = tmdbService.fetchMovieGenres()
                async let tvGenres = tmdbService.fetchTVGenres()
                let (mg, tg) = try await (movieGenres, tvGenres)
                for g in mg { genreMap[g.id] = g.name }
                for g in tg { genreMap[g.id] = g.name }
            }

            if showAnime && usesAniListAnimeSource {
                await ensureAniListGenresLoaded()
            }

            var results: [MediaItem] = []

            if showMovies {
                let movies = try await tmdbService.searchMovies(query: query)
                results.append(contentsOf: movies.map { mapMovie($0) })
            }

            if showTVShows {
                let tvItems = try await tmdbService.searchTV(query: query)
                let filteredTVItems = filterTVShowsExcludingAnime(tvItems)
                results.append(contentsOf: filteredTVItems.map { mapTV($0, type: .tvShow) })
            }

            if showAnime {
                if usesAniListAnimeSource {
                    let animeItems = (try? await aniListService.searchAnime(query: query)) ?? []
                    results.append(contentsOf: mapAniListAnimeCollection(animeItems))
                } else {
                    let animeItems = try await tmdbService.searchTV(query: query)
                    let filteredAnimeItems = filterAnimeTVShows(animeItems)
                    results.append(contentsOf: mapTmdbAnimeCollection(filteredAnimeItems))
                }
            }

            // Deduplicate, preserving existing allMedia state for watched/queue
            var merged: [MediaItem] = []
            var seen = Set<Int>()
            for var item in results {
                if seen.contains(item.id) { continue }
                seen.insert(item.id)
                // Merge user state from allMedia if item is already there
                if let existing = allMedia.first(where: { $0.id == item.id }) {
                    item.isWatched = existing.isWatched
                    item.isInProgress = existing.isInProgress
                    item.isInQueue = existing.isInQueue
                    item.watchedEpisodes = existing.watchedEpisodes
                    item.totalEpisodes = existing.totalEpisodes
                    item.totalSeasons = existing.totalSeasons
                } else {
                    item.isWatched = watchedIds.contains(item.id)
                    item.isInProgress = inProgressIds.contains(item.id) && !item.isWatched
                    item.isInQueue = queueIds.contains(item.id)
                    item.watchedEpisodes = episodeWatchedMap[item.id]?.count ?? 0
                }
                merged.append(item)
            }

            searchResults = merged
        } catch {
            searchResults = []
        }
        isSearching = false
    }

    // MARK: - Discover

    private func fetchDiscoverPage(page: Int, type: MediaType?, catalog: DiscoverCatalog, genreId: Int?, query: String) async throws -> [MediaItem] {
        var results: [MediaItem] = []
        let isMovie = type == nil || type == .movie
        let isTV = type == nil || type == .tvShow
        let isAnime = type == nil || type == .anime
        let selectedGenreName = genreName(for: genreId)
        let selectedTmdbGenreId = tmdbGenreId(from: genreId)

        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            if isMovie {
                let movies = try await tmdbService.searchMovies(query: query, page: page)
                results.append(contentsOf: movies.map { mapMovie($0) })
            }
            if isTV {
                let tvItems = try await tmdbService.searchTV(query: query, page: page)
                let filteredTVItems = filterTVShowsExcludingAnime(tvItems)
                results.append(contentsOf: filteredTVItems.map { mapTV($0, type: .tvShow) })
            }
            if isAnime {
                if usesAniListAnimeSource {
                    let animeItems = (try? await aniListService.searchAnime(
                        query: query,
                        page: page,
                        genre: selectedGenreName
                    )) ?? []
                    results.append(contentsOf: mapAniListAnimeCollection(animeItems))
                } else {
                    let animeItems = try await tmdbService.searchTV(query: query, page: page)
                    var filteredAnimeItems = filterAnimeTVShows(animeItems)
                    if let selectedTmdbGenreId {
                        filteredAnimeItems = filteredAnimeItems.filter { $0.genreIds.contains(selectedTmdbGenreId) }
                    }
                    results.append(contentsOf: mapTmdbAnimeCollection(filteredAnimeItems))
                }
            }
        } else if let gId = selectedTmdbGenreId {
            switch catalog {
            case .popular:
                if isMovie {
                    let movies = try await tmdbService.discoverMoviesByGenre(genreId: gId, page: page)
                    results.append(contentsOf: movies.map { mapMovie($0) })
                }
                if isTV {
                    let tvItems = try await tmdbService.discoverTVByGenre(genreId: gId, page: page)
                    let filteredTVItems = filterTVShowsExcludingAnime(tvItems)
                    results.append(contentsOf: filteredTVItems.map { mapTV($0, type: .tvShow) })
                }
                if isAnime {
                    if usesAniListAnimeSource {
                        let animeItems = (try? await aniListService.fetchPopularAnime(
                            page: page,
                            genre: selectedGenreName
                        )) ?? []
                        results.append(contentsOf: mapAniListAnimeCollection(animeItems))
                    } else {
                        let animeItems = try await fetchTmdbAnime(page: page, catalog: .popular, genreId: gId)
                        results.append(contentsOf: mapTmdbAnimeCollection(animeItems))
                    }
                }
            case .new:
                if isMovie {
                    let movies = try await tmdbService.fetchNowPlayingMovies(page: page)
                    let genreFilteredMovies = movies.filter { $0.genreIds.contains(gId) }
                    results.append(contentsOf: genreFilteredMovies.map { mapMovie($0) })
                }
                if isTV {
                    let tvItems = try await tmdbService.fetchOnTheAirTV(page: page)
                    let genreFilteredTVItems = tvItems.filter { $0.genreIds.contains(gId) }
                    let filteredTVItems = filterTVShowsExcludingAnime(genreFilteredTVItems)
                    results.append(contentsOf: filteredTVItems.map { mapTV($0, type: .tvShow) })
                }
                if isAnime {
                    if usesAniListAnimeSource {
                        let animeItems = (try? await aniListService.fetchNewAnime(
                            page: page,
                            genre: selectedGenreName
                        )) ?? []
                        results.append(contentsOf: mapAniListAnimeCollection(animeItems))
                    } else {
                        let animeItems = try await fetchTmdbAnime(page: page, catalog: .new, genreId: gId)
                        results.append(contentsOf: mapTmdbAnimeCollection(animeItems))
                    }
                }
            case .featured:
                if isMovie {
                    let movies = try await tmdbService.fetchTrendingMovies(page: page)
                    let genreFilteredMovies = movies.filter { $0.genreIds.contains(gId) }
                    results.append(contentsOf: genreFilteredMovies.map { mapMovie($0) })
                }
                if isTV {
                    let tvItems = try await tmdbService.fetchTrendingTV(page: page)
                    let genreFilteredTVItems = tvItems.filter { $0.genreIds.contains(gId) }
                    let filteredTVItems = filterTVShowsExcludingAnime(genreFilteredTVItems)
                    results.append(contentsOf: filteredTVItems.map { mapTV($0, type: .tvShow) })
                }
                if isAnime {
                    if usesAniListAnimeSource {
                        let animeItems = (try? await aniListService.fetchTrendingAnime(
                            page: page,
                            genre: selectedGenreName
                        )) ?? []
                        results.append(contentsOf: mapAniListAnimeCollection(animeItems))
                    } else {
                        let animeItems = try await fetchTmdbAnime(page: page, catalog: .featured, genreId: gId)
                        results.append(contentsOf: mapTmdbAnimeCollection(animeItems))
                    }
                }
            }
        } else if isAnime, let selectedGenreName, usesAniListAnimeSource {
            let animeItems: [AniListAnime]
            switch catalog {
            case .popular:
                animeItems = (try? await aniListService.fetchPopularAnime(page: page, genre: selectedGenreName)) ?? []
            case .new:
                animeItems = (try? await aniListService.fetchNewAnime(page: page, genre: selectedGenreName)) ?? []
            case .featured:
                animeItems = (try? await aniListService.fetchTrendingAnime(page: page, genre: selectedGenreName)) ?? []
            }
            results.append(contentsOf: mapAniListAnimeCollection(animeItems))
        } else {
            switch catalog {
            case .popular:
                if isMovie {
                    let movies = try await tmdbService.fetchPopularMovies(page: page)
                    results.append(contentsOf: movies.map { mapMovie($0) })
                }
                if isTV {
                    let tvItems = try await tmdbService.fetchPopularTV(page: page)
                    let filteredTVItems = filterTVShowsExcludingAnime(tvItems)
                    results.append(contentsOf: filteredTVItems.map { mapTV($0, type: .tvShow) })
                }
                if isAnime {
                    if usesAniListAnimeSource {
                        let animeItems = (try? await aniListService.fetchPopularAnime(page: page)) ?? []
                        results.append(contentsOf: mapAniListAnimeCollection(animeItems))
                    } else {
                        let animeItems = try await fetchTmdbAnime(page: page, catalog: .popular)
                        results.append(contentsOf: mapTmdbAnimeCollection(animeItems))
                    }
                }
            case .new:
                if isMovie {
                    let movies = try await tmdbService.fetchNowPlayingMovies(page: page)
                    results.append(contentsOf: movies.map { mapMovie($0) })
                }
                if isTV {
                    let tvItems = try await tmdbService.fetchOnTheAirTV(page: page)
                    let filteredTVItems = filterTVShowsExcludingAnime(tvItems)
                    results.append(contentsOf: filteredTVItems.map { mapTV($0, type: .tvShow) })
                }
                if isAnime {
                    if usesAniListAnimeSource {
                        let animeItems = (try? await aniListService.fetchNewAnime(page: page)) ?? []
                        results.append(contentsOf: mapAniListAnimeCollection(animeItems))
                    } else {
                        let animeItems = try await fetchTmdbAnime(page: page, catalog: .new)
                        results.append(contentsOf: mapTmdbAnimeCollection(animeItems))
                    }
                }
            case .featured:
                if isMovie {
                    let movies = try await tmdbService.fetchTrendingMovies(page: page)
                    results.append(contentsOf: movies.map { mapMovie($0) })
                }
                if isTV {
                    let tvItems = try await tmdbService.fetchTrendingTV(page: page)
                    let filteredTVItems = filterTVShowsExcludingAnime(tvItems)
                    results.append(contentsOf: filteredTVItems.map { mapTV($0, type: .tvShow) })
                }
                if isAnime {
                    if usesAniListAnimeSource {
                        let animeItems = (try? await aniListService.fetchTrendingAnime(page: page)) ?? []
                        results.append(contentsOf: mapAniListAnimeCollection(animeItems))
                    } else {
                        let animeItems = try await fetchTmdbAnime(page: page, catalog: .featured)
                        results.append(contentsOf: mapTmdbAnimeCollection(animeItems))
                    }
                }
            }
        }
        return results
    }

    func loadDiscover(reset: Bool, type: MediaType?, catalog: DiscoverCatalog, genreId: Int?, query: String) async {
        if reset {
            currentDiscoverPage = 1
            hasMoreDiscover = true
            discoverMedia = []
        }

        guard !isDiscoverLoading, hasMoreDiscover else { return }

        isDiscoverLoading = true
        defer { isDiscoverLoading = false }

        do {
            if genreMap.isEmpty {
                async let movieGenres = tmdbService.fetchMovieGenres()
                async let tvGenres = tmdbService.fetchTVGenres()
                let (mg, tg) = try await (movieGenres, tvGenres)
                for g in mg { genreMap[g.id] = g.name }
                for g in tg { genreMap[g.id] = g.name }
            }

            if usesAniListAnimeSource {
                await ensureAniListGenresLoaded()
            }

            let fetchedItems = try await fetchDiscoverPage(
                page: currentDiscoverPage,
                type: type,
                catalog: catalog,
                genreId: genreId,
                query: query
            )

            if fetchedItems.isEmpty {
                hasMoreDiscover = false
                return
            }

            var merged: [MediaItem] = []
            var seen = Set<Int>(discoverMedia.map { $0.id })

            for var item in fetchedItems {
                if seen.contains(item.id) { continue }
                seen.insert(item.id)

                if let existing = allMedia.first(where: { $0.id == item.id }) {
                    item.isWatched = existing.isWatched
                    item.isInProgress = existing.isInProgress
                    item.isInQueue = existing.isInQueue
                    item.watchedEpisodes = existing.watchedEpisodes
                    item.totalEpisodes = existing.totalEpisodes
                    item.totalSeasons = existing.totalSeasons
                } else {
                    item.isWatched = watchedIds.contains(item.id)
                    item.isInProgress = inProgressIds.contains(item.id) && !item.isWatched
                    item.isInQueue = queueIds.contains(item.id)
                    item.watchedEpisodes = episodeWatchedMap[item.id]?.count ?? 0
                }

                merged.append(item)
            }

            // Also merge new items into allMedia so they're available elsewhere
            for item in merged {
                if !allMedia.contains(where: { $0.id == item.id }) {
                    allMedia.append(item)
                }
            }

            if !merged.isEmpty {
                discoverMedia.append(contentsOf: merged)
            }
            currentDiscoverPage += 1
        } catch {
            if reset { discoverMedia = [] }
            hasMoreDiscover = false
        }
    }

    // MARK: - Genre Discover

    func genreIdForName(_ name: String) -> Int? {
        let matchingIds = genreMap
            .filter { $0.value == name }
            .map(\.key)

        if let tmdbMatch = matchingIds
            .filter({ $0 < aniListGenreBaseId })
            .min() {
            return tmdbMatch
        }

        return matchingIds.min()
    }

    func discoverByGenre(genreName: String, selectedFilter: MediaType?, showMovies: Bool, showTVShows: Bool, showAnime: Bool) async {
        // Check cache (valid for 5 minutes)
        let cacheKey = "\(genreName)-\(selectedFilter?.rawValue ?? "all")"
        if let cached = genreMediaCache[cacheKey],
           Date().timeIntervalSince(cached.date) < 300 {
            genreMedia = cached.items
            return
        }

        if usesAniListAnimeSource {
            await ensureAniListGenresLoaded()
        }

        guard let resolvedGenreId = genreIdForName(genreName) else {
            genreMedia = []
            return
        }
        let resolvedTmdbGenreId = tmdbGenreId(from: resolvedGenreId)

        isLoadingGenre = true
        do {
            if genreMap.isEmpty {
                async let movieGenres = tmdbService.fetchMovieGenres()
                async let tvGenres = tmdbService.fetchTVGenres()
                let (mg, tg) = try await (movieGenres, tvGenres)
                for g in mg { genreMap[g.id] = g.name }
                for g in tg { genreMap[g.id] = g.name }
            }

            var results: [MediaItem] = []

            let shouldFetchMovies = showMovies && (selectedFilter == nil || selectedFilter == .movie)
            let shouldFetchTV = showTVShows && (selectedFilter == nil || selectedFilter == .tvShow)
            let shouldFetchAnime = showAnime && (selectedFilter == nil || selectedFilter == .anime)

            if shouldFetchMovies, let resolvedTmdbGenreId {
                let movies = try await tmdbService.discoverMoviesByGenre(genreId: resolvedTmdbGenreId)
                results.append(contentsOf: movies.map { mapMovie($0) })
            }

            if shouldFetchTV, let resolvedTmdbGenreId {
                let tvItems = try await tmdbService.discoverTVByGenre(genreId: resolvedTmdbGenreId)
                let filteredTVItems = filterTVShowsExcludingAnime(tvItems)
                results.append(contentsOf: filteredTVItems.map { mapTV($0, type: .tvShow) })
            }

            if shouldFetchAnime {
                if usesAniListAnimeSource {
                    let animeItems = (try? await aniListService.fetchPopularAnime(page: 1, genre: genreName)) ?? []
                    results.append(contentsOf: mapAniListAnimeCollection(animeItems))
                } else if let resolvedTmdbGenreId {
                    let animeItems = (try? await fetchTmdbAnime(page: 1, catalog: .popular, genreId: resolvedTmdbGenreId)) ?? []
                    results.append(contentsOf: mapTmdbAnimeCollection(animeItems))
                }
            }

            // Deduplicate, merge user state
            var merged: [MediaItem] = []
            var seen = Set<Int>()
            for var item in results {
                if seen.contains(item.id) { continue }
                seen.insert(item.id)
                if let existing = allMedia.first(where: { $0.id == item.id }) {
                    item.isWatched = existing.isWatched
                    item.isInProgress = existing.isInProgress
                    item.isInQueue = existing.isInQueue
                    item.watchedEpisodes = existing.watchedEpisodes
                    item.totalEpisodes = existing.totalEpisodes
                    item.totalSeasons = existing.totalSeasons
                } else {
                    item.isWatched = watchedIds.contains(item.id)
                    item.isInProgress = inProgressIds.contains(item.id) && !item.isWatched
                    item.isInQueue = queueIds.contains(item.id)
                    item.watchedEpisodes = episodeWatchedMap[item.id]?.count ?? 0
                }
                merged.append(item)
            }

            merged.sort { $0.rating > $1.rating }
            genreMedia = merged
            genreMediaCache[cacheKey] = (items: merged, date: Date())

            // Also merge new items into allMedia so they're available elsewhere
            for item in merged {
                if !allMedia.contains(where: { $0.id == item.id }) {
                    allMedia.append(item)
                }
            }
        } catch {
            genreMedia = []
        }
        isLoadingGenre = false
    }

    // MARK: - Item-level actions

    func toggleWatched(_ item: MediaItem) {
        guard let index = allMedia.firstIndex(where: { $0.id == item.id }) else { return }
        allMedia[index].isWatched.toggle()
        if allMedia[index].isWatched {
            allMedia[index].isInQueue = false
            allMedia[index].isInProgress = false
            watchedIds.insert(item.id)
            inProgressIds.remove(item.id)
            queueIds.remove(item.id)
            recordWatchedAddition(item.id)
            removeQueueAddition(item.id)
            removeInProgressUpdate(item.id)
            recordWatchedDate()
        } else {
            watchedIds.remove(item.id)
            inProgressIds.remove(item.id)
            episodeWatchedMap.removeValue(forKey: item.id)
            allMedia[index].watchedEpisodes = 0
            allMedia[index].isInProgress = false
            removeWatchedAddition(item.id)
            removeInProgressUpdate(item.id)
        }
        saveUserData()
        saveEpisodeData()
    }

    func toggleQueue(_ item: MediaItem) {
        guard let index = allMedia.firstIndex(where: { $0.id == item.id }) else { return }
        allMedia[index].isInQueue.toggle()
        if allMedia[index].isInQueue {
            queueIds.insert(item.id)
            recordQueueAddition(item.id)
        } else {
            queueIds.remove(item.id)
            episodeQueueMap.removeValue(forKey: item.id)
            removeQueueAddition(item.id)
        }
        saveUserData()
        saveEpisodeData()
    }

    func markWatched(_ item: MediaItem) {
        guard let index = allMedia.firstIndex(where: { $0.id == item.id }) else { return }
        allMedia[index].isWatched = true
        allMedia[index].isInProgress = false
        allMedia[index].isInQueue = false
        watchedIds.insert(item.id)
        inProgressIds.remove(item.id)
        queueIds.remove(item.id)
        recordWatchedAddition(item.id)
        removeQueueAddition(item.id)
        removeInProgressUpdate(item.id)
        recordWatchedDate()
        saveUserData()
    }

    func toggleInProgress(_ item: MediaItem) {
        guard let index = allMedia.firstIndex(where: { $0.id == item.id }) else { return }

        if allMedia[index].isInProgress {
            allMedia[index].isInProgress = false
            inProgressIds.remove(item.id)
        } else {
            allMedia[index].isInProgress = true
            allMedia[index].isWatched = false
            inProgressIds.insert(item.id)
            watchedIds.remove(item.id)
            removeWatchedAddition(item.id)
        }

        reconcileProgressState(for: index)
        syncInProgressUpdate(for: index)
        saveUserData()
    }

    func addToQueue(_ item: MediaItem) {
        guard let index = allMedia.firstIndex(where: { $0.id == item.id }) else { return }
        if !allMedia[index].isInQueue {
            allMedia[index].isInQueue = true
            queueIds.insert(item.id)
            recordQueueAddition(item.id)
            saveUserData()
        }
    }

    // MARK: - Episode-level actions

    func isEpisodeWatched(mediaId: Int, key: String) -> Bool {
        episodeWatchedMap[mediaId]?.contains(key) ?? false
    }

    func isEpisodeQueued(mediaId: Int, key: String) -> Bool {
        episodeQueueMap[mediaId]?.contains(key) ?? false
    }

    func watchedEpisodeCount(mediaId: Int) -> Int {
        episodeWatchedMap[mediaId]?.count ?? 0
    }

    func queuedEpisodeCount(mediaId: Int) -> Int {
        episodeQueueMap[mediaId]?.count ?? 0
    }

    func toggleEpisodeWatched(mediaId: Int, key: String, totalEpisodes: Int) {
        if episodeWatchedMap[mediaId] == nil {
            episodeWatchedMap[mediaId] = []
        }

        if episodeWatchedMap[mediaId]!.contains(key) {
            episodeWatchedMap[mediaId]!.remove(key)
        } else {
            episodeWatchedMap[mediaId]!.insert(key)
            recordWatchedAddition(mediaId)
            recordWatchedDate()
        }

        if let index = allMedia.firstIndex(where: { $0.id == mediaId }) {
            reconcileProgressState(for: index, totalEpisodesOverride: totalEpisodes)
            syncInProgressUpdate(for: index)
        }

        if (episodeWatchedMap[mediaId]?.isEmpty ?? true),
           !(allMedia.first(where: { $0.id == mediaId })?.isWatched ?? false) {
            removeWatchedAddition(mediaId)
        }

        saveUserData()
        saveEpisodeData()
    }

    func toggleEpisodeQueued(mediaId: Int, key: String) {
        if episodeQueueMap[mediaId] == nil {
            episodeQueueMap[mediaId] = []
        }

        if episodeQueueMap[mediaId]!.contains(key) {
            episodeQueueMap[mediaId]!.remove(key)
        } else {
            episodeQueueMap[mediaId]!.insert(key)
            recordQueueAddition(mediaId)
        }

        if (episodeQueueMap[mediaId]?.isEmpty ?? true),
           !(allMedia.first(where: { $0.id == mediaId })?.isInQueue ?? false) {
            removeQueueAddition(mediaId)
        }

        saveEpisodeData()
        saveUserData()
    }

    func markAllEpisodesWatched(mediaId: Int, keys: [String], totalEpisodes: Int) {
        episodeWatchedMap[mediaId] = Set(keys)
        recordWatchedAddition(mediaId)

        if let index = allMedia.firstIndex(where: { $0.id == mediaId }) {
            reconcileProgressState(for: index, totalEpisodesOverride: totalEpisodes)
            syncInProgressUpdate(for: index)
        }

        saveUserData()
        saveEpisodeData()
    }

    func markSeasonWatched(mediaId: Int, seasonNumber: Int, episodeCount: Int, totalEpisodes: Int) {
        if episodeWatchedMap[mediaId] == nil {
            episodeWatchedMap[mediaId] = []
        }
        
        guard episodeCount > 0 else { return }
        for epNum in 1...episodeCount {
            let key = "s\(seasonNumber)e\(epNum)"
            episodeWatchedMap[mediaId]?.insert(key)
        }
        recordWatchedAddition(mediaId)
        
        recordWatchedDate()
        
        if let index = allMedia.firstIndex(where: { $0.id == mediaId }) {
            reconcileProgressState(for: index, totalEpisodesOverride: totalEpisodes)
            syncInProgressUpdate(for: index)
        }
        
        saveUserData()
        saveEpisodeData()
    }

    func unmarkSeasonWatched(mediaId: Int, seasonNumber: Int, episodeCount: Int) {
        guard episodeCount > 0 else { return }
        
        for epNum in 1...episodeCount {
            let key = "s\(seasonNumber)e\(epNum)"
            episodeWatchedMap[mediaId]?.remove(key)
        }
        
        if let index = allMedia.firstIndex(where: { $0.id == mediaId }) {
            reconcileProgressState(for: index)
            syncInProgressUpdate(for: index)
        }

        if (episodeWatchedMap[mediaId]?.isEmpty ?? true),
           !(allMedia.first(where: { $0.id == mediaId })?.isWatched ?? false) {
            removeWatchedAddition(mediaId)
        }
        
        saveUserData()
        saveEpisodeData()
    }

    func unmarkAllEpisodesWatched(mediaId: Int) {
        episodeWatchedMap.removeValue(forKey: mediaId)

        if let index = allMedia.firstIndex(where: { $0.id == mediaId }) {
            reconcileProgressState(for: index)
            syncInProgressUpdate(for: index)
        }

        if !(allMedia.first(where: { $0.id == mediaId })?.isWatched ?? false) {
            removeWatchedAddition(mediaId)
        }

        saveUserData()
        saveEpisodeData()
    }

    func updateMediaEpisodeInfo(mediaId: Int, totalEpisodes: Int, totalSeasons: Int) {
        guard let index = allMedia.firstIndex(where: { $0.id == mediaId }) else { return }
        allMedia[index].totalEpisodes = totalEpisodes
        allMedia[index].totalSeasons = totalSeasons
        reconcileProgressState(for: index, totalEpisodesOverride: totalEpisodes)
    }

    // MARK: - IMDB Rating

    private var imdbRatingCache: [Int: Double] = [:]
    var imdbLoadingIds: Set<Int> = []

    func isLoadingImdbRating(_ itemId: Int) -> Bool {
        imdbLoadingIds.contains(itemId)
    }

    private func applyImdbRating(_ rating: Double, for itemId: Int) {
        if let index = allMedia.firstIndex(where: { $0.id == itemId }) {
            allMedia[index].imdbRating = rating
        }
        if let index = featuredMovies.firstIndex(where: { $0.id == itemId }) {
            featuredMovies[index].imdbRating = rating
        }
        if let index = featuredTVShows.firstIndex(where: { $0.id == itemId }) {
            featuredTVShows[index].imdbRating = rating
        }
        if let index = featuredAnime.firstIndex(where: { $0.id == itemId }) {
            featuredAnime[index].imdbRating = rating
        }
        if let index = searchResults.firstIndex(where: { $0.id == itemId }) {
            searchResults[index].imdbRating = rating
        }
        if let index = genreMedia.firstIndex(where: { $0.id == itemId }) {
            genreMedia[index].imdbRating = rating
        }
        if let index = discoverMedia.firstIndex(where: { $0.id == itemId }) {
            discoverMedia[index].imdbRating = rating
        }
    }

    func fetchImdbRatingForItem(_ item: MediaItem) async -> Double? {
        // Check cache
        if let cached = imdbRatingCache[item.id] {
            applyImdbRating(cached, for: item.id)
            return cached
        }

        // AniList-based anime entries do not have TMDB external IDs.
        if item.type == .anime && item.id >= Self.aniListAnimeIdOffset {
            return nil
        }

        // Check if OMDB key is available
        guard !Config.OMDB_API_KEY.isEmpty, Config.OMDB_API_KEY != "YOUR_OMDB_API_KEY_HERE" else {
            return nil
        }

        // Prevent duplicate concurrent fetches for the same item
        if imdbLoadingIds.contains(item.id) {
            return nil
        }

        imdbLoadingIds.insert(item.id)
        defer { imdbLoadingIds.remove(item.id) }

        do {
            let imdbId: String?
            if item.type == .movie {
                let ext = try await tmdbService.fetchMovieExternalIds(movieId: item.tmdbId)
                imdbId = ext.imdbId
            } else {
                let ext = try await tmdbService.fetchTVExternalIds(tvId: item.tmdbId)
                imdbId = ext.imdbId
            }

            guard let id = imdbId else { return nil }
            if let rating = try await tmdbService.fetchImdbRating(imdbId: id) {
                imdbRatingCache[item.id] = rating
                applyImdbRating(rating, for: item.id)
                return rating
            }
        } catch {
            // Silently fail
        }
        return nil
    }

    // MARK: - Episode helpers for Library

    func watchedEpisodeKeys(mediaId: Int) -> Set<String> {
        episodeWatchedMap[mediaId] ?? []
    }

    func queuedEpisodeKeys(mediaId: Int) -> Set<String> {
        episodeQueueMap[mediaId] ?? []
    }

    func removeEpisodeFromQueue(mediaId: Int, key: String) {
        episodeQueueMap[mediaId]?.remove(key)
        if episodeQueueMap[mediaId]?.isEmpty == true {
            episodeQueueMap.removeValue(forKey: mediaId)
        }
        if !(allMedia.first(where: { $0.id == mediaId })?.isInQueue ?? false) {
            removeQueueAddition(mediaId)
            saveUserData()
        }
        saveEpisodeData()
    }

    func markEpisodeWatched(mediaId: Int, key: String, totalEpisodes: Int) {
        // Remove from queue
        episodeQueueMap[mediaId]?.remove(key)
        if episodeQueueMap[mediaId]?.isEmpty == true {
            episodeQueueMap.removeValue(forKey: mediaId)
        }
        removeQueueAddition(mediaId)

        // Add to watched
        if episodeWatchedMap[mediaId] == nil {
            episodeWatchedMap[mediaId] = []
        }
        episodeWatchedMap[mediaId]!.insert(key)
        recordWatchedAddition(mediaId)

        // Update item
        if let index = allMedia.firstIndex(where: { $0.id == mediaId }) {
            reconcileProgressState(for: index, totalEpisodesOverride: totalEpisodes)
            syncInProgressUpdate(for: index)
        }

        saveUserData()
        saveEpisodeData()
        recordWatchedDate()
    }

    // MARK: - Mapping

    func mapAniListAnime(_ anime: AniListAnime) -> MediaItem {
        mapAniListSeries(
            entries: [anime],
            seriesKey: normalizedAniListSeriesKey(from: canonicalAniListTitle(anime))
        )
    }

    func mapMovie(_ movie: TMDBMovie) -> MediaItem {
        let year = extractYear(from: movie.releaseDate)
        let genres = movie.genreIds.compactMap { genreMap[$0] }
        return MediaItem(
            id: movie.id,
            title: movie.title,
            subtitle: "\(year) · \(genres.prefix(2).joined(separator: ", "))",
            overview: movie.overview,
            type: .movie,
            posterPath: movie.posterPath,
            backdropPath: movie.backdropPath,
            rating: movie.voteAverage,
            year: year,
            releaseDateString: movie.releaseDate,
            genres: genres,
            totalEpisodes: nil,
            watchedEpisodes: 0,
            totalSeasons: nil,
            isWatched: false,
            isInQueue: false,
            genreIds: movie.genreIds,
            imdbRating: nil
        )
    }

    func mapTV(_ tv: TMDBTV, type: MediaType) -> MediaItem {
        let year = extractYear(from: tv.firstAirDate)
        let genres = tv.genreIds.compactMap { genreMap[$0] }
        return MediaItem(
            id: tv.id + 100000,
            title: tv.name,
            subtitle: "\(year) · \(genres.prefix(2).joined(separator: ", "))",
            overview: tv.overview,
            type: type,
            posterPath: tv.posterPath,
            backdropPath: tv.backdropPath,
            rating: tv.voteAverage,
            year: year,
            releaseDateString: tv.firstAirDate,
            genres: genres,
            totalEpisodes: nil,
            watchedEpisodes: 0,
            totalSeasons: nil,
            isWatched: false,
            isInQueue: false,
            genreIds: tv.genreIds,
            imdbRating: nil
        )
    }

    private func extractYear(from dateString: String?) -> Int {
        guard let dateString, dateString.count >= 4,
              let year = Int(dateString.prefix(4)) else { return 0 }
        return year
    }

    // MARK: - Persistence

    private func applyUserData() {
        for i in allMedia.indices {
            allMedia[i].isWatched = watchedIds.contains(allMedia[i].id)
            allMedia[i].isInProgress = inProgressIds.contains(allMedia[i].id) && !allMedia[i].isWatched
            allMedia[i].isInQueue = queueIds.contains(allMedia[i].id)
        }
    }

    private func applyEpisodeCounts() {
        for i in allMedia.indices {
            reconcileProgressState(for: i)
        }
    }

    private func recentItems(
        from order: [Int],
        type: MediaType,
        limit: Int,
        where include: (MediaItem) -> Bool
    ) -> [MediaItem] {
        guard limit > 0 else { return [] }

        var items: [MediaItem] = []
        var seen: Set<Int> = []
        for id in order.reversed() {
            guard !seen.contains(id) else { continue }
            guard let item = allMedia.first(where: { $0.id == id }) else { continue }
            guard item.type == type, include(item) else { continue }
            seen.insert(id)
            items.append(item)
            if items.count >= limit {
                break
            }
        }
        return items
    }

    private func recordQueueAddition(_ mediaId: Int) {
        queueAddedOrder.removeAll { $0 == mediaId }
        queueAddedOrder.append(mediaId)
    }

    private func removeQueueAddition(_ mediaId: Int) {
        queueAddedOrder.removeAll { $0 == mediaId }
    }

    private func recordWatchedAddition(_ mediaId: Int) {
        watchedAddedOrder.removeAll { $0 == mediaId }
        watchedAddedOrder.append(mediaId)
    }

    private func removeWatchedAddition(_ mediaId: Int) {
        watchedAddedOrder.removeAll { $0 == mediaId }
    }

    private func recordInProgressUpdate(_ mediaId: Int) {
        inProgressUpdatedOrder.removeAll { $0 == mediaId }
        inProgressUpdatedOrder.append(mediaId)
    }

    private func removeInProgressUpdate(_ mediaId: Int) {
        inProgressUpdatedOrder.removeAll { $0 == mediaId }
    }

    private func syncInProgressUpdate(for index: Int) {
        let mediaId = allMedia[index].id
        if allMedia[index].isInProgress && !allMedia[index].isWatched {
            recordInProgressUpdate(mediaId)
        } else {
            removeInProgressUpdate(mediaId)
        }
    }

    private func loadUserData() {
        let watched = UserDefaults.standard.array(forKey: "watchedIds") as? [Int] ?? []
        let inProgress = UserDefaults.standard.array(forKey: "inProgressIds") as? [Int] ?? []
        let queued = UserDefaults.standard.array(forKey: "queueIds") as? [Int] ?? []
        let watchedOrder = UserDefaults.standard.array(forKey: "watchedAddedOrder") as? [Int] ?? []
        let queueOrder = UserDefaults.standard.array(forKey: "queueAddedOrder") as? [Int] ?? []
        let inProgressOrder = UserDefaults.standard.array(forKey: "inProgressUpdatedOrder") as? [Int] ?? []
        watchedIds = Set(watched)
        inProgressIds = Set(inProgress)
        queueIds = Set(queued)
        watchedAddedOrder = watchedOrder
        queueAddedOrder = queueOrder
        inProgressUpdatedOrder = inProgressOrder
    }

    private func saveUserData() {
        UserDefaults.standard.set(Array(watchedIds), forKey: "watchedIds")
        UserDefaults.standard.set(Array(inProgressIds), forKey: "inProgressIds")
        UserDefaults.standard.set(Array(queueIds), forKey: "queueIds")
        UserDefaults.standard.set(watchedAddedOrder, forKey: "watchedAddedOrder")
        UserDefaults.standard.set(queueAddedOrder, forKey: "queueAddedOrder")
        UserDefaults.standard.set(inProgressUpdatedOrder, forKey: "inProgressUpdatedOrder")
    }

    private func reconcileProgressState(for index: Int, totalEpisodesOverride: Int? = nil) {
        let mediaId = allMedia[index].id
        let watchedCount = episodeWatchedMap[mediaId]?.count ?? 0
        let totalEpisodes = max(0, totalEpisodesOverride ?? allMedia[index].totalEpisodes ?? 0)

        allMedia[index].watchedEpisodes = watchedCount

        if allMedia[index].hasSeasonsAndEpisodes {
            if totalEpisodes > 0 && watchedCount >= totalEpisodes {
                allMedia[index].isWatched = true
                allMedia[index].isInProgress = false
                allMedia[index].isInQueue = false
                watchedIds.insert(mediaId)
                inProgressIds.remove(mediaId)
                queueIds.remove(mediaId)
                return
            }

            if watchedCount > 0 {
                allMedia[index].isWatched = false
                allMedia[index].isInProgress = true
                watchedIds.remove(mediaId)
                inProgressIds.insert(mediaId)
                return
            }
        }

        if allMedia[index].isWatched {
            allMedia[index].isInProgress = false
            watchedIds.insert(mediaId)
            inProgressIds.remove(mediaId)
        } else {
            allMedia[index].isInProgress = inProgressIds.contains(mediaId)
            watchedIds.remove(mediaId)
        }
    }

    private func loadEpisodeData() {
        if let data = UserDefaults.standard.data(forKey: "episodeWatchedMap"),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            episodeWatchedMap = decoded.reduce(into: [:]) { result, pair in
                if let id = Int(pair.key) {
                    result[id] = Set(pair.value)
                }
            }
        }
        if let data = UserDefaults.standard.data(forKey: "episodeQueueMap"),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            episodeQueueMap = decoded.reduce(into: [:]) { result, pair in
                if let id = Int(pair.key) {
                    result[id] = Set(pair.value)
                }
            }
        }
    }

    private func saveEpisodeData() {
        let watchedDict = episodeWatchedMap.reduce(into: [String: [String]]()) { $0[String($1.key)] = Array($1.value) }
        let queueDict = episodeQueueMap.reduce(into: [String: [String]]()) { $0[String($1.key)] = Array($1.value) }
        if let data = try? JSONEncoder().encode(watchedDict) {
            UserDefaults.standard.set(data, forKey: "episodeWatchedMap")
        }
        if let data = try? JSONEncoder().encode(queueDict) {
            UserDefaults.standard.set(data, forKey: "episodeQueueMap")
        }
    }

    // MARK: - Watched Dates Tracking

    func recordWatchedDate() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        watchedDates.append(formatter.string(from: Date()))
        saveWatchedDates()
    }

    private func computeWeeklyActivity() -> [DayActivity] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var dayCounts: [String: Int] = [:]
        for name in dayNames { dayCounts[name] = 0 }

        let dayOfWeekFormatter = DateFormatter()
        dayOfWeekFormatter.dateFormat = "E"
        dayOfWeekFormatter.locale = Locale(identifier: "en_US")

        // Count all watched dates in the last 7 days
        for dateStr in watchedDates {
            guard let date = formatter.date(from: dateStr) else { continue }
            let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: today).day ?? 0
            guard diff >= 0 && diff < 7 else { continue }
            let shortDay = String(dayOfWeekFormatter.string(from: date).prefix(3))
            dayCounts[shortDay, default: 0] += 1
        }

        // Build activity array in order from 7 days ago to today
        var result: [DayActivity] = []
        for i in stride(from: 6, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let shortDay = String(dayOfWeekFormatter.string(from: date).prefix(3))
            result.append(DayActivity(day: shortDay, count: dayCounts[shortDay] ?? 0))
        }
        return result
    }

    private func loadWatchedDates() {
        watchedDates = UserDefaults.standard.stringArray(forKey: "watchedDates") ?? []
    }

    private func saveWatchedDates() {
        UserDefaults.standard.set(watchedDates, forKey: "watchedDates")
    }
}
