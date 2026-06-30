import SwiftUI

/// Resolves palette and color scheme from the app theme using the live system scheme.
///
/// Must wrap app content inside `WindowGroup` so `@Environment(\.colorScheme)` reflects the device.
struct SharedThemedRootView<Content: View>: View {
    @AppStorage(SharedAppTheme.storageKey) private var sharedAppThemeRaw = SharedAppTheme.system.rawValue
    @Environment(\.colorScheme) private var systemColorScheme

    @ViewBuilder let content: () -> Content

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
        content()
            .environment(\.sharedPalette, resolvedPalette)
            .environment(\.sharedAppTheme, sharedAppTheme)
            .environment(\.onThemeToggle, toggleTheme)
            .preferredColorScheme(sharedAppTheme.preferredColorScheme(systemScheme: systemColorScheme))
    }

    private func toggleTheme() {
        sharedAppThemeRaw = sharedAppTheme.next.rawValue
    }
}
