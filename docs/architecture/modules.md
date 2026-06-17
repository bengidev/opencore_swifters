# Module Layout

OpenCore uses feature-oriented folders inside the app target. The folders are intentionally shaped like modules so they can be promoted to internal Swift Package or Xcode framework targets later without rewriting feature boundaries.

State management for onboarding uses Gang of Four patterns (Command, Strategy, Factory Method, Facade, Observer) with `@Observable` flow controllers — not TCA.

## Module map

```text
App
├── Shared        # Theme + UI primitives (cross-cutting)
└── Onboarding    # First-run product tour
```

## Current layout

```text
OpenCore/
├── App/                      # App shell
│   ├── OpenCoreApp.swift
│   ├── AppRootView.swift
│   └── HomePlaceholderView.swift
├── Features/
│   └── Onboarding/           # Role-based
│       ├── Core/             # Flow controller, commands, strategies
│       ├── Models/
│       ├── Views/
│       └── Utilities/
└── Shared/
    ├── Theme/
    └── UI/
```

## Design patterns (Onboarding)

| Pattern | Role in onboarding |
| --- | --- |
| **Command** | `OnboardingCommand` + concrete commands encapsulate mutations |
| **Invoker** | `OnboardingCommandInvoker` executes commands |
| **Strategy** | `OnboardingPageBehaviorStrategy` applies page-specific demo defaults |
| **Factory Method** | `OnboardingPageBehaviorStrategyFactory`, `OnboardingPageVisualFactory` |
| **Facade** | `OnboardingFlowController` — single API for views |
| **Observer** | `OnboardingFlowObserving` notifies completion |
| **State** | `OnboardingFlowState` — immutable snapshot mutated only via commands |

## Access control

All types default to `internal`. Use `public` only when promoting a module to an internal framework or Swift Package boundary.
