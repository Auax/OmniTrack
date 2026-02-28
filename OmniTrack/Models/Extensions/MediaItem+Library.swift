import Foundation

extension Sequence where Element == MediaItem {
    func sortedForLibrary() -> [MediaItem] {
        self.sorted { lhs, rhs in
            if lhs.year != rhs.year {
                return lhs.year > rhs.year
            }
            if lhs.rating != rhs.rating {
                return lhs.rating > rhs.rating
            }
            return lhs.title.localizedCompare(rhs.title) == .orderedAscending
        }
    }
}
