# Settings Context

| | |
| --- | --- |
| **Context** | App preferences + context compaction |
| **Code** | `OpenCore/Features/Settings/` (`Settings…` symbols) |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

Top-level feature module for provider credentials, model-related prefs (via shared `SidePanelProviderPreferenceStore`), and automatic context window compaction.

## Architecture

- State lives in `SettingsFlowController`; pure field updates use `SettingsCommand` via `SettingsCommandInvoker`.
- Persistence goes through `CredentialStoring`, `SidePanelProviderPreferenceStore`, and `SettingsContextCompactionPreferenceStore` — never direct UserDefaults/Keychain from views.
- Compaction uses Strategy pattern: `SettingsContextCompactionTrimStrategy`, `SettingsContextCompactionSummarizeStrategy`, orchestrated by `SettingsContextCompactionEngine`.
- `SettingsContextCompactionClient` is injected into `ChatFlowController` for send-time compaction.

## Context compaction

- Default trigger: **90%** of model context window (`SettingsContextCompactionPreference.triggerThresholdPercent`).
- User adjusts threshold and enable flag in `SettingsContextWindowSection`.
- When triggered before send/retry, compaction replaces thread messages (and persisted history) with a summary system message plus recent tail.

## Naming

All symbols use the `Settings` prefix — e.g. `SettingsView`, `SettingsFlowController`, `SettingsContextCompactionEngine`.
