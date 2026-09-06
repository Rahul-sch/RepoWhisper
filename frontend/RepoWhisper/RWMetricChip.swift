import SwiftUI

struct RWMetricChip: View {
    let symbol: String
    let value: String
    let label: String
    var tint: Color = RWTheme.textMuted

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
            Text(value).font(.system(size: 11, weight: .semibold, design: .rounded))
            Text(label).font(.system(size: 11)).foregroundStyle(RWTheme.textMuted)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(RWTheme.surface, in: Capsule())
        .overlay(Capsule().stroke(RWTheme.border))
        .accessibilityElement(children: .combine)
    }
}
