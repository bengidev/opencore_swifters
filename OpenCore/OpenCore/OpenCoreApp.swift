import SwiftData
import SwiftUI

@main
struct OpenCoreApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @State private var onboardingFlow: OnboardingFlowController
    @State private var atoms: AtomsFlowController
    @State private var home: HomeFlowController
    @State private var chat: ChatFlowController
    @State private var settings: SettingsFlowController
    @State private var speech: SpeechFlowController
    @State private var vision: VisionFlowController

    private let modelContainer: ModelContainer
    private let grdbDatabase: PersistenceGRDBDatabase
    private let atomHistoryStore: PersistenceAtomHistoryStore

    init() {
        let modelContainer = Self.makeModelContainer()
        self.modelContainer = modelContainer

        let grdbDatabase: PersistenceGRDBDatabase
        do {
            grdbDatabase = try PersistenceGRDBDatabase.make()
            try PersistenceAtomHistoryStore.migrateSwiftDataIfNeeded(
                database: grdbDatabase,
                modelContainer: modelContainer
            )
        } catch {
            fatalError("Could not create GRDB database: \(error)")
        }
        self.grdbDatabase = grdbDatabase

        let atomHistoryStore = PersistenceAtomHistoryStore.live(database: grdbDatabase)
        self.atomHistoryStore = atomHistoryStore

        _onboardingFlow = State(
            initialValue: OnboardingFlowController(
                persistence: .live(modelContainer: modelContainer)
            )
        )
        let credentialStore = CredentialKeychainStore(service: CredentialKeychainStore.openCoreService)
        let providerPreference = UserDefaultsProviderPreferenceStore()
        let contextCompactionPreference = SettingsUserDefaultsContextCompactionPreferenceStore()
        _atoms = State(
            initialValue: AtomsFlowController(history: .live(store: atomHistoryStore))
        )

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
            history: .live(store: atomHistoryStore),
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
            AtomEntity.self,
            AtomMessageEntity.self
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
                    atoms: atoms,
                    home: home,
                    chat: chat,
                    settings: settings,
                    speech: speech,
                    vision: vision
                )
            }
            .task {
                await onboardingFlow.onAppear()
                await ContextTokenCounter.warmUp()
                await sweepExpiredVoiceAttachmentsIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await sweepExpiredVoiceAttachmentsIfNeeded()
                }
            }
        }
        .modelContainer(modelContainer)
    }

    @MainActor
    private func sweepExpiredVoiceAttachmentsIfNeeded() async {
        do {
            try PersistenceAtomHistoryStore.sweepExpiredVoiceAttachments(
                database: grdbDatabase
            )
        } catch {
            assertionFailure("Voice attachment retention sweep failed: \(error)")
        }
    }
}
