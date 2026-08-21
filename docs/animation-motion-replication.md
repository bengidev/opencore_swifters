# Animation and Motion Replication Specification

## Source

- Recording: `/Users/beng/Desktop/Screen Recording 2026-08-20 at 16.19.29.mov`
- Video: `680 × 1456`, `120 fps`, approximately `2.36 s`
- Target project: OpenCore SwiftUI app
- Deployment target: iOS 17.6

This document describes the observed visual language and provides implementation-ready terminology and values for reproducing it in this project. It is a specification, not an implementation.

## Motion language

The interface should feel **technical, calm, precise, luminous, and slightly alive**. Its primary motion vocabulary is:

- Ambient animation
- Pulse and float
- Orbit
- Dynamic gradient
- Morph and continuity transition
- Scale-in and fade-in
- Origin-aware pop-in
- Crossfade
- Stagger
- Layout animation
- Spring motion
- Follow-through
- Materialization

Avoid large travel distances, excessive bounce, cartoon squash-and-stretch, and synchronized movement across all elements.

## Layered scene model

Build the scene from independently animated layers rather than one monolithic animation:

1. Near-black background
2. Slow atmospheric gradient field
3. Central luminous object
4. Soft glow and bloom
5. Particle/orbit field
6. Fast sparkle accents
7. Static or lightly animated controls

SwiftUI should own layout and interaction. Use `Canvas`, `CALayer`, or the existing UIKit-backed particle renderer for high-frequency continuous visuals.

## Background field

The background remains visually stable while low-opacity lighting drifts behind the content.

Recommended values:

- Cyan/blue radial fields at low opacity
- Loop duration: `8–14 s`
- Linear or gently eased motion
- No visible loop seam
- No abrupt hue or brightness changes
- Blur only the aggregate field, not every particle

A SwiftUI starting point:

```swift
struct DynamicBackgroundField: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(
                x: size.width * (0.5 + 0.08 * sin(phase)),
                y: size.height * (0.42 + 0.05 * cos(phase * 0.8))
            )

            let gradient = Gradient(colors: [
                Color.cyan.opacity(0.10),
                Color.blue.opacity(0.04),
                Color.clear
            ])

            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - size.width * 0.65,
                    y: center.y - size.height * 0.4,
                    width: size.width * 1.3,
                    height: size.height * 0.8
                )),
                with: .radialGradient(
                    gradient,
                    center: center,
                    startRadius: 0,
                    endRadius: size.width * 0.8
                )
            )
        }
        .blur(radius: 35)
        .task {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}
```

## Central luminous object

The central object should combine:

- A stable silhouette
- Moving gradient highlights
- A soft outer glow
- Internal texture or particles
- A slow breathing pulse
- Small orbital or radial motion

Suggested hierarchy:

```swift
ZStack {
    CentralGlow()
    CentralGradientShape()
    CentralParticleField()
    CentralHighlight()
}
```

### Breathing pulse

The pulse is an idle animation, not a bounce:

- Scale range: `0.985...1.015`
- Duration: `2.8–4.5 s`
- Easing: `.easeInOut`
- Repeat forever with autoreverse
- Opacity variation: approximately `0.04...0.10`

```swift
centralShape
    .scaleEffect(breathing ? 1.015 : 0.985)
    .opacity(breathing ? 1.0 : 0.92)
    .animation(
        .easeInOut(duration: 3.6).repeatForever(autoreverses: true),
        value: breathing
    )
```

## Dynamic gradient

The gradient should read as energy moving through the object rather than as a static fill.

Recommended palette:

```swift
[
    .white.opacity(0.98),
    .cyan.opacity(0.95),
    .blue.opacity(0.80),
    .indigo.opacity(0.60),
    .black.opacity(0.10)
]
```

Use two or more overlapping radial/linear gradients with independently moving centers. Use `.blendMode(.screen)` sparingly for highlights. Keep the bright cyan/white highlight localized and let the edges fall into deep blue or transparency.

```swift
ZStack {
    RadialGradient(
        colors: [.cyan.opacity(0.8), .blue.opacity(0.1), .clear],
        center: UnitPoint(x: 0.35, y: 0.3),
        startRadius: 0,
        endRadius: 220
    )

    RadialGradient(
        colors: [.white.opacity(0.55), .clear],
        center: UnitPoint(x: 0.65, y: 0.6),
        startRadius: 0,
        endRadius: 160
    )
}
.blendMode(.screen)
```

## Particle behavior

Use three motion scales.

### Slow atmospheric particles

- Duration: `4–12 s`
- Low contrast
- Slow orbit or drift
- Small opacity changes
- Independent deterministic phase offsets

### Medium structural particles

- Duration: `2.5–6 s`
- Orbit or rotate around the central object
- Moderate opacity
- Slight radial pulse

### Fast accents

- Duration: `0.18–0.45 s`
- Short sparkle, flash, or streak
- Used for state changes, not as constant noise

Use phase offsets so particles do not move in lockstep:

```swift
.opacity(0.35 + 0.35 * sin(time * frequency + particle.phase))
```

The existing implementation is the preferred foundation:

```text
OpenCore/OpenCore/Features/Home/Views/HomeParticleOrbView.swift
```

It already provides CALayer-backed rendering, orbit dots, sparks, core blocks, orb dust, phase offsets, keyframe animation, scale/rotation/opacity animation, scene lifecycle handling, and reduced-motion support. Extend it rather than introducing a second particle engine.

## Transform limits

Use small transforms for the ambient centerpiece:

- Scale: maximum approximately `±1.5%`
- Rotation: approximately `±1–3°`
- Translation: approximately `2–8 pt`
- Avoid translating the entire interface during idle motion

Animate `opacity`, `scale`, `offset`, and `rotation` rather than layout properties whenever possible.

## Entrance transition

Use a restrained **scale-in + fade-in + stagger** sequence:

| Element | Delay | Duration |
| --- | ---: | ---: |
| Background | `0 ms` | `250 ms` |
| Central silhouette | `0 ms` | `350 ms` |
| Glow | `50 ms` | `450 ms` |
| Particle groups | `100–280 ms` | `400–700 ms` |
| Controls | `180–300 ms` | `250–350 ms` |

The centerpiece should start around `0.96` scale and resolve to `1.0`. Keep vertical travel small, approximately `8–14 pt`. The interface should feel like it is resolving into focus, not flying into place.

```swift
ZStack {
    background
        .opacity(appeared ? 1 : 0)

    centralObject
        .scaleEffect(appeared ? 1 : 0.96)
        .opacity(appeared ? 1 : 0)

    controls
        .offset(y: appeared ? 0 : 8)
        .opacity(appeared ? 1 : 0)
}
.onAppear {
    withAnimation(.easeOut(duration: 0.35)) {
        appeared = true
    }
}
```

## Control behavior

Controls should respond immediately on press-down.

Recommended press feedback:

- Scale: `0.985–0.97`
- Perceptual response: `180–240 ms`
- No layout resizing
- Optional opacity reduction: `0.92–0.96`

The project already uses this pattern in:

```text
OpenCore/OpenCore/Shared/UI/SharedPrimaryButtonStyle.swift
OpenCore/OpenCore/Shared/UI/SharedSecondaryButtonStyle.swift
OpenCore/OpenCore/Shared/UI/SharedThemeToggleButton.swift
```

Existing spring values are `.spring(response: 0.22, dampingFraction: 0.72)`. For a more precise technical feel, use approximately `.spring(response: 0.20, dampingFraction: 0.86)` unless the recording clearly shows bounce.

## State transitions

Prefer continuity over replacing an entire view:

- `matchedGeometryEffect` for shared identity
- Opacity crossfade for equivalent content in the same location
- Layout animation for changed size or position
- Animated mask/clip shape for reveals
- Animated gradient position for visual state changes

For independent state content, use a crossfade with a small scale correction:

```swift
ZStack {
    ViewA()
        .opacity(state == .a ? 1 : 0)
        .scaleEffect(state == .a ? 1 : 0.97)

    ViewB()
        .opacity(state == .b ? 1 : 0)
        .scaleEffect(state == .b ? 1 : 0.97)
}
.animation(.easeOut(duration: 0.22), value: state)
```

## Popovers and panels

Use an **origin-aware pop-in** anchored to the triggering control. The project already has the appropriate pattern in:

```text
OpenCore/OpenCore/Features/Home/Views/HomeComposerContextRail.swift
OpenCore/OpenCore/Features/Home/Views/HomeContextUsagePopoverMotion.swift
```

Recommended transition:

```swift
AnyTransition.asymmetric(
    insertion: .opacity
        .combined(with: .scale(scale: 0.96, anchor: .bottomTrailing))
        .combined(with: .offset(y: 8)),
    removal: .opacity
        .combined(with: .scale(scale: 0.98, anchor: .bottomTrailing))
        .combined(with: .offset(y: 5))
)
```

Recommended presentation animation:

```swift
.spring(response: 0.34, dampingFraction: 0.86)
```

The panel should feel attached to its trigger, not independently dropped into the screen.

## Scrim and focus

A focused panel may dim the background, but the scrim should fade rather than move:

```swift
Color.black.opacity(isPresented ? 0.34 : 0)
    .ignoresSafeArea()
    .allowsHitTesting(isPresented)
    .transition(.opacity)
```

Recommended timing:

- Fade in: `180–240 ms`
- Fade out: `160–220 ms`
- Use `.easeOut` for insertion and `.easeIn` for removal

## Accessibility and reduced motion

Use the project’s existing environment-driven pattern:

```swift
@Environment(\.accessibilityReduceMotion)
private var reduceMotion
```

When reduced motion is enabled:

- Disable particles and orbital animation
- Disable continuous large-scale pulses
- Replace slide/spring movement with short opacity fades
- Retain color and opacity changes that communicate state
- Avoid leaving elements in an intermediate transformed state

```swift
.animation(
    reduceMotion
        ? .easeInOut(duration: 0.16)
        : .spring(response: 0.34, dampingFraction: 0.86),
    value: isPresented
)
```

For continuous animation, also gate on the active scene phase:

```swift
shouldAnimate = !reduceMotion && scenePhase == .active
```

## Performance requirements

Prefer:

- `opacity`, `scale`, `offset`, and `rotation`
- `Canvas`
- `CALayer` and `CAKeyframeAnimation`
- One shared animation clock
- Deterministic particle data
- Independent phase offsets

Avoid:

- Per-frame `frame`, `width`, or `height` animation
- Rebuilding large `ForEach` collections every frame
- Multiple independent `TimelineView`s for the same scene
- Hundreds of individually blurred SwiftUI particles
- Animating layout when a transform is sufficient
- Synchronized particle phases

## Project mapping

| Recording behavior | Existing project location/API |
| --- | --- |
| Animated central particle object | `Features/Home/Views/HomeParticleOrbView.swift` |
| Continuous CALayer motion | `ParticleOrbUIKitView` |
| Dynamic colors | `SharedOpenCorePalette` and palette environment |
| Gradient construction | `LinearGradient`, `RadialGradient`, `Canvas` |
| Primary button press | `SharedPrimaryButtonStyle.swift` |
| Secondary button press | `SharedSecondaryButtonStyle.swift` |
| Sliding theme control | `SharedThemeToggleButton.swift` |
| Popover transition | `HomeContextUsagePopoverMotion.swift` |
| Popover presentation | `HomeComposerContextRail.swift` |
| Scrim presentation | `HomeView.swift` |
| Reduced motion | `accessibilityReduceMotion` environment value |
| Scene lifecycle | `scenePhase` environment value |
| Staggered entrance | `delay(...)` on animations |
| Lightweight animation | `TimelineView(.animation(...))` |

## Implementation brief

> Build a dark SwiftUI interface with a luminous cyan-blue centerpiece on a near-black background. The centerpiece consists of a stable rounded silhouette, moving radial-gradient highlights, a soft blurred glow, low-contrast orbital particles, and occasional sparkle accents. The background uses a slow low-opacity dynamic gradient with an 8–14 second loop. The centerpiece breathes between 98.5% and 101.5% scale over approximately 3.6 seconds using ease-in-out. Particles animate independently using deterministic phase offsets and durations between 2.5 and 12 seconds. Use CALayer or Canvas for continuous high-particle-count animation and SwiftUI for layout and interaction.
>
> On entrance, fade in the background immediately, materialize the centerpiece from 96% scale over 350 ms, resolve its glow over 450 ms, then stagger particle layers and controls over 100–300 ms. Use origin-aware pop-in transitions for popovers: opacity plus a 96% scale anchored to the trigger and an 8-point offset, using a spring with response 0.34 and damping fraction 0.86. Buttons respond on press-down with a 1.5% scale reduction and a short high-damping spring. State changes preserve spatial identity through matched geometry, layout animation, or crossfade. Respect reduced motion by disabling particle/orbit animation and replacing movement with short opacity fades.
