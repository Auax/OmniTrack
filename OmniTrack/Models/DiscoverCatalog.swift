import Foundation

enum DiscoverCatalog: String, CaseIterable, Identifiable {
    case popular = "Popular"
    case new = "New"
    case featured = "Featured"

    var id: String { rawValue }
}
