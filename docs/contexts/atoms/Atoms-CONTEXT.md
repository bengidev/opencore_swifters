# Atoms Context

| | |
| --- | --- |
| **Context** | Saved-conversation browser |
| **Code** | `OpenCore/Features/Atoms/` (`Atoms…` symbols) |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

Top-level feature module for browsing saved conversations: search, pin, rename, groups, and delete.

## Architecture

- State lives in `AtomsFlowController` (`AtomsFlowState`); every mutation goes through an explicit `AtomsCommand` executed by `AtomsCommandInvoker` — not TCA.
- Persistence goes through `AtomsHistoryClient` over the shared `PersistenceAtomHistoryStore` (GRDB) — the same append-only session tree Chat writes to.
- `AtomsSection.Kind` is a typed enum (pinned, named group, created-date bucket). The section `id` derives from the kind and ignores the expansion flag, so section identity stays stable across expand/collapse.

## Delegates

The parent (`HomeTabShellView`) drives live chat through three callbacks:

- `onOpenAtom` — fired by `selectAtom(_:)` when an atom is tapped
- `onActiveAtomRenamed` — fired by `renameAtom(id:title:)` only when the renamed atom is the active one
- `onActiveAtomDeleted` — fired by `deleteAtom(id:)` only when the deleted atom is the active one

Callbacks fire from the mutating methods themselves, not from command dispatch, and only for the active atom. Background atoms persist silently. The active atom is owned by `ChatFlowState.atom`; the list mirrors it via `mirrorActiveAtomID(_:)`.

## Presentation

`AtomsListView` (pinned, named groups, created-date buckets) hosted as the Atoms tab in `HomeTabShellView`.

## Naming

All symbols use the `Atoms` prefix — e.g. `AtomsListView`, `AtomsFlowController`, `AtomsHistoryClient`.
