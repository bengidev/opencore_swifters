import SwiftUI

/// Theme preference: system, light, or dark.
enum SharedAppTheme: String, Equatable, Sendable {
    case system
    case light
    case dark

    static let storageKey = "sharedAppTheme"

    func resolveColorScheme(_ systemScheme: ColorScheme) -> ColorScheme {
        switch self {
        case .system: return systemScheme
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// `nil` lets the system drive appearance when theme is `.system`.
    func preferredColorScheme(systemScheme: ColorScheme) -> ColorScheme? {
        self == .system ? nil : resolveColorScheme(systemScheme)
    }

    var next: SharedAppTheme {
        switch self {
        case .system: .light
        case .light: .dark
        case .dark: .system
        }
    }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var isDark: Bool {
        self == .dark
    }
}

private struct SharedAppThemeKey: EnvironmentKey {
    static let defaultValue: SharedAppTheme = .system
}

extension EnvironmentValues {
    var sharedAppTheme: SharedAppTheme {
        get { self[SharedAppThemeKey.self] }
        set { self[SharedAppThemeKey.self] = newValue }
    }
}

private struct OnThemeToggleKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var onThemeToggle: () -> Void {
        get { self[OnThemeToggleKey.self] }
        set { self[OnThemeToggleKey.self] = newValue }
    }
}
