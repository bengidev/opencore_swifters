import SwiftData
import SwiftUI

@main
struct OpenCoreApp: App {
    @State private var onboardingFlow: OnboardingFlowController
    @State private var sidePanel: SidePanelFlowController
    @State private var home: HomeFlowController
    @State private var chat: ChatFlowController
    @State private var settings: SettingsFlowController
    @State private var speech: SpeechFlowController
    @State private var vision: VisionFlowController

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

        _speech = State(initialValue: SpeechFlowController(
            recognition: .live(
                credentialStore: credentialStore,
                providerPreference: providerPreference
            )
        ))
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

    var body: some Scene {
        WindowGroup {
            SharedThemedRootView {
                AppRootView(
                    onboardingFlow: onboardingFlow,
                    sidePanel: sidePanel,
                    home: home,
                    chat: chat,
                    settings: settings,
                    speech: speech,
                    vision: vision
                )
            }
            .task {
                await onboardingFlow.onAppear()
                do {
                    try PersistenceConversationHistoryStore.sweepExpiredVoiceAttachments(
                        modelContainer: modelContainer
                    )
                } catch {
                    assertionFailure("Voice attachment retention sweep failed: \(error)")
                }
            }
        }
        .modelContainer(modelContainer)
    }
}
