import SwiftUI

struct RWGlassSurface: ViewModifier {
    var radius: CGFloat = RWTheme.cardRadius
    var emphasized = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(emphasized ? RWTheme.surfaceStrong : RWTheme.surface)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(emphasized ? RWTheme.borderStrong : RWTheme.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }
}

extension View {
    func rwGlass(radius: CGFloat = RWTheme.cardRadius, emphasized: Bool = false) -> some View {
        modifier(RWGlassSurface(radius: radius, emphasized: emphasized))
    }
}
