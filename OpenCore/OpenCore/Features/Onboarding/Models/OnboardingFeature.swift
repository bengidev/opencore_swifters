import SwiftUI

/// A highlight card shown after the cube hero transitions into the header.
struct OnboardingFeature: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let description: String
    let userPrompt: String
    let iconName: String
    let imageName: String
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
            description: """
            Understands your workspace context locally — no cloud round trips, no network lag. \
            Models run on Apple silicon so answers stay private and feel instant.
            """,
            userPrompt: "How does on-device reasoning work?",
            iconName: "cpu",
            imageName: "OnboardingFeatureNeuralCore",
            orbStyleIndex: 0
        ),
        OnboardingFeature(
            title: "Dynamic Spatial Canvas",
            subtitle: "Multi-dimensional organization for fluid workspace mapping.",
            description: """
            Arrange notes, files, and threads in a spatial layout that mirrors how you think. \
            Pan, cluster, and refocus without losing track of where anything lives.
            """,
            userPrompt: "Can it map my workspace spatially?",
            iconName: "square.3.layers.3d",
            imageName: "OnboardingFeatureSpatialCanvas",
            orbStyleIndex: 1
        ),
        OnboardingFeature(
            title: "Autonomous Workflows",
            subtitle: "Self-healing pipelines that automate cross-tool tasks.",
            description: """
            Chain actions across apps with routines that recover on their own. \
            Set triggers once and let background pipelines handle the repetitive work.
            """,
            userPrompt: "What about automating workflows?",
            iconName: "arrow.triangle.branch",
            imageName: "OnboardingFeatureWorkflows",
            orbStyleIndex: 2
        ),
        OnboardingFeature(
            title: "Encrypted Edge Vault",
            subtitle: "Zero-knowledge security anchored to device hardware.",
            description: """
            Keys are sealed in Secure Enclave with zero-knowledge encryption. \
            Your vault stays on-device — only you hold the keys, even we cannot read it.
            """,
            userPrompt: "Is my data secure on-device?",
            iconName: "lock.shield",
            imageName: "OnboardingFeatureVault",
            orbStyleIndex: 3
        )
    ]
}
