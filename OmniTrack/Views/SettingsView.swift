import SwiftUI

struct SettingsView: View {
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 16) {
                        HStack(spacing: 0) {
                            ForEach(ThemeMode.allCases, id: \.rawValue) { mode in
                                Button {
                                    withAnimation(.snappy) {
                                        settings.themeMode = mode
                                    }
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: mode.icon)
                                            .font(.title3)
                                            .frame(width: 48, height: 48)
                                            .background(
                                                settings.themeMode == mode
                                                    ? Color.primary.opacity(0.12)
                                                    : Color.clear
                                            )
                                            .clipShape(Circle())

                                        Text(mode.rawValue)
                                            .font(.caption.weight(.medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(settings.themeMode == mode ? .primary : .secondary)
                                }
                                .buttonStyle(.plain)
                                .sensoryFeedback(.selection, trigger: settings.themeMode)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Appearance")
                }

                Section {
                    Toggle(isOn: $settings.showMovies) {
                        Label("Movies", systemImage: "film")
                    }
                    .tint(.blue)
                    
                    Toggle(isOn: $settings.showTVShows) {
                        Label("TV Shows", systemImage: "tv")
                    }
                    .tint(.blue)
                    
                    Toggle(isOn: $settings.showAnime) {
                        Label("Anime", systemImage: "sparkles.tv")
                    }
                    .tint(.blue)

                    Picker(selection: $settings.animeTitlePreference) {
                        ForEach(AnimeTitlePreference.allCases) { option in
                            Text(option.rawValue)
                                .tag(option)
                        }
                    } label: {
                        Label("Anime Titles", systemImage: settings.animeTitlePreference.icon)
                    }
                    
                    Picker(selection: $settings.imageCacheDuration) {
                        ForEach(ImageCacheDuration.allCases) { duration in
                            Text(duration.rawValue)
                                .tag(duration)
                        }
                    } label: {
                        Label("Image Cache", systemImage: "photo.badge.arrow.down")
                    }
                } header: {
                    Text("Content")
                } footer: {
                    Text("Choose media types, anime title language, and how long images are saved offline.")
                }

                Section {
                    Picker(selection: $settings.ratingProvider) {
                        ForEach(RatingProvider.allCases) { provider in
                            Text(provider.rawValue)
                                .tag(provider)
                        }
                    } label: {
                        Text("Rating Provider")
                    }
                    .tint(.secondary)
                } header: {
                    Text("Ratings")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Data Source")
                        Spacer()
                        Text("TMDB + AniList")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Author")
                        Spacer()
                        Text("Ibai Farina")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
