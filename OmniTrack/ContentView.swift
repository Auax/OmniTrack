import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeView()
            }

            Tab("Library", systemImage: "books.vertical.fill") {
                LibraryView()
            }

            Tab("Stats", systemImage: "chart.bar.fill") {
                StatsView()
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .tint(colorScheme == .dark ? .white : .primary)
    }
}
