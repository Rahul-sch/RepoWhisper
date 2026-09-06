import SwiftUI

struct RWAmbientBackground: View {
    var body: some View {
        ZStack {
            RWTheme.canvas
            RadialGradient(
                colors: [RWTheme.accent.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 520
            )
            RadialGradient(
                colors: [RWTheme.cyan.opacity(0.08), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 440
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
