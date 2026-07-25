# Brand Identity System — Design Spec

> Status: approved 2026-07-25. Foundation (color assets + `BrandHeroSurface`) landed
> in the same pass; symbol, app icon, wordmark, and full hero/glass migration are
> Sprint 6.5 work.

## Context

GymBros wanted a **unique brand identity** without abandoning the accessibility of
Apple's system colors. The reframe: color is ~15% of a brand — the app's uniqueness
lives mostly in name-agnostic layers (voice, motion, signature moments, a symbol, and
one disciplined accent). This spec defines that system.

It intentionally **reverses** the earlier "system-colors-only, brand colors deferred"
rule (`GYMTRACK.md` §6). That rule existed because the original electric lime failed
light-mode contrast. This spec keeps the energy but **codifies the accessibility rules
so that failure can't recur.**

The app name is a separate, decoupled task (every literal candidate — GymBros, Showup,
Just Lift, Nexset — is already taken on the App Store; an ownable name must be coined
and separately vetted). Everything here is name-agnostic except the wordmark, which
waits for the name.

## Brand soul

> **You bring the body. The app brings the brain.** Just show up — today's session is
> already decided.

A sharpening of the existing tagline ("มาแค่นี้พอ เราจะดูแลส่วนที่เหลือ / Just show up.
We'll handle the rest.") and the anti-guilt voice already in `GYMTRACK.md` §6. The
identity should feel calm, confident, and energetic — never guilt-inducing or busy.

## Color system

Brand colors (already present in `Gymbros/Assets.xcassets`, rediscovered from the
original deferred palette):

| Role | Color | Asset | Usage |
|---|---|---|---|
| Workhorse (tint) | violet — light `#7B5CD6`, dark `#9B7FE8` | `AccentColor` | The SwiftUI `.tint()`. Interactive controls, Start button, selected/active states, links, comeback/milestone moments. |
| Spark | lime `#C8FF00` | `SparkLime` | Limited energy only: gradient wash, highlight bars, progress fills, PR/success badges — **always with dark text**. |
| Hero violet | `#9B7FE8` | `GymPurple` | The violet end of the gradient wash and large violet fills. |
| Ink / anchor | system `.primary` / label | — | Primary text, big bold type, selected pills, nav. Keeps most of the app system-native. |

### The two-role model (from the user's reference image)

Text stays **dark/near-black almost everywhere**; lime and violet do their work as
**gradient washes and dark-text fills**; **black/ink anchors** the bold structure.
Violet `#9B7FE8` + near-black text ≈ 4.7:1 (passes AA normal text) — which is why the
reference's violet "Buy" button uses dark, not white, text.

### Accessibility rules (must not regress)

| Combination | Verdict |
|---|---|
| Violet accent (`#7B5CD6` light) + white text | passes AA — used for system controls that force white-on-tint |
| Violet `#9B7FE8` + dark/near-black text | passes AA (~4.7:1) — the default for custom brand controls |
| `#9B7FE8` + white text at small sizes | large text only (~3.2:1) — avoid for body/links |
| Lime `#C8FF00` + dark text (`~#2C3A00`) | passes strongly (~15:1) |
| Lime `#C8FF00` + white text | **never** — this is the exact failure that got lime deferred |
| Lime `#C8FF00` as text/small icon on white | **never** — too light |

Everything outside the brand accents stays **system semantic colors, flat and clean.**
The workout logger, forms, and history stay system-native and legible (sweaty hands >
flair).

## Visual style

- Big confident type on hero surfaces (the existing `Font.gymNumber` rounded-bold works
  well here); rounded pills/cards with generous radius; warm off-white space.
- **Signature texture:** a soft **lime → transparent → violet** gradient wash, applied
  via `View.brandHeroSurface()`. Scoped to hero moments only — Today header, comeback
  card, PR celebration. **Never** the logger/forms.

## Liquid Glass — "glass heroes + solid content"

Frosted glass on the **chrome and hero surfaces** only (floating nav/tab bar, filter
pills, session/Today cards, comeback and PR surfaces, the violet-tinted glass Start
button), with the brand gradient refracting *behind* the glass. The workout logger and
dense forms stay solid and system-native. Glass is strongest in dark mode, where the
brand colors glow through smoky glass.

### iOS floor + fallback

- Real Liquid Glass (`.glassEffect()`) is **iOS 26+**. The app's actual deployment
  target is **iOS 18.4** (the docs previously said 17.0 — stale; corrected here).
- iOS 18.4–25 get a **system-material / solid fallback**. This is the same dual-path
  the app already ships for the bottom workout pill
  (`ActiveWorkoutWidgetView.activeWorkoutWidgetBackground()`).
- Applied via `View.brandGlassBackground(cornerRadius:)` in
  `Gymbros/Core/BrandTheme.swift`, gated with `if #available(iOS 26.0, *)`.
- **No users dropped.**

## Symbol, wordmark, icon

- **Symbol:** an abstract, **name-agnostic** mark (violet form + lime spark) for the
  app icon, launch screen, and empty states. Grows into a letter monogram once the name
  is chosen. — Sprint 6.5.
- **Wordmark:** deferred until the name lands (the only slot that truly needs it).
- **App icon:** bold lime + violet; lives outside the UI, so no system-color/contrast
  constraint applies. — Sprint 6.5.

## Motion + signature moments

- A "today's session revealed" reveal on the Today card.
- Keep the existing haptic language (light haptic on comeback set completion; double
  haptic when baseline is regained).
- A consistent card/shape style across hero surfaces.
— Spec-level here; built in Sprint 6.5.

## What landed in this pass (foundation)

- `AccentColor` switched from lime to the **violet workhorse** (light `#7B5CD6`, dark
  `#9B7FE8`) — this becomes the app-wide tint automatically.
- New `SparkLime` color asset (`#C8FF00`).
- `GymPurple` (`#9B7FE8`) retained as the hero violet.
- `Gymbros/Core/BrandTheme.swift` surface primitives:
  - `View.brandAmbientBackground()` — **page-level** ambient wash (lime radial from
    top-leading, violet from bottom-trailing, over `.systemBackground`). This is the
    signature backdrop; glass cards float on it. Opacities are per-scheme (light is
    deliberately softer so the status bar isn't washed out).
  - `View.brandGlassCard()` — frosted card, Liquid Glass on iOS 26+ / material below.
  - `View.brandGlassAccent()` — violet-tinted glass for the primary action.
  - `BrandSparkBadge` — the lime capsule badge, dark text enforced.
  - `Color.brandSparkLime` / `Color.brandHeroViolet` named accessors.
- **Today screen rebuilt to the reference aesthetic:** ambient wash behind the whole
  scroll view, brand header (gradient avatar + greeting + tagline + big dot-separated
  `DD.MM` date + weekday), glass session card, full-width violet-glass Start button
  with dark text, lime spark badge for the streak, glass welcome-back banner, and the
  nav title set to `.inline` so it doesn't duplicate the brand header.
- New localized string `today.brand.tagline` (EN "Just show up." / TH "มาแค่นี้พอ").
- **Programs, History, and Session detail** brought onto the same system: ambient wash
  behind the list, `BrandGlassRow` glass rows (via `.listRowBackground(.clear)` +
  `.listRowSeparator(.hidden)` so system swipe actions still work), staggered
  `brandEntrance()` animation, and the Programs "Active" badge as a lime spark badge.
  Session detail uses a translucent material row fill so the wash reads through.
- **Motion:** `BrandPressButtonStyle` (spring scale + dim on press) and
  `brandEntrance(index:isVisible:)` (staggered spring entrance for list content).
- `ProgramListView` gained a `loadsOnAppear` flag mirroring `TodayView`/`HistoryView`
  — its `.task` previously always hit the network, which also meant its own SwiftUI
  previews could never show their mock state.

### Text color rule (explicit)

Brand color is for **surfaces, accents, and badges only**. Body text, form labels,
settings rows, picker options (e.g. ลดน้ำหนัก / เพิ่มน้ำหนัก), and legal/policy links
keep **system semantic colors** (`.primary` / `.secondary` / system tint). Apple's text
colors are already correct for contrast and dark mode — do not recolor them.
- Build verified `** BUILD SUCCEEDED **` on iPhone 17.
- **Runtime-verified** in the simulator (iPhone 17, iOS 26.5) via a temporary
  launch-arg harness that rendered the real screens with offline mock ViewModels
  (since the Today hero sits behind the Apple Sign-In wall). Confirmed in **light and
  dark**: the gradient hero renders on the Today greeting, and the violet tint applies
  app-wide (Start button, "Change day", tab bar); History stays a solid system list
  with no gradient (correct — not a hero surface). Harness removed after.
- **Gotcha fixed during verification:** the `AccentColor` asset did not resolve as the
  app-wide tint (controls stayed system blue) until the colorset included an **"Any
  Appearance" base entry** — light+dark-only entries are not enough for the global
  accent resolver. The shipped colorset is `Any (#7B5CD6)` + `Dark (#9B7FE8)`.

## Deferred to Sprint 6.5

Abstract symbol, app icon, launch screen, wordmark (post-name), the full hero/chrome
glass migration (comeback card, PR celebration, tab bar, cards), the motion/signature
moments, and the localized brand voice pass.

## Related

- Naming: separate vetted coined-name exploration task (App Store + trademark checks).
- Roadmap: `GYMTRACK.md` §9 Sprint 6.5.
