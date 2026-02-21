import SwiftUI

struct ProgressRingView: View {
    let progress: Double
    let accentColor: Color
    let lineWidth: CGFloat
    let size: CGFloat

    init(progress: Double, accentColor: Color, lineWidth: CGFloat = 4, size: CGFloat = 44) {
        self.progress = progress
        self.accentColor = accentColor
        self.lineWidth = lineWidth
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(accentColor.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                .foregroundStyle(accentColor)
        }
        .frame(width: size, height: size)
    }
}
