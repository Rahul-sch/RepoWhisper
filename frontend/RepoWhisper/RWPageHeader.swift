import SwiftUI

struct RWPageHeader<Trailing: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: () -> Trailing

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(RWTheme.accentBright)
                Text(title)
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .foregroundStyle(RWTheme.text)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(RWTheme.textMuted)
            }
            Spacer(minLength: 16)
            trailing()
        }
        .accessibilityElement(children: .contain)
    }
}
