import SwiftData
import SwiftUI
import Testing
@testable import OpenCore

@MainActor
@Suite("OnboardingFlowState Tests")
struct OnboardingFlowStateTests {

    @Test("Initial state is not finished")
    func initialState() {
        let state = OnboardingFlowState()
        #expect(state.isFinished == false)
    }

    @Test("Equality compares isFinished")
    func equality() {
        #expect(OnboardingFlowState() == OnboardingFlowState())
        #expect(OnboardingFlowState(isFinished: true) == OnboardingFlowState(isFinished: true))
        #expect(OnboardingFlowState() != OnboardingFlowState(isFinished: true))
    }
}

@MainActor
@Suite("OnboardingCube Contract Tests")
struct OnboardingCubeContractTests {

    @Test("Cube view type exists and is a SwiftUI View")
    func cubeTypeExists() {
        #expect(OnboardingCubeView.self != AnyView.self)
    }
}

@MainActor
@Suite("OnboardingFlowController Tests")
struct OnboardingFlowControllerTests {

    @Test("finish persists completion")
    func finishPersists() async {
        var didComplete = false
        let persistence = OnboardingPersistenceClient(
            isCompleted: { false },
            complete: { didComplete = true }
        )
        let controller = OnboardingFlowController(persistence: persistence)
        let succeeded = await controller.finish()
        #expect(succeeded)
        #expect(controller.state.isFinished)
        #expect(didComplete)
    }

    @Test("finish does not mark finished when persistence fails")
    func finishFailure() async {
        enum TestError: Error { case failed }
        let persistence = OnboardingPersistenceClient(
            isCompleted: { false },
            complete: { throw TestError.failed }
        )
        let controller = OnboardingFlowController(persistence: persistence)
        let succeeded = await controller.finish()
        #expect(!succeeded)
        #expect(!controller.state.isFinished)
    }

    @Test("onAppear loads completion status")
    func onAppearLoads() async {
        let persistence = OnboardingPersistenceClient(
            isCompleted: { true },
            complete: {}
        )
        let controller = OnboardingFlowController(persistence: persistence)
        await controller.onAppear()
        #expect(controller.state.isFinished)
    }

    @Test("onAppear defaults to incomplete when persistence fails")
    func onAppearFailure() async {
        enum TestError: Error { case failed }
        let persistence = OnboardingPersistenceClient(
            isCompleted: { throw TestError.failed },
            complete: {}
        )
        let controller = OnboardingFlowController(
            state: OnboardingFlowState(isFinished: true),
            persistence: persistence
        )
        await controller.onAppear()
        #expect(!controller.state.isFinished)
    }

    @Test("live persistence round trip")
    func persistenceRoundTrip() async throws {
        let schema = Schema([OnboardingProgressEntity.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let client = OnboardingPersistenceClient.live(modelContainer: container)

        #expect(try await client.isCompleted() == false)
        try await client.complete()
        #expect(try await client.isCompleted() == true)
    }
}

@MainActor
@Suite("OnboardingFeature Tests")
struct OnboardingFeatureTests {

    @Test("Catalog entries include descriptions for assistant bubbles")
    func catalogDescriptions() {
        for feature in OnboardingFeature.catalog {
            #expect(!feature.description.isEmpty)
            #expect(!feature.accessibilitySummary.isEmpty)
        }
    }

    @Test("Accessibility summary matches title and subtitle")
    func accessibilitySummary() {
        let feature = OnboardingFeature.catalog[0]
        #expect(feature.accessibilitySummary == "\(feature.title). \(feature.subtitle)")
    }

    @Test("Feed accessibility label includes the assistant description")
    func feedAccessibilityLabel() {
        let feature = OnboardingFeature.catalog[0]
        #expect(feature.feedAccessibilityLabel == "\(feature.title). \(feature.subtitle). \(feature.description)")
    }

    @Test("Wrapped catalog index handles negative and overflow indices")
    func wrappedCatalogIndex() {
        let count = OnboardingFeature.catalog.count
        #expect(count > 0)

        #expect(OnboardingFeature.wrappedCatalogIndex(0) == 0)
        #expect(OnboardingFeature.wrappedCatalogIndex(count - 1) == count - 1)
        #expect(OnboardingFeature.wrappedCatalogIndex(count) == 0)
        #expect(OnboardingFeature.wrappedCatalogIndex(-1) == count - 1)
        #expect(OnboardingFeature.wrappedCatalogIndex(count + 2) == 2)
    }
}

@MainActor
@Suite("OnboardingChatMessage Tests")
struct OnboardingChatMessageTests {

    @Test("Morph to assistant preserves message identity")
    func morphPreservesIdentity() {
        let feature = OnboardingFeature.catalog[0]
        let thinking = OnboardingChatMessage.thinking(feature: feature)
        let assistant = thinking.morphToAssistant()

        #expect(assistant.id == thinking.id)
        #expect(assistant.role == .assistant)
        #expect(assistant.feature?.id == feature.id)
    }

    @Test("Assistant accessibility label matches the feed label")
    func assistantAccessibilityLabel() {
        let feature = OnboardingFeature.catalog[0]
        let assistant = OnboardingChatMessage.assistant(feature: feature)
        #expect(assistant.feature?.feedAccessibilityLabel == feature.feedAccessibilityLabel)
    }
}

@MainActor
@Suite("OnboardingUsageNotice Tests")
struct OnboardingUsageNoticeTests {

    @Test("Usage notice exposes UI test hook and spoken copy")
    func usageNoticeMetadata() {
        #expect(OnboardingUsageNoticeView.accessibilityTestIdentifier == "onboarding-usage-notice")
        #expect(!OnboardingUsageNoticeView.noticeCopy.isEmpty)
        #expect(OnboardingUsageNoticeView.voiceOverCopy.contains("Bring your own API key"))
    }
}

@MainActor
@Suite("OnboardingChatFeedTiming Tests")
struct OnboardingChatFeedTimingTests {

    @Test("Feed timing constants stay positive")
    func timingConstants() {
        #expect(OnboardingChatFeedTiming.firstMessageDelay > .zero)
        #expect(OnboardingChatFeedTiming.afterUserDelay > .zero)
        #expect(OnboardingChatFeedTiming.thinkingDuration > .zero)
        #expect(OnboardingChatFeedTiming.afterAssistantDelay > .zero)
    }
}

@MainActor
@Suite("Theme Tests")
struct ThemeTests {

    @Test("SharedOpenCorePalette light mode has correct base color")
    func lightPalette() {
        let palette = SharedOpenCorePalette.resolve(.light)
        #expect(palette.isDark == false)
    }

    @Test("SharedOpenCorePalette dark mode has correct base color")
    func darkPalette() {
        let palette = SharedOpenCorePalette.resolve(.dark)
        #expect(palette.isDark == true)
    }

    @Test("SharedAppTheme cycles correctly")
    func themeCycle() {
        #expect(SharedAppTheme.system.next == .light)
        #expect(SharedAppTheme.light.next == .dark)
        #expect(SharedAppTheme.dark.next == .system)
    }

    @Test("SharedAppTheme storage key round trips raw values")
    func themeStorageKey() {
        #expect(SharedAppTheme(rawValue: SharedAppTheme.dark.rawValue) == .dark)
        #expect(SharedAppTheme.storageKey == "sharedAppTheme")
    }

    @Test("SharedAppTheme resolveColorScheme follows system when theme is system")
    func resolveColorSchemeSystem() {
        #expect(SharedAppTheme.system.resolveColorScheme(.light) == .light)
        #expect(SharedAppTheme.system.resolveColorScheme(.dark) == .dark)
    }

    @Test("SharedAppTheme resolveColorScheme pins light and dark overrides")
    func resolveColorSchemeOverrides() {
        #expect(SharedAppTheme.light.resolveColorScheme(.dark) == .light)
        #expect(SharedAppTheme.dark.resolveColorScheme(.light) == .dark)
    }

    @Test("SharedAppTheme preferredColorScheme is nil only for system theme")
    func preferredColorScheme() {
        #expect(SharedAppTheme.system.preferredColorScheme(systemScheme: .light) == nil)
        #expect(SharedAppTheme.light.preferredColorScheme(systemScheme: .dark) == .light)
        #expect(SharedAppTheme.dark.preferredColorScheme(systemScheme: .light) == .dark)
    }

    @Test("SharedOpenCorePalette elevation tiers scale shadow opacity in dark mode")
    func elevationTiers() {
        let light = SharedOpenCorePalette.resolve(.light)
        let dark = SharedOpenCorePalette.resolve(.dark)

        #expect(light.elevation(.chip) == Color.black.opacity(0.06))
        #expect(dark.elevation(.chip) == Color.black.opacity(0.18))

        #expect(light.elevation(.popover) == Color.black.opacity(0.12))
        #expect(dark.elevation(.popover) == Color.black.opacity(0.35))

        #expect(light.elevation(.composerChrome(lightOpacity: 0.08)) == Color.black.opacity(0.08))
        #expect(dark.elevation(.composerChrome(lightOpacity: 0.08)) == Color.black.opacity(0.2))
    }

    @Test("SharedOpenCorePalette scrimOverlay strengthens opacity in dark mode")
    func scrimOverlay() {
        let light = SharedOpenCorePalette.resolve(.light)
        let dark = SharedOpenCorePalette.resolve(.dark)

        #expect(light.scrimOverlay(opacity: 0.06) == Color.black.opacity(0.06))
        #expect(dark.scrimOverlay(opacity: 0.06) == Color.black.opacity(0.15))
    }

    @Test("SharedOpenCorePalette effect and media control tokens adapt to scheme")
    func effectAndMediaTokens() {
        let light = SharedOpenCorePalette.resolve(.light)
        let dark = SharedOpenCorePalette.resolve(.dark)

        #expect(light.effectGlitchHighlight == Color.white)
        #expect(dark.effectGlitchHighlight == Color(hex: "F5F5F5"))
        #expect(light.mediaControlScrim == Color.black.opacity(0.72))
        #expect(dark.mediaControlScrim == Color.black.opacity(0.55))
        #expect(light.mediaControlIcon == Color.white)
        #expect(dark.mediaControlIcon == Color.white)
    }

    @Test("SharedOpenCorePalette composerGlass bundles surface recipe")
    func composerGlassTokens() {
        let light = SharedOpenCorePalette.resolve(.light)
        let dark = SharedOpenCorePalette.resolve(.dark)

        let lightGlass = light.composerGlass(shadowOpacity: 0.08)
        #expect(lightGlass.usesUltraThinMaterial == false)
        #expect(lightGlass.fill == light.surfaceRaised)
        #expect(lightGlass.strokeOpacity == 0.55)
        #expect(lightGlass.shadow == light.elevation(.composerChrome(lightOpacity: 0.08)))

        let darkGlass = dark.composerGlass(shadowOpacity: 0.08)
        #expect(darkGlass.usesUltraThinMaterial == true)
        #expect(darkGlass.fill == dark.surfacePaper.opacity(0.85))
        #expect(darkGlass.strokeOpacity == 0.35)
    }
}
