# Settings Context

| | |
| --- | --- |
| **Context** | App preferences + context compaction |
| **Code** | `OpenCore/Features/Settings/` (`Settings…` symbols) |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

Top-level feature module for provider credentials, model-related prefs (via shared `ProviderPreferenceStore`), and Pi-aligned context window compaction.

## Architecture

- State lives in `SettingsFlowController`; pure field updates use `SettingsCommand` via `SettingsCommandInvoker`.
- Persistence goes through `CredentialStoring`, `ProviderPreferenceStore`, and `SettingsContextCompactionPreferenceStore` — never direct UserDefaults/Keychain from views.
- Compaction uses Strategy pattern: `SettingsContextCompactionTrimStrategy`, orchestrated by `SettingsContextCompactionEngine`.
- `SettingsContextCompactionClient` is injected into `ChatFlowController` for send-time, manual, and overflow compaction.

## Context compaction (pi.dev aligned)

Compaction follows the pi.dev append-only session tree model:

```mermaid
flowchart TD
    T["Trigger<br/>tokensUsed > contextWindow - reserveTokens"]
    C["Cut point<br/>walk backward, keep keepRecentTokens verbatim"]
    S["Summarize<br/>structured prompt + file-operation tags"]
    K["Checkpoint<br/>append AtomCompactionCheckpoint to GRDB"]
    R["Reinject<br/>projected context = summary + kept tail"]

    T --> C --> S --> K --> R
```

1. **Trigger** — automatic compaction runs when `tokensUsed > contextWindow - reserveTokens` (default reserve: 16,384).
2. **Cut point** — walk backward from the leaf, keeping `keepRecentTokens` (default 20,000) verbatim.
3. **Summarize** — structured summary prompt with cumulative file-operation tags.
4. **Checkpoint** — append `AtomCompactionCheckpoint` to the GRDB session tree.
5. **Reinject** — projected model context becomes `summary + kept tail`.

Three paths invoke the same engine:

```mermaid
flowchart LR
    subgraph triggers [Triggers]
        A["Send<br/>auto threshold"]
        M["Composer<br/>manual button"]
        O["Overflow<br/>provider error retry"]
    end

    triggers --> E[SettingsContextCompactionEngine]
    E --> CP[(GRDB checkpoint)]
    E --> UI["ChatFlowController.state.messages"]
```

### Session tree

History is never deleted. Compaction appends a checkpoint node; older message entries remain in the tree.

```mermaid
graph TD
    M1["message: old user turn"]
    M2["message: old assistant reply"]
    M3["message: recent user turn"]
    CP["compaction checkpoint<br/>summary + firstKeptEntryID"]
    M4["message: new turn after compact"]

    M1 --> M2 --> M3 --> CP --> M4
```

### Storage vs. chat thread

Atom history uses two views of the same append-only session tree:

```mermaid
flowchart TB
    subgraph tree [GRDB session tree]
        ME[message entries]
        CC[compaction checkpoints]
    end

    tree --> DV["Display view<br/>loadChatMessages"]
    tree --> PV["Projected view<br/>loadProjectedChatMessages"]

    DV --> DR["buildDisplayMessages<br/>every message entry"]
    PV --> PR["buildModelMessages<br/>latest checkpoint + kept tail"]

    DR --> AUDIT["Full raw history<br/>never deleted"]
    PR --> CHAT["Chat thread + model context<br/>summary bubble + recent messages"]
```

| View | API | Used for |
| --- | --- | --- |
| **Display** | `loadChatMessages` → `AtomSessionContextBuilder.buildDisplayMessages` | Raw message entries only; full history is never deleted |
| **Projected** | `loadProjectedChatMessages` → `AtomSessionContextBuilder.buildModelMessages` | Compaction-aware context: latest checkpoint summary + kept tail |

`ChatFlowController.reopenAtom` loads the **projected** view so resuming an atom shows the same compacted thread you had before leaving. Send-time compaction, manual compaction, and overflow recovery all persist checkpoints and update in-memory `state.messages` to the projected shape.

```mermaid
sequenceDiagram
    participant User
    participant Atoms as Atoms tab
    participant Chat as ChatFlowController
    participant Store as GRDB store

    User->>Atoms: Tap atom to resume
    Atoms->>Chat: reopenAtom(atom)
    Chat->>Store: loadProjectedChatMessages
    Note over Store: Applies latest checkpoint<br/>on leaf path
    Store-->>Chat: summary + kept tail
    Chat-->>User: Compacted thread restored
```

Synthetic summary bubbles (wrapped in `<summary>` tags) exist only in the projected view; they are derived from checkpoint entries, not duplicated as message rows in GRDB.

### User controls (`SettingsContextWindowSection`)

| Setting | Default | Purpose |
| --- | --- | --- |
| Automatic compaction | on | Master switch for threshold-triggered compaction |
| Reserve response headroom | 16,384 tokens | Pi `reserveTokens` — space left for the model reply |
| Keep recent context | 20,000 tokens | Pi `keepRecentTokens` — recent history kept verbatim |

Manual compaction is available from the composer compact button. Overflow recovery compacts once and retries the failed turn when the provider reports a context-length error.

### Token counting

`ContextTokenCounter` warms up at launch and falls back to a character heuristic before load or on failure. `ContextWindowEstimator` and `AtomSessionCompactionPlanner` share this counter.

### Split-turn compaction

When a single assistant turn exceeds `keepRecentTokens`, compaction cuts mid-turn, summarizes both the prior history and the turn prefix, and merges them into one checkpoint summary (`## Current Turn (partial)`).

```mermaid
flowchart LR
    subgraph before [Before split-turn compact]
        H[long history]
        T["assistant turn prefix…"]
        T2["…assistant turn suffix kept"]
        H --> T --> T2
    end

    subgraph after [After split-turn compact]
        S["checkpoint summary<br/>history + partial turn"]
        K["kept turn suffix"]
        S --> K
    end

    before --> after
```

## Naming

All symbols use the `Settings` prefix — e.g. `SettingsView`, `SettingsFlowController`, `SettingsContextCompactionEngine`.
