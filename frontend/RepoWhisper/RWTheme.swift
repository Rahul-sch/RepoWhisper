import SwiftUI

enum RWTheme {
    static let canvas = Color(red: 0.025, green: 0.030, blue: 0.045)
    static let canvasRaised = Color(red: 0.045, green: 0.052, blue: 0.075)
    static let surface = Color.white.opacity(0.065)
    static let surfaceStrong = Color.white.opacity(0.10)
    static let surfaceHover = Color.white.opacity(0.13)
    static let border = Color.white.opacity(0.11)
    static let borderStrong = Color.white.opacity(0.19)
    static let text = Color.white.opacity(0.96)
    static let textMuted = Color.white.opacity(0.62)
    static let textFaint = Color.white.opacity(0.40)
    static let accent = Color(red: 0.38, green: 0.52, blue: 1.0)
    static let accentBright = Color(red: 0.52, green: 0.68, blue: 1.0)
    static let cyan = Color(red: 0.30, green: 0.82, blue: 0.96)
    static let success = Color(red: 0.33, green: 0.84, blue: 0.64)
    static let warning = Color(red: 1.0, green: 0.72, blue: 0.30)
    static let danger = Color(red: 1.0, green: 0.39, blue: 0.46)

    static let pagePadding: CGFloat = 28
    static let sectionSpacing: CGFloat = 20
    static let cardRadius: CGFloat = 18
    static let controlRadius: CGFloat = 12
    static let compactRadius: CGFloat = 9

    static let accentGradient = LinearGradient(
        colors: [accentBright, accent, Color(red: 0.49, green: 0.35, blue: 0.96)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
