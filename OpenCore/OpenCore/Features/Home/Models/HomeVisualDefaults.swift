import Foundation

/// Static demo values for the home visual shell before feature wiring lands.
enum HomeVisualDefaults {
    static let selectedModelTitle = "Free Models Router"
    static let contextUsage = HomeComposerContextUsage(usedTokens: 107_000, tokenLimit: 258_000)
    static let speedMode = HomeComposerSpeedMode.fast
    static let availableSpeedModes: [HomeComposerSpeedMode] = [.standard, .fast]
}
