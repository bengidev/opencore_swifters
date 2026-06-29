import SwiftData
import SwiftUI

@main
struct OpenCoreApp: App {
    @AppStorage(SharedAppTheme.storageKey) private var sharedAppThemeRaw = SharedAppTheme.system.rawValue
    @State private var onboardingFlow: OnboardingFlowController
    @State private var sidePanel: SidePanelFlowController
    @State private var home: HomeFlowController
    @State private var chat: ChatFlowController
    @State private var settings: SettingsFlowController
    @State private var speech: SpeechFlowController
    @State private var vision: VisionFlowController

    @Environment(\.colorScheme) private var systemColorScheme

    private let modelContainer: ModelContainer

    init() {
        let modelContainer = Self.makeModelContainer()
        self.modelContainer = modelContainer
        _onboardingFlow = State(
            initialValue: OnboardingFlowController(
                persistence: .live(modelContainer: modelContainer)
            )
        )
        let credentialStore = CredentialKeychainStore(service: CredentialKeychainStore.openCoreService)
        let providerPreference = SidePanelUserDefaultsProviderPreferenceStore()
        let contextCompactionPreference = SettingsUserDefaultsContextCompactionPreferenceStore()
        let session = SidePanelSessionFlowController(history: .live(modelContainer: modelContainer))
        _sidePanel = State(initialValue: SidePanelFlowController(session: session))

        let homeController = HomeFlowController(
            credentialStore: credentialStore,
            providerPreference: providerPreference
        )
        _home = State(initialValue: homeController)

        let summarizer = SettingsContextCompactionStreamSummarizer(
            streaming: .live(credentialStore: credentialStore),
            providerPreference: providerPreference
        )
        let compactionEngine = SettingsContextCompactionEngine(summarizer: summarizer)
        let contextCompaction = SettingsContextCompactionClient.live(
            engine: compactionEngine,
            preferenceStore: contextCompactionPreference
        )

        _chat = State(initialValue: ChatFlowController(
            streaming: .live(credentialStore: credentialStore),
            history: .live(modelContainer: modelContainer),
            providerPreference: providerPreference,
            contextCompaction: contextCompaction,
            contextLengthResolver: {
                homeController.state.selectedModelOption?.contextLength ?? 0
            }
        ))

        _settings = State(initialValue: SettingsFlowController(
            credentialStore: credentialStore,
            providerPreference: providerPreference,
            contextCompactionPreference: contextCompactionPreference
        ))

        _speech = State(initialValue: SpeechFlowController(recognition: .live()))
        _vision = State(initialValue: VisionFlowController())
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            OnboardingProgressEntity.self,
            SidePanelConversationEntity.self,
            SidePanelMessageEntity.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    private var sharedAppTheme: SharedAppTheme {
        SharedAppTheme(rawValue: sharedAppThemeRaw) ?? .system
    }

    private var resolvedColorScheme: ColorScheme? {
        switch sharedAppTheme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    private var resolvedPalette: SharedOpenCorePalette {
        .resolve(resolvedColorScheme ?? systemColorScheme)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                onboardingFlow: onboardingFlow,
                sidePanel: sidePanel,
                home: home,
                chat: chat,
                settings: settings,
                speech: speech,
                vision: vision,
                onThemeToggle: toggleTheme
            )
            .environment(\.sharedPalette, resolvedPalette)
            .environment(\.sharedAppTheme, sharedAppTheme)
            .preferredColorScheme(resolvedColorScheme)
            .task {
                await onboardingFlow.onAppear()
            }
        }
        .modelContainer(modelContainer)
    }

    private func toggleTheme() {
        sharedAppThemeRaw = sharedAppTheme.next.rawValue
    }
}
