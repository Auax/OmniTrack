import Foundation

enum Config {
    static var TMDB_API_KEY: String {
        return Bundle.main.infoDictionary?["TMDB_API_KEY"] as? String ?? "TMDB_API_KEY_NOT_FOUND"
    }

    static var OMDB_API_KEY: String {
        return Bundle.main.infoDictionary?["OMDB_API_KEY"] as? String ?? ""
    }
}

