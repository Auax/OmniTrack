import SwiftUI

struct SettingsView: View {
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings
    @State private var showingClearDataAlert = false

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
                    Picker(selection: $settings.animeSource) {
                        ForEach(AnimeSource.allCases) { source in
                            Text(source.rawValue)
                                .tag(source)
                        }
                    } label: {
                        Label("Anime API", systemImage: settings.animeSource.icon)
                    }

                    Picker(selection: $settings.animeTitlePreference) {
                        ForEach(AnimeTitlePreference.allCases) { option in
                            Text(option.rawValue)
                                .tag(option)
                        }
                    } label: {
                        Label("Anime Titles", systemImage: settings.animeTitlePreference.icon)
                    }
                    .disabled(settings.animeSource == .tmdb)
                    
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
                    Text("Choose anime source, anime title language, and how long images are saved offline.")
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
                } footer: {
                    Text("Movies and TV follow the selected rating provider. Anime ratings depend on the selected Anime API.")
                }

                Section {
                    Button(role: .destructive) {
                        showingClearDataAlert = true
                    } label: {
                        Label("Remove All Saved Data", systemImage: "trash")
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Removes watchlist, watched history, and episode progress from this device.")
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
            .onChange(of: settings.animeSource) { _, _ in
                reloadMediaData()
            }
            .onChange(of: settings.animeTitlePreference) { _, _ in
                reloadMediaData()
            }
            .alert("Remove All Saved Data?", isPresented: $showingClearDataAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    mediaService.clearAllSavedData()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    private func reloadMediaData() {
        Task {
            await mediaService.loadContent(
                showMovies: settings.showMovies,
                showTVShows: settings.showTVShows,
                showAnime: settings.showAnime
            )
        }
    }
}
