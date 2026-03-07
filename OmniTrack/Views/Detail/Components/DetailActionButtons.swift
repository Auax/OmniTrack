import SwiftUI

struct DetailActionButtons: View {
    let currentItem: MediaItem
    let hasEpisodesLoaded: Bool
    let allEpisodeKeys: [String]
    let totalEpisodesCount: Int

    @Environment(MediaService.self) private var mediaService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            watchButtonControl

            Button {
                withAnimation(.snappy) {
                    mediaService.toggleQueue(currentItem)
                }
            } label: {
                Label(
                    currentItem.isInQueue ? "In Watchlist" : "Watchlist",
                    systemImage: currentItem.isInQueue ? "plus.circle.fill" : "plus.circle"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(DetailButtonGlassBackground(activeTint: currentItem.isInQueue ? .orange : nil, colorScheme: colorScheme))
                .foregroundStyle(currentItem.isInQueue ? .orange : .primary)
                .clipShape(Squircle(cornerRadius: 12))
            }
            .sensoryFeedback(.impact, trigger: currentItem.isInQueue)
        }
    }

    @ViewBuilder
    private var watchButtonControl: some View {
        if currentItem.hasSeasonsAndEpisodes {
            if currentItem.isWatched || currentItem.isInProgress {
                Button {
                    withAnimation(.snappy) {
                        unmarkCurrentItemWatchState()
                    }
                } label: {
                    Label(
                        currentItem.isWatched ? "Completed" : "In Progress",
                        systemImage: currentItem.isWatched ? "checkmark" : "play.circle.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(DetailButtonGlassBackground(activeTint: currentItem.isWatched ? .green : .blue, colorScheme: colorScheme))
                    .foregroundStyle(currentItem.isWatched ? .green : .blue)
                    .clipShape(Squircle(cornerRadius: 12))
                }
                .sensoryFeedback(.impact, trigger: currentItem.isWatched || currentItem.isInProgress)
            } else {
                Menu {
                    Button {
                        withAnimation(.snappy) {
                            markCurrentItemCompleted()
                        }
                    } label: {
                        Label("Mark completed", systemImage: "checkmark.circle")
                    }

                    Button {
                        withAnimation(.snappy) {
                            mediaService.toggleInProgress(currentItem)
                        }
                    } label: {
                        Label("In progress", systemImage: "play.circle")
                    }
                } label: {
                    Label("Watch", systemImage: "eye")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DetailButtonGlassBackground(activeTint: nil, colorScheme: colorScheme))
                        .foregroundStyle(.primary)
                        .clipShape(Squircle(cornerRadius: 12))
                }
            }
        } else {
            Button {
                withAnimation(.snappy) {
                    mediaService.toggleWatched(currentItem)
                }
            } label: {
                Label(
                    currentItem.isWatched ? "Watched" : "Watch",
                    systemImage: currentItem.isWatched ? "checkmark" : "eye"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(DetailButtonGlassBackground(activeTint: currentItem.isWatched ? .green : nil, colorScheme: colorScheme))
                .foregroundStyle(currentItem.isWatched ? .green : .primary)
                .clipShape(Squircle(cornerRadius: 12))
            }
            .sensoryFeedback(.impact, trigger: currentItem.isWatched)
        }
    }

    private func unmarkCurrentItemWatchState() {
        if currentItem.hasSeasonsAndEpisodes {
            if currentItem.isWatched {
                mediaService.toggleWatched(currentItem)
                return
            }
            if currentItem.isInProgress {
                if mediaService.watchedEpisodeCount(mediaId: currentItem.id) > 0 {
                    mediaService.unmarkAllEpisodesWatched(mediaId: currentItem.id)
                    if mediaService.allMedia.first(where: { $0.id == currentItem.id })?.isInProgress == true {
                        mediaService.toggleInProgress(currentItem)
                    }
                    return
                }
                mediaService.toggleInProgress(currentItem)
                return
            }
            mediaService.unmarkAllEpisodesWatched(mediaId: currentItem.id)
        } else if currentItem.isWatched {
            mediaService.toggleWatched(currentItem)
        } else if currentItem.isInProgress {
            mediaService.toggleInProgress(currentItem)
        }
    }

    private func markCurrentItemCompleted() {
        if currentItem.hasSeasonsAndEpisodes {
            if hasEpisodesLoaded && !allEpisodeKeys.isEmpty {
                mediaService.markAllEpisodesWatched(
                    mediaId: currentItem.id,
                    keys: allEpisodeKeys,
                    totalEpisodes: totalEpisodesCount
                )
            } else if let total = currentItem.totalEpisodes, total > 0 {
                let syntheticKeys = (1...total).map { "s1e\($0)" }
                mediaService.markAllEpisodesWatched(
                    mediaId: currentItem.id,
                    keys: syntheticKeys,
                    totalEpisodes: total
                )
            } else {
                mediaService.markWatched(currentItem)
            }
        } else {
            mediaService.markWatched(currentItem)
        }
    }

}

struct DetailButtonGlassBackground: View {
    let activeTint: Color?
    let colorScheme: ColorScheme

    var body: some View {
        Squircle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .overlay {
                Squircle(cornerRadius: 12)
                    .fill((activeTint ?? .white).opacity(activeTint == nil ? (colorScheme == .dark ? 0.10 : 0.22) : 0.18))
            }
            .overlay {
                Squircle(cornerRadius: 12)
                    .stroke(.white.opacity(colorScheme == .dark ? 0.24 : 0.40), lineWidth: 1)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.08), radius: 8, y: 3)
    }
}
