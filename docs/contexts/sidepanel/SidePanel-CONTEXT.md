# SidePanel Feature Context

| | |
| --- | --- |
| **Code** | `OpenCore/Features/SidePanel/` |
| **Role-based layout** | `Core/`, `Models/`, `Views/`, `Utilities/` |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

The SidePanel feature manages the navigation drawer and settings menu, providing access to app-wide settings and conversation browsing.

## Folder Structure

```text
OpenCore/Features/SidePanel/
├── Core/
│   └── SidePanelFlowController.swift          # Host flow controller (composes session + setting)
├── Models/
│   ├── SidePanelConversation.swift             # Pure domain value
│   └── SidePanelConversationEntity.swift       # SwiftData entities
├── Session/
│   ├── Core/
│   │   ├── SidePanelSessionFlowController.swift # Session browser flow controller
│   │   ├── SidePanelSessionFlowState.swift
│   │   ├── SidePanelSessionSection.swift        # Recency-bucketed grouping
│   │   └── SidePanelSessionCommand.swift        # Command pattern
│   └── Views/
│       └── SidePanelSessionSidebarView.swift   # Sliding drawer
├── Setting/
│   ├── Core/
│   │   ├── SidePanelSettingFlowController.swift # Settings flow controller
│   │   ├── SidePanelSettingFlowState.swift
│   │   └── SidePanelSettingCommand.swift
│   └── Views/
│       └── SidePanelSettingView.swift          # Settings sheet
├── Utilities/
│   ├── SidePanelHistoryClient.swift            # SwiftData persistence boundary
│   ├── SidePanelCredentialStore.swift           # Keychain adapter + in-memory double
│   ├── SidePanelProviderAPI.swift              # Provider catalog
│   ├── SidePanelProviderPreferenceStore.swift  # UserDefaults preference store
│   └── SidePanelReasoningModel.swift           # Reasoning effort enum
└── Views/
    └── SidePanelView.swift                      # Host view
```

## Dependencies

**Required:**
- `OpenCore/Features/SidePanel/Utilities/` - Uses `SidePanelCredentialStore`, `SidePanelProviderPreferenceStore`, `SidePanelHistoryClient`, `SidePanelProviderAPI`, `SidePanelReasoningModel`
- `OpenCore/Shared/` - Uses `SharedOpenZonePalette`, `SharedUI` primitives

**Optional:**
- None - SidePanel is a leaf feature for navigation/settings

## State Management (Flow Controller)

The SidePanel feature uses a host flow controller that composes two sub-controllers:

```swift
@MainActor
@Observable
final class SidePanelFlowController {
    let session: SidePanelSessionFlowController
    private(set) var setting: SidePanelSettingFlowController?

    // Delegate outputs (surfaced to parent)
    var onOpenConversation: ((SidePanelConversation) -> Void)?
    var onActiveConversationRenamed: ((UUID, String) -> Void)?
    var onActiveConversationDeleted: ((UUID) -> Void)?
    var onCredentialsChanged: (() -> Void)?
    var onReasoningModelChanged: (() -> Void)?
    var onProviderChanged: ((String) -> Void)?
}
```

The host does not own its own flow state — it composes the sub-controllers' states. The session controller manages the conversation list and sidebar visibility. The setting controller is presented (`nil` when dismissed) and manages credentials, provider selection, and reasoning effort.

Each sub-controller dispatches commands against its own `*FlowState` struct:
- `SidePanelSessionFlowController` dispatches `SidePanelSessionCommand` values (sidebar toggle, search, pin/rename/delete/group changes).
- `SidePanelSettingFlowController` dispatches `SidePanelSettingCommand` values (draft API key changes) and calls store-backed methods for persistence operations (save, clear, selectReasoningModel, selectProvider).

## External Integrations

- **Provider Preferences** - `SidePanelProviderPreferenceStore` to read/write current provider selection
- **Credentials** - `SidePanelCredentialStore` to check if credentials exist, save, and clear per-provider keys
- **Conversation History** - `SidePanelHistoryClient` to load, pin, rename, delete, and group conversations via SwiftData
- **Theme** - `SharedOpenZonePalette` and `SharedUI` primitives for visual styling

## Conversation Browsing

The session scope provides:

1. **Saved Conversations** - Browse and resume past conversations grouped by recency
2. **Pin** - Pin conversations to the top of the list
3. **Rename** - Rename conversations inline
4. **Delete** - Remove conversations with confirmation
5. **Groups** - Organize conversations into named folders
6. **Search** - Filter the conversation list by title

## Cross-Feature Communication

SidePanel communicates via delegate closures surfaced to the parent (`HomeView` / `AppRootView`):

```swift
// Session scope delegates
controller.session.onOpenConversation = { conversation in
    // Resume conversation in chat
}
controller.session.onActiveConversationRenamed = { id, title in
    // Update chat header
}
controller.session.onActiveConversationDeleted = { id in
    // Clear chat if active conversation was deleted
}

// Setting scope delegates
controller.onCredentialsChanged = {
    // Refresh credential gating in parent
}
controller.onReasoningModelChanged = {
    // Reload model list / update composer chip
}
controller.onProviderChanged = { providerID in
    // Swap provider context (model list, credential gate)
}
```

## Settings Management

The setting scope displays app-wide preferences:

- **Provider** - Menu picker over `SidePanelProviderAPI.all`. Selection persisted via `SidePanelProviderPreferenceStore`.
- **API Key** - Secure text entry with save/clear. Persisted per-provider via `SidePanelCredentialStore` (Keychain).
- **Reasoning Effort** - Toggleable when the selected model supports reasoning. Persisted via `SidePanelProviderPreferenceStore`.

Custom providers are out of scope.

## Recent Architecture Changes

- Restructured into role-based subfolders (Core/Models/Views/Utilities) with Session/Setting scopes
- Migrated from TCA (`@Reducer`) to flow-controller pattern (`@MainActor @Observable final class`)
- Added `SidePanel` prefix to all types for clarity
- Removed `public` modifiers (internal access by default)
- Session and Setting each have their own command protocol for state mutations
