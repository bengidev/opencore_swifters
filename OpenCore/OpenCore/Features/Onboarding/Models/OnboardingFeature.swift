import SwiftUI

/// A feature highlight surfaced in the onboarding chat loop after the cube hero docks.
struct OnboardingFeature: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let userPrompt: String
    let iconName: String
    let orbStyleIndex: Int

    /// Monochrome orb ramps derived from the shared palette.
    func orbColors(palette: SharedOpenCorePalette) -> [Color] {
        let ramps: [[Color]]
        if palette.isDark {
            ramps = [
                [palette.textTertiary, palette.textSecondary, palette.accentPrimary],
                [palette.surfaceSubtle, palette.lineStrong, palette.accentDeep],
                [palette.lineSoft, palette.textSecondary, palette.accentPrimary],
                [palette.surfaceGalaxyTint, palette.lineStrong, palette.textPrimary.opacity(0.9)]
            ]
        } else {
            ramps = [
                [palette.textTertiary, palette.textSecondary, palette.accentDeep],
                [palette.lineStrong, palette.textSecondary, palette.accentPrimary],
                [palette.surfaceSubtle, palette.lineSoft, palette.accentDeep],
                [palette.textTertiary, palette.accentPrimary, palette.accentDeep]
            ]
        }
        return ramps[orbStyleIndex % ramps.count]
    }

    static let catalog: [OnboardingFeature] = [
        OnboardingFeature(
            title: "Intelligent Neural Core",
            subtitle: "On-device contextual reasoning with zero external latency.",
            userPrompt: "How does on-device reasoning work?",
            iconName: "cpu",
            orbStyleIndex: 0
        ),
        OnboardingFeature(
            title: "Dynamic Spatial Canvas",
            subtitle: "Multi-dimensional organization for fluid workspace mapping.",
            userPrompt: "Can it map my workspace spatially?",
            iconName: "square.3.layers.3d",
            orbStyleIndex: 1
        ),
        OnboardingFeature(
            title: "Autonomous Workflows",
            subtitle: "Self-healing pipelines that automate cross-tool tasks.",
            userPrompt: "What about automating workflows?",
            iconName: "arrow.triangle.branch",
            orbStyleIndex: 2
        ),
        OnboardingFeature(
            title: "Encrypted Edge Vault",
            subtitle: "Zero-knowledge security anchored to device hardware.",
            userPrompt: "Is my data secure on-device?",
            iconName: "lock.shield",
            orbStyleIndex: 3
        )
    ]
}
