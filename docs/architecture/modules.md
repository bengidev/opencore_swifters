# Module Layout

OpenCore uses feature-oriented folders inside the app target. The folders are intentionally shaped like modules so they can be promoted to internal Swift Package or Xcode framework targets later without rewriting feature boundaries.

Onboarding flow state is owned by `OnboardingFlowController` and mutated through explicit commands — not TCA.

## Module map

```text
App
├── Shared        # Theme + UI primitives (cross-cutting)
├── Onboarding    # First-run product tour
├── SidePanel     # Conversation browser + settings (self-contained internal module)
├── Chat          # Live message stream, send/receive, active conversation (ChatView — thread + error banner)
└── Home          # Welcome hero + composer chatbox (wires Chat + SidePanel)
```

## Current layout

```text
OpenCore/
├── OpenCoreApp.swift         # @main entry point
├── App/                      # App shell
│   └── AppRootView.swift
├── Features/
│   ├── Onboarding/           # Role-based
│   │   ├── Core/
│   │   ├── Models/
│   │   ├── Views/
│   │   └── Utilities/
│   ├── Home/
│   │   ├── Core/
│   │   ├── Models/           # HomeModelOption, ContextWindowUsage, HomeComposerSpeedMode
│   │   ├── Utilities/        # HomeModelCatalogClient, ContextWindowEstimator
│   │   └── Views/
│   ├── Chat/
│   │   ├── Core/
│   │   ├── Models/
│   │   ├── Views/
│   │   └── Utilities/
│   └── SidePanel/
│       ├── Core/
│       ├── Models/
│       ├── Utilities/
│       ├── Session/
│       │   ├── Core/
│       │   └── Views/
│       ├── Setting/
│       │   ├── Core/
│       │   └── Views/
│       └── Views/
└── Shared/
    ├── Theme/
    └── UI/
```

SidePanel is a self-contained internal module combining two scopes (session + setting) with feature-owned infrastructure in `Utilities/`. Its role folders nest `Session/` and `Setting/` sub-folders, each with their own `Core/` and `Views/`.

Home uses flat role folders only (`Core/`, `Models/`, `Utilities/`, `Views/`). Context window and speed mode types live alongside other Home models and utilities.

## Role-based folders

Each feature organizes files by responsibility:

- `Core/` — flow controller, commands, flow state
- `Models/` — domain types and SwiftData entities
- `Views/` — SwiftUI screens and visual components
- `Utilities/` — persistence clients, visual builders

Folder names describe product roles, not design-pattern names.

## Access control

All types default to `internal`. Use `public` only when promoting a module to an internal framework or Swift Package boundary.
