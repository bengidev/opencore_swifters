import SwiftUI

private struct SharedPaletteKey: EnvironmentKey {
    static let defaultValue: SharedOpenCorePalette = .resolve(.light)
}

extension EnvironmentValues {
    var sharedPalette: SharedOpenCorePalette {
        get { self[SharedPaletteKey.self] }
        set { self[SharedPaletteKey.self] = newValue }
    }
}
