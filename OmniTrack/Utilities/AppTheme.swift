import SwiftUI

enum AppTheme {
    static let creamBackground = Color(red: 0.97, green: 0.95, blue: 0.91)
    static let creamSecondary = Color(red: 0.93, green: 0.90, blue: 0.85)
    static let creamTertiary = Color(red: 0.88, green: 0.85, blue: 0.80)

    static func adaptiveBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.04) : creamBackground
    }

    static func adaptiveSecondary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.10) : creamSecondary
    }

    static func adaptiveTertiary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.15) : creamTertiary
    }

    static func adaptiveCardBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.08) : .white
    }
}
