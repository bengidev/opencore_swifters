import SwiftData
import SwiftUI

@main
struct OpenCoreApp: App {
    @AppStorage(SharedAppTheme.storageKey) private var sharedAppThemeRaw = SharedAppTheme.system.rawValue
    @State private var onboardingFlow: OnboardingFlowController
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
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            OnboardingProgressEntity.self
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
