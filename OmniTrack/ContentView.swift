import SwiftUI

enum AppTab: Hashable {
    case home
    case discover
    case library
    case profile
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView(onExplore: {
                    selectedTab = .discover
                })
            }

            Tab("Discover", systemImage: "safari.fill", value: AppTab.discover) {
                DiscoverView()
            }

            Tab("Library", systemImage: "books.vertical.fill", value: AppTab.library) {
                LibraryView()
            }

            Tab("Profile", systemImage: "chart.bar.fill", value: AppTab.profile) {
                StatsView()
            }
        }
        .tint(colorScheme == .dark ? .white : .primary)
    }
}
