import SwiftData
import SwiftUI
import Testing
@testable import OpenCore

@MainActor
@Suite("Onboarding Domain Tests")
struct OnboardingDomainTests {

    @Test("OnboardingPage.all has 5 pages in correct order")
    func pageCount() {
        #expect(OnboardingPage.all.count == 5)
        #expect(OnboardingPage.all[0].type == .encryptedPairing)
        #expect(OnboardingPage.all[1].type == .ideaStudio)
        #expect(OnboardingPage.all[2].type == .promptQueue)
        #expect(OnboardingPage.all[3].type == .reasoningControl)
        #expect(OnboardingPage.all[4].type == .workspaceReady)
    }

    @Test("OnboardingPage has unique IDs")
    func pageIDs() {
        let ids = OnboardingPage.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("OnboardingPromptOption has 3 samples")
    func promptOptions() {
        #expect(OnboardingPromptOption.samples.count == 3)
        #expect(OnboardingPromptOption.samples[0].label == "ASK")
        #expect(OnboardingPromptOption.samples[1].label == "WRITE")
        #expect(OnboardingPromptOption.samples[2].label == "EXPLORE")
    }

    @Test("OnboardingQueueItem has 4 samples with correct statuses")
    func queueItems() {
        #expect(OnboardingQueueItem.samples.count == 4)
        #expect(OnboardingQueueItem.samples[0].status == .running)
        #expect(OnboardingQueueItem.samples[1].status == .next)
        #expect(OnboardingQueueItem.samples[2].status == .queued)
        #expect(OnboardingQueueItem.samples[3].status == .ready)
    }

    @Test("OnboardingPageType has all cases")
    func pageTypes() {
        #expect(OnboardingPageType.allCases.count == 5)
    }
}

@MainActor
@Suite("OnboardingFlowState Tests")
struct OnboardingFlowStateTests {

    @Test("Initial state is page 0, not finished")
    func initialState() {
        let state = OnboardingFlowState()
        #expect(state.currentPage == 0)
        #expect(state.isFinished == false)
        #expect(state.totalPages == 5)
        #expect(state.isLastPage == false)
    }
}

@MainActor
@Suite("Onboarding Command Tests")
struct OnboardingCommandTests {

    private var invoker: OnboardingCommandInvoker {
        OnboardingCommandInvoker()
    }

    @Test("AdvancePageCommand advances page")
    func advancePage() {
        var state = OnboardingFlowState()
        invoker.invoke(OnboardingAdvancePageCommand(), on: &state)
        #expect(state.currentPage == 1)
    }

    @Test("RetreatPageCommand goes back")
    func retreatPage() {
        var state = OnboardingFlowState(currentPage: 1)
        invoker.invoke(OnboardingRetreatPageCommand(), on: &state)
        #expect(state.currentPage == 0)
    }

    @Test("RetreatPageCommand clamps at 0")
    func retreatClamp() {
        var state = OnboardingFlowState()
        invoker.invoke(OnboardingRetreatPageCommand(), on: &state)
        #expect(state.currentPage == 0)
    }

    @Test("SelectPageCommand jumps to index")
    func selectPage() {
        var state = OnboardingFlowState()
        invoker.invoke(OnboardingSelectPageCommand(index: 3), on: &state)
        #expect(state.currentPage == 3)
    }

    @Test("SkipToLastPageCommand jumps to last page")
    func skip() {
        var state = OnboardingFlowState()
        invoker.invoke(OnboardingSkipToLastPageCommand(), on: &state)
        #expect(state.currentPage == state.totalPages - 1)
    }

    @Test("SelectPromptChipCommand updates selection")
    func promptChip() {
        var state = OnboardingFlowState()
        invoker.invoke(OnboardingSelectPromptChipCommand(index: 2), on: &state)
        #expect(state.selectedPromptIndex == 2)
    }

    @Test("IncrementQueueCommand increments count")
    func addQueue() {
        var state = OnboardingFlowState()
        invoker.invoke(OnboardingIncrementQueueCommand(), on: &state)
        #expect(state.queuedPromptCount == 3)
    }

    @Test("SetReasoningLevelCommand clamps value")
    func reasoningClamp() {
        var state = OnboardingFlowState()
        invoker.invoke(OnboardingSetReasoningLevelCommand(level: 1.5), on: &state)
        #expect(state.reasoningLevel == 1.0)
        invoker.invoke(OnboardingSetReasoningLevelCommand(level: -0.5), on: &state)
        #expect(state.reasoningLevel == 0.0)
    }

    @Test("TogglePairingCommand toggles state")
    func pairingToggle() {
        var state = OnboardingFlowState()
        #expect(state.pairingConfirmed == true)
        invoker.invoke(OnboardingTogglePairingCommand(), on: &state)
        #expect(state.pairingConfirmed == false)
    }
}

@MainActor
@Suite("OnboardingFlowController Tests")
struct OnboardingFlowControllerTests {

    @Test("dispatch advances page through facade")
    func facadeAdvance() {
        let controller = OnboardingFlowController(persistence: .preview)
        controller.dispatch(OnboardingAdvancePageCommand())
        #expect(controller.state.currentPage == 1)
    }

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
