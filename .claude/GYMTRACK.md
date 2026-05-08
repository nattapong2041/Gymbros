# GymTrack — Source of Truth

> Living document. Update as decisions evolve.
> Last updated: 2026-05-08

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
11. [Marketing Plan](#11-marketing-plan)
12. [Development Workflow & CI/CD](#12-development-workflow--cicd)
13. [Decisions Made (and Rejected)](#13-decisions-made-and-rejected)
14. [Open Decisions](#14-open-decisions)
15. [Decision Log](#15-decision-log)

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
| AI V1 | Rule-based Swift | Offline, Thai, free |
| AI V2 | Firebase AI Logic (Gemini) | Thai coaching, Pro only |
| Payments | StoreKit 2 + RevenueCat | Native subscriptions |
| Health | HealthKit | Calories + rings |
| i18n | String Catalogs | Thai is primary language. English is user-selectable in Settings. |
| Crashes V1 | Apple built-in | Free |
| Crashes V2 | Crashlytics | When Firebase enters |
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
  Default display:    Thai — app always opens in Thai first
  Device locale:      If device is set to Thai → Thai
                      If device is set to anything else → Thai (not English)
                      (this app is Thai-first, not locale-first)
  User override:      Settings → Language → ภาษาไทย / English
  String Catalogs:    sourceLanguage = "en" (key format)
                      Locales: "th" (complete) + "en" (complete)
                      Thai strings are never optional — must always exist

Why not "auto from device locale"?
  Most Thai users have English device language for other reasons.
  They should still get Thai by default. Let them opt into English.
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
Spec: /specs/S01-foundation-data.md

☐ Xcode project + folder structure
☐ Supabase schema.sql + seed exercises
☐ All Codable model structs + enums
☐ SupabaseClient + Apple Sign-In auth
☐ Repositories (Profile, Exercise, Program, Workout)
☐ ~100 exercises seeded in Thai + English
☐ Localizable.xcstrings — Thai (primary) + English (fallback)
☐ Login screen strings localized (first real usage)
☐ App language follows device locale automatically

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
☐ Set targets per exercise: sets, rep range, rest seconds
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
☐ RestTimerRingView — bottom sheet, lime ring, haptic
☐ Finish → mark complete in Supabase → clear backup
☐ HealthKit: start/end HKWorkoutSession
☐ Crash recovery: "Restore?" prompt on relaunch

Done: Log full Upper A. Rest timer works.
      Apple Fitness rings fill. Crash recovery tested.
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
☐ Empty states (no program, no sessions)

Done: Full loop. Open → today's workout → start → log
      → finish → see in history. CI/CD set up.
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

☐ OnboardingView — 3 questions → recommend program
☐ String Catalogs — all text in Thai (complete) + English (complete)
☐ App defaults to Thai regardless of device locale
☐ Settings → Language toggle (ภาษาไทย / English)
☐ UserDefaults stores language preference
☐ TelemetryDeck — 10 core events
☐ App icon + launch screen
☐ Anti-guilt UX — never show "streak broken"

Done: New user → 3 swipes → program → Today.
      App opens in Thai. Settings lets user switch to English.
```

---

**Sprint 7 — App Store Ship** | Effort: Simple
```
Spec: /specs/S07-app-store-ship.md

☐ Screenshots (TH + EN)
☐ App Store description (Thai primary)
☐ Privacy policy
☐ Final TestFlight → fix bugs
☐ Submit for review
☐ CHECKPOINT: review "lost workout" beta feedback

Done: App live. Free download. Public users.
```

**→ RELEASE: App Store 1.0**

---

### PHASE 3 — "Personal" → App Store 1.1 (2 sprints)

**Sprint 8 — Templates + Substitution** | Effort: Medium
```
☐ 5 program templates as JSON bundles (see Section 9)
☐ "Browse Templates" in ProgramListView
☐ Clone template → user owns the copy → fully editable
☐ Exercise substitution (movement pattern matching)
☐ Mid-workout swap ("gym crowded" one tap)
☐ Full onboarding quiz (5 questions → template match)

Done: Users pick from 5 templates. Mid-workout swap works.
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
☐ watchOS: rest timer (lime ring on wrist)
☐ Widget: today's workout + streak
☐ PR sharing card (IG Story — purple/lime branded)
☐ Gate Watch + Widget behind Pro

Done: Watch timer. Widget on home. PR sharing live.
```

**→ RELEASE: App Store 1.2 — Pro subscription live**

---

### PHASE 5 — "AI + Platform" → App Store 2.0 (2 sprints)

**Sprint 12 — Gemini AI Coaching** | Effort: Complex
```
☐ Firebase AI Logic + Gemini
☐ Chat UI — Thai coaching
☐ Session context injection
☐ Crashlytics added
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
| 1 | Foundation + Data | ☐ | spec ready: S01 |
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
  JSON references exercise by name_en
  On clone, app queries exercise table: WHERE name_en = ?
  Graceful fallback if exercise not found
```

---

## 10. Monetization

| Tier | Price | Includes |
|---|---|---|
| Free | ฿0 | Logger, custom programs, history, suggestions, timer |
| Pro | ฿129/mo · ฿990/yr | Templates, AI, graphs, heatmap, watch, widget, export |
| PT Pro | ฿390/mo | Client management, assign programs, dashboard |

---

## 11. Marketing Plan

**Pre-launch:** TikTok + Twitter/X in Thai. "หยุดเล่นยิม 2 อาทิตย์ กลับมายังไง" — no app yet.

**Launch:** TestFlight 20 → Product Hunt → Thai communities → 10 micro-influencers (free Pro) → first 50 users get 3-month Pro.

**Growth:** PR share card (purple/lime branded) → IG story loop. Facebook Group. PTs as distribution. B2B gym deals.

---

## 12. Development Workflow & CI/CD

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

## 13. Decisions Made (and Rejected)

| Area | Chosen | Rejected | Why |
|---|---|---|---|
| Framework | SwiftUI | Flutter, RN | watchOS, Foundation Models |
| Backend | Supabase | Firestore | Relational data, new skill |
| Storage V1 | Supabase + in-memory | SwiftData hybrid | Over-engineered for V1 |
| Models | ONE Codable struct | DTO + @Model split | No mapping code |
| AI V1 | Rule-based | AI-first | Offline, Thai, free |
| Design | SwiftUI native | Figma | Solo dev, 3× faster |
| Crash V1/V2 | Apple → Crashlytics | Sentry | Free, then free with Firebase |
| Analytics | TelemetryDeck | Firebase/PostHog | Privacy, Swift |
| Architecture | MVVM + Repo + Service | UseCase/Coordinator | Lean |
| Folders | Layer + feature Presentation | Full feature-based | Solo dev clarity |
| Positioning | "Consistency coach" | "Thai tracker" | Hevy already Thai |
| Social | Cut | Build social | Hevy owns this |
| CI/CD | Xcode Cloud | GitHub Actions | Simplest, free |
| Release | Sprint→TestFlight, Phase→App Store | Sprint→App Store | Marketing + review risk |
| Custom programs | V1 Sprint 2 | V3 only | Dev tests own routine |
| Pre-built templates | Phase 3 Sprint 8 | V1 | Custom-first |
| Accent color | #C8FF00 Lime | All other options | Gym energy, unique |
| Secondary color | #9B7FE8 Purple | None | Comeback/PR semantic |

---

## 14. Open Decisions

All major decisions resolved. ✅

> Add new open decisions here as they arise during development.

---

## 15. Decision Log

### 2026-05-08 (session 7)
- **App name:** GymBros (placeholder, will rename before App Store launch)
- **Default unit:** kg. Toggle to lb deferred — add to Settings in a later sprint if needed.
- **Localization:** Thai is PRIMARY language (app opens in Thai regardless of device locale). English is user-selectable in Settings. Not auto-detected from device.
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

**Sprint 1 spec:** /specs/S01-foundation-data.md — ready to hand to Claude Code.
