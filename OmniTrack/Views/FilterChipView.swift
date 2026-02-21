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
            .background(isSelected ? Color.primary : Color.clear)
            .foregroundStyle(isSelected
                ? (colorScheme == .dark ? Color.black : Color.white)
                : Color.primary
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(.primary.opacity(isSelected ? 0 : 0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
