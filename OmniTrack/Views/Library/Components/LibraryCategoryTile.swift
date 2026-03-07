import SwiftUI

struct LibraryCategoryTile: View {
    let title: String
    let count: Int
    let icon: String
    let type: MediaType
    let kind: LibraryCollectionKind
    let previewItems: [MediaItem]
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationLink(value: LibraryCollectionRoute(type: type, kind: kind)) {
            VStack(spacing: 12) {
                Spacer(minLength: 0)
                
                categoryArtwork
                
                Text("\(title) \(count)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 178)
            .background {
                ZStack {
                    Squircle(cornerRadius: 24)
                        .fill(tileGradient)
                    
                    Squircle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .opacity(colorScheme == .dark ? 0.22 : 0.55)
                }
            }
            .overlay(
                Squircle(cornerRadius: 24)
                    .stroke(.white.opacity(colorScheme == .dark ? 0.14 : 0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var categoryArtwork: some View {
        if previewItems.isEmpty {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white.opacity(0.25))
                .frame(height: 114)
        } else if previewItems.count == 1, let first = previewItems.first {
            PosterCard(item: first, width: 78, height: 112, cornerRadius: 14)
                .frame(height: 114)
        } else {
            ZStack {
                if previewItems.indices.contains(1) {
                    PosterCard(item: previewItems[1], width: 78, height: 112, cornerRadius: 14)
                        .rotationEffect(.degrees(8))
                        .offset(x: 20, y: 2)
                }
                
                PosterCard(item: previewItems[0], width: 78, height: 112, cornerRadius: 14)
                    .rotationEffect(.degrees(-7))
                    .offset(x: -16, y: -2)
            }
            .frame(height: 114)
        }
    }
    
    private var tileGradient: LinearGradient {
        let colors: [Color]
        switch type {
        case .movie:
            colors = [Color(hex: "13263A"), Color(hex: "1D3750")]
        case .tvShow:
            colors = [Color(hex: "1A233B"), Color(hex: "24344F")]
        case .anime:
            colors = [Color(hex: "163446"), Color(hex: "1F4760")]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
