import SwiftUI

@main
struct OmniTrackApp: App {
    @State private var mediaService = MediaService()
    @State private var settingsManager = SettingsManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(mediaService)
                .environment(settingsManager)
                .preferredColorScheme(settingsManager.preferredColorScheme)
        }
    }
}
