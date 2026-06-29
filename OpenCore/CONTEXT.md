# OpenCore Context

| | |
| --- | --- |
| **Code** | `OpenCore/` |
| **Layout** | [docs/architecture/modules.md](../docs/architecture/modules.md) |
| **Map** | [CONTEXT-MAP.md](../CONTEXT-MAP.md) |

OpenCore is the iOS app shell. Implemented feature modules: **Onboarding**, **Home**, **Chat**, **SidePanel**, **Settings**, and **About**.

## Onboarding

- **Flow controller**: `OnboardingFlowController`
- **Persistence**: `OnboardingPersistenceClient` + `OnboardingProgressEntity` (SwiftData)
- **Completion**: `AppRootView` routes to `HomeTabShellView` when `isFinished` is true

## Home

- **Flow controller**: `HomeFlowController` (model catalog, selection, tab shell state)
- **Entry views**: `HomeTabShellView` (tabs), `HomeView` (chat/welcome tab)
- **Visual shell**: `HomeWelcomeView`, `HomeParticleOrbView`, `HomeComposerView`, `HomeModelPopupView`
- **Catalog**: `HomeModelCatalogClient` + `HomeModelCatalogCachePreferenceClient`
- **Composition**: wires `ChatView` + `SidePanelView`; switches welcome vs active chat
- **Context window (display)**: `ContextWindowEstimator`, `ContextWindowUsage`
- **Speed mode**: `HomeComposerSpeedMode` (standard vs fast provider routing)

## Vision

- **Flow controller**: `VisionFlowController` copies attachments into durable storage for send
- **Composer wiring**: `HomeComposerView` plus-button attachment menu; indicators via `ChatComposerAttachmentsStripView`
- **Model input**: file paths are sent in `ChatModelInputBuilder` behind the scenes; bubbles show the media

## Speech

- **Flow controller**: `SpeechFlowController` records voice notes, keeps transcript for model input, and surfaces waveform audio attachments in the composer and chat bubble

## Settings

- **Flow controller**: `SettingsFlowController` (provider + API key + compaction prefs)
- **Entry view**: `SettingsView` + `SettingsContextWindowSection`
- **Compaction**: `SettingsContextCompactionEngine`, `SettingsContextCompactionClient` (injected into Chat)
- **Docs**: [docs/contexts/settings/Settings-CONTEXT.md](../docs/contexts/settings/Settings-CONTEXT.md)

## About

- **Entry view**: `AboutView` (app metadata + GitHub link)

## Chat

- **Flow controller**: `ChatFlowController` (commands + async send/retry/stream + compaction hook)
- **Attachments**: `ChatMessageAttachment` stores bubble media; `ChatModelInputBuilder` sends file paths and hidden speech transcripts to the model
- **Entry view**: `ChatView` (title, thread, error banner; composer stays in Home)
- **Streaming**: `ChatStreamingClient` + `ChatOpenAICompatibleStreamingClient`
- **Persistence**: `ChatHistoryClient` maps `ChatMessage` ↔ `SidePanelMessageEntity` (SwiftData)
- **Views**: `ChatView`, `ChatThreadView`, `ChatMessageRowView`, `ChatReasoningCardView`, `ChatErrorBannerView`

## SidePanel

- **Host controller**: `SidePanelFlowController`
- **Session scope**: `SidePanelSessionFlowController` (saved-conversation browser + sidebar)
- **Persistence**: `SidePanelHistoryClient` + `SidePanelConversationEntity` (SwiftData)
- **Presentation**: `SidePanelView` hosts session sidebar; `HomeView` toggles the drawer
- **Delegates**: `onOpenConversation`, `onActiveConversationRenamed`, `onActiveConversationDeleted`

Provider preferences and credentials are shared via `SidePanelProviderPreferenceStore` and `CredentialStoring` (used by Home, Chat, and Settings).
