import SwiftUI

struct RWPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(RWTheme.accentGradient, in: RoundedRectangle(cornerRadius: RWTheme.controlRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: RWTheme.controlRadius).stroke(.white.opacity(0.16)))
            .shadow(color: RWTheme.accent.opacity(configuration.isPressed ? 0.12 : 0.28), radius: 12, y: 5)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

struct RWSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(RWTheme.text)
            .padding(.horizontal, 13)
            .frame(minHeight: 36)
            .background(configuration.isPressed ? RWTheme.surfaceHover : RWTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: RWTheme.compactRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: RWTheme.compactRadius).stroke(RWTheme.border))
    }
}
