import Foundation

/// Static demo values for the home visual shell before feature wiring lands.
enum HomeVisualDefaults {
    static let selectedModelTitle = "Free Models Router"
    static let contextUsage = ContextWindowUsage.zero
    static let speedMode = HomeComposerSpeedMode.fast
    static let availableSpeedModes: [HomeComposerSpeedMode] = [.standard, .fast]
}
