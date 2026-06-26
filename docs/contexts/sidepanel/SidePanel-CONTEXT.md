# SidePanel Feature Context

| | |
| --- | --- |
| **Code** | `OpenCore/Features/SidePanel/` |
| **Role-based layout** | `Core/`, `Models/`, `Views/`, `Utilities/` |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

The SidePanel feature manages the navigation drawer for conversation browsing.

## Folder Structure

```text
OpenCore/Features/SidePanel/
├── Core/
│   └── SidePanelFlowController.swift          # Host flow controller (session only)
├── Models/
│   ├── SidePanelConversation.swift
│   └── SidePanelConversationEntity.swift
├── Session/
│   ├── Core/
│   │   ├── SidePanelSessionFlowController.swift
│   │   ├── SidePanelSessionFlowState.swift
│   │   ├── SidePanelSessionSection.swift
│   │   └── SidePanelSessionCommand.swift
│   └── Views/
│       └── SidePanelSessionSidebarView.swift
├── Utilities/
│   ├── SidePanelHistoryClient.swift
│   ├── SidePanelProviderPreferenceStore.swift
│   └── ModelReasoningEffort.swift
└── Views/
    └── SidePanelView.swift
```

Settings moved to the top-level **Settings** module (`OpenCore/Features/Settings/`). See [Settings context](../settings/Settings-CONTEXT.md).

## Dependencies

**Required:**
- `OpenCore/Features/SidePanel/Utilities/` - Uses `SidePanelCredentialStore`, `SidePanelProviderPreferenceStore`, `SidePanelHistoryClient`, `SidePanelProviderAPI`, `SidePanelReasoningModel`
- `OpenCore/Shared/` - Uses `SharedOpenCorePalette`, `SharedUI` primitives

**Optional:**
- None - SidePanel is a leaf feature for navigation/settings

## State Management (Flow Controller)

The SidePanel feature uses a host flow controller for the session scope:

```swift
@MainActor
@Observable
final class SidePanelFlowController {
    let session: SidePanelSessionFlowController

    var onOpenConversation: ((SidePanelConversation) -> Void)?
    var onActiveConversationRenamed: ((UUID, String) -> Void)?
    var onActiveConversationDeleted: ((UUID) -> Void)?
}
```

The session controller manages the conversation list and sidebar visibility.

`SidePanelSessionFlowController` dispatches `SidePanelSessionCommand` values (sidebar toggle, search, pin/rename/delete/group changes).

## External Integrations

- **Provider Preferences** - `SidePanelProviderPreferenceStore` to read/write current provider selection
- **Credentials** - `SidePanelCredentialStore` to check if credentials exist, save, and clear per-provider keys
- **Conversation History** - `SidePanelHistoryClient` to load, pin, rename, delete, and group conversations via SwiftData
- **Theme** - `SharedOpenCorePalette` and `SharedUI` primitives for visual styling

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
- Adopted flow-controller pattern (`@MainActor @Observable final class`)
- Added `SidePanel` prefix to all types for clarity
- Removed `public` modifiers (internal access by default)
- Session and Setting each have their own command protocol for state mutations
