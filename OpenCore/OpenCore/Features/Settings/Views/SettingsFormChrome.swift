import SwiftUI

enum SettingsFormChrome {
    static func sectionHeader(_ title: String) -> some View {
        Text(title)
            .textCase(nil)
    }

    struct SectionFooter: View {
        let text: String

        @Environment(\.sharedPalette) private var palette

        var body: some View {
            Text(text)
                .foregroundStyle(palette.textSecondary)
                .textCase(nil)
        }
    }
}
