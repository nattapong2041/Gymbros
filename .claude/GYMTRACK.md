# GymTrack — Source of Truth

> Living document. Update as decisions evolve.  
> Last updated: 2026-05-12

---

## Table of Contents

1. [Vision & Identity](#1-vision--identity)
2. [Target Users & Pain Points](#2-target-users--pain-points)
3. [Core Value Proposition](#3-core-value-proposition)
4. [Competitive Wedge](#4-competitive-wedge)
5. [Tech Stack](#5-tech-stack)
6. [Design System](#6-design-system)
7. [App Architecture](#7-app-architecture)
8. [Re-engagement Strategy](#8-re-engagement-strategy)
9. [Agile Roadmap](#9-agile-roadmap)
10. [Core Algorithms](#10-core-algorithms)
11. [Program Templates](#11-program-templates)
12. [Monetization](#12-monetization)
13. [Product Metrics](#13-product-metrics)
14. [B2B Gym Partnership Track](#14-b2b-gym-partnership-track)
15. [Marketing Plan](#15-marketing-plan)
16. [Development Workflow & CI/CD](#16-development-workflow--cicd)
17. [Decisions Made and Rejected](#17-decisions-made-and-rejected)
18. [Open Decisions](#18-open-decisions)
19. [Decision Log](#19-decision-log)
20. [Appendix — Quick Reference](#20-appendix--quick-reference)

---

## 1. Vision & Identity

**App name:** GymBros *(placeholder — will rename before App Store launch)*

**Positioning:** The gym app that adapts to your real life.

**Tagline TH:** "ขาดไป 2 อาทิตย์? บาดเจ็บ? ยิมแน่น? เราจัดการให้"

**Tagline EN:** "Missed 2 weeks? Injured? Gym crowded? We've got you."

### The shift

We are not just “a coach, not a tracker.” Fitbod, Garmin, Slate, and other apps already claim parts of that territory.

GymTrack is narrower and sharper:

> **The app that handles when life breaks the plan.**

Most gym apps assume the user follows the program perfectly. GymTrack assumes the user has work, family, low sleep, crowded gyms, injuries, missed days, and decision fatigue.

### Problem

Many gym-goers do not fail because they are lazy. They fail because real life keeps interrupting the plan:

- “I missed 1–2 days. Do I continue or restart the week?”
- “I missed 2 weeks. Should I deload, restart, or try my old numbers?”
- “I slept 4 hours. Should I still push?”
- “Bench is taken. What should I do instead?”
- “My shoulder feels wrong. What should I avoid?”
- “I finished a deload. What happens next?”
- “I am at the gym, but I feel mentally messy and do not want to think.”

### What makes us different

When life breaks the plan, GymTrack has an answer.

```text
Open app
→ app understands what changed
→ app tells you today’s best session
→ execute
→ done
```

---

## 2. Target Users & Pain Points

### Primary user

Gym-goer, 18–35, iPhone. Wants to train 3–5×/week, actually trains 1–3×/week because life gets busy. Has tried Hevy, Strong, Notes, spreadsheets, or Garmin-style logging, but eventually drops off because logging alone does not answer what to do next.

Launch market: **Thailand**, while keeping English first-class for worldwide ambition.

### Not for yet

- Competitive powerlifters
- Cardio-first athletes
- CrossFit-specific training
- Bodybuilding competitors with dedicated coaches

### Secondary users later

- Personal trainers managing 5–15 clients
- Independent Thai gyms with member retention problems

### The pain points we solve

| # | Pain | Existing app behavior | GymTrack answer |
|---|---|---|---|
| 1 | Missed days make the plan confusing | Many apps keep the schedule static | SmartSessionAdvisor reschedules or adjusts today |
| 2 | Coming back after a break is hard | User guesses whether to deload/restart | ComebackRampService gives weight/set reduction and ramp plan |
| 3 | User does not know when to progress | Some apps suggest progression, many trackers do not | ProgressiveOverloadEngine gives concrete next weight/reps |
| 4 | User does not know when to deload | Often hidden or advanced | StallDetector + DeloadAdvisor explain and apply deloads |
| 5 | Injury disrupts the plan | User manually deletes or skips exercises | Injury substitution filters unsafe movements |
| 6 | Gym is crowded | User improvises badly or waits | Substitute + Defer flows preserve the session |
| 7 | User feels messy at the gym | Too many choices, charts, and inputs | Today screen gives one clear next action |
| 8 | Progress is invisible | Charts exist but may be buried/paywalled | Plain-language progress and comeback wins |

### Pain points we deliberately do not solve

- Form check / video analysis — separate product domain
- Nutrition / macros — partner integration later, not core
- Social / community — violates anti-guilt principle
- Streak pressure — can punish busy users emotionally
- Running / cardio expansion — different category, different competitors, different workflow

---

## 3. Core Value Proposition

```text
Apple Fitness: how many calories you burned
Hevy / Strong: log it yourself, figure it out yourself
Fitbod / Garmin: adaptive planning, but not centered on life disruption
GymTrack:      what to lift today, even after 2 weeks off,
               even with a shoulder tweak,
               even when the gym is crowded,
               even after bad sleep
```

### Product promise

> **You have a life. GymTrack handles the gym decisions.**

### Main product loop

```text
Normal day:
  “Do Upper B today. Try 77.5 kg.”

Missed 1 day:
  “No problem. Do the next scheduled session today.”

Missed 4 days:
  “Pick up here. No need to rearrange anything.”

Missed 2 weeks:
  “Comeback session today: 80%, one fewer set. We’ll ramp you back.”

Gym crowded:
  “Bench taken? Switch to Machine Chest Press. Suggested weight: 67.5 kg.”

After deload:
  “You’re ready to resume progression. Try 75 kg again.”
```

---

## 4. Competitive Wedge

### Not unique by itself

These already exist in the market:

- Workout logging
- Custom programs
- Templates
- Progressive overload suggestions
- Adaptive workouts
- Muscle maps
- Workout scheduling
- Basic charts

### Potentially differentiated as a product system

```text
Life disruption handling:
  missed days
  comeback ramp
  deload exit path
  injury substitution
  crowded-gym substitute/defer
  anti-guilt UX
  “what should I do today?” as the default product state
```

### Positioning rule

Do not compete on “best tracker.”

Do not compete on “AI workout app.”

Own this:

> **When life breaks your plan, GymTrack tells you exactly what to do next.**

### Shining feature

**Next Best Session Engine**

This is the umbrella feature that decides:

- today’s workout
- today’s load
- whether to progress
- whether to deload
- whether to ramp back after absence
- whether to substitute or defer
- what happens after the adjusted session

Smart Comeback is the first public proof of this engine.

---

## 5. Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| iOS + watchOS | SwiftUI | Native Apple experience, watchOS path |
| Storage V1 | Supabase + in-memory active session | Simple, fast, already in use |
| Storage later | SwiftData + Supabase | Only if reliability/watch needs justify it |
| Cloud | Supabase Postgres | Relational data, SQL queries |
| Auth | Supabase + Apple Sign-In | One-tap, iOS-native |
| AI V1 | Rule-based Swift | Offline, testable, cheap, explainable |
| AI V2 | Deferred | Only if user demand/data justify chat-style AI |
| Payments | StoreKit 2 + RevenueCat | Native subscriptions, regional pricing, entitlement management |
| Health | HealthKit later | Workout, HRV, sleep, recovery inputs |
| i18n | String Catalogs | Thai + English first-class |
| Crashes early beta | Apple built-in | Free, enough for early TestFlight |
| Crashes before public launch | Crashlytics | Better crash grouping and release monitoring |
| Analytics | TelemetryDeck | Privacy-first, Swift-native product analytics |
| CI/CD | Xcode Cloud | Auto TestFlight on push to main |
| Notifications | UserNotifications | Opt-in, low-frequency, pattern-based |

---

## 6. Design System

### Localization Strategy

```text
Thai and English are FIRST-CLASS languages.
Neither is treated as a weak translation of the other.

String keys:
  English-style keys in code, e.g. start_workout

Default display:
  Device locale
  Thai device → Thai
  Any other language → English

User override:
  Settings → Language → ภาษาไทย / English

String Catalogs:
  sourceLanguage = en
  locales = th + en
  both must be complete before App Store 1.0
```

### Bilingual copy rule

Most UI should use the selected language only.

Critical emotional moments may show both Thai and English side-by-side:

- welcome back
- comeback card
- PR achievement
- baseline regained

Do not make one language feel like a footnote.

### Approach

SwiftUI native design system. No Figma for V1. Paper sketches or quick references for key screens only.

### System Color Strategy

```text
Current whole-app rule:
  Use SwiftUI system and semantic colors only across the entire app.

Allowed:
  .primary, .secondary
  .background, systemBackground, secondarySystemBackground
  Default SwiftUI button/list/form/navigation styling
  Adaptive system colors only when semantic:
    .blue   → primary actions when explicit tint is needed
    .green  → success/completion
    .orange → warning/recovery
    .red    → destructive/error
    .purple → comeback/PR/milestone only when semantic and readable

Forbidden in app UI:
  Color.gymAccent
  Color.gymPurple
  Color.gymAccentText
  Custom named color assets for UI styling
  Hex literals in code/docs as active implementation guidance
  Color(red:green:blue:) in code
```

Reason: the initial lime brand color has poor readability on light backgrounds. Apple guidance for SwiftUI Color, HIG Color, and HIG Dark Mode favors dynamic system colors and semantic colors that adapt across appearances. Custom brand colors are deferred for the whole app until they can be redesigned and tested for light mode, dark mode, contrast, accessibility, and Thai/English UI density.

### Deferred Brand Color Direction

```text
Deferred:
  Lime / electric accent direction
  Purple comeback / PR / deload direction

Before reintroducing:
  Define light + dark variants
  Verify contrast against system backgrounds
  Verify button, text, badge, chart, and card use cases
  Avoid using brand colors for body text unless contrast is proven
```

### Custom Components

```text
SetRowView             weight + reps + RPE/feeling + checkbox
RestTimerRingView      circular countdown ring
ComebackCardView       semantic standout card for return/adaptation moments
EasingBackBadge        appears on comeback-adjusted exercise rows
HowDidThatFeelPicker   Easy / Just right / Hard input for comeback mode
SubstituteActionSheet  Substitute / Defer / Skip / Cancel
DeferredBadge          semantic “Deferred” pill
SubstituteOriginBadge  shows what exercise was replaced
```

### Tap target rule

48pt minimum. Users have sweaty hands and are moving between sets.

### Anti-Guilt UX

Concrete rules:

```text
✓ “Welcome back” after 7+ days
✓ Streak shown only if intact
✓ Never show “streak broken”
✓ Last workout date in soft grey, never red/orange
✓ “Fresh start” framing instead of “you missed X days”
✓ Empty states say “Ready when you are”
✓ No daily reminders
✓ Max 1 push notification per week, opt-in only
```

### Copy Principles

```text
Do:
  “Welcome back”
  “80% means 80 kg today”
  “2-week ramp”
  “We’ve got you”
  “Ready when you are”

Avoid:
  “You missed X days”
  “It’s been too long”
  “Take it easy” without numbers
  “You can do this! 💪🔥”
  guilt, pity, or over-motivation
```

---

## 7. App Architecture

### Pattern: MVVM + Repository + Service

```text
Presentation → Data + Model + Core
Data         → Model + Core
Model        → Core
Core         → nothing
```

### Folder Structure

```text
GymTrack/
├── App/
│   ├── GymTrackApp.swift
│   └── RootView.swift
├── Core/
│   ├── AppTheme.swift
│   ├── Constants.swift
│   └── Extensions/
├── Model/
│   ├── Profile
│   ├── Exercise
│   ├── Program
│   ├── ProgramDay
│   ├── ProgramExercise
│   ├── WorkoutSession
│   ├── WorkoutSet
│   └── Enums/
│       ├── MovementPattern
│       ├── MuscleGroup
│       ├── Equipment
│       ├── ExperienceLevel
│       ├── Goal
│       └── WeightUnit
├── Data/
│   ├── Remote/
│   │   ├── SupabaseClient.swift
│   │   └── AuthService.swift
│   ├── Repository/
│   │   ├── ProfileRepo
│   │   ├── ExerciseRepo
│   │   ├── ProgramRepo
│   │   └── WorkoutRepo
│   └── Services/
│       ├── NextBestSessionEngine
│       ├── SmartSessionAdvisor
│       ├── ComebackRampService
│       ├── ProgressiveOverloadEngine
│       ├── StallDetector
│       ├── DeloadAdvisor
│       ├── SubstituteRanker
│       ├── InjurySubstitutionService
│       ├── RecoveryAdvisor
│       └── SmartNotificationEngine
├── Presentation/
│   ├── Auth/
│   ├── Today/
│   ├── Workout/
│   ├── Programs/
│   ├── History/
│   ├── Progress/
│   ├── Onboarding/
│   └── Settings/
└── Resources/
    ├── Localizable.xcstrings
    ├── Assets.xcassets
    └── Programs/
```

### Future Migration Path: SwiftData

Triggers:

```text
5+ “lost workout” reports
or >5% sessions without finish event
or watchOS active-session reliability needs local persistence
```

Estimated migration cost: 3–4 days because repositories abstract the data source.

---

## 8. Re-engagement Strategy

### Honest premise

Software cannot force someone to the gym. The app’s job is to reduce friction when the user is already considering training, and to stay passively visible without guilt.

### Three-layer re-engagement

```text
Layer 1 — Passive presence
  Home Screen Widget
  Lock Screen Widget
  Apple Watch Complication

Layer 2 — Surgical notifications
  Opt-in only
  Max 1/week
  Triggered by behavior gaps, not daily schedule pressure

Layer 3 — Optional integrations later
  Calendar block integration
  Geofence soft-detect
```

### Smart notification rules

```text
Default: OFF on install
Ask permission: after first 3 workouts logged
Max frequency: 1 per week
Trigger: trained ≥2 sessions but quiet ≥7 days
Never send: 11pm–7am local time
Never send: if previous push was dismissed without opening
Every push: has Less Often / Stop actions
```

### What we do not build

```text
❌ Daily reminders
❌ Streak pressure
❌ Friend/social pings
❌ “You missed X days” notifications
❌ Re-engagement emails as primary channel
```

---

## 9. Agile Roadmap

### Release Channels

```text
TestFlight: every sprint push to main after CI is set up
App Store: phase-level releases
```

### Sprint Progress

```text
✅ Sprint 1 — Foundation + Data          7h actual
✅ Sprint 2 — Custom Program Builder     10h actual
✅ Sprint 3 — Logger + Timer             complete
⏳ Sprint 4 — Today + History + Navigation + Anti-Guilt UX next up
```

---

### PHASE 1 — “Real Life Works” → TestFlight (Sprints 1–6)

**Goal:** A beta user can create/select a program, log workouts, and experience the key differentiator: after missing time, the app handles the comeback.

---

### Sprint 1 — Foundation + Data ✅ DONE

**Effort:** Medium  
**Actual:** 7h

```text
✓ Xcode project + folder structure
✓ Supabase schema
✓ Apple Sign-In auth
✓ Codable models
✓ Repositories
✓ 95 system exercises seeded
✓ Basic localized sign-in screen
```

---

### Sprint 2 — Custom Program Builder ✅ DONE

**Effort:** Complex  
**Actual:** ~10h

```text
✓ ProgramListView
✓ ProgramBuilderView
✓ DayBuilderView
✓ ExercisePickerView
✓ Set targets
✓ Reorder exercises
✓ Active program toggle
✓ Delete program
```

---

### Sprint 3 — Logger + Timer ✅ DONE

**Effort:** Complex

```text
Spec: .claude/sprints/S03-logger-timer/spec.md

✓ WorkoutSessionView as a paged TabView, one exercise per page
✓ WorkoutExercisePageView per exercise: header, set list, Add Set, Finish Exercise
✓ Top progress header: Day name · X / N · K done
✓ WorkoutSessionViewModel with in-memory active session
✓ ActiveSessionBackup using UserDefaults JSON (versioned, includes
  finishedExerciseIds and currentExerciseIndex)
✓ Per-exercise default weight from ProgramExercise.targetWeight (new column)
  → last-logged fallback → blank
✓ Set 1 pre-fills from default weight; set 2+ pre-fills weight and reps from
  the previous set's actual logged values
✓ SetRowView: weight + reps + RPE + checkbox
✓ Add set, copy last values
✓ Swipe/delete set
✓ Background async upload per set
✓ RestTimerRingView with haptic — triggers on set completion
✓ Free swipe between unfinished exercise pages (supports supersets /
  alternating exercises informally; no formal grouping in Sprint 3)
✓ Finish Exercise locks the page, marks it finished, and auto-advances to
  the next unfinished page
✓ Finished pages are read-only for the rest of the session — no resume prompt
✓ Finish Workout enables only when every exercise is finished
✓ Finish session → mark complete remotely → clear backup
✓ Session-level Restore prompt only; restore jumps to the first unfinished
  exercise

Important scope note:
  Do NOT include HealthKit in Sprint 3.
  Sprint 3 must prove reliable logging first.
  Editing past sets of a finished exercise is deferred to History (Sprint 4+).
  Formal superset grouping (group_id paired pages) is deferred.

Done:
  User can log a complete workout one exercise at a time, swipe freely
  between unfinished exercises for supersets, finish each exercise to lock it,
  finish the workout when all exercises are done, and restore mid-session
  after a crash/relaunch.
```

---

### Sprint 4 — Today + History + Navigation + Anti-Guilt UX

**Effort:** Medium

```text
Spec: .claude/sprints/S04-today-history/spec.md

☐ TodayView with greeting, next workout card, Start CTA
☐ TodayViewModel: active program + next day logic
☐ HistoryView: past sessions, newest first
☐ SessionDetailView: sets per exercise (read-only)
☐ Tab navigation: Today / Programs / History (3 tabs; Settings added in Sprint 5)
☐ StreakService: week-based streak, anti-guilt rules
☐ Anti-guilt features:
  ☐ Welcome back banner after 7+ days
  ☐ Streak visible only when intact (≥2 consecutive weeks)
  ☐ Last workout date soft grey
  ☐ Empty states: “Ready when you are”

Done:
  Full loop exists: open → today → start → log → finish → history.
  App feels anti-guilt, not streak-punitive.
```

**Set up Xcode Cloud CI/CD here.**

---

### Sprint 5 — Settings

**Effort:** Simple

```text
Spec: .claude/sprints/S05-settings/spec.md

☐ Settings tab (4th tab) added to TabView
☐ Weight unit toggle: kg / lb (functional, persists via ProfileRepository)
☐ Sign Out (functional, returns to SignInView)
☐ App version + build number (static)
☐ Privacy Policy placeholder
☐ Delete Account placeholder
☐ ProfileRepositoryProviding protocol for test injection

Done:
  User can sign out, toggle weight unit, and see app version.
```

---

### Sprint 6 — Next Best Session Engine v1 / Smart Comeback

**Effort:** Complex

```text
Spec: .claude/sprints/S06-next-best-session/spec.md

This sprint defines the product.
After this sprint, opening the app after 14 days off shows a clear adjusted session.

☐ NextBestSessionEngine coordinator service
☐ SmartSessionAdvisor pure Swift service + tests
☐ ComebackRampService pure Swift service + tests
☐ Basic ProgressiveOverloadEngine pure Swift service + tests
☐ ComebackCardView — semantic, concrete, bilingual-ready
☐ WorkoutSessionView comeback mode:
  ☐ Easing Back badges
  ☐ Adjusted weights and sets
  ☐ Previous baseline visible but not shaming
  ☐ HowDidThatFeelPicker: Easy / Just right / Hard
☐ TelemetryDeck events:
  ☐ comeback_card_shown
  ☐ comeback_session_started
  ☐ comeback_session_finished
  ☐ comeback_exit_baseline_reached
☐ Haptics:
  ☐ light haptic for comeback set completion
  ☐ double haptic when baseline is regained

Done:
  Force last workout date to 15 days ago → comeback card appears,
  weights/sets are reduced, session logs successfully, next ramp decision is ready.
```

**→ RELEASE: TestFlight to 10 Thai + 10 international beta testers**

---

### PHASE 2 — “Polished” → App Store 1.0

**Goal:** Onboarding, templates, localization, stability, and public App Store readiness.

---

### Sprint 7 — Onboarding + Templates + i18n + Brain Polish

**Effort:** Medium

```text
Spec: .claude/sprints/S07-onboarding-i18n/spec.md

☐ OnboardingView: 3 questions
  ☐ goal
  ☐ days/week
  ☐ experience
☐ Recommend starter template
☐ 3 starter templates as JSON bundles:
  ☐ Upper/Lower 4 days
  ☐ PPL 3 days
  ☐ Full Body 2 days
☐ Template → clone to user account → fully editable
☐ Browse Templates entry in ProgramListView
☐ String Catalogs complete:
  ☐ Thai native copy
  ☐ English native copy
☐ Device locale default
☐ Settings language override
☐ StallDetector + tests
☐ DeloadAdvisor + tests
☐ TelemetryDeck V1 core events
☐ App icon + launch screen

Done:
  New user → 3 questions → starter/custom path → Today.
  Both languages feel native. Stalls and deloads have basic handling.
```

---

### Sprint 8 — App Store Ship

**Effort:** Simple

```text
Spec: .claude/sprints/S08-app-store-ship/spec.md

☐ Screenshots TH + EN
☐ App Store description TH + EN
☐ Public privacy policy URL
☐ In-app Privacy Policy link
☐ In-app account deletion initiation
☐ App Store Connect privacy questionnaire
☐ Add Crashlytics before public release
☐ Final TestFlight bug fixes
☐ Submit for review
☐ Check lost-workout feedback and SwiftData trigger

Done:
  App Store 1.0 live.
```

**→ RELEASE: App Store 1.0**

---

### PHASE 3 — “Adaptive” → App Store 1.1

**Goal:** Handle crowded gyms, injuries, progress visibility, and recovery inputs.

---

### Sprint 9 — Substitute + Defer

**Effort:** Medium-Complex

```text
Spec: .claude/sprints/S09-substitute-defer/spec.md

MID-WORKOUT FLOWS
☐ Long-press/swipe exercise row → action sheet:
  ☐ Substitute
  ☐ Do this later
  ☐ Skip entirely
  ☐ Cancel

SUBSTITUTE
☐ Ranked substitute list
☐ Same movement pattern + primary muscle
☐ Different equipment preference when original equipment is unavailable
☐ Familiarity-ranked using user history
☐ Suggested weight from history or biomechanics ratio
☐ SubstituteOriginBadge: “↩ Bench”
☐ Completed sets before substitution remain logged as original

DEFER
☐ Move exercise to end of session
☐ DeferredBadge
☐ Preserve completed sets
☐ Resume at next set number later
☐ End-of-workout prompt if deferred exercise unfinished
☐ Bring Back action

TELEMETRY
☐ exercise_substituted
☐ substitute_rank_selected
☐ exercise_deferred
☐ deferred_exercise_resumed
☐ deferred_exercise_skipped

Done:
  Bench taken → user can substitute or defer without breaking the session.
```

---

### Sprint 10 — Injury Mode + Progress Graphs

**Effort:** Medium-Complex

```text
Spec: .claude/sprints/S10-injury-progress/spec.md

INJURY MODE
☐ Report injury flow: shoulder/knee/back/wrist/elbow/hip/ankle
☐ Injury flag persists until cleared
☐ Affected exercises are substituted or warned
☐ InjurySubstitutionService + tests
☐ Clear injury flow

PROGRESS
☐ Swift Charts: weight over time per exercise
☐ Volume per week
☐ PR history timeline
☐ Plain-language wins:
  ☐ “Bench +15% in 8 weeks”
  ☐ “You’re back to baseline after your break”
☐ Basic muscle-volume summary

Done:
  Injury changes future workouts. Progress is visible without needing spreadsheets.
```

---

### Sprint 11 — HealthKit Recovery / HRV

**Effort:** Medium

```text
Spec: .claude/sprints/S11-healthkit-recovery/spec.md

☐ HealthKit permission flow
☐ Read sleep duration
☐ Read HRV if available
☐ Optional workout session write support
☐ RecoveryAdvisor service + tests
☐ Recovery card variants:
  ☐ normal
  ☐ lighter today
  ☐ rest/deload suggested
☐ Avoid overclaiming HRV certainty
☐ User can ignore recovery suggestion

Done:
  Bad sleep / low recovery can adjust today’s session, but app remains conservative and transparent.
```

**→ RELEASE: App Store 1.1 — “Adapts to real life”**

---

### PHASE 4 — “Revenue + Re-engagement” → App Store 1.2

---

### Sprint 12 — RevenueCat + Paywall

**Effort:** Complex

```text
Spec: .claude/sprints/S12-revenuecat-paywall/spec.md

☐ RevenueCat + StoreKit 2
☐ Entitlement model
☐ 30-day trial configuration if used
☐ Pro Monthly: ฿99/mo
☐ Pro Annual: ฿790/yr
☐ Paywall UI
☐ Paywall copy leads with comeback/life-disruption value
☐ Feature gating:
  ☐ advanced comeback ramp
  ☐ injury substitution
  ☐ HRV recovery
  ☐ substitute/defer intelligence
  ☐ graphs/analytics
  ☐ export
☐ Restore purchases
☐ Subscription management link
☐ RevenueCat events checked

Deferred from initial launch:
  Student tier
  Lifetime tier

Done:
  Pro subscriptions live with a clear paid boundary.
```

---

### Sprint 13 — Watch + Widget + Smart Notifications

**Effort:** Complex

```text
Spec: .claude/sprints/S13-watch-widget-notifications/spec.md

☐ Migration checkpoint: SwiftData if watch/local active session needs it
☐ watchOS rest timer
☐ Home Screen Widget: today’s workout
☐ Lock Screen Widget: today’s lift / comeback state
☐ Apple Watch complication
☐ SmartNotificationEngine
☐ Notification permission after 3 workouts
☐ Max 1 push/week
☐ Less Often / Stop actions
☐ Widget/watch gated behind Pro where appropriate

Done:
  Passive re-engagement layer is live without daily nagging.
```

---

### Sprint 14 — PT Pro

**Effort:** Complex

```text
Spec: .claude/sprints/S14-pt-pro/spec.md

☐ PT Pro tier: ฿390/mo
☐ PT account creation flow
☐ Client invite via share link / LINE / SMS
☐ Client dashboard:
  ☐ last trained
  ☐ days quiet
  ☐ key lift trend
  ☐ comeback status
☐ One-click clone PT template to client
☐ Client owns copy, PT can edit with notification
☐ PT-only notes
☐ Bangkok in-person distribution test

Done:
  5 Bangkok PTs onboarded, managing real clients.
```

**→ RELEASE: App Store 1.2 — Pro + PT Pro live**

---

### FUTURE / OPTIONAL

Build only if data/user demand justifies it.

```text
AI chat:
  Deferred. Rule-based engine is the core AI.
  Add only if users ask for explanations/coaching questions.

Phase planning:
  Bulk/Cut/Maintain deferred. Less important than comeback/decision removal.

Muscle heatmap:
  Optional. Not a differentiator.

B2B gym admin platform:
  Separate product line. Build only after clear pull.

Form check/video:
  Separate product category.

Nutrition:
  Partner/integrate later, do not build V1.

Running/cardio:
  Rejected for this app. Different category and competitors.
```

---

### Sprint Tracking

| Sprint | Name | Status | Hours | Notes |
|---|---|---:|---:|---|
| 1 | Foundation + Data | ✅ | 7 | Complete |
| 2 | Custom Program Builder | ✅ | 10 | Complete |
| 3 | Logger + Timer | ✅ | — | Complete |
| 4 | Today + History + Anti-Guilt | ⏳ | — | Next |
| 5 | Settings | ☐ | — | Phase 1 wrap-up |
| 6 | Next Best Session v1 / Smart Comeback | ☐ | — | Differentiator |
| 7 | Onboarding + Templates + i18n | ☐ | — | App Store polish foundation |
| 8 | App Store Ship | ☐ | — | 1.0 release |
| 9 | Substitute + Defer | ☐ | — | Crowded gym adaptation |
| 10 | Injury Mode + Progress Graphs | ☐ | — | Real-life adaptation |
| 11 | HealthKit Recovery / HRV | ☐ | — | Recovery adaptation |
| 12 | RevenueCat + Paywall | ☐ | — | Monetization |
| 13 | Watch + Widget + Notifications | ☐ | — | Re-engagement |
| 14 | PT Pro | ☐ | — | B2B/PT revenue |

### Velocity expectations

```text
Observed so far:
  Sprint 1: 7h
  Sprint 2: 10h

Planning estimates:
  Simple: 4–6h
  Medium: 8–12h
  Complex: 15–25h

Algorithm-heavy or platform-heavy sprints may take longer.
Do not judge the plan by raw speed alone; judge by validated product learning.
```

---

## 10. Core Algorithms

All services live in `Data/Services/`. They should be pure Swift where possible, with no I/O, and covered by unit tests.

### NextBestSessionEngine

Coordinator service that combines:

```text
active program
last completed session
missed days
exercise history
stall/deload state
comeback state
injury state
recovery state
substitution context
```

Output:

```text
TodayRecommendation:
  program_day
  exercises
  suggested_sets
  suggested_weights
  reason
  mode: normal / comeback / deload / injury_adjusted / recovery_adjusted
```

---

### Progressive Overload

```text
RPE ≤ 7 + all target reps achieved:
  +2.5 kg next time for main lifts
  or +1 rep for accessories

RPE 7.5–8.5:
  same weight, add rep if available

RPE ≥ 9:
  hold or reduce depending on history

3× same weight+reps without progress:
  stall detected
```

Sprint 3 scope: only carry actual weight/reps forward within an exercise (set N → set N+1). Smart cross-session progression suggestions are Sprint 6+.

---

### Smart Session Advisor

```text
0–2 days:
  continue normally

3–6 days:
  reschedule missed days, pick up where left off

7–13 days:
  comeback: -10% weight, -1 set, target easy/controlled

14–20 days:
  comeback: -20% weight, -1 set

21–41 days:
  comeback: -30% weight, ramp 10%/session

42+ days:
  near-restart: -50% weight, slower ramp
```

Copy rule: never say “you failed” or “you missed too much.” Use “welcome back” and “today’s adjusted session.”

---

### Comeback Ramp

```text
HowDidThatFeelPicker maps to internal RPE:
  Easy       → RPE 6.0
  Just right → RPE 7.5
  Hard       → RPE 9.0

Next session:
  RPE < 6.5   → ramp +15%
  RPE 6.5–7.5 → ramp +10%
  RPE 7.5–8.5 → hold weight, add reps
  RPE ≥ 8.5   → reduce 5%

Exit comeback mode:
  current weight ≥ baseline
  AND RPE ≤ 7.5
  → 1 consolidation session
  → resume normal progression
  → fire “baseline regained” moment
```

---

### Stall Detector

```text
Stall if:
  same exercise
  same load
  same or lower reps
  repeated 3 exposures
  and RPE not decreasing

Then:
  suggest deload or rep-target change
```

---

### Deload Advisor

```text
Triggers:
  repeated stalls
  high RPE trend
  poor comeback feedback
  low recovery later

Decision:
  -10% to -15% load
  or -1 set per exercise
  or technique/light day

Exit:
  one successful controlled session
  then resume progression gradually
```

---

### Substitute Ranker

```text
Inputs:
  original exercise
  user history
  unavailable equipment if known
  exercise library

Filter:
  same movement pattern
  same primary muscle
  different exercise ID
  equipment not marked unavailable

Rank:
  1. user familiarity = historical set count
  2. equipment difference if original equipment unavailable
  3. stable alphabetical fallback

Suggested weight:
  if user logged substitute before:
    last weight × performance trend
  else:
    original target × biomechanics ratio

Initial biomechanics ratios:
  barbell → machine same pattern: 0.85
  barbell → dumbbell same pattern: 0.40 per side
  barbell → cable same pattern: 0.75
  free weight → smith machine: 0.95
```

---

### Defer Logic

```text
When user defers exercise:
  exercise.deferred = true
  original_order preserved
  exercise_order = end of list
  completed sets remain logged

When user returns:
  resume at next set number

End of workout:
  if deferred exercise unfinished:
    prompt: Finish now / Skip and finish workout

Constraints:
  multiple deferred exercises allowed
  cannot defer last remaining exercise
  defer is reversible via Bring Back
```

---

### Injury Substitution

```text
User reports:
  shoulder, knee, lower back, wrist, elbow, hip, ankle

For each exercise:
  if affected area overlaps primary or secondary muscles/joints:
    find safer candidates
    prefer same movement pattern where safe
    prefer familiar exercises
    show substituted badge

Important:
  App should not diagnose or treat injury.
  Copy must be conservative and recommend professional help for pain.
```

---

### Recovery Advisor

```text
Inputs:
  sleep_hours
  sleep_baseline
  hrv_today
  hrv_baseline

Score:
  hrv_ratio = hrv_today / baseline
  sleep_ratio = sleep_today / baseline
  combined = hrv_ratio * 0.6 + sleep_ratio * 0.4

Decision:
  combined ≥ 0.9:
    normal training
  0.75–0.9:
    normal but monitor effort
  0.6–0.75:
    suggest -10% or -1 set
  <0.6:
    suggest deload/rest option

Copy:
  “Your recovery looks lower than usual. Today is adjusted.”
  Do not claim medical certainty.
```

---

## 11. Program Templates

Templates ship in two stages:

### Starter templates — Sprint 6

1. **Upper/Lower 4 Days** — Intermediate, balanced strength + muscle
2. **PPL 3 Days** — Beginner/intermediate, each pattern once
3. **Full Body 2 Days** — Beginner or time-constrained, minimum effective dose

### Additional templates — Sprint 8 or later

4. **PPL 6 Days** — Intermediate/advanced, high volume
5. **Bro Split 5 Days** — Intermediate, dedicated muscle focus

### Template Implementation Notes

```text
Storage:
  JSON files in app bundle

Path:
  /Resources/Programs/upper-lower-4day.json
  /Resources/Programs/ppl-3day.json
  /Resources/Programs/full-body-2day.json
  /Resources/Programs/ppl-6day.json
  /Resources/Programs/bro-split-5day.json

On selection:
  app reads JSON
  creates Program + ProgramDays + ProgramExercises in Supabase
  user owns the copy
  fully editable

Exercise matching:
  Prefer stable exercise slug
  Fallback to canonical name only if needed
```

---

## 12. Monetization

### Tier Structure

| Tier | Price | Includes |
|---|---:|---|
| Free | ฿0 | Logger, custom programs, 3 starter templates, basic comeback card, timer, basic history, both languages |
| Pro Monthly | ฿99/mo | Advanced comeback ramp, injury mode, substitute/defer intelligence, HRV recovery, progress graphs, volume analytics, Watch/Widget, export, smart notifications |
| Pro Annual | ฿790/yr | Same as Pro Monthly, annual discount |
| PT Pro | ฿390/mo | Pro + client management, client dashboard, PT notes, program assignment |

### Deferred pricing experiments

```text
Student tier:
  Defer until Pro conversion is understood.
  Reason: verification adds complexity.

Lifetime tier:
  Defer until retention and LTV are known.
  Reason: may sell best users too cheaply.
```

### Free vs Pro Philosophy

```text
Free:
  Useful enough to build trust.
  Gives a taste of the differentiator.
  “You missed 2 weeks. Start around 80% today.”

Pro:
  Manages the training system over time.
  Full comeback ramp.
  Advanced progression/deload.
  Recovery adaptation.
  Injury and gym-crowded workflows.
```

Short version:

> **Free tells you what to do today. Pro manages the whole training system.**

### Paywall Strategy

```text
Do not cold-paywall before value is understood.

Recommended flow:
  Sign in
  → onboarding
  → template/custom program
  → Today screen / recommendation
  → Pro trial offer
```

### Trial Strategy

Use a **30-day trial** if RevenueCat/StoreKit setup supports the launch strategy cleanly.

Reason:

```text
GymTrack’s value compounds over multiple sessions.
Busy users may train only 1–3×/week.
A short 3–7 day trial may expire before the user experiences comeback/recovery value.
```

### Revenue Projections — Planning Only

These are not promises. Use them as directional milestones.

```text
Early goal:
  50–100 paying Pro users
  ฿5K–฿10K MRR

Indie validation goal:
  500 paying Pro users
  ~฿50K MRR

Strong indie goal:
  1,500 paying Pro users
  ~฿150K MRR

PT Pro upside:
  50 PTs × ฿390 = ฿19.5K MRR
  100 PTs × ฿390 = ฿39K MRR
```

### Monetization Learning Before Sprint 11

Track:

```text
pro_feature_tapped
paywall_preview_seen
feature_locked_viewed
comeback_basic_used
advanced_comeback_teaser_tapped
trial_started
trial_converted
trial_cancelled
```

---

## 13. Product Metrics

### North-Star Metric

```text
% of new users who complete 2 workout sessions within 14 days of signup
```

Why:

```text
1 session can be curiosity.
2 sessions means they returned.
14 days fits busy lifters training 1–3×/week.
```

### Activation Funnel

```text
sign_up_completed
onboarding_completed
program_created_or_selected
first_workout_started
first_workout_finished
second_workout_finished
```

### Differentiator Metrics

```text
comeback_card_shown
comeback_session_started
comeback_session_finished
baseline_reached_after_comeback
smart_suggestion_shown
smart_suggestion_accepted
smart_suggestion_edited
smart_suggestion_ignored
```

### Real-Life Adaptation Metrics

```text
exercise_substituted
substitute_rank_selected
exercise_deferred
deferred_exercise_resumed
deferred_exercise_skipped
injury_reported
injury_substitution_accepted
recovery_adjustment_shown
recovery_adjustment_accepted
```

### Retention Metrics

```text
D7 return
D30 return
week_2_workout_completion
completed_2_sessions_within_14_days
completed_workouts_in_3_consecutive_calendar_weeks
```

### Comeback Recovery Rate

```text
users inactive 7+ days who complete 2 sessions after returning
```

### Reliability Metrics

```text
workout_started
workout_finished
workout_restored
unfinished_session_detected
upload_failed
session_finish_missing
```

Migration watch:

```text
5+ lost-workout reports
or >5% sessions without finish event
→ revisit storage strategy / SwiftData
```

### Monetization Metrics

```text
paywall_viewed
trial_started
trial_cancelled
trial_converted
monthly_started
annual_started
restore_purchase_tapped
pro_feature_tapped
```

---

## 14. B2B Gym Partnership Track

Separate product line. Do not let this scope creep into B2C roadmap.

### Opportunity

Independent gyms care about member retention. GymTrack can become a comeback/retention layer on top of existing gym operations.

### Build only when all are true

```text
☐ PT Pro is healthy: 50+ paying PTs in Thailand
☐ 5+ gym owners ask unprompted
☐ Core B2C app is stable after public launch
☐ Clear distribution path exists through Bangkok PT/gym network
```

### Narrow product

```text
Gym dashboard:
  inactive members
  comeback campaigns
  co-branded onboarding
  simple member status

Not building:
  billing
  class booking
  door access
  full gym CRM
```

---

## 15. Marketing Plan

### Pre-launch

Channels:

```text
Thailand:
  TikTok
  Facebook fitness groups
  LINE OpenChat
  Thai gym communities

International:
  Reddit
  X/Twitter
  IndieHackers
  iOS developer communities
```

### Core content pillars

#### 1. Comeback after missing time

```text
“หยุดเล่นยิม 2 อาทิตย์ กลับมายังไง?”
“Stopped gym for 2 weeks? Don’t restart at 100%.”
```

#### 2. Crowded gym

```text
“Bench taken? Tap once. We swap it.”
```

#### 3. Progression confusion

```text
“Should you add weight today? The app tells you.”
```

#### 4. Anti-guilt comeback

```text
“No streak broken. No shame. Just today’s workout.”
```

### TestFlight

```text
10 Thai beta users
10 international beta users
First 50 users get 3 months Pro when monetization launches
```

### Launch

```text
Thai community launch
short-form demo videos
micro-influencer outreach
Product Hunt only as secondary channel
```

### Growth loops

```text
Comeback share card:
  after baseline regained
  “I came back. Lost nothing.”
  system-color visual for now; brand visual direction deferred

Crowded gym demo:
  bench taken → substitute → suggested weight ready

PT-led distribution:
  each PT brings 5–15 clients
```

### Anti-marketing principles

```text
❌ Do not compete on generic tracker features
❌ Do not lead with “AI-powered”
❌ Do not guilt users
✅ Own: real life happens, the app handles it
✅ Make the comeback the brand
```

---

## 16. Development Workflow & CI/CD

### Full Loop

```text
1. READ   GYMTRACK.md
2. SPEC   create /specs/S[N]-name.md
3. BUILD  Claude Code / local implementation
4. REVIEW Codex or second model review
5. TEST   simulator + unit tests
6. FIX    iterate until stable
7. COMMIT push to main
8. CI/CD  Xcode Cloud → TestFlight
9. SHIP   phase complete → App Store
10. LOOP  update source-of-truth and sprint status
```

### CI/CD

Set up in Sprint 4.

```text
main push
→ build
→ test
→ archive
→ TestFlight
```

### Branching

```text
main       → always deployable
feature/*  → one branch per sprint or task
```

### AI Workflow

```text
Planning/spec:
  Claude / ChatGPT

Implementation:
  Claude Code first choice
  Gemini CLI or Codex fallback depending on limits

Review:
  Codex for code review
  second model for architecture sanity check

Parallel worktrees:
  only for isolated tasks:
    UI polish
    tests
    copy/localization
    isolated services
  avoid parallel changes to shared models/schema unless carefully coordinated
```

---

## 17. Decisions Made and Rejected

| Area | Chosen | Rejected / Deferred | Why |
|---|---|---|---|
| Framework | SwiftUI | Flutter/RN | Native Apple path, watchOS |
| Backend | Supabase | Firestore | Relational data, SQL clarity |
| Storage V1 | Supabase + in-memory + UserDefaults backup | SwiftData hybrid | Avoid overengineering |
| Models | One Codable struct per entity | DTO/model split | Less mapping code |
| AI V1 | Rule-based services | AI-first chat | Testable, cheap, offline |
| AI chat | Future/optional | Mandatory Sprint 13 | Not core until demand appears |
| Design | SwiftUI native | Figma-heavy process | Solo speed |
| Analytics | TelemetryDeck | Firebase Analytics V1 | Privacy-first, Swift-native |
| Crashes | Apple early → Crashlytics before public | Sentry V1 | Lean now, stronger later |
| Architecture | MVVM + Repo + Service | UseCase/Coordinator-heavy | Lean and understandable |
| Positioning | Adapts to real life | Generic coach/tracker | More specific wedge |
| Differentiator | Next Best Session / Smart Comeback | Muscle map | Comeback is more ownable |
| HealthKit | Sprint 11 | Sprint 3 | Avoid overloading logger sprint |
| Social | Cut | Friends/community | Distracts, violates anti-guilt |
| Streak pressure | Cut | Broken streaks | Bad fit for busy users |
| Notifications | Max 1/week, opt-in | Daily reminders | Respectful re-engagement |
| Custom programs | Sprint 2 | Later | Power users and dogfooding |
| Templates | Sprint 7 | Sprint 9 only | First-time users need easy path |
| Substitute + Defer | Sprint 9 | One generic swap flow | Different user intents |
| Injury mode | Sprint 10 | Future | Strong “real life” fit |
| HRV/recovery | Sprint 11 | V1 logger | Useful later, not MVP |
| RevenueCat | Sprint 12 | Hand-rolled subscriptions | Less subscription complexity |
| Student tier | Deferred | Launch | Verification complexity |
| Lifetime tier | Deferred | Launch | Need LTV/retention first |
| PT Pro | Sprint 14 | B2B platform first | PT is smaller/simpler wedge |
| B2B gyms | Separate track | Core roadmap | Different sales/product motion |
| Running expansion | Rejected | Unified fitness app | Dilutes strength moat |
| Muscle heatmap | Optional | Core Pro feature | Not differentiated enough |
| CI/CD | Xcode Cloud | GitHub Actions | Simplest Apple path |
| Release cadence | Sprint→TestFlight, phase→App Store | Every sprint App Store | Lower review/marketing overhead |
| Whole-app color policy | SwiftUI system and semantic colors only | Custom lime/purple brand colors in current app UI | Avoid light-mode readability problems; follow adaptive Apple color behavior first |
| Brand color direction | Deferred lime/purple exploration | Shipping unreadable accent colors | Revisit only after light/dark contrast and UI-role testing |
| Sprint 3 logger UI | Paged one-exercise-at-a-time + per-exercise finish | Single-scroll sectioned list | Clearer "show next exercise" product flow |
| Sprint 3 supersets | Free-swipe between unfinished pages | Formal group_id paired pages | Supports superset/alternating workflows without expanding Sprint 3 scope |
| Sprint 3 default weight | Add nullable program_exercises.target_weight column | Derive only from history | Lets users set a starting weight per exercise; history is a fallback |
| Custom colors policy | No active custom UI colors anywhere in the app | `gymAccentText`, ad-hoc hex literals, custom named color styling | System colors are the current app-wide contract; brand palette can return later after validation |

---

## 18. Open Decisions

```text
☐ Final app name
  Current placeholder: GymBros
  Must resolve by Sprint 8 before App Store submission

☐ Sound vs haptic-only
  Current default: haptic-only
  Decide after testing special moments

☐ Student tier
  Deferred until Pro conversion data exists

☐ Lifetime tier
  Deferred until retention/LTV data exists

☐ lb toggle timing
  kg default confirmed
  lb toggle likely needed before international scale

☐ Formal superset grouping
  Sprint 3 supports supersets via free-swipe between pages.
  A future sprint may add explicit group_id pairing for true alternating
  set rounds (A1 → B1 → rest → A2 → B2).
  Decide based on user feedback after Sprint 3 ships.
```

---

## 19. Decision Log

### 2026-05-17 — Settings sprint split + roadmap renumber

- Extracted Settings from Sprint 4 into its own **Sprint 5**. Sprint 4 remains "Today + History + Navigation + Anti-Guilt UX" without Settings rows.
- Sprint 5 scope: Settings tab (4th tab), weight-unit toggle (kg/lb, functional), Sign Out, app version, Privacy Policy placeholder, Delete Account placeholder.
- Shifted old Sprints 5–13 to Sprints 6–14 doc-wide (Sprint Tracking table, roadmap entries, all cross-references, decision log forward pointers).
- Phase 1 ("Real Life Works") now spans Sprints 1–6 (was 1–5), ending after Next Best Session v1.
- Rationale: Settings is independent work that should not block the core Today+History loop; giving it a dedicated sprint keeps Sprint 4 focused and makes the roadmap easier to track.
- Sprint 4 spec: `.claude/sprints/S04-today-history/spec.md`; Sprint 5 spec: `.claude/sprints/S05-settings/spec.md`.

### 2026-05-11 — Whole-app system color reset

- The whole app now uses SwiftUI system and semantic colors only.
- Deferred the lime/purple brand palette because the lime accent is hard to read on white/light backgrounds.
- Active UI must not use `Color.gymAccent`, `Color.gymPurple`, `Color.gymAccentText`, custom named color styling, hex literals, or `Color(red:green:blue:)`.
- Revisit brand colors only after defining light/dark variants and testing contrast across buttons, badges, cards, charts, Thai copy, and English copy.
- Decision is based on Apple SwiftUI Color, HIG Color, and HIG Dark Mode guidance favoring dynamic, semantic colors that adapt to appearance.

### 2026-05-11 — Sprint 3 realignment

- Reframed Sprint 3 logger as a paged, one-exercise-at-a-time flow with per-exercise finish.
- Free swipe between unfinished exercise pages supports supersets and alternating workflows without modeling them formally.
- Added `program_exercises.target_weight` (nullable) as the per-exercise default weight source; fallback chain at session start is `targetWeight` → last-logged weight → blank.
- Set 2+ pre-fills weight and reps from the previous set's **actual** logged values; RPE stays blank per set.
- Resume on relaunch is session-level only; restore jumps to the first unfinished exercise. Finished exercise pages never prompt resume and are read-only for the remainder of the session.
- Editing past sets of finished exercises deferred to History (Sprint 4+).
- Formal superset grouping (paired pages with a `group_id` column) deferred — added to Open Decisions.
- Color policy now follows the whole-app system color reset above.

### 2026-05-12 — Sprint 3 complete

- Logger + Timer implementation is complete and smoke-tested on `iPhone 17e`.
- User can create a workout session, resume an unfinished session, add/delete sets, skip unfinished exercises by finishing the exercise page, and finish the workout session.
- Start Workout is wired from `DayBuilderView` through `WorkoutSessionScreen` and `WorkoutSessionViewModel`.
- Automated verification passed: build, targeted workout tests, full test suite, color grep, and `git diff --check`.
- Next up: Sprint 4 — Today + History + Navigation + Anti-Guilt UX.

### 2026-05-11 — Source-of-truth consolidation

- Reframed product around: **“the gym app that adapts to your real life.”**
- Clarified that the primary concept is not simply “inconsistent lifters,” but people with real responsibilities and gym decision fatigue.
- Added **Competitive Wedge** section.
- Renamed core differentiator umbrella to **Next Best Session Engine**.
- Kept **Smart Comeback** as the first public proof of the engine.
- Moved HealthKit out of Sprint 3 to avoid overloading logger implementation.
- Split overloaded roadmap items:
  - Sprint 9 = Substitute + Defer
  - Sprint 10 = Injury Mode + Progress Graphs
  - Sprint 11 = HealthKit Recovery / HRV
  - Sprint 12 = RevenueCat + Paywall
  - Sprint 13 = Watch + Widget + Notifications
  - Sprint 14 = PT Pro
- Added dedicated **Product Metrics** section.
- Deferred Student and Lifetime pricing until after conversion/retention data.
- Kept B2B gym partnerships as a separate track, not core roadmap.

### 2026-05-11 — Running expansion + mid-workout swap design

- Running expansion rejected for this app.
- Reason: different category, competitors, metrics, hardware expectations, and workflow.
- If pursued later, consider separate app rather than unified product.
- Mid-workout swap expanded into two flows:
  - Substitute = replace exercise
  - Defer = move exercise later
- SubstituteRanker algorithm specified.
- Defer logic specified with preserved set history.

### 2026-05-11 — Strategic refinement after Sprints 1–2

- Sprint 1 complete: 7h actual.
- Sprint 2 complete: ~10h actual.
- Smart Comeback moved into Phase 1 because it defines the product.
- Templates moved earlier: 3 starter templates in Sprint 7.
- Anti-guilt UX promoted from principle to concrete UI requirements.
- Injury substitution added as a core real-life adaptation feature.
- HRV/recovery added later, not MVP.
- Gemini AI chat deprioritized.
- Worldwide ambition confirmed while keeping Thai as launch wedge.
- Re-engagement strategy set: widget-first, max 1 push/week, no daily reminders.

### 2026-05-10

- Apple Sign-In: collect Apple user ID + email, save name if Apple provides it; do not force real email or extra profile fields at signup.
- Free plan: useful logger + small coach taste.
- Pro boundary: full coach system.
- Analytics: TelemetryDeck for product behavior.
- Crash tracking: Apple early, Crashlytics before public launch.
- Product metrics: activation, comeback, suggestion, reliability.

### 2026-05-08

- App name placeholder: GymBros.
- Default unit: kg.
- Early brand color idea: lime accent + purple secondary, now deferred by the 2026-05-11 whole-app system color reset.
- Program templates defined.
- Architecture selected: Core / Model / Data / Presentation.
- CI/CD selected: Xcode Cloud.
- Social and videos cut.
- Storage simplified: Supabase + in-memory + UserDefaults backup.

### 2026-05-06

- Document created.
- Initial stack: SwiftUI + Supabase + rule-based engine.

---

## 20. Appendix — Quick Reference

**What we are:** The gym app that handles when life breaks the plan.

**Who we serve:** Busy gym-goers who want to train but do not want to manage the training system themselves.

**The gap:** Most apps assume you show up perfectly. GymTrack assumes real life interrupts.

**Headline feature:** Next Best Session Engine, proven first through Smart Comeback.

**Product promise:** You have a life. GymTrack handles the gym decisions.

**Core loop:** open app → know exactly what to do today → execute → done.

**Colors:** Lime for normal progress. Purple for comeback, deload, PRs, and “this is different” moments.

**Pricing direction:** Free useful logger + Pro full coach system. Start with monthly/annual. Defer Student/Lifetime.

**Analytics:** TelemetryDeck for product behavior. RevenueCat for subscription analytics. Apple/Crashlytics for crash reporting.

**North-star metric:** % of new users who complete 2 workout sessions within 14 days.

**Next up:** Sprint 4 — Today + History + Navigation + Anti-Guilt UX.

---

## Reference Notes

These sources informed strategic assumptions and should be rechecked before public claims:

- RevenueCat subscription benchmarks and trial-length data: https://www.revenuecat.com/state-of-subscription-apps/
- Apple subscription/free trial guidance: https://developer.apple.com/app-store/subscriptions/
- TelemetryDeck Swift/privacy-first analytics: https://telemetrydeck.com/platforms/swift/
- Exercise adherence / lack-of-time research: https://pmc.ncbi.nlm.nih.gov/articles/PMC11992532/
