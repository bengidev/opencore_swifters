# OpenCore Context

| | |
| --- | --- |
| **Code** | `OpenCore/` |
| **Layout** | [docs/architecture/modules.md](../docs/architecture/modules.md) |
| **Map** | [CONTEXT-MAP.md](../CONTEXT-MAP.md) |

OpenCore is the iOS app shell. The first implemented feature module is **Onboarding** — a five-page first-run product tour.

## Onboarding

- **Flow controller**: `OnboardingFlowController`
- **Persistence**: `OnboardingPersistenceClient` + `OnboardingProgressEntity` (SwiftData)
- **Completion**: `AppRootView` routes to `HomePlaceholderView` when `isFinished` is true
