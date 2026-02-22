import SwiftUI

struct FilterChipView: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.9))
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(isSelected ? Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14) : Color.clear)
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected
                            ? Color.accentColor.opacity(colorScheme == .dark ? 0.6 : 0.45)
                            : Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.14),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
