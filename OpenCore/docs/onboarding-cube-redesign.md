# OpenCore Onboarding — Design Analysis & Implementation Brief

**Date:** 2026-08-20  
**Source images:** `Desktop/Screenshot 2026-08-20 at 19.34.45.png` (current) and `Downloads/Bezels 4/iPhone/hvhhhh.jpg` (concept)  
**Target platform:** iOS, SwiftUI (existing `OpenCore/OpenCore/Features/Onboarding/` module)

---

## 1. Executive Summary

The current onboarding (`OnboardingSinglePageView`) is a **light-themed, information-dense utility card** — diagonal hatch background, a soft cyan/blue radial gradient, a stable glowing orb, four feature rows, and a black solid CTA. It reads as a feature sheet.

The concept is a **dark, cinematic, single-claim hero** — a hand-drawn 3D wireframe cube that feels constructed from dust on a near-black field, one sentence of supporting copy, and a single swipe-to-start bar. The whole screen is a moment of construction, not a list.

The redesign is mostly **subtractive and tonal**: delete the brand lockup and four feature rows, swap the light theme for a dark/black canvas, and replace the orb with a wireframe cube that materializes from particles. Keep the swipe-style CTA, restyled for dark.

---

## 2. Current State — Detailed Description

**File:** `OpenCoreSinglePageView` (screenshot on light bezel, "iPhone 17 / iOS 26.5" device chrome).

### Layout (top → bottom)
1. **Status bar** — system time, Dynamic Island, signal/wifi/battery.
2. **Brand lockup** (≈y 280px) — small rounded-square sparkles icon in a blue/indigo gradient, "OPENCORE" 15pt semibold, "AI ASSISTANCE" 9pt mono caption. Centered horizontally, padded above the orb.
3. **Orb centerpiece** (≈y 410–650px) — circular, ~190pt wide on this device. Soft outer glow + stable white-cyan-blue-indigo radial gradient + bright localized highlight + 12 orbital cyan particles. Sits with significant breathing room above and below.
4. **Headline** — "OpenCore" in a large display serif/sans (looks like SF Pro Display), tight tracking. Followed by "Your AI-native command center" in 16pt regular secondary grey.
5. **Four feature rows** — 40×40 icon tile on the left, three lines of text (mono eyebrow in accent, semibold title, regular detail), chevron on the right. Rows are 9pt apart, on light-grey translucent cards with a 1pt hairline border.
6. **Primary CTA** — full-width black bar with "ENTER OPENCORE" + arrow.up.right. Sits ~20pt above the bottom safe area.

### Visual style
- **Theme:** light. The orb's center is white/cyan over a *very* light grey/white ground. The hatch pattern and dot grid (rendered in `OnboardingSinglePageView` via `SharedPixelGridBackground` + `SharedDiagonalHatchPattern`) read as off-white at low opacity.
- **Palette (current):** white/grey base, cyan→indigo gradient on the orb, black CTA, accent blue for eyebrows and icons.
- **Texture:** pixel grid + diagonal hatch (technical/blueprint feel).
- **Atmosphere:** `OnboardingBackgroundFieldView` adds a slow cyan radial drift behind the orb, blurred at 35pt.
- **CTA:** flat black bar, white text, no shadow, no fill animation.

### Typography
- Display headline: large, default-tracking, near-black on light.
- Subhead: 16pt regular, secondary grey.
- Mono eyebrow on rows: 9.5pt semibold, accent blue.
- Body on rows: 14pt medium title, 12pt regular detail.

### First-impression critique
- **List-y, not cinematic.** Four rows compete with the orb for attention.
- **Light theme fights the dark/technical mood** the rest of the app probably has (orb is dark-blue, accent is dark blue, hatch is dark on light). A dark surface would let the orb actually glow.
- **CTA label is shouty** ("ENTER OPENCORE"); the concept uses a softer "Swipe to Get Started".
- **Brand lockup is a second header** before the headline — redundant with the wordmark below.

---

## 3. Concept (Target) — Exhaustive Description

**File:** `hvhhhh.jpg`, iPhone bezel mock.

### Composition & hero
- **Pure white screen** (the bezel is dark; the *interior* of the screen is white). Aspect ratio: iPhone.
- The composition is **vertical, top-weighted**: ~55% of the screen height is the cube, the rest is copy + CTA.
- Negative space is generous — nothing competes with the cube.

### Central element: the wireframe cube
- **Geometry:** a single 3D cube, isometric-ish projection, drawn as black **line art** (no fill, no shading). Roughly square silhouette, drawn at a slight three-quarter angle so three faces are visible (top, front-left, front-right).
- **Line style:** hand-drawn — *not* perfectly geometric. Edges have small wobbles and slight thickening at corners, like ink on paper. Line weight ≈2pt, pure black.
- **Hidden edges:** the back three edges that would be occluded are rendered as **dashed lines** (medium-length dashes, 2pt black). This is a classic technical-drawing convention that immediately reads as "wireframe / blueprint."
- **Vertices:** 8 small filled black dots at the corners (a few look slightly irregular — hand-drawn).
- **No fill, no particles inside, no glow.** The cube is purely a line drawing. (The user's brief mentions "particles forming the cube" as an *animation* — the *static* reference image is a clean line drawing; the motion concept is what fills the structure with dust.)
- **No color.** Pure black on white. No accent. No gradient.

### Background
- **Solid white.** No gradient, no vignette, no grid, no texture. The only contrast comes from the black ink of the cube and the text.

### Typography
- **"OPENCORE"** — letter-spaced all-caps, semibold/bold, ~18pt optical. **Tight** tracking (letters close together despite the capitals). Black.
- **Body copy** — italic, 16–17pt, regular weight, black. Long-form (4 lines visible) describing the value prop. Italic gives it a personal, almost editorial feel — like a caption under an illustration.
- No mono accents. No eyebrows.

### CTA
- **Bottom bar** — dark rounded pill, ≈25pt tall, full-width with side insets.
- Inside the bar: a **white circle** on the left containing a **black right-arrow icon**. To the right: "Swipe to Get Started" in white italic, 16pt.
- The circle + arrow reads as a **swipe affordance** — the gesture hint is built into the visual.

### Mood, lighting, cinematic feel
- **Editorial / blueprint.** Feels like a sketch in a product designer's notebook, or a museum exhibit label.
- **High contrast, low chrome.** Every pixel is either black, white, or near-white.
- **Quiet confidence.** No glowing orb, no particles in the still — the motion concept adds life, but the *rest state* is calm and graphic.

### Implied animation
- **Cube construction:** dots/particles fly in from off-screen and snap to the 8 vertices and 12 edges of the cube (vertices are anchors; edges draw in via line-drawing or as a stream of dots).
- **Hand-drawn feel:** lines could be drawn in with a slight `path.trim` reveal (≈400–600ms each, staggered) rather than snapping in.
- **Ambient motion:** a very slow continuous rotation of the cube around its vertical axis (≈0.05–0.1 rad/s, ~60s per revolution), or a subtle floating bob — present in the concept but understated.
- **Dust inside the cube:** a sparse particle field inside the wireframe volume that drifts slowly (separate from the edge particles). Concept: "the cube contains something — a model, a workspace, an idea — represented by floating dust."
- **Text entrance:** headline + body fade up with a small Y offset and 200ms stagger; the body italic animates last.
- **CTA:** the white circle drifts slightly toward the right edge of the bar on a slow loop, then resets (a "swipe hint" idle animation), or responds to actual drag (preferred).
- **Entrance orchestration (suggested timing):** background dot field (0ms, fast) → vertex dots pop in (200–500ms, staggered 30ms each) → edges draw in (500–1100ms, 80ms stagger) → dust appears (1100ms, fade over 400ms) → headline (1300ms, fade+rise) → body (1500ms, fade+rise) → CTA (1700ms, slide up from bottom).

---

## 4. Side-by-Side Comparison

| Aspect | Current | Concept | Action |
| --- | --- | --- | --- |
| Theme | Light (white/grey) | Light (white) | **Keep light** — the concept is white, not dark. Drop the hatch/pixel grid; the white is clean. |
| Background | White + diagonal hatch + pixel grid + cyan radial drift | Pure white | Remove `SharedPixelGridBackground`, `SharedDiagonalHatchPattern`, and `OnboardingBackgroundFieldView` (or repurpose for the dust field). |
| Hero | Glowing cyan/blue orb (radial gradient, breathing pulse, orbital particles) | Hand-drawn 3D wireframe cube (black ink, dashed hidden edges, vertex dots) | Replace `OnboardingOrbView` with `OnboardingCubeView` (line-drawing + dashed back edges + vertex dots + slow rotation + internal dust). |
| Brand lockup | Sparkles icon + "OPENCORE / AI ASSISTANCE" header above the orb | None — the wordmark IS the first text | Delete the brand-lockup HStack. Headline is just "OPENCORE" letter-spaced caps. |
| Headline | "OpenCore" display + "Your AI-native command center" subtitle | "OPENCORE" caps + 4-line italic body | Replace headline stack. Use `SharedOpenCoreTypography` semibold caps for "OPENCORE"; use `.italic()` SF Pro body for the long copy. |
| Feature list | Four rows, ~80pt each, with icons + mono eyebrow + chevron | None | **Delete entirely.** Not in the concept. |
| CTA | "ENTER OPENCORE ↗" black bar, full-width, with `.buttonStyle(SharedPrimaryButtonStyle)` | Rounded dark pill with circular arrow + "Swipe to Get Started" italic | Restyle: rounded `Capsule`, side insets, white circle w/ black `arrow.right` SF Symbol, "Swipe to Get Started" italic white text. |
| Accent color | Cyan/indigo (orb + accentPrimary) | Black only | Drop the cyan accent from this screen; let the cube and text carry it. Keep `accentPrimary` available for other screens. |
| Type voice | Mono eyebrows, semibold sans display, regular body | Bold caps headline, italic body | Drop mono. Italic is the new voice. |
| Motion | Breathing orb (3.6s sin) + 12 orbital particles + slow 10s gradient drift | Cube construction → idle rotation/float → internal dust drift | See "Implied animation" timing in §3. |

---

## 5. Visual Specification (Implementation Targets)

### Canvas
- **Background:** `Color.white` (or `palette.surfaceBase` if `isDark`; in light mode = white). No hatch, no dot grid, no atmospheric gradient.
- **Safe areas:** respect top + bottom; the cube uses ~55% of the height between them.

### Cube (`OnboardingCubeView`, replaces `OnboardingOrbView`)
- **Size:** ~280×280pt on standard iPhone, scales down to ~220pt on compact heights (`size.height < 760`).
- **Position:** vertically centered in the top 60% of the available space, horizontally centered.
- **Projection:** isometric (30° from horizontal on each visible axis). Three visible faces; the 3 back edges are dashed.
- **Stroke:** `Color.black`, line width 2.0, rounded joins. Subtle hand-drawn feel via `Path` with small randomized offsets per vertex (deterministic seed, ~0.6pt).
- **Hidden edges:** 3 dashed segments (each back vertex pair). Dashes: 4pt on, 3pt off, line cap round. Same black, 2.0pt.
- **Vertices:** 8 filled black circles, radius 3pt, drawn on top of the line strokes.
- **Animation:**
  - **Entrance:** vertices pop in (scale 0→1, 200ms each, stagger 30ms), then edges draw via `Path.trimmed(from: 0, to: 1)` over 350ms each, stagger 60ms. Dashed back edges draw last.
  - **Idle:** continuous slow rotation around the world Y axis at ~0.08 rad/s (one revolution per ~78s). Apply with `rotation3DEffect(.degrees(yaw), axis: (0, 1, 0), perspective: 0.25)`. Discretize to a 30Hz `TimelineView` like the orb.
  - **Dust:** 60–80 small (1–2pt) black dots inside the cube volume, each on its own drift loop. Use `Canvas` to draw them in 3D, with size attenuated by depth (closer = larger). Opacity ~0.15–0.35.
- **Reduced motion:** render the cube at a static 3-quarter angle with no rotation, no dust drift, no draw-in — just the line drawing on a static frame.

### Typography
- **Headline:** "OPENCORE" — `SharedOpenCoreTypography` semibold, ~17pt, `tracking(1.5)` (slightly looser than the current lockup, to read as a wordmark), `lineLimit(1)`.
- **Body:** italic, ~16pt regular, 1.45 line-height, max 4–5 lines on standard iPhone, `foregroundStyle(.black)`.
- **Suggested copy** (matches the concept verbatim):
  > *Take control of your workflow with a native, open-source client. Plug in your API key to switch between top foundation models, tweak parameters, and monitor raw token usage with zero intermediary servers.*

### CTA
- **Shape:** `Capsule()`.
- **Fill:** `Color.black`.
- **Insets:** `horizontal: 20` from screen edge, `height: 56`, vertical `bottom: 24` from safe area.
- **Inner layout:** `HStack(spacing: 14)` — leading white `Circle` (28pt) with `Image(systemName: "arrow.right")` (black, 14pt, semibold); trailing `Text("Swipe to Get Started")` italic 16pt white.
- **Animation:**
  - Entrance: slides up from below + fades in, 400ms after body, spring `response: 0.5, dampingFraction: 0.85`.
  - Idle: the inner white circle drifts ~6pt to the right and back over 1.6s (a "swipe hint" loop). Pause the loop on touch-down.
  - Gesture: real swipe to commit. Use `DragGesture(minimumDistance: 10)` on the capsule; if `translation.width > 100` and `predictedEndTranslation.width > 160`, fire `flow.finish()`. Mirror velocity into the spring on release (see §"velocity handoff" in apple-design skill).

---

## 6. Current File Map

The redesign is now implemented as a single-page scene. The files below are the active onboarding boundary; the former pager, feature, queue, prompt, and visual-factory types have been removed because they have no remaining consumers.

| File | Responsibility |
| --- | --- |
| `Features/Onboarding/Views/OnboardingView.swift` | Stable screen entry point that injects the flow controller into the hero scene. |
| `Features/Onboarding/Views/OnboardingSinglePageView.swift` | Responsive composition for the cube, wordmark, editorial copy, and swipe/tap completion CTA. |
| `Features/Onboarding/Views/OnboardingCubeView.swift` | Decorative isometric wireframe cube, including construction, dashed hidden edges, dust, idle float, and reduced-motion rendering. |
| `Features/Onboarding/Core/OnboardingFlowController.swift` | Owns onboarding state and calls persistence when the hero completes. |
| `Features/Onboarding/Core/OnboardingFlowState.swift` | Value state for completion routing. |
| `Features/Onboarding/Utilities/OnboardingPersistenceClient.swift` | Persistence boundary for onboarding completion. |
| `Features/Onboarding/Models/OnboardingProgressEntity.swift` | SwiftData entity used by the persistence client. |
| `docs/animation-motion-replication.md` | Timing and motion reference for the cube and CTA implementation. |

---

## 7. Animation Vocabulary (per `animation-vocabulary` skill)

Use these exact terms when prompting / reviewing the implementation:

- **Pop in** — the 8 vertex dots.
- **Line drawing** — the 12 edges drawing in via `Path.trim`.
- **Reveal** — the dashed back edges drawing in last.
- **Float** — the cube's slow idle bob (if you add one in addition to rotation).
- **Orbit** — not used here (replaces the orb's orbital particles).
- **Idle animation** — the white circle drifting inside the CTA bar.
- **Spring** — all entrance/exit motion. Defaults: `dampingFraction: 0.85, response: 0.5` for content, `dampingFraction: 0.8, response: 0.4` for the CTA slide-up (per `apple-design` §4).
- **Stagger** — vertex pop-ins (30ms) and edge draws (60ms).
- **3D tilt** — the cube's continuous rotation (`rotation3DEffect`).
- **Perspective** — `0.25` on the rotation, to give the cube volume without distortion.
- **Compositing / will-change** — the cube view should hint `transform: 'will-change'` (or in SwiftUI, just trust the GPU; avoid non-transform animations on the cube).
- **Reduced motion** — static cube at 3-quarter angle, no draw-in, no dust drift, no CTA idle loop. **Required** — the current code already reads `accessibilityReduceMotion`; keep that contract.

---

## 8. Risk & Open Questions

- **`palette.surfaceBase` in dark mode.** If `isDark` is true, the current code will render this screen dark; the concept is white-on-white. **Decide:** force the onboarding to a fixed white palette regardless of system theme (a common iOS pattern — onboarding is its own moment), or honor dark mode by inverting ink to white. Recommendation: **force white** for the cube design; onboarding's first impression shouldn't change with the system theme.
- **Swipe-to-confirm vs. tap.** The concept clearly implies a gesture. If implementing a real drag-to-commit, mirror velocity into the spring (per apple-design §5) and use `DragGesture` with `predictedEndTranslation` for the commit threshold. If simplifying, a tap-anywhere-on-the-bar is acceptable but loses the "swipe hint" affordance — keep the drifting circle either way.
- **Haptics.** Light `.impact(.light)` on commit, mirroring the current `sensoryFeedback(.selection, trigger: appeared)` pattern.
- **No analytics in this brief** — out of scope.
- **Accessibility:** the cube is `accessibilityHidden(true)` (it is decorative). The CTA must expose its action via a label and a single tap fallback (`accessibilityAction { flow.finish() }`).

---

## 9. Acceptance for the Implementer

A reviewer should see, on first launch of onboarding, **only**:

1. A white screen.
2. A hand-drawn 3D wireframe cube (black ink, dashed back edges, 8 vertex dots) materializing — vertices pop, edges draw in.
3. A faint drift of dust inside the cube.
4. "OPENCORE" in spaced caps appearing below.
5. An italic 4-line paragraph of body copy appearing below that.
6. A dark pill at the bottom: white circle + arrow on the left, "Swipe to Get Started" italic on the right, with a subtle swipe-hint idle loop.

**Nothing else.** No brand lockup, no feature rows, no atmospheric cyan gradient, no hatch, no pixel grid, no "ENTER OPENCORE" shouty CTA.
