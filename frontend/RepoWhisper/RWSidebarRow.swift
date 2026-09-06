import SwiftUI

struct RWSidebarRow: View {
    let item: RWNavigation
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 18)
            Text(item.title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            Spacer()
        }
        .foregroundStyle(isSelected ? RWTheme.text : RWTheme.textMuted)
        .padding(.horizontal, 11)
        .frame(height: 36)
        .background(isSelected ? RWTheme.surfaceStrong : .clear, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? RWTheme.borderStrong : .clear)
        )
        .contentShape(Rectangle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
