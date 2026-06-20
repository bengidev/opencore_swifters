# OpenCore Context

| | |
| --- | --- |
| **Code** | `OpenCore/` |
| **Layout** | [docs/architecture/modules.md](../docs/architecture/modules.md) |
| **Map** | [CONTEXT-MAP.md](../CONTEXT-MAP.md) |

OpenCore is the iOS app shell. Implemented feature modules: **Onboarding** (first-run tour) and **Home** (welcome + composer visual shell).

## Onboarding

- **Flow controller**: `OnboardingFlowController`
- **Persistence**: `OnboardingPersistenceClient` + `OnboardingProgressEntity` (SwiftData)
- **Completion**: `AppRootView` routes to `HomeView` when `isFinished` is true

## Home

- **Entry view**: `HomeView`
- **Visual shell**: `HomeWelcomeView`, `HomeParticleOrbView`, `HomeComposerView`
- **Demo defaults**: `HomeVisualDefaults` (static model label, context usage, speed mode)
- **Scope**: visual layout only — sidebar, chat, model catalog, and send flow are not wired yet

## SidePanel

- **Host controller**: `SidePanelFlowController`
- **Session scope**: `SidePanelSessionFlowController` (saved-conversation browser + sidebar)
- **Setting scope**: `SidePanelSettingFlowController` (settings sheet: provider + API key + reasoning)
- **Persistence**: `SidePanelHistoryClient` + `SidePanelConversationEntity` (SwiftData), `SidePanelCredentialStore` (Keychain), `SidePanelProviderPreferenceStore` (UserDefaults)
- **Presentation**: `SidePanelView` hosts session sidebar + settings sheet; `HomeView` owns the controller and toggles the drawer
- **Delegates**: `onOpenConversation`, `onActiveConversationRenamed`/`onActiveConversationDeleted`, `onCredentialsChanged`, `onReasoningModelChanged`, `onProviderChanged`
