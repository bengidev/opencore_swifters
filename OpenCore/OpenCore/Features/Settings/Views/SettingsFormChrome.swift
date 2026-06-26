import SwiftUI

enum SettingsFormChrome {
    static func sectionHeader(_ title: String) -> some View {
        Text(title)
            .textCase(nil)
    }

    static func sectionFooter(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .textCase(nil)
    }
}
