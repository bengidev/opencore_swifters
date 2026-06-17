# Module Layout

OpenCore uses feature-oriented folders inside the app target. The folders are intentionally shaped like modules so they can be promoted to internal Swift Package or Xcode framework targets later without rewriting feature boundaries.

Onboarding flow state is owned by `OnboardingFlowController` and mutated through explicit commands — not TCA.

## Module map

```text
App
├── Shared        # Theme + UI primitives (cross-cutting)
└── Onboarding    # First-run product tour
```

## Current layout

```text
OpenCore/
├── OpenCoreApp.swift         # @main entry point
├── App/                      # App shell
│   ├── AppRootView.swift
│   └── HomePlaceholderView.swift
├── Features/
│   └── Onboarding/           # Role-based
│       ├── Core/             # Flow controller, commands, flow state
│       ├── Models/
│       ├── Views/
│       └── Utilities/
└── Shared/
    ├── Theme/
    └── UI/
```

## Role-based folders

Each feature organizes files by responsibility:

- `Core/` — flow controller, commands, flow state
- `Models/` — domain types and SwiftData entities
- `Views/` — SwiftUI screens and visual components
- `Utilities/` — persistence clients, visual builders

Folder names describe product roles, not design-pattern names.

## Access control

All types default to `internal`. Use `public` only when promoting a module to an internal framework or Swift Package boundary.
