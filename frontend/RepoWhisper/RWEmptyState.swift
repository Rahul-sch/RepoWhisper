import SwiftUI

struct RWEmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(RWTheme.accentBright)
                .frame(width: 52, height: 52)
                .background(RWTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(RWTheme.text)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(RWTheme.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(30)
        .accessibilityElement(children: .combine)
    }
}
