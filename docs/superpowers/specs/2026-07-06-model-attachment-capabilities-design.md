# Model Attachment Capabilities Design

**Date:** 2026-07-06  
**Status:** Approved  
**Scope:** Composer attachment UX, per-model capability fetch, model picker icons

## Problem

The composer plus button is always visible and offers file/photo attachment regardless of whether the selected model accepts non-text input. Users can attach media to text-only models and only discover the mismatch at send time. The model picker also gives no visual indication of input modalities.

## Goals

1. Fetch fresh input capabilities when the user selects a model (network request).
2. Hide the plus button when the selected model is text-only; show a filtered attachment menu when it supports non-text input.
3. Disable and dim the plus button while capabilities are loading.
4. Auto-clear draft attachments when switching to a text-only model.
5. Show capability icons (e.g. eye for image) on model picker rows.

## Non-goals

- Displaying OpenRouter API `description` text in the picker.
- Per-model network fetch for every row in the model list (list/catalog data is sufficient for icons).
- Audio attachment upload via the plus menu (icon shown if supported; upload not in v1 unless already wired).

## Decisions (user-approved)

| Topic | Decision |
| --- | --- |
| Capability source | Fresh network request on model selection |
| Switch to text-only | Auto-clear draft attachments |
| Attachment menu | Filtered by supported modalities |
| While fetching | Plus button disabled and dimmed |
| Picker icons | SF Symbols on subtitle row next to context length |

## Architecture

### New types

**`ModelInputModality`** — enum: `text`, `file`, `image`, `video`, `audio`.

**`ModelInputCapabilities`** — lightweight struct:

```swift
struct ModelInputCapabilities: Equatable, Sendable {
    let inputModalities: Set<ModelInputModality>

    var supportsFileInput: Bool
    var supportsImageInput: Bool
    var supportsVideoInput: Bool
    var supportsAudioInput: Bool
    var supportsAttachments: Bool  // any modality other than .text
}
```

**`HomeModelCapabilityClient`** — mirrors `HomeModelCatalogClient`:

```swift
fetchCapabilities(
    providerID: String,
    modelID: String,
    secret: String?,
    catalogFallback: ChatModel?,
    urlSession: URLSession
) async -> ModelInputCapabilities
```

### Provider strategy

| Provider | Fetch method |
| --- | --- |
| OpenRouter | `GET /api/v1/model/{author}/{slug}` — split `modelID` on first `/` |
| OpenCode, Command Code, Ollama | No single-model endpoint; derive from cached catalog entry for `modelID` |

OpenRouter response uses `architecture.input_modalities` (e.g. `["text", "file", "image"]`). When the array is absent, fall back to legacy `architecture.modality` string parsing (`text+image+video`).

### State additions (`HomeFlowState`)

- `inputCapabilities: ModelInputCapabilities?`
- `isLoadingInputCapabilities: Bool`

### Fetch triggers

1. `HomeFlowController.selectModel(_:)` — primary
2. `onAppear` / `loadCatalog` reconcile — restore persisted selection
3. `handleProviderChanged` — reset capabilities

### Data flow

```
User selects model
  → isLoadingInputCapabilities = true
  → HomeModelCapabilityClient.fetchCapabilities(...)
  → OpenRouter: GET /model/{author}/{slug}
  → Parse input_modalities → ModelInputCapabilities
  → Update HomeFlowState
  → If text-only: chat.clearDraftAttachments()
  → isLoadingInputCapabilities = false
  → Composer reacts (hide/show/disable plus)
```

### Protocol extension

Add optional `makeModelDetailURLRequest(modelID:secret:) -> URLRequest?` to `ProviderAdapting`. OpenRouter adapter implements it; others return `nil` to signal catalog fallback.

### Parser changes (`ProviderCatalogParser`)

- Decode `architecture.input_modalities: [String]?` alongside legacy `modality`.
- Prefer `input_modalities` when present.
- Extend `ChatModel` with `supportsFileInput: Bool` (and optionally store `inputModalities` for icon rendering in the list).
- Keep existing `supportsImageInput` / `supportsVideoInput` booleans derived from modalities for backward compatibility.

## Composer behavior

### Plus button visibility

| State | Plus button |
| --- | --- |
| `isLoadingInputCapabilities` | Visible, disabled, opacity ~0.35 |
| `!supportsAttachments` | Hidden |
| `supportsAttachments` | Enabled |

### Filtered attachment menu

| Modality | Menu item | Picker |
| --- | --- | --- |
| `file` | "Import File" | `.fileImporter` (plain text, text) |
| `image` and/or `video` | "Photo Library" | `.photosPicker` filtered to supported types |

- If only one menu item is available, skip the confirmation dialog and open the picker directly.
- Existing `HomeComposerModelCapabilityLogic` validation remains as a safety net at attach/send time.

### Model switch cleanup

When fetched capabilities indicate text-only (`!supportsAttachments`), call `chat.clearDraftAttachments()` which removes files from disk via existing `ChatAttachmentStore` cleanup.

## Model picker icons

### Placement

`HomeModelPopupRow` subtitle line — after context length label, separated by a middle dot.

### Data source

Catalog list entries (parsed at catalog load). No per-row network fetch.

### Icon mapping

| Modality | SF Symbol | Accessibility |
| --- | --- | --- |
| `file` | `doc.text` | "Supports file input" |
| `image` | `eye` | "Supports image input" |
| `video` | `video` | "Supports video input" |
| `audio` | `waveform` | "Supports audio input" |

Text-only models show no icons.

### Shared component

`ModelInputCapabilityIconsView` — takes `ModelInputCapabilities` or derivable `ChatModel`, used in popup rows. Optionally on the selected-model chip in `HomeComposerContextRail` (follow-up if space allows).

### Accessibility

Append capability summary to row `accessibilityLabel` (e.g. "GPT-4o, free, supports image and file input").

## Error handling

- **Fetch fails:** Fall back to catalog-derived capabilities for the selected model. Clear loading state. Log silently; no user-facing error for capability fetch alone.
- **No API key:** Treat as text-only (hide plus); skip network fetch.
- **Model not in catalog after fetch 404:** Fall back to text-only; hide plus.

## Testing

| Area | Tests |
| --- | --- |
| `ProviderCatalogParser` | `input_modalities` array parsing; legacy `modality` fallback; `supportsFileInput` |
| `HomeModelCapabilityClient` | OpenRouter URL building; catalog fallback for non-OpenRouter providers |
| `HomeComposerModelCapabilityLogic` | Extend for `supportsFileInput`; `supportsAttachments` helper |
| `ModelInputCapabilities` | Derived boolean properties |
| UI logic (unit) | Menu item filtering; single-item skip-dialog; plus visibility rules |

## Files to touch (implementation reference)

| File | Change |
| --- | --- |
| `ProviderCatalogParser.swift` | Parse `input_modalities`; add `supportsFileInput` |
| `ChatModel.swift` | Add `supportsFileInput` field |
| `ProviderAdapting.swift` | Optional `makeModelDetailURLRequest` |
| `ProviderOpenRouterAdapter.swift` | Implement model detail URL |
| `ProviderDescriptor.swift` | `modelDetailURL(author:slug:)` helper |
| `HomeModelCapabilityClient.swift` | **New** — fetch + fallback |
| `ModelInputCapabilities.swift` | **New** — modality struct |
| `ModelInputCapabilityIconsView.swift` | **New** — icon row |
| `HomeFlowState.swift` | Capability state fields |
| `HomeFlowController.swift` | Fetch on selection; clear attachments |
| `HomeComposerPromptPanel.swift` | Plus visibility, loading, filtered menu |
| `HomeComposerIconButton.swift` | Optional `isEnabled` / dimmed style |
| `HomeModelPopupView.swift` | Icons on rows |
| `HomeComposerModelCapabilityLogic.swift` | File modality checks |
| Tests | Parser, client, logic, visibility |

## Open questions (resolved)

All questions resolved during brainstorming. No open items.
