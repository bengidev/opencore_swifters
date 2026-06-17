# OpenCore Context

| | |
| --- | --- |
| **Code** | `OpenCore/` |
| **Layout** | [docs/architecture/modules.md](../docs/architecture/modules.md) |
| **Map** | [CONTEXT-MAP.md](../CONTEXT-MAP.md) |

OpenCore is the iOS app shell. The first implemented feature module is **Onboarding** — a five-page product tour duplicated from OpenZone Swifters, reimplemented without TCA using GoF patterns and TDD.

## Onboarding

- **Flow controller**: `OnboardingFlowController` (Facade)
- **Persistence**: `OnboardingPersistenceClient` + `OnboardingProgressEntity` (SwiftData)
- **Completion**: `AppRootView` routes to `HomePlaceholderView` when `isFinished` is true
