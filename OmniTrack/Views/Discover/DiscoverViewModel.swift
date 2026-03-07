import SwiftUI
import Observation
import Combine

@MainActor
@Observable
final class DiscoverViewModel {
    var searchText: String = "" {
        didSet {
            searchTextSubject.send(searchText)
        }
    }
    
    var selectedType: MediaType? = nil
    var selectedCatalog: DiscoverCatalog = .popular
    var selectedGenre: String? = nil
    var selectedItem: MediaItem?

    private var searchTextSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()
    private var activeLoadTask: Task<Void, Never>?

    var isSearchingQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var spotlightTitle: String {
        selectedCatalog == .new ? "New Releases" : "Trending Now"
    }

    func setupSearchDebounce(mediaService: MediaService) {
        searchTextSubject
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                self?.loadData(reset: true, mediaService: mediaService)
            }
            .store(in: &cancellables)
    }

    func availableGenres(mediaService: MediaService, settings: SettingsManager) -> [String] {
        mediaService.discoverGenreNames(includeAniListGenres: settings.animeSource == .aniList)
    }

    func trendingPreviewItems(mediaService: MediaService) -> [MediaItem] {
        Array(mediaService.discoverMedia.prefix(8))
    }

    func gridItems(mediaService: MediaService) -> [MediaItem] {
        if isSearchingQuery {
            return mediaService.discoverMedia
        }

        let trendingCount = trendingPreviewItems(mediaService: mediaService).count
        let remainder = Array(mediaService.discoverMedia.dropFirst(trendingCount))
        return remainder.isEmpty ? mediaService.discoverMedia : remainder
    }

    func loadData(reset: Bool, mediaService: MediaService) {
        activeLoadTask?.cancel()
        activeLoadTask = Task { @MainActor in
            let genreId = selectedGenre.flatMap { mediaService.genreIdForName($0) }
            await mediaService.loadDiscover(
                reset: reset,
                type: selectedType,
                catalog: selectedCatalog,
                genreId: genreId,
                query: searchText
            )
        }
    }

    func loadMore(mediaService: MediaService) {
        guard activeLoadTask == nil || activeLoadTask?.isCancelled == true else { return }
        activeLoadTask = Task { @MainActor in
            let genreId = selectedGenre.flatMap { mediaService.genreIdForName($0) }
            await mediaService.loadDiscover(
                reset: false,
                type: selectedType,
                catalog: selectedCatalog,
                genreId: genreId,
                query: searchText
            )
            activeLoadTask = nil
        }
    }
}
