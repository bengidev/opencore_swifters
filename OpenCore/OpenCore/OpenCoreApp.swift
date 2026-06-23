import SwiftData
import SwiftUI

@main
struct OpenCoreApp: App {
    @AppStorage(SharedAppTheme.storageKey) private var sharedAppThemeRaw = SharedAppTheme.system.rawValue
    @State private var onboardingFlow: OnboardingFlowController
    @State private var sidePanel: SidePanelFlowController
    @State private var home: HomeFlowController
    @State private var chat: ChatFlowController

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
        let credentialStore = SidePanelKeychainCredentialStore(service: SidePanelKeychainCredentialStore.openCoreService)
        let providerPreference = SidePanelUserDefaultsProviderPreferenceStore()
        let session = SidePanelSessionFlowController(history: .live(modelContainer: modelContainer))
        _sidePanel = State(initialValue: SidePanelFlowController(
            session: session,
            credentialStore: credentialStore,
            providerPreference: providerPreference
        ))
        _home = State(initialValue: HomeFlowController(
            credentialStore: credentialStore,
            providerPreference: providerPreference
        ))
        _chat = State(initialValue: ChatFlowController(
            streaming: .live(credentialStore: credentialStore),
            history: .live(modelContainer: modelContainer),
            providerPreference: providerPreference
        ))
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

    private var resolvedPalette: SharedOpenZonePalette {
        .resolve(resolvedColorScheme ?? systemColorScheme)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                onboardingFlow: onboardingFlow,
                sidePanel: sidePanel,
                home: home,
                chat: chat,
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
