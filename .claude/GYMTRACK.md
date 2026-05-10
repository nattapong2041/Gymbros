# GymTrack — Source of Truth

> Living document. Update as decisions evolve.
> Last updated: 2026-05-10

---

## Table of Contents

1. [Vision & Identity](#1-vision--identity)
2. [Target Users](#2-target-users)
3. [Core Value Proposition](#3-core-value-proposition)
4. [Tech Stack](#4-tech-stack)
5. [Design System](#5-design-system)
6. [App Architecture](#6-app-architecture)
7. [Agile Roadmap](#7-agile-roadmap)
8. [Core Algorithms](#8-core-algorithms)
9. [Program Templates](#9-program-templates)
10. [Monetization](#10-monetization)
11. [Product Metrics](#11-product-metrics)
12. [Marketing Plan](#12-marketing-plan)
13. [Development Workflow & CI/CD](#13-development-workflow--cicd)
14. [Decisions Made (and Rejected)](#14-decisions-made-and-rejected)
15. [Open Decisions](#15-open-decisions)
16. [Decision Log](#16-decision-log)

---

## 1. Vision & Identity

**App name:** GymBros *(placeholder — will rename before App Store launch)*

**Positioning:** The gym companion for people with real lives.

**Tagline TH:** "มาแค่นี้พอ เราจะดูแลส่วนที่เหลือ"
**Tagline EN:** "Just show up. We'll handle the rest."

**Problem:** 50% of gym members quit within 6 months — not because they're lazy, but because no app handles real life: missed sessions, comebacks, decision fatigue, invisible progress.

**What makes us different:** Every app is a tracker. We are a coach. Open app → zero decisions → execute → done.

---

## 2. Target Users

**Primary:** Thai gym-goers, 18–35, iPhone. Wants 3–5×/week, actually trains 1–3×/week.

**Not for (yet):** Competitive powerlifters, cardio athletes.

**Secondary (V3):** Personal trainers managing 5–15 Thai clients.

**Insight:** The inconsistent lifter is 80% of the gym market and 0% of apps' focus.

---

## 3. Core Value Proposition

```
Apple Fitness: how many calories you burned
GymTrack:      what to lift, how much, what's next — even after 2 weeks off
```

---

## 4. Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| iOS + watchOS | SwiftUI | watchOS + Foundation Models + native |
| Storage (V1) | Supabase + in-memory active session | Simple, fast |
| Storage (later) | SwiftData + Supabase | ONLY if user feedback demands it |
| Cloud | Supabase (Postgres) | Relational data, SQL queries |
| Auth | Supabase + Apple Sign-In | One tap |
| Auth later | Google Sign-In optional, Apple Sign-In remains | If a third-party login is added, keep Apple Sign-In available for App Review compliance |
| AI V1 | Rule-based Swift | Offline, Thai, free |
| AI V2 | Firebase AI Logic (Gemini) | Thai coaching, Pro only |
| Payments | StoreKit 2 + RevenueCat | Native subscriptions |
| Health | HealthKit (post-1.0 unless beta feedback demands it) | Nice-to-have, not core differentiation |
| i18n | String Catalogs | Thai is primary language. English is user-selectable in Settings. |
| Crashes early beta | Apple built-in | Enough while validating the core loop |
| Crashes before App Store launch | Crashlytics | Free, mobile-native, needed before public release |
| Analytics | TelemetryDeck | Privacy-first, Swift native |
| CI/CD | Xcode Cloud | Auto TestFlight on push to main |

---

## 5. Design System

### Localization Strategy

```
Thai = primary language of the app
English = alternative, user switches in Settings

How it works:
  String keys:        English format in code (e.g. "start_workout")
                      → readable for development, language-agnostic
  Default display:    Follows device language
  Device locale:      If device is set to Thai → Thai
                      If device is set to anything else → English
  User override:      Settings → Language → ภาษาไทย / English
  String Catalogs:    sourceLanguage = "en" (key format)
                      Locales: "th" (complete) + "en" (complete)
                      Thai strings are never optional — must always exist

Why device locale first?
  It is the fastest correct default for V1. Thai users with Thai devices get Thai.
  Everyone else gets English. Sprint 6 adds an easy Settings override.
```

### Approach

SwiftUI native design system. No Figma. Paper sketches for 4 key screens.

### Color Strategy

```
Base:   SwiftUI semantic colors (automatic dark/light mode)
        .systemBackground, .secondarySystemBackground
        .primary, .secondary
        These handle 90% of all color needs.

Custom: TWO named colors defined in Assets.xcassets
        → AccentColor (primary interactive)
        → GymPurple   (special states)
```

### The Two Custom Colors

Inspired by image reference (black → purple → green gradient palette):

```swift
// Assets.xcassets → AccentColor (electric lime)
// Light mode:  #C8FF00
// Dark mode:   #C8FF00
// Used for:    All primary buttons, toggles, progress rings,
//              checkmarks, links, completion states
//              "You did it" moments

// Assets.xcassets → GymPurple
// Light mode:  #9B7FE8
// Dark mode:   #9B7FE8
// Used for:    Comeback mode cards, PR badges, deload indicators,
//              milestone achievements, "special" states
//              "This is different" moments
```

### Color Semantic Map

```
Lime   (#C8FF00) →  Completion  · Progress  · Primary CTA   · Normal training
Purple (#9B7FE8) →  Comeback    · PRs       · Deload        · Milestones
Red    (system)  →  Destructive · Delete    · Warning
Green  (system)  →  Success (use sparingly — lime is our green)
```

### Why This Works for a Gym App

```
Psychologically:
  Lime    = "go", "push", "you're progressing"
  Purple  = "this session is different", "you achieved something"

In context:
  Normal suggestion card     → lime accent
  "PR broken" badge          → purple
  Comeback mode card         → purple border + "start lighter"
  Rest timer ring            → lime countdown
  Deload week card           → purple (rest is special, not failure)
```

### AppTheme.swift

```swift
import SwiftUI

extension Color {
    // Primary interactive — electric lime
    static let gymAccent = Color("AccentColor")

    // Special states — purple
    static let gymPurple = Color("GymPurple")

    // Convenience aliases
    static let gymSurface = Color(.secondarySystemBackground)
    static let gymBackground = Color(.systemBackground)
}

extension Font {
    // Chunky numbers for weights and reps
    static let gymNumber = Font.title.bold().monospaced()
    static let gymNumberLarge = Font.largeTitle.bold().monospaced()
}
```

### Custom Components (Only 2)

```
SetRowView         weight + reps + RPE + checkbox
RestTimerRingView  circular countdown ring (lime stroke on dark)
```

### Tap Targets: 48pt minimum — sweaty hands

---

## 6. App Architecture

### Pattern: MVVM + Repository + Service

```
Presentation  → Data + Model + Core
Data          → Model + Core
Model         → Core
Core          → nothing
```

### Folder Structure

```
GymTrack/
├── App/                GymTrackApp.swift, RootView.swift
├── Core/               AppTheme.swift, Constants.swift, Extensions/
├── Model/              Profile, Exercise, Program, ProgramDay,
│                       ProgramExercise, WorkoutSession, WorkoutSet
│   └── Enums/          MovementPattern, MuscleGroup, Equipment,
│                       ExperienceLevel, Goal, WeightUnit, TrainingPhase
├── Data/
│   ├── Remote/         SupabaseClient.swift, AuthService.swift
│   ├── Repository/     ProfileRepo, ExerciseRepo, ProgramRepo, WorkoutRepo
│   └── Services/       ProgressiveOverloadEngine, SmartSessionAdvisor,
│                       ComebackRampService, StallDetector, DeloadAdvisor
├── Presentation/
│   ├── Auth/           SignInView
│   ├── Today/          TodayView + ViewModel
│   ├── Workout/        WorkoutSessionView + ViewModel + Components/
│   ├── Programs/       ProgramListView, ProgramBuilderView,
│   │                   ProgramDetailView, DayBuilderView, ExercisePickerView
│   ├── History/        HistoryView, SessionDetailView + ViewModel
│   ├── Progress/       ProgressView + ViewModel
│   ├── Onboarding/     OnboardingView + ViewModel
│   └── Settings/       SettingsView
└── Resources/          Localizable.xcstrings, Assets.xcassets
```

### Future Migration Path: SwiftData

**Triggers:** 5+ "lost workout" reports / >5% sessions without finish event / building watch app (Sprint 11)

**Migration cost:** ~3–4 days (repos abstract the data source — swap without touching ViewModels)

---

## 7. Agile Roadmap

### Release Channels

```
TestFlight: every sprint push to main (CI/CD auto-deploys)
App Store:  every phase complete (batched for marketing stories)
```

---

### PHASE 1 — "Usable" → TestFlight (4 sprints)

**Goal:** Dev creates their own Upper/Lower program and logs workouts. Full loop tested.

---

**Sprint 1 — Foundation + Data** | Effort: Medium
```
Spec: /sprints/S01-foundation-data/spec.md
Plan: /sprints/S01-foundation-data/plan.md

☐ Xcode project + folder structure
☐ Supabase schema.sql + seed exercises
☐ All Codable model structs + enums
☐ SupabaseClient + Apple Sign-In auth
☐ Repositories (Profile, Exercise, Program, Workout)
☐ ~100 system exercises seeded with canonical names
☐ Localizable.xcstrings — Thai (primary) + English (fallback)
☐ Login screen strings localized (first real usage)
☐ App language follows device locale automatically (Thai device → Thai, all other device languages → English)

Done: Signs in. Data layer ready. Exercises in Supabase.
      Localization infrastructure ready — every sprint adds strings from now on.
```

---

**Sprint 2 — Custom Program Builder** | Effort: Complex
```
Spec: /specs/S02-custom-program-builder.md

☐ ProgramListView — list programs + "Create New"
☐ ProgramBuilderView — create/edit program (name, description)
☐ Add/remove/rename program days
☐ DayBuilderView — manage exercises per day
☐ ExercisePickerView — search/filter exercise library
☐ Set targets per exercise: sets, rep range, target rest seconds
☐ Reorder exercises within a day (drag handle)
☐ Mark program as active (one at a time)
☐ Delete program (with confirmation)

Test: Create Upper/Lower 4-day program (dev's own routine)

Done: Dev creates their full Upper/Lower plan, navigates it.
```

---

**Sprint 3 — Logger + Timer** | Effort: Complex
```
Spec: /specs/S03-logger-timer.md

☐ WorkoutSessionView — active workout screen
☐ WorkoutSessionViewModel — session in memory (@Observable)
☐ ActiveSessionBackup — UserDefaults JSON crash safety
☐ SetRowView — weight + reps + RPE + checkbox
☐ Add set (copies last values), swipe to delete
☐ Background async upload per set (fire-and-forget)
☐ RestTimerRingView — bottom sheet, lime ring, haptic, records target vs actual rest
☐ Finish → mark complete in Supabase → clear backup
☐ Crash recovery: "Restore?" prompt on relaunch

Done: Log full Upper A. Rest timer works.
      Crash recovery tested.
```

---

**Sprint 4 — Today + History + Navigation** | Effort: Medium
```
Spec: /specs/S04-today-history-nav.md

☐ TodayView — greeting, today's workout card, "Start" CTA
☐ TodayViewModel — active program + next day logic
☐ HistoryView — past sessions, newest first
☐ SessionDetailView — sets per exercise for a session
☐ Tab navigation: Today / Programs / History / Settings
☐ Settings → Sign out calls Supabase Auth signOut and returns to login
☐ Settings → Legal section reserves Privacy Policy and Account Deletion entries for App Store readiness
☐ Basic onboarding — goal, days/week, experience
☐ First-run choice: "Start with a recommended plan" or "Build my own"
☐ V1 starter plans: Full Body 2 Days + PPL 3 Days
☐ Empty states (no program, no sessions)

Done: Full loop. New user can choose a starter plan or build their own.
      Open → today's workout → start → log → finish → see in history.
      CI/CD set up.
```

**→ RELEASE: TestFlight to 20 beta testers**
**→ SET UP Xcode Cloud CI/CD here**

---

### PHASE 2 — "Smart" → App Store 1.0 (3 sprints)

**Goal:** App tells you what to lift. Handles missed days. Public launch.

---

**Sprint 5 — The Brain** | Effort: Complex
```
Spec: /specs/S05-brain.md

☐ ProgressiveOverloadEngine (service + 100% tests)
☐ StallDetector (service + 100% tests)
☐ DeloadAdvisor (service + 100% tests)
☐ SmartSessionAdvisor (service + 100% tests)
☐ ComebackRampService (service + 100% tests)
☐ Lime suggestion card in TodayView
☐ Purple comeback card in TodayView

Done: "Try 77.5kg on Bench today."
      "14 days off — start at 65kg."
```

---

**Sprint 6 — Onboarding + Localization + Polish** | Effort: Medium
```
Spec: /specs/S06-onboarding-i18n.md

☐ Expand onboarding polish — clearer copy, smoother first-run path
☐ String Catalogs — all text in Thai (complete) + English (complete)
☐ Settings → Language toggle can override device language (ภาษาไทย / English)
☐ UserDefaults stores language preference
☐ TelemetryDeck — V1 product metrics events
☐ App icon + launch screen
☐ Anti-guilt UX — never show "streak broken"
☐ Pro fake-door learning: surface locked premium features before monetization build

Done: New user → starter plan or custom plan → Today.
      App follows device language. Settings lets user switch language.
      Core product metrics are measurable.
```

---

**Sprint 7 — App Store Ship** | Effort: Simple
```
Spec: /specs/S07-app-store-ship.md

☐ Screenshots (TH + EN)
☐ App Store description (Thai primary)
☐ Public privacy policy URL
☐ In-app Privacy Policy link from Settings
☐ In-app account deletion initiation from Settings
☐ App Store Connect privacy questionnaire
☐ Add Crashlytics before public release
☐ Final TestFlight → fix bugs
☐ Submit for review
☐ CHECKPOINT: review "lost workout" beta feedback

Done: App live. Public users. Stability monitoring in place.
```

**→ RELEASE: App Store 1.0**

---

### PHASE 3 — "Personal" → App Store 1.1 (2 sprints)

**Sprint 8 — Templates + Substitution** | Effort: Medium
```
☐ Full 5-template library as JSON bundles (see Section 9)
☐ "Browse Templates" in ProgramListView
☐ Clone template → user owns the copy → fully editable
☐ Custom exercises — user can add private exercises to their own library
☐ Custom exercise fields: name, movement pattern, primary muscle, secondary muscles, equipment, compound/accessory
☐ Custom exercises appear in ExercisePickerView alongside system exercises
☐ Exercise substitution (movement pattern matching)
☐ Mid-workout swap ("gym crowded" one tap)
☐ Full onboarding quiz (5 questions → template match)

Done: Users pick from 5 templates. Mid-workout swap works.
      Users can add missing exercises without waiting for the system library.
```

---

**Sprint 9 — Progress Graphs** | Effort: Medium
```
☐ Swift Charts: weight over time per exercise
☐ Volume per week bar chart
☐ PR history timeline
☐ Plain-language: "Bench +15% in 8 weeks" (purple text)

Done: ProgressView with real charts. Progress visible.
```

**→ RELEASE: App Store 1.1**

---

### PHASE 4 — "Revenue" → App Store 1.2 (2 sprints)

**Sprint 10 — Subscription + Paywall** | Effort: Complex
```
☐ RevenueCat + StoreKit 2 (฿129/mo, ฿990/yr)
☐ Paywall UI + feature gating
☐ Muscle heatmap (Pro)

Done: Users subscribe. Pro features unlock.
```

---

**Sprint 11 — Watch + Widget** | Effort: Complex
```
☐ MIGRATION CHECKPOINT: add SwiftData if watch needs it
☐ HealthKit integration if still valuable after beta feedback
☐ watchOS: rest timer (lime ring on wrist)
☐ Widget: today's workout + streak
☐ PR sharing card (IG Story — purple/lime branded)
☐ Gate Watch + Widget behind Pro

Done: Watch timer. Widget on home. PR sharing live.
```

**→ RELEASE: App Store 1.2 — Pro subscription live**

---

### PHASE 5 — "AI + Platform" → App Store 2.0 (2 sprints)

**Sprint 12 — Gemini AI Coaching (Conditional)** | Effort: Complex
```
Trigger only if user demand or retention data justifies it:
  - users repeatedly ask coaching questions
  - AI can improve retention, explanation, or conversion
  - product data shows the core loop is already working

☐ Firebase AI Logic + Gemini
☐ Chat UI — Thai coaching
☐ Session context injection
☐ Gate behind Pro

Done: Pro asks AI in Thai, gets contextual answer.
```

---

**Sprint 13 — PT Pro + Phase Planning** | Effort: Complex
```
☐ PT Pro (฿390/mo)
☐ Client management + assign programs
☐ Bulk/Cut phase selector
☐ TDEE guidance + Apple Health link

Done: PT manages clients. Phase affects suggestions.
```

**→ RELEASE: App Store 2.0**

---

### Sprint Tracking

| Sprint | Name | Status | Notes |
|--------|------|--------|-------|
| 1 | Foundation + Data | ✅ | Complete. Database live. |
| 2 | Custom Program Builder | ☐ | |
| 3 | Logger + Timer | ☐ | |
| 4 | Today + History + Nav | ☐ | |
| 5 | The Brain | ☐ | |
| 6 | Onboarding + i18n | ☐ | |
| 7 | App Store Ship | ☐ | |
| 8 | Templates + Substitution | ☐ | |
| 9 | Progress Graphs | ☐ | |
| 10 | Subscription + Paywall | ☐ | |
| 11 | Watch + Widget | ☐ | |
| 12 | Gemini AI | ☐ | |
| 13 | PT Pro + Phases | ☐ | |

---

## 8. Core Algorithms

All in `Data/Services/`. Pure Swift. No I/O. 100% unit tested.

### Progressive Overload
```
RPE ≤ 7 + all reps  → +2.5kg (lime suggestion card)
RPE 7.5–8.5         → same weight, +1 rep
RPE ≥ 9             → deload 10%
3× same weight+reps → stall detected
```

### Smart Session Advisor
```
0–2 days   → continue normally
3–6 days   → reschedule missed days, pick up where left off
7–13 days  → comeback -10%wt -1set RPE ≤ 7  (purple card)
14–20 days → comeback -20%wt -1set RPE ≤ 7  (purple card)
21–41 days → comeback -30%wt ramp 10%/session
42+ days   → near-restart -50%wt slow ramp
```

### Comeback Ramp (per exercise)
```
RPE < 6.5   → ramp +15%
RPE 6.5–7.5 → ramp +10%
RPE 7.5–8.5 → hold, +reps
RPE ≥ 8.5   → reduce 5%
Exit: weight ≥ baseline AND RPE ≤ 7.5 → 1 consolidation → resume overload
```

---

## 9. Program Templates

Templates ship as JSON bundles in Sprint 8. Each template is cloned into the user's account on selection.

Dev's routine (Sprint 2 test case): **Upper/Lower 4 Days**

---

### Template 1: Upper/Lower 4 Days
**Target:** Intermediate, 4×/week, balanced strength + muscle

```
Day 1 — Upper A (Strength)
  Barbell Bench Press        4×5    rest 3min
  Barbell Bent Over Row      4×5    rest 3min
  Barbell Overhead Press     3×8    rest 2min
  Machine Lat Pulldown       3×10   rest 90s
  Cable Tricep Pushdown      3×12   rest 60s
  Dumbbell Bicep Curl        3×12   rest 60s

Day 2 — Lower A (Strength)
  Barbell Back Squat         4×5    rest 3min
  Romanian Deadlift          3×8    rest 2min
  Leg Press                  3×10   rest 90s
  Leg Curl (Lying)           3×12   rest 60s
  Calf Raise (Standing)      4×15   rest 60s

Day 3 — Upper B (Hypertrophy)
  Barbell Incline Bench      4×8    rest 2min
  Cable Row (Seated)         4×10   rest 2min
  Dumbbell Shoulder Press    3×10   rest 90s
  Machine Lat Pulldown       3×12   rest 90s
  Dumbbell Lateral Raise     3×15   rest 60s
  Cable Tricep Extension     3×15   rest 60s
  Dumbbell Hammer Curl       3×12   rest 60s

Day 4 — Lower B (Hypertrophy)
  Barbell Deadlift           4×5    rest 3min
  Dumbbell Bulgarian SS      3×10   rest 90s
  Leg Extension              3×12   rest 60s
  Leg Curl (Seated)          3×12   rest 60s
  Barbell Hip Thrust         3×12   rest 90s
  Calf Raise (Seated)        3×15   rest 60s
```

---

### Template 2: PPL 6 Days
**Target:** Intermediate-Advanced, 6×/week, maximum volume

```
Day 1 — Push A
  Barbell Bench Press        4×5    rest 3min
  Barbell Overhead Press     3×8    rest 2min
  Barbell Incline Bench      3×10   rest 90s
  Dumbbell Lateral Raise     4×15   rest 60s
  Cable Tricep Pushdown      4×15   rest 60s

Day 2 — Pull A
  Barbell Deadlift           4×5    rest 3min
  Barbell Bent Over Row      4×8    rest 2min
  Machine Lat Pulldown       3×10   rest 90s
  Cable Face Pull            3×15   rest 60s
  Dumbbell Bicep Curl        4×12   rest 60s

Day 3 — Legs A
  Barbell Back Squat         4×6    rest 3min
  Romanian Deadlift          3×10   rest 2min
  Leg Press                  3×12   rest 90s
  Leg Extension              3×15   rest 60s
  Leg Curl (Lying)           3×12   rest 60s
  Calf Raise (Standing)      4×15   rest 60s

Day 4 — Push B
  Barbell Incline Bench      4×8    rest 2min
  Dumbbell Shoulder Press    4×10   rest 90s
  Machine Chest Press        3×12   rest 90s
  Cable Lateral Raise        4×15   rest 60s
  Dumbbell Skull Crusher     3×15   rest 60s

Day 5 — Pull B
  Cable Row (Seated)         4×10   rest 2min
  Machine Lat Pulldown       4×12   rest 90s
  Cable Face Pull            3×15   rest 60s
  Dumbbell Rear Delt Fly     3×15   rest 60s
  Dumbbell Hammer Curl       4×12   rest 60s

Day 6 — Legs B
  Romanian Deadlift          4×8    rest 2min
  Dumbbell Bulgarian SS      3×10   rest 90s
  Hack Squat                 3×12   rest 90s
  Leg Curl (Seated)          4×12   rest 60s
  Barbell Hip Thrust         3×12   rest 90s
  Calf Raise (Seated)        4×15   rest 60s
```

---

### Template 3: Bro Split 5 Days
**Target:** Intermediate, 5×/week, dedicated muscle focus

```
Day 1 — Chest
  Barbell Bench Press        4×8    rest 2min
  Barbell Incline Bench      3×10   rest 90s
  Dumbbell Incline Press     3×12   rest 90s
  Machine Chest Fly          3×15   rest 60s
  Cable Crossover            3×15   rest 60s

Day 2 — Back
  Barbell Deadlift           4×5    rest 3min
  Barbell Bent Over Row      4×8    rest 2min
  Machine Lat Pulldown       3×10   rest 90s
  Cable Row (Seated)         3×12   rest 90s
  Dumbbell Shrug             4×15   rest 60s

Day 3 — Shoulders
  Barbell Overhead Press     4×8    rest 2min
  Dumbbell Shoulder Press    3×10   rest 90s
  Dumbbell Lateral Raise     4×15   rest 60s
  Dumbbell Rear Delt Fly     3×15   rest 60s
  Cable Face Pull            3×15   rest 60s

Day 4 — Arms
  Barbell Curl               4×10   rest 90s
  Dumbbell Hammer Curl       3×12   rest 60s
  Cable Bicep Curl           3×15   rest 60s
  Cable Tricep Pushdown      4×12   rest 60s
  Barbell Skull Crusher      3×12   rest 60s
  Cable Tricep Extension     3×15   rest 60s

Day 5 — Legs
  Barbell Back Squat         4×6    rest 3min
  Romanian Deadlift          3×10   rest 2min
  Leg Press                  3×12   rest 90s
  Leg Extension              3×15   rest 60s
  Leg Curl (Lying)           3×12   rest 60s
  Calf Raise (Standing)      4×15   rest 60s
```

---

### Template 4: PPL 3 Days
**Target:** Beginner-Intermediate, 3×/week, each pattern once

```
Day 1 — Push
  Barbell Bench Press        3×8    rest 2min
  Barbell Overhead Press     3×8    rest 2min
  Dumbbell Lateral Raise     3×15   rest 60s
  Cable Tricep Pushdown      3×12   rest 60s

Day 2 — Pull
  Barbell Bent Over Row      3×8    rest 2min
  Machine Lat Pulldown       3×10   rest 90s
  Cable Face Pull            3×15   rest 60s
  Dumbbell Bicep Curl        3×12   rest 60s

Day 3 — Legs
  Barbell Back Squat         3×8    rest 2min
  Romanian Deadlift          3×10   rest 90s
  Leg Press                  3×12   rest 90s
  Leg Extension              3×12   rest 60s
  Leg Curl (Seated)          3×12   rest 60s
  Calf Raise (Standing)      3×15   rest 60s
```

---

### Template 5: Full Body 2 Days
**Target:** Beginner or time-constrained, 2×/week minimum effective dose

```
Day A — Full Body A
  Barbell Back Squat         3×8    rest 2min
  Barbell Bench Press        3×8    rest 2min
  Barbell Bent Over Row      3×8    rest 2min
  Barbell Overhead Press     2×10   rest 90s
  Plank                      3×45s  rest 60s

Day B — Full Body B
  Barbell Deadlift           3×6    rest 3min
  Barbell Incline Bench      3×8    rest 2min
  Machine Lat Pulldown       3×10   rest 90s
  Dumbbell Lateral Raise     3×15   rest 60s
  Hanging Knee Raise         3×12   rest 60s
```

---

### Template Implementation Notes

```
Storage:  JSON files in app bundle (not Supabase)
          /Resources/programs/upper-lower-4day.json
          /Resources/programs/ppl-6day.json
          etc.

On user selection (Sprint 8):
  App reads JSON → creates Program + ProgramDays + ProgramExercises
  in Supabase → user owns the copy → can edit freely

Exercise matching:
  JSON references exercise by stable system slug
  On clone, app queries exercise table: WHERE slug = ?
  Graceful fallback if exercise not found
```

---

## 10. Monetization

### Model

```
Launch model:
  30-day full Pro trial
  → limited Free plan after trial
  → Pro unlocks the full "coach" experience

Why:
  GymTrack's value compounds over multiple sessions and missed-week comebacks.
  A 30-day trial gives inconsistent lifters enough time to feel the core value.
```

| Tier | Price | Includes |
|---|---:|---|
| Trial | 30 days | Full Pro experience |
| Free | ฿0 | Manual logger, custom programs, rest timer, basic history, 1 starter template, basic next-session suggestion, 1 free comeback rescue |
| Pro | ฿129/mo · ฿990/yr | Unlimited smart suggestions, unlimited comeback mode, stall detection, deload guidance, full template library, graphs, heatmap, watch, widget, export, AI |
| PT Pro | ฿390/mo | Client management, assign programs, dashboard |

### Paywall Strategy

```
Do not paywall before the user understands the product.

Flow:
  Sign in
  → onboarding
  → starter plan or custom plan
  → Today screen / first recommendation
  → "Try Pro free for 1 month"

Free should feel useful.
Pro should feel like:
  "GymTrack thinks for me."
```

### Monetization Learning Before Sprint 10

Track demand before building the full subscription system:
- fake-door taps on Pro features
- which locked features users try most
- whether smart suggestions or progress features create the strongest upgrade intent
- conversion by users who experienced comeback mode vs users who did not

## 11. Product Metrics

### North-Star Metric

```
% of new users who complete 2 workout sessions within 14 days of signup
```

Why this metric:
- One session can be curiosity.
- Two completed sessions show the user understood the flow and returned.
- It matches the target user better than daily app opens because they may only train 1–3×/week.

### Activation Funnel

```
sign_up_completed
onboarding_completed
program_created_or_selected
first_workout_started
first_workout_finished
second_workout_finished
```

### Training Retention

```
week_2_workout_completion
completed_2_sessions_within_14_days
completed_workouts_in_3_consecutive_calendar_weeks
D7 / D30 return
```

### Comeback Metrics

```
inactive_7d_returned
inactive_14d_returned
comeback_card_shown
comeback_workout_started
comeback_workout_finished
second_workout_after_comeback_finished
```

Primary comeback metric:
```
Comeback recovery rate =
users inactive 7+ days who complete 2 sessions after returning
```

### Smart Suggestion Effectiveness

```
suggestion_shown
suggestion_accepted
suggestion_edited
suggestion_ignored
session_completed_after_suggestion
next_session_completed_after_suggestion
```

### Reliability Metrics

```
workout_started
workout_finished
workout_restored
unfinished_session_detected
upload_failed
session_finish_missing
```

Migration watch:
```
5+ "lost workout" reports
or >5% sessions without finish event
→ reconsider storage strategy / SwiftData migration
```

### V1 TelemetryDeck Event Set

```
sign_up_completed
onboarding_completed
program_created
template_selected
workout_started
workout_finished
suggestion_shown
suggestion_accepted
comeback_card_shown
workout_restored
```

Add later:
```
second_workout_finished
inactive_7d_returned
inactive_14d_returned
comeback_workout_finished
session_finish_missing
paywall_viewed
pro_feature_tapped
```

---

## 12. Marketing Plan

**Pre-launch:** TikTok + Twitter/X in Thai. "หยุดเล่นยิม 2 อาทิตย์ กลับมายังไง" — no app yet.

**Launch:** TestFlight 20 → Product Hunt → Thai communities → 10 micro-influencers (free Pro) → first 50 users get 3-month Pro.

**Growth:** PR share card (purple/lime branded) → IG story loop. Facebook Group. PTs as distribution. B2B gym deals.

---

## 13. Development Workflow & CI/CD

### The Full Loop

```
1. READ   GYMTRACK.md → pick next sprint
2. SPEC   Claude web → /specs/S[N]-name.md
3. BUILD  Claude Code → implement sprint
4. TEST   Simulator + unit tests
5. FIX    Iterate until stable
6. COMMIT Push to main
7. CI/CD  Xcode Cloud → auto TestFlight
8. SHIP   Phase complete → App Store
9. LOOP   Mark ✅ → next sprint
```

### CI/CD: Xcode Cloud (after Sprint 4)

Push to `main` → Build + Test + Archive → TestFlight auto-deploy.

### Branching

```
main       → always deployable
feature/   → one branch per sprint
git push main → CI/CD ships to TestFlight
```

---

## 14. Decisions Made (and Rejected)

| Area | Chosen | Rejected | Why |
|---|---|---|---|
| Framework | SwiftUI | Flutter, RN | watchOS, Foundation Models |
| Backend | Supabase | Firestore | Relational data, new skill |
| Storage V1 | Supabase + in-memory | SwiftData hybrid | Over-engineered for V1 |
| Models | ONE Codable struct | DTO + @Model split | No mapping code |
| AI V1 | Rule-based | AI-first | Offline, Thai, free |
| Design | SwiftUI native | Figma | Solo dev, 3× faster |
| Architecture | MVVM + Repo + Service | UseCase/Coordinator | Lean |
| Folders | Layer + feature Presentation | Full feature-based | Solo dev clarity |
| Positioning | "Consistency coach" | "Thai tracker" | Hevy already Thai |
| Social | Cut | Build social | Hevy owns this |
| Onboarding | Basic onboarding in Phase 1 | Wait until Sprint 6 | Product promise needs guided first-run |
| V1 templates | 2 starter plans in Phase 1 | Templates only in Sprint 8 | Reduce blank-state friction without removing customization |
| Analytics | TelemetryDeck | Firebase Analytics V1 | Privacy-first, enough for V1 product metrics |
| Crash tracking | Apple early beta → Crashlytics before public launch | Sentry V1 | Lean early, stronger public-release monitoring |
| HealthKit | Delay unless beta feedback demands it | Ship in Sprint 3 | Nice-to-have, not core wedge |
| Monetization | 30-day full Pro trial + limited Free | Free core coach forever | Trial matches time-to-value; coach remains monetizable |
| Free plan | Useful logger + small coach taste | Plain logger only | Preserve differentiation after trial |
| AI | Conditional later phase | Mandatory roadmap item | Build only if user demand/data justify it |
| CI/CD | Xcode Cloud | GitHub Actions | Simplest, free |
| Release | Sprint→TestFlight, Phase→App Store | Sprint→App Store | Marketing + review risk |
| Custom programs | V1 Sprint 2 | V3 only | Dev tests own routine |
| Pre-built templates | Phase 3 Sprint 8 | V1 | Custom-first |
| Accent color | #C8FF00 Lime | All other options | Gym energy, unique |
| Secondary color | #9B7FE8 Purple | None | Comeback/PR semantic |

---

## 15. Open Decisions

All major strategic decisions resolved. ✅

Monitor after beta:
- whether 2 starter plans are enough for first-run success
- whether users understand the Free vs Pro boundary
- whether HealthKit is requested often enough to pull forward
- whether AI coaching has real demand or should remain deferred

> Add new open decisions here as they arise during development.

---

## 16. Decision Log

### 2026-05-10 (session 8)
- **Exercise names:** store one canonical exercise `name` in Supabase; do not translate system exercise names for V1. User-created exercises use the exact name the user enters.
- **Custom exercises:** use one `exercises` table with nullable `owner_user_id`; system exercises have no owner and user-created exercises belong to one profile.
- **Rest tracking:** program exercises store editable `target_rest_seconds`; workout sets can snapshot target rest and record actual rest taken when users exceed the timer.
- **Apple Sign-In data:** collect Apple user ID + email; save name only when Apple provides it; do not force real email or extra profile fields at signup
- **V1 first-run flow:** keep custom program builder early, but add basic onboarding plus two starter plans (Full Body 2 Days, PPL 3 Days)
- **HealthKit:** move out of Sprint 3; revisit after beta feedback / later watch work
- **Monetization:** switch to 30-day full Pro trial → limited Free plan → Pro subscription
- **Free plan:** manual logger, custom programs, timer, basic history, 1 starter template, basic next-session suggestion, 1 free comeback rescue
- **Pro boundary:** unlimited smart suggestions, unlimited comeback mode, stall/deload guidance, full templates, graphs, heatmap, watch/widget, export, AI
- **Analytics:** keep TelemetryDeck for V1 product analytics
- **Crash tracking:** Apple built-in during early beta; add Crashlytics before public App Store launch
- **Product metrics:** add north-star, activation, retention, comeback, suggestion, and reliability metrics
- **AI:** keep in roadmap but make conditional on user demand / retention value

### 2026-05-10 (session 9)
- **Logout placement:** Sprint 1 auth plumbing has `AuthService.signOut()`, but the visible UI belongs in Settings. A temporary Settings screen can expose sign-out before Sprint 4 tab navigation lands.
- **Google Sign-In:** optional later auth expansion. If added, Apple Sign-In must remain available as an equivalent sign-in option for App Review compliance.
- **App Store privacy:** before App Store 1.0, ship a public privacy policy URL, link it from Settings, complete App Store Connect privacy disclosures, and provide in-app account deletion initiation.

### 2026-05-08 (session 7)
- **App name:** GymBros (placeholder, will rename before App Store launch)
- **Default unit:** kg. Toggle to lb deferred — add to Settings in a later sprint if needed.
- **Localization:** Thai is primary for Thai devices. Non-Thai device languages use English. Sprint 6 adds Settings language override.
- **Open decisions:** all resolved ✅

### 2026-05-08 (session 6)
- **Accent color locked:** #C8FF00 electric lime (primary), #9B7FE8 purple (comeback/PRs/deload)
- **Color semantics defined:** Lime = progress/go, Purple = special/different states
- **Program templates defined:** 5 templates (Upper/Lower, PPL6, Bro Split, PPL3, Full Body 2-day)
- **Dev's starter routine:** Upper/Lower 4 days (Sprint 2 test case)
- **Templates storage:** JSON bundles in app, cloned to Supabase on user selection (Sprint 8)
- **Two remaining open decisions:** App name, default units

### 2026-05-08 (session 5)
- Custom programs added to Phase 1 (Sprint 2)
- Pre-built templates moved to Phase 3
- Phase 1 expanded to 4 sprints

### 2026-05-08 (session 4)
- Storage simplified: Supabase + in-memory + UserDefaults
- One Codable struct per entity

### 2026-05-08 (session 3)
- Roadmap: 13 sprints across 5 phases
- Architecture: Core / Model / Data / Presentation
- CI/CD: Xcode Cloud

### 2026-05-08 (session 2)
- Reframed: "Consistency coach"
- Social + videos cut

### 2026-05-06
- Document created, SwiftUI + Supabase + rule-based AI

---

## Appendix — Quick Reference

**What we are:** The gym companion that handles everything so you just show up.

**Who we serve:** The 80% of gym members who are inconsistent.

**The gap:** Every app tracks. We tell you what to do next — even after 2 weeks off.

**Colors:** Lime (#C8FF00) for progress. Purple (#9B7FE8) for special states. SwiftUI for everything else.

**Storage V1:** Supabase + in-memory + UserDefaults. SwiftData later if needed.

**Architecture:** Presentation → Data → Model → Core. Services pure. Tests mandatory.

**North-star metric:** % of new users who complete 2 workout sessions within 14 days.

**Monetization:** 30-day full Pro trial → limited Free → Pro unlocks the full coach.

**Analytics:** TelemetryDeck for product behavior. Apple built-in early beta → Crashlytics before public launch.

**Sprint 1:** spec at /sprints/S01-foundation-data/spec.md, plan at /sprints/S01-foundation-data/plan.md — ready to hand to Claude Code.
