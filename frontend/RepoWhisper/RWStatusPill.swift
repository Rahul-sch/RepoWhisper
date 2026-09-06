import SwiftUI

struct RWStatusPill: View {
    let title: String
    let color: Color
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 7) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
            } else {
                Circle().fill(color).frame(width: 6, height: 6)
            }
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(symbol == nil ? RWTheme.textMuted : color)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(color.opacity(0.10), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.18)))
        .accessibilityElement(children: .combine)
    }
}
