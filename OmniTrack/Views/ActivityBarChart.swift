import SwiftUI

struct ActivityBarChart: View {
    let data: [DayActivity]
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared: Bool = false

    private var maxCount: Int {
        data.map(\.count).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Activity")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, day in
                    VStack(spacing: 4) {
                        // Value label above bar
                        if day.count > 0 {
                            Text(formattedTime(day.count))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.05 + 0.3), value: appeared)
                        } else {
                            Text("")
                                .font(.system(size: 9))
                        }

                        // Bar
                        RoundedRectangle(cornerRadius: 5)
                            .fill(
                                LinearGradient(
                                    colors: day.count > 0
                                        ? [.blue.opacity(0.5), .blue]
                                        : [Color.gray.opacity(0.15), Color.gray.opacity(0.15)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(
                                height: appeared
                                    ? max(4, CGFloat(day.count) / CGFloat(max(1, maxCount)) * 90)
                                    : 4
                            )
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.7)
                                .delay(Double(index) * 0.05),
                                value: appeared
                            )

                        Text(day.day)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 130)
        }
        .padding(16)
        .background(AppTheme.adaptiveCardBackground(colorScheme))
        .clipShape(Squircle(cornerRadius: 14))
        .onAppear { appeared = true }
    }

    private func formattedTime(_ episodes: Int) -> String {
        // Approximate: ~45min per episode
        let totalMinutes = episodes * 45
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h\(mins)m"
        }
        return "\(totalMinutes)m"
    }
}
