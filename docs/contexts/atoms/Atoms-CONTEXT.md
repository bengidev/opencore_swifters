# Atoms Context

| | |
| --- | --- |
| **Context** | Saved-conversation browser (the Atoms tab) |
| **Code** | `OpenCore/Features/Atoms/` (`Atoms…` symbols) |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

## Glossary

- **Atom** — one saved conversation: metadata (`Atom`) plus its ordered messages
- **Atom list entry** — an `Atom` with its last message preview and timestamp, the row model of `AtomsListView`
- **Group** — a user-named folder that atoms can be filed under (`groupName`)

An atom persists in two stores. `AtomEntity` and `AtomMessageEntity` (SwiftData) hold the atom record and its messages. The GRDB session tree (`session_entries`) holds the append-only message and compaction history that powers context compaction. `AtomsHistoryClient` is the interface the feature uses, backed by `PersistenceAtomHistoryStore.live`.

## Browser

`AtomsFlowController` (`@MainActor`, `@Observable`) owns `AtomsFlowState` and mutates it through `AtomsCommand` values dispatched by `AtomsCommandInvoker`. The list supports search (title or preview), pin (pinned atoms lead the list and leave the date buckets), rename, delete, and per-atom groups.

## Wiring

Delegate closures surface to `HomeTabShellView`:

- `onOpenAtom` — switch to the Home tab and call `ChatFlowController.reopenAtom`
- `onActiveAtomRenamed` — rename the active atom in `ChatFlowController`
- `onActiveAtomDeleted` — clear the active conversation when the deleted atom was active
