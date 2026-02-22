import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)

                Spacer()
            }

            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(AppTheme.adaptiveCardBackground(colorScheme))
        .clipShape(Squircle(cornerRadius: 14))
    }
}
