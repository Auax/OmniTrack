import SwiftUI

struct EpisodeSkeletonCard: View {
    let width: CGFloat
    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.gray.opacity(0.2))
            .frame(width: width, height: 190)
            .opacity(isAnimating ? 0.4 : 0.8)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}
