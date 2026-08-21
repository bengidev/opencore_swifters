# OpenCore Swifters — Interface Reconnaissance

Read-only reconnaissance of the Swift project at `/Users/beng/Documents/iOS Projects/opencore_swifters`.
Purpose: identify app framework/targets, UI technology, existing animation/transition/gradient/motion
utilities, and the best files/APIs for replicating a supplied interface recording.

---

## 1. App Framework & Targets

- **App entry point (`@main`)**: `OpenCore/OpenCore/OpenCoreApp.swift` — a SwiftUI `App` with `@main`,
  `WindowGroup { SharedThemedRootView { AppRootView(...) } }`, plus `.modelContainer(ModelContainer)` for SwiftData.
- **Targets** (`OpenCore/OpenCore.xcodeproj/project.pbxproj`):
  - `OpenCore` — `com.apple.product-type.application` (the app)
  - `OpenCoreTests` — unit test bundle
  - `OpenCoreUITests` — UI test bundle
- **Config**: `IPHONEOS_DEPLOYMENT_TARGET = 17.6`, `SDKROOT = iphoneos`,
  `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"`, `TARGETED_DEVICE_FAMILY = "1,2"`
  (iPhone + iPad), `SWIFT_VERSION = 6.0` (and 5.0 for some test configs),
  `PRODUCT_BUNDLE_IDENTIFIER = io.github.bengidev.OpenCore`, `MARKETING_VERSION = 1.0`.
- **SPM dependencies** (`project.pbxproj:208-209`): `swift-markdown-ui` (MarkdownUI) and
  `LaTeXSwiftUI`. Imported directly in chat rendering (e.g. `ChatRichContentView.swift`,
  `ChatRichContentTheme.swift`).
- **Architecture**: feature-oriented folders inside the single app target
  (`docs/architecture/modules.md`). Modules: App, Shared, Onboarding, Home, Chat, SidePanel,
  Settings, Speech, Vision, About. Access control is `internal` by default.
- Note: `OpenCore/Internal/Textual/` is an empty directory (only `.swiftpm/xcode` metadata; no
  sources), so it is **not** an active dependency source.

## 2. UI Technology

- **SwiftUI** is the sole declarative UI framework. `import SwiftUI` in every view.
- **UIKit interop** used only for targeted/performance-sensitive pieces:
  - `SharedTabBarPaletteStyle` (`UIViewControllerRepresentable`) — styles the hosting `UITabBar`.
  - `HomeParticleOrbView` (`UIViewRepresentable`) — heavy CALayer/Core Animation particle orb.
  - `ChatMermaidViews.swift` — `WKWebView` for Mermaid diagram snapshot rendering.
  - `ChatRichContentTheme.swift` — UIKit fonts (`UIFont`) for MarkdownUI/LaTeX rendering.
- **Navigation**: `TabView` (Home/Settings/About) via `HomeTabShellView`; `NavigationStack`
  (Settings, About, model popup, output detail sheet); `.sheet` for model popup and output detail.
- **State**: Flow controllers (`*FlowController` with `@State`) driven by explicit commands
  (`ChatCommand`, `OnboardingCommand`, `SettingsCommand`, etc.), not TCA.
- **Persistence**: SwiftData (`ModelContainer` with `OnboardingProgressEntity`,
  `SidePanelConversationEntity`, `SidePanelMessageEntity`).

## 3. Theme / Design System (Shared)

- **`SharedOpenCorePalette`** (`Shared/Theme/SharedOpenCorePalette.swift`) — the single source of
  truth for colors. **Fully grayscale/monochrome** ramp (hue-less). Key tokens:
  - Surfaces: `surfaceBase` (`F7F7F7` light / `0B0B0B` dark), `surfacePaper`, `surfaceRaised`,
    `surfaceSubtle`, `surfaceGalaxyTint`.
  - Text: `textPrimary`, `textSecondary`, `textTertiary`.
  - Lines: `lineSoft`, `lineStrong`.
  - Accent (graphite): `accentPrimary`, `accentDeep`, `accentSoft`.
  - Controls: `controlStrong`, `controlStrongText`, `controlDisabledFill`.
  - Status: `success`, `warning`, `danger`.
  - Effects: `effectGlitchHighlight`.
  - Elevation helpers: `elevation(_:)` (chip/popover/composerChrome), `scrimOverlay(opacity:)`,
    `composerGlass(shadowOpacity:)`.
- **Environment injection**: `SharedThemedRootView.swift` resolves the palette by live
  `ColorScheme` and injects via `.environment(\.sharedPalette, ...)` and `.environment(\.sharedAppTheme, ...)`.
  Views consume it with `@Environment(\.sharedPalette) private var palette`.
- **Theme modes**: `SharedAppTheme` (system/light/dark) with `SharedThemeToggleButton`
  (sliding-thumb animation, `Shared/UI/SharedThemeToggleButton.swift`).
- **Typography**: `SharedOpenCoreTypography` (`Shared/Theme/SharedOpenCoreTypography.swift`) —
  display (`displayXL` 56pt … `displayMD` 32pt), body (`bodyLG` 21pt, `bodyMD` 16pt),
  label (`labelMD` 13pt), mono (`monoSM` 12pt, `monoXS` 10pt), plus UIKit font variants.
  Tracking helpers: `displayTracking()` (-0.04), `monoTracking()` (+0.04).
- **Color init**: `Color+Hex.swift` — `Color(hex:)` for 3/6/8-digit hex.
- **UI primitives** (`Shared/UI/`): `SharedCardChrome` (paper card w/ thin border + radius 12),
  `SharedPrimaryButtonStyle` / `SharedSecondaryButtonStyle` (graphite, spring press animation
  `.spring(response: 0.22, dampingFraction: 0.72)`), `SharedBadge` (eyebrow chip),
  `SharedDiagonalHatchPattern` (Canvas 45° hatch), `SharedPixelGridBackground` (Canvas dot grid),
  `SharedTabBarPaletteStyle`, `SharedThemeToggleButton`, `SharedSignalGlitchModifier`.

## 4. Motion / Animation Inventory (file:line evidence)

### Dedicated motion helper
- **`HomeContextUsagePopoverMotion`** — `Features/Home/Views/HomeContextUsagePopoverMotion.swift`
  - `static let animation = Animation.spring(response: 0.34, dampingFraction: 0.86)`
  - `private static let reduceMotionAnimation = Animation.easeInOut(duration: 0.16)`
  - `static let transition = AnyTransition.asymmetric(...)` (opacity + scale + offset popover)
  - `presentationAnimation(reduceMotion:)` and `popoverTransition(reduceMotion:)` — the canonical
    pattern for **reduce-motion-aware** presentation.

### UIKit / Core Animation particle orb (most advanced motion)
- **`HomeParticleOrbView.swift`** (`Features/Home/Views/`) — `UIViewRepresentable` over a UIKit
  view managing a `CALayer` hierarchy:
  - `CAKeyframeAnimation` for position/orbit, `CABasicAnimation` for rotation/scale,
    opacity keyframes, `CACurrentMediaTime()`-based phase offsets.
  - Descriptors: `ParticleOrbLayerDescriptor`, `ParticleOrbOrbitDotDescriptor`,
    `ParticleOrbSparkDescriptor` with drift/orbit/rotation/scale/opacity phases.
  - Deterministic layout: `ParticleOrbLayoutFactory` (noise seeds), `ParticleOrbRenderer`
    (rasterizes glyph ramp `░▒▓█` blocks/dots/sparks), `ParticleOrbMath` (noise/gaussian).
  - Honours `@Environment(\.accessibilityReduceMotion)` and `scenePhase`.

### TimelineView-based (time-driven) animation
- `OnboardingCubeView.swift` — `TimelineView(.animation(minimumInterval: 1.0/30.0))` drives the
  wireframe cube’s construction reveal, internal dust drift, and idle float while reduced motion
  renders a static completed frame.
- `ChatRichContentView.swift` — `TimelineView` cursor blink; streaming text throttled at ~33ms.
- `ChatReasoningCardView.swift` / `ChatStreamingStatusCapsuleView.swift` — pulsing dot via
  `withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true))`.

### Gradient usage (deliberate, restrained)
- `SharedSignalGlitchModifier.swift:15` — `LinearGradient` overlay + `blendMode(.screen)` for
  luminance glitch effects in the shared UI layer. The current onboarding hero remains monochrome
  and does not add a gradient overlay.

### Common transition/spring idioms across the app
- Page/route fade: `OnboardingView.swift` delegates to the single-page hero; `AppRootView.swift`
  `.animation(.easeInOut(duration: 0.3), value:)` crossfades into the home shell.
- Hero entrance/completion: `OnboardingSinglePageView.swift` uses staggered opacity/offset springs
  for the cube, wordmark, copy, and CTA, then a short completion scrim before routing home.
- Chat thread auto-scroll: `ChatThreadView.swift` — `withAnimation(.easeOut(duration: 0.15))`.
- Waveform/audio progress: `ChatWaveformBarsView.swift`, `ChatUserMessageBubbleView.swift`
  (`.contentTransition(.numericText())`, `.linear(duration: 0.05)`); `SpeechRecordingComposerView.swift`
  (`.easeOut(duration: 0.08)`).
- Composer chrome: `HomeComposerContextRail.swift`/`HomeComposerPromptPanel.swift` —
  `.easeInOut(duration: 0.18)` + `HomeContextUsagePopoverMotion` popover; glass chrome via
  `.homeComposerGlass(cornerRadius:shadowOpacity:)`.
- Buttons/controls: spring press `(0.22, 0.72)` in `SharedPrimaryButtonStyle`,
  `SharedSecondaryButtonStyle`, `SharedThemeToggleButton`.

### Reduce-motion handling (accessibility constraint)
- `@Environment(\.accessibilityReduceMotion)` is honored in: `HomeParticleOrbView`,
  `HomeContextUsagePopoverMotion`, `OnboardingCubeView`, `OnboardingSinglePageView`,
  `ChatReasoningCardView`, `ChatStreamingStatusCapsuleView`, `ChatRichContentView`,
  `HomeComposerContextRail`/`HomeView`.
- Canonical pattern: pick a reduced motion fallback (static opacity / `.easeInOut(0.16)`) when
  `reduceMotion` is true; still reach final state.

## 5. Best Files/APIs for Replicating an Interface Recording

For a SwiftUI interface that visually matches OpenCore's monochrome instrument-panel aesthetic:

1. **Palette/design tokens** — `Shared/Theme/SharedOpenCorePalette.swift` (all colors), plus
   `Color+Hex.swift`, `SharedOpenCoreTypography.swift`, `SharedThemedRootView.swift`,
   `SharedOpenCorePalette+Environment.swift`. Any new UI should consume `@Environment(\.sharedPalette)`.
2. **Reusable chrome** — `Shared/UI/SharedCardChrome.swift`, `SharedBadge.swift`,
   `SharedPrimaryButtonStyle.swift`, `SharedSecondaryButtonStyle.swift`, `SharedPixelGridBackground.swift`,
   `SharedDiagonalHatchPattern.swift`, `SharedSignalGlitchModifier.swift`.
3. **Motion library** — copy the `HomeContextUsagePopoverMotion` pattern
   (`Features/Home/Views/HomeContextUsagePopoverMotion.swift`) for reduce-motion-aware springs/transitions.
4. **Time-driven animation** — `TimelineView(.animation(minimumInterval: 1.0/30.0))` pattern from
   `Features/Onboarding/Views/OnboardingCubeView.swift`, which drives the cube’s construction,
   dust drift, and idle float.
5. **Heavy particle/motion** — `Features/Home/Views/HomeParticleOrbView.swift`
   (CALayer + `CAKeyframeAnimation` + deterministic layout) as the reference for complex, performant motion.
6. **Typography/tracking** — `SharedOpenCoreTypography.swift` + `displayTracking()`/`monoTracking()`.
7. **Theme toggling** — `Shared/UI/SharedThemeToggleButton.swift`, `SharedAppTheme.swift`.

### Implementation constraints
- **Monochrome only** — no hue-based colors; rely on the grayscale ramp. `LinearGradient` is used
  only twice and is deliberately restrained; avoid introducing colorful/rainbow gradients.
- **Respect `accessibilityReduceMotion`** in every animated view (established convention).
- **Deployment target 17.6** — modern SwiftUI APIs (`contentTransition(.numericText())`,
  `scrollDismissesKeyboard`, `.defaultScrollAnchor`, `.scrollBounceBehavior`) are available.
- **Single app target, internal access** — add new files under the relevant `Features/*` or
  `Shared/` folder; keep types `internal` unless promoting a module.
- **Performance** — heavy continuous motion belongs in `UIViewRepresentable`/Core Animation
  (see orb) or `TimelineView`; avoid per-frame SwiftUI body recomputation for particle-heavy scenes.
- **Not using TCA** — flow controllers + explicit commands; views are declarative and read state.
- **No Color/asset gradients in Assets.xcassets** — only `AccentColor.colorset` and `AppIcon`.
  Gradient effects are code-built (LinearGradient in the two files above).
