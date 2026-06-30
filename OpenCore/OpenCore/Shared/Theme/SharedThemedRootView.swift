import SwiftUI

/// Resolves palette and color scheme from the app theme using the live system scheme.
///
/// Must wrap app content inside `WindowGroup` so `@Environment(\.colorScheme)` reflects the device.
struct SharedThemedRootView<Content: View>: View {
    @AppStorage(SharedAppTheme.storageKey) private var sharedAppThemeRaw = SharedAppTheme.system.rawValue
    @Environment(\.colorScheme) private var systemColorScheme

    @ViewBuilder let content: (_ theme: SharedAppTheme, _ onThemeToggle: @escaping () -> Void) -> Content

    private var sharedAppTheme: SharedAppTheme {
        SharedAppTheme(rawValue: sharedAppThemeRaw) ?? .system
    }

    private var effectiveColorScheme: ColorScheme {
        sharedAppTheme.resolveColorScheme(systemColorScheme)
    }

    private var resolvedPalette: SharedOpenCorePalette {
        .resolve(effectiveColorScheme)
    }

    var body: some View {
        content(sharedAppTheme, toggleTheme)
            .environment(\.sharedPalette, resolvedPalette)
            .environment(\.sharedAppTheme, sharedAppTheme)
            .preferredColorScheme(sharedAppTheme == .system ? nil : effectiveColorScheme)
    }

    private func toggleTheme() {
        sharedAppThemeRaw = sharedAppTheme.next.rawValue
    }
}
