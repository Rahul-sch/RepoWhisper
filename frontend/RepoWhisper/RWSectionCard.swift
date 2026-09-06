import SwiftUI

struct RWSectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let symbol: String
    @ViewBuilder let content: () -> Content

    init(title: String, subtitle: String? = nil, symbol: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RWTheme.accentBright)
                    .frame(width: 28, height: 28)
                    .background(RWTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(RWTheme.text)
                    if let subtitle {
                        Text(subtitle).font(.system(size: 11)).foregroundStyle(RWTheme.textMuted)
                    }
                }
            }
            content()
        }
        .padding(18)
        .rwGlass()
    }
}
