import SwiftUI

struct RWBrandMark: View {
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(RWTheme.accentGradient)
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: RWTheme.accent.opacity(0.30), radius: size * 0.28, y: size * 0.12)
        .accessibilityLabel("RepoWhisper")
    }
}
