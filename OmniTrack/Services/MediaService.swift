import Foundation

@MainActor
@Observable
class MediaService {
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
    var genreMap: [Int: String] = [:]
    private var watchedIds: Set<Int> = []
    private var queueIds: Set<Int> = []
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
                fTV = trendingTV.prefix(5).map { mapTV($0, type: .tvShow) }
                items.append(contentsOf: popularTV.map { mapTV($0, type: .tvShow) })
            }

            if showAnime {
                let animeList = try await tmdbService.fetchAnime()
                fAnime = animeList.prefix(5).map { mapTV($0, type: .anime) }
                items.append(contentsOf: animeList.map { mapTV($0, type: .anime) })
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
                newItems.append(contentsOf: tvShows.map { mapTV($0, type: .tvShow) })
            }
            
            if showAnime && hasMoreAnime {
                currentAnimePage += 1
                let animeList = try await tmdbService.fetchAnime(page: currentAnimePage)
                if animeList.isEmpty { hasMoreAnime = false }
                newItems.append(contentsOf: animeList.map { mapTV($0, type: .anime) })
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

            var results: [MediaItem] = []

            if showMovies {
                let movies = try await tmdbService.searchMovies(query: query)
                results.append(contentsOf: movies.map { mapMovie($0) })
            }

            if showTVShows || showAnime {
                let tvItems = try await tmdbService.searchTV(query: query)
                for tv in tvItems {
                    // Anime detection: genre id 16 = Animation + Japanese origin heuristic
                    let isAnimation = tv.genreIds.contains(16)
                    if isAnimation && showAnime {
                        results.append(mapTV(tv, type: .anime))
                    } else if !isAnimation && showTVShows {
                        results.append(mapTV(tv, type: .tvShow))
                    } else if isAnimation && !showAnime && showTVShows {
                        results.append(mapTV(tv, type: .tvShow))
                    }
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
                    item.isInQueue = existing.isInQueue
                    item.watchedEpisodes = existing.watchedEpisodes
                    item.totalEpisodes = existing.totalEpisodes
                    item.totalSeasons = existing.totalSeasons
                } else {
                    item.isWatched = watchedIds.contains(item.id)
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

        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            if isMovie {
                let movies = try await tmdbService.searchMovies(query: query, page: page)
                results.append(contentsOf: movies.map { mapMovie($0) })
            }
            if isTV || isAnime {
                let tvItems = try await tmdbService.searchTV(query: query, page: page)
                for tv in tvItems {
                    let isAnimation = tv.genreIds.contains(16)
                    if isAnimation && isAnime {
                        results.append(mapTV(tv, type: .anime))
                    } else if !isAnimation && isTV {
                        results.append(mapTV(tv, type: .tvShow))
                    } else if isAnimation && !isAnime && isTV {
                        results.append(mapTV(tv, type: .tvShow))
                    }
                }
            }
        } else if let gId = genreId {
            if isMovie {
                let movies = try await tmdbService.discoverMoviesByGenre(genreId: gId, page: page)
                results.append(contentsOf: movies.map { mapMovie($0) })
            }
            if isTV || isAnime {
                let tvItems = try await tmdbService.discoverTVByGenre(genreId: gId, page: page)
                for tv in tvItems {
                    let isAnimation = tv.genreIds.contains(16)
                    if isAnimation && isAnime {
                        results.append(mapTV(tv, type: .anime))
                    } else if !isAnimation && isTV {
                        results.append(mapTV(tv, type: .tvShow))
                    } else if isAnimation && !isAnime && isTV {
                        results.append(mapTV(tv, type: .tvShow))
                    }
                }
            }
        } else {
            switch catalog {
            case .popular:
                if isMovie {
                    let movies = try await tmdbService.fetchPopularMovies(page: page)
                    results.append(contentsOf: movies.map { mapMovie($0) })
                }
                if isTV || isAnime {
                    let tvItems = try await tmdbService.fetchPopularTV(page: page)
                    for tv in tvItems {
                        let isAnimation = tv.genreIds.contains(16)
                        if isAnimation && isAnime {
                            results.append(mapTV(tv, type: .anime))
                        } else if !isAnimation && isTV {
                            results.append(mapTV(tv, type: .tvShow))
                        } else if isAnimation && !isAnime && isTV {
                            results.append(mapTV(tv, type: .tvShow))
                        }
                    }
                }
            case .new:
                if isMovie {
                    let movies = try await tmdbService.fetchNowPlayingMovies(page: page)
                    results.append(contentsOf: movies.map { mapMovie($0) })
                }
                if isTV || isAnime {
                    let tvItems = try await tmdbService.fetchOnTheAirTV(page: page)
                    for tv in tvItems {
                        let isAnimation = tv.genreIds.contains(16)
                        if isAnimation && isAnime {
                            results.append(mapTV(tv, type: .anime))
                        } else if !isAnimation && isTV {
                            results.append(mapTV(tv, type: .tvShow))
                        } else if isAnimation && !isAnime && isTV {
                            results.append(mapTV(tv, type: .tvShow))
                        }
                    }
                }
            case .featured:
                if isMovie {
                    let movies = try await tmdbService.fetchTrendingMovies(page: page)
                    results.append(contentsOf: movies.map { mapMovie($0) })
                }
                if isTV {
                    let tvItems = try await tmdbService.fetchTrendingTV(page: page)
                    for tv in tvItems {
                        let isAnimation = tv.genreIds.contains(16)
                        if !isAnimation { results.append(mapTV(tv, type: .tvShow)) }
                    }
                }
                if isAnime {
                    let tvItems = try await tmdbService.fetchAnime(page: page)
                    for tv in tvItems { results.append(mapTV(tv, type: .anime)) }
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
        do {
            if genreMap.isEmpty {
                async let movieGenres = tmdbService.fetchMovieGenres()
                async let tvGenres = tmdbService.fetchTVGenres()
                let (mg, tg) = try await (movieGenres, tvGenres)
                for g in mg { genreMap[g.id] = g.name }
                for g in tg { genreMap[g.id] = g.name }
            }

            let pagesToFetch = Array(currentDiscoverPage..<(currentDiscoverPage + 5))
            var pageResultsDict = [Int: [MediaItem]]()

            for page in pagesToFetch {
                let items = try await fetchDiscoverPage(page: page, type: type, catalog: catalog, genreId: genreId, query: query)
                if items.isEmpty { hasMoreDiscover = false }
                pageResultsDict[page] = items
                if !hasMoreDiscover { break }
            }

            var merged: [MediaItem] = []
            var seen = Set<Int>(discoverMedia.map { $0.id })
            
            for page in pagesToFetch.sorted() {
                guard let results = pageResultsDict[page] else { continue }
                for var item in results {
                    if seen.contains(item.id) { continue }
                    seen.insert(item.id)
                    if let existing = allMedia.first(where: { $0.id == item.id }) {
                        item.isWatched = existing.isWatched
                        item.isInQueue = existing.isInQueue
                        item.watchedEpisodes = existing.watchedEpisodes
                        item.totalEpisodes = existing.totalEpisodes
                        item.totalSeasons = existing.totalSeasons
                    } else {
                        item.isWatched = watchedIds.contains(item.id)
                        item.isInQueue = queueIds.contains(item.id)
                        item.watchedEpisodes = episodeWatchedMap[item.id]?.count ?? 0
                    }
                    merged.append(item)
                }
            }

            // Also merge new items into allMedia so they're available elsewhere
            for item in merged {
                if !allMedia.contains(where: { $0.id == item.id }) {
                    allMedia.append(item)
                }
            }

            if merged.isEmpty && pageResultsDict.values.contains(where: { !$0.isEmpty }) {
                // If everything was seen, keep trying next page if needed
                if hasMoreDiscover {
                    currentDiscoverPage += 5
                    isDiscoverLoading = false // unlock for next fetch
                    return await loadDiscover(reset: false, type: type, catalog: catalog, genreId: genreId, query: query)
                }
            } else if !merged.isEmpty {
                discoverMedia.append(contentsOf: merged)
                currentDiscoverPage += 5
            }

        } catch {
            if reset { discoverMedia = [] }
            hasMoreDiscover = false
        }
        isDiscoverLoading = false
    }

    // MARK: - Genre Discover

    func genreIdForName(_ name: String) -> Int? {
        genreMap.first(where: { $0.value == name })?.key
    }

    func discoverByGenre(genreName: String, selectedFilter: MediaType?, showMovies: Bool, showTVShows: Bool, showAnime: Bool) async {
        // Check cache (valid for 5 minutes)
        let cacheKey = "\(genreName)-\(selectedFilter?.rawValue ?? "all")"
        if let cached = genreMediaCache[cacheKey],
           Date().timeIntervalSince(cached.date) < 300 {
            genreMedia = cached.items
            return
        }

        guard let genreId = genreIdForName(genreName) else {
            genreMedia = []
            return
        }

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

            if shouldFetchMovies {
                let movies = try await tmdbService.discoverMoviesByGenre(genreId: genreId)
                results.append(contentsOf: movies.map { mapMovie($0) })
            }

            if shouldFetchTV || shouldFetchAnime {
                let tvItems = try await tmdbService.discoverTVByGenre(genreId: genreId)
                for tv in tvItems {
                    let isAnimation = tv.genreIds.contains(16)
                    if isAnimation && shouldFetchAnime {
                        results.append(mapTV(tv, type: .anime))
                    } else if !isAnimation && shouldFetchTV {
                        results.append(mapTV(tv, type: .tvShow))
                    } else if isAnimation && !shouldFetchAnime && shouldFetchTV {
                        results.append(mapTV(tv, type: .tvShow))
                    }
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
                    item.isInQueue = existing.isInQueue
                    item.watchedEpisodes = existing.watchedEpisodes
                    item.totalEpisodes = existing.totalEpisodes
                    item.totalSeasons = existing.totalSeasons
                } else {
                    item.isWatched = watchedIds.contains(item.id)
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
            watchedIds.insert(item.id)
            queueIds.remove(item.id)
            recordWatchedDate()
        } else {
            watchedIds.remove(item.id)
            episodeWatchedMap.removeValue(forKey: item.id)
            allMedia[index].watchedEpisodes = 0
        }
        saveUserData()
        saveEpisodeData()
    }

    func toggleQueue(_ item: MediaItem) {
        guard let index = allMedia.firstIndex(where: { $0.id == item.id }) else { return }
        allMedia[index].isInQueue.toggle()
        if allMedia[index].isInQueue {
            queueIds.insert(item.id)
        } else {
            queueIds.remove(item.id)
            episodeQueueMap.removeValue(forKey: item.id)
        }
        saveUserData()
        saveEpisodeData()
    }

    func markWatched(_ item: MediaItem) {
        guard let index = allMedia.firstIndex(where: { $0.id == item.id }) else { return }
        allMedia[index].isWatched = true
        allMedia[index].isInQueue = false
        watchedIds.insert(item.id)
        queueIds.remove(item.id)
        recordWatchedDate()
        saveUserData()
    }

    func addToQueue(_ item: MediaItem) {
        guard let index = allMedia.firstIndex(where: { $0.id == item.id }) else { return }
        if !allMedia[index].isInQueue {
            allMedia[index].isInQueue = true
            queueIds.insert(item.id)
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
            recordWatchedDate()
        }

        if let index = allMedia.firstIndex(where: { $0.id == mediaId }) {
            allMedia[index].watchedEpisodes = episodeWatchedMap[mediaId]?.count ?? 0

            if totalEpisodes > 0 && (episodeWatchedMap[mediaId]?.count ?? 0) >= totalEpisodes {
                allMedia[index].isWatched = true
                allMedia[index].isInQueue = false
                watchedIds.insert(mediaId)
                queueIds.remove(mediaId)
            } else {
                allMedia[index].isWatched = false
                watchedIds.remove(mediaId)
            }
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
        }

        saveEpisodeData()
    }

    func markAllEpisodesWatched(mediaId: Int, keys: [String], totalEpisodes: Int) {
        episodeWatchedMap[mediaId] = Set(keys)

        if let index = allMedia.firstIndex(where: { $0.id == mediaId }) {
            allMedia[index].watchedEpisodes = keys.count
            if totalEpisodes > 0 && keys.count >= totalEpisodes {
                allMedia[index].isWatched = true
                allMedia[index].isInQueue = false
                watchedIds.insert(mediaId)
                queueIds.remove(mediaId)
            }
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
        
        recordWatchedDate()
        
        if let index = allMedia.firstIndex(where: { $0.id == mediaId }) {
            allMedia[index].watchedEpisodes = episodeWatchedMap[mediaId]?.count ?? 0
            
            if totalEpisodes > 0 && (episodeWatchedMap[mediaId]?.count ?? 0) >= totalEpisodes {
                allMedia[index].isWatched = true
                allMedia[index].isInQueue = false
                watchedIds.insert(mediaId)
                queueIds.remove(mediaId)
            }
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
            allMedia[index].watchedEpisodes = episodeWatchedMap[mediaId]?.count ?? 0
            
            let totalEpisodes = allMedia[index].totalEpisodes ?? 0
            if totalEpisodes > 0 && (episodeWatchedMap[mediaId]?.count ?? 0) < totalEpisodes {
                allMedia[index].isWatched = false
                watchedIds.remove(mediaId)
            }
        }
        
        saveUserData()
        saveEpisodeData()
    }

    func unmarkAllEpisodesWatched(mediaId: Int) {
        episodeWatchedMap.removeValue(forKey: mediaId)

        if let index = allMedia.firstIndex(where: { $0.id == mediaId }) {
            allMedia[index].watchedEpisodes = 0
            allMedia[index].isWatched = false
            watchedIds.remove(mediaId)
        }

        saveUserData()
        saveEpisodeData()
    }

    func updateMediaEpisodeInfo(mediaId: Int, totalEpisodes: Int, totalSeasons: Int) {
        guard let index = allMedia.firstIndex(where: { $0.id == mediaId }) else { return }
        allMedia[index].totalEpisodes = totalEpisodes
        allMedia[index].totalSeasons = totalSeasons
        allMedia[index].watchedEpisodes = episodeWatchedMap[mediaId]?.count ?? 0
    }

    // MARK: - IMDB Rating

    private var imdbRatingCache: [Int: Double] = [:]
    var imdbLoadingIds: Set<Int> = []

    func isLoadingImdbRating(_ itemId: Int) -> Bool {
        imdbLoadingIds.contains(itemId)
    }

    func fetchImdbRatingForItem(_ item: MediaItem) async -> Double? {
        // Check cache
        if let cached = imdbRatingCache[item.id] {
            return cached
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
                
                // Propagate to all collections
                if let index = allMedia.firstIndex(where: { $0.id == item.id }) {
                    allMedia[index].imdbRating = rating
                }
                if let index = featuredMovies.firstIndex(where: { $0.id == item.id }) {
                    featuredMovies[index].imdbRating = rating
                }
                if let index = featuredTVShows.firstIndex(where: { $0.id == item.id }) {
                    featuredTVShows[index].imdbRating = rating
                }
                if let index = featuredAnime.firstIndex(where: { $0.id == item.id }) {
                    featuredAnime[index].imdbRating = rating
                }
                if let index = searchResults.firstIndex(where: { $0.id == item.id }) {
                    searchResults[index].imdbRating = rating
                }
                if let index = genreMedia.firstIndex(where: { $0.id == item.id }) {
                    genreMedia[index].imdbRating = rating
                }
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
        saveEpisodeData()
    }

    func markEpisodeWatched(mediaId: Int, key: String, totalEpisodes: Int) {
        // Remove from queue
        episodeQueueMap[mediaId]?.remove(key)
        if episodeQueueMap[mediaId]?.isEmpty == true {
            episodeQueueMap.removeValue(forKey: mediaId)
        }

        // Add to watched
        if episodeWatchedMap[mediaId] == nil {
            episodeWatchedMap[mediaId] = []
        }
        episodeWatchedMap[mediaId]!.insert(key)

        // Update item
        if let index = allMedia.firstIndex(where: { $0.id == mediaId }) {
            allMedia[index].watchedEpisodes = episodeWatchedMap[mediaId]?.count ?? 0
            if totalEpisodes > 0 && (episodeWatchedMap[mediaId]?.count ?? 0) >= totalEpisodes {
                allMedia[index].isWatched = true
                allMedia[index].isInQueue = false
                watchedIds.insert(mediaId)
                queueIds.remove(mediaId)
            }
        }

        saveUserData()
        saveEpisodeData()
        recordWatchedDate()
    }

    // MARK: - Mapping

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
            allMedia[i].isInQueue = queueIds.contains(allMedia[i].id)
        }
    }

    private func applyEpisodeCounts() {
        for i in allMedia.indices {
            let count = episodeWatchedMap[allMedia[i].id]?.count ?? 0
            allMedia[i].watchedEpisodes = count
        }
    }

    private func loadUserData() {
        let watched = UserDefaults.standard.array(forKey: "watchedIds") as? [Int] ?? []
        let queued = UserDefaults.standard.array(forKey: "queueIds") as? [Int] ?? []
        watchedIds = Set(watched)
        queueIds = Set(queued)
    }

    private func saveUserData() {
        UserDefaults.standard.set(Array(watchedIds), forKey: "watchedIds")
        UserDefaults.standard.set(Array(queueIds), forKey: "queueIds")
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
