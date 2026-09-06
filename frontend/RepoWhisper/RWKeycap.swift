import SwiftUI

struct RWKeycap: View {
    let keys: String

    var body: some View {
        Text(keys)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(RWTheme.textMuted)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(RWTheme.border))
            .accessibilityLabel("Keyboard shortcut (keys)")
    }
}
