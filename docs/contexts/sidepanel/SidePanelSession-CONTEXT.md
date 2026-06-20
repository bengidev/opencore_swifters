# Side Panel — Session Scope

| | |
| --- | --- |
| **Context** | Side panel → session scope |
| **Code** | `OpenCore/Features/SidePanel/` (`SidePanelSession…` symbols) |
| **Parent** | [SidePanel context](./SidePanel-CONTEXT.md) |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

The session scope is the saved-conversation browser inside the side panel. It replaces the former "history chat" surface. It lists persisted conversations, groups them by recency, and lets the user open, pin, rename, delete, and group them.

## Language

- **Session** — a saved conversation as presented for browsing/resuming (was "history chat" entry). The underlying persisted thread is the `SidePanelConversation` domain type.
- **Session section** — a recency- or pin-based group of sessions (`SidePanelSessionSection`): Pinned, Today, Yesterday, Previous 7 Days, Previous 30 Days, Older, plus named user groups.
- **Session list** — the rendered, grouped list of sessions in the side panel (`SidePanelSessionSidebarView`).

## Architecture

- The session scope is its own flow controller, `@MainActor @Observable final class SidePanelSessionFlowController`. Its state (`SidePanelSessionFlowState`) owns the loaded conversation list, the search query (with a `filteredConversations` derived property), sidebar visibility, and the active-conversation id used to highlight the open thread.
- State mutations are dispatched through `SidePanelSessionCommand` protocol values (sidebar toggle, search, pin/rename/delete/group changes) via a `SidePanelSessionCommandInvoker`.
- It reads/writes persisted conversations through `SidePanelHistoryClient` (SwiftData): loading on open, and persisting pin/rename/delete before reloading the authoritative order.
- Grouping/relative-time labeling logic lives with the session scope (`SidePanelSessionSection`).
- It never touches the live chat controller directly. Instead it surfaces delegate closures the parent acts on: `onOpenConversation` (resume in chat), `onActiveConversationRenamed`, and `onActiveConversationDeleted`.
- Naming the session symbols `…Section`/`…SidebarView`/`…FlowController` follows the [file-naming rules](../../architecture/modules.md#file-naming).

## Naming convention

All session-scope symbols and files use the `SidePanelSession` prefix, then a role suffix per the [file-naming rules](../../architecture/modules.md#file-naming) — e.g. `SidePanelSessionSidebarView` (view), `SidePanelSessionSection` (value type).

## Migration note

This scope supersedes the old "history chat" naming. Former Home-scoped browsing symbols (`ChatHistorySidebarView`, `ChatHistorySection`) are renamed to `SidePanelSessionSidebarView` / `SidePanelSessionSection` and moved into `Features/SidePanel/`. Persistence types owned by Chat (`ChatHistoryClient`, `ChatHistoryEntities`) remain in `Features/Chat/`; this scope uses `SidePanelHistoryClient` as its own persistence boundary.

## Boundaries

- Owns browsing/navigation across saved sessions only — not the live stream (Chat) or the composer (Home).
- Reuse theme and UI primitives from `OpenCore/Shared`.
