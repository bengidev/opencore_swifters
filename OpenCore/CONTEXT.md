# OpenCore Context

| | |
| --- | --- |
| **Code** | `OpenCore/` |
| **Layout** | [docs/architecture/modules.md](../docs/architecture/modules.md) |
| **Map** | [CONTEXT-MAP.md](../CONTEXT-MAP.md) |

OpenCore is the iOS app shell. Implemented feature modules: **Onboarding** (first-run tour), **Home** (welcome + composer shell), **Chat** (live streaming), and **SidePanel** (history + settings).

## Onboarding

- **Flow controller**: `OnboardingFlowController`
- **Persistence**: `OnboardingPersistenceClient` + `OnboardingProgressEntity` (SwiftData)
- **Completion**: `AppRootView` routes to `HomeView` when `isFinished` is true

## Home

- **Flow controller**: `HomeFlowController` (model catalog, selection, send gating)
- **Entry view**: `HomeView`
- **Visual shell**: `HomeWelcomeView`, `HomeParticleOrbView`, `HomeComposerView`, `HomeModelPopupView`
- **Catalog**: `HomeModelCatalogClient` + `HomeModelCatalogCachePreferenceClient`
- **Composition**: owns `ChatFlowController` + `SidePanelFlowController`; switches welcome vs thread layout
- **ContextWindow** (sub-module): `ContextWindowEstimator`, `ContextWindowUsage`
- **SpeedMode** (sub-module): `HomeComposerSpeedMode` (standard vs fast provider routing)

## Chat

- **Flow controller**: `ChatFlowController` (commands + async send/retry/stream)
- **Streaming**: `ChatStreamingClient` + `ChatOpenAICompatibleStreamingClient`
- **Persistence**: `ChatHistoryClient` maps `ChatMessage` ↔ `SidePanelMessageEntity` (SwiftData)
- **Views**: `ChatThreadView`, `ChatMessageRowView`, `ChatReasoningCardView`, `ChatErrorBannerView`

## SidePanel

- **Host controller**: `SidePanelFlowController`
- **Session scope**: `SidePanelSessionFlowController` (saved-conversation browser + sidebar)
- **Setting scope**: `SidePanelSettingFlowController` (settings sheet: provider + API key + reasoning)
- **Persistence**: `SidePanelHistoryClient` + `SidePanelConversationEntity` (SwiftData), `SidePanelCredentialStore` (Keychain), `SidePanelProviderPreferenceStore` (UserDefaults)
- **Presentation**: `SidePanelView` hosts session sidebar + settings sheet; `HomeView` owns the controller and toggles the drawer
- **Delegates**: `onOpenConversation`, `onActiveConversationRenamed`/`onActiveConversationDeleted`, `onCredentialsChanged`, `onReasoningModelChanged`, `onProviderChanged`
