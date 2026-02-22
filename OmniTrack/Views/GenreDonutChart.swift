import SwiftUI

struct GenreDonutChart: View {
    let slices: [GenreSlice]
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared: Bool = false

    private var total: Int {
        slices.map(\.count).reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Genre Breakdown")
                .font(.headline)

            HStack(spacing: 24) {
                ZStack {
                    ForEach(Array(sliceAngles.enumerated()), id: \.element.id) { index, slice in
                        DonutSlice(
                            startAngle: slice.start,
                            endAngle: slice.end,
                            color: Color(hex: slice.color)
                        )
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.5)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.08), value: appeared)
                    }

                    VStack(spacing: 2) {
                        Text("\(total)")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        Text("titles")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 100, height: 100)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(slices) { slice in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: slice.color))
                                .frame(width: 8, height: 8)

                            Text(slice.name)
                                .font(.caption)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text("\(slice.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.adaptiveCardBackground(colorScheme))
        .clipShape(Squircle(cornerRadius: 14))
        .onAppear { appeared = true }
    }

    private var sliceAngles: [(id: String, start: Angle, end: Angle, color: String)] {
        var result: [(id: String, start: Angle, end: Angle, color: String)] = []
        var currentAngle: Double = -90
        for slice in slices {
            let angle = Double(slice.count) / Double(max(total, 1)) * 360
            result.append((
                id: slice.name,
                start: .degrees(currentAngle),
                end: .degrees(currentAngle + angle),
                color: slice.color
            ))
            currentAngle += angle
        }
        return result
    }
}

struct DonutSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.6
        path.addArc(center: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}

extension DonutSlice: View {
    var body: some View {
        self.fill(color)
    }
}
