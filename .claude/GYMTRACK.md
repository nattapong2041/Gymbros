# GymTrack — Source of Truth

> Living document. Update as decisions evolve.
> Last updated: 2026-05-11

---

## Table of Contents

1. [Vision & Identity](#1-vision--identity)
2. [Target Users & Pain Points](#2-target-users--pain-points)
3. [Core Value Proposition](#3-core-value-proposition)
4. [Tech Stack](#4-tech-stack)
5. [Design System](#5-design-system)
6. [App Architecture](#6-app-architecture)
7. [Re-engagement Strategy](#7-re-engagement-strategy)
8. [Agile Roadmap](#8-agile-roadmap)
9. [Core Algorithms](#9-core-algorithms)
10. [Program Templates](#10-program-templates)
11. [Monetization](#11-monetization)
12. [B2B Gym Partnership Track](#12-b2b-gym-partnership-track)
13. [Marketing Plan](#13-marketing-plan)
14. [Development Workflow & CI/CD](#14-development-workflow--cicd)
15. [Decisions Made (and Rejected)](#15-decisions-made-and-rejected)
16. [Open Decisions](#16-open-decisions)
17. [Decision Log](#17-decision-log)

---

## 1. Vision & Identity

**App name:** GymBros *(placeholder — will rename before App Store launch)*

**Positioning:** The gym app that adapts to your real life.

**Tagline TH:** "ขาดไป 2 อาทิตย์? บาดเจ็บ? ยิมแน่น? เราจัดการให้"
**Tagline EN:** "Missed 2 weeks? Injured? Gym crowded? We've got you."

**The shift:** We're not "a coach not a tracker" (Fitbod/Slate/Load Muscle already claim this). We are **the app that handles when life breaks the plan.** Every other tracker assumes you show up perfectly. We don't.

**Problem:** 50% of gym members quit within 6 months; 80% within 90 days. Not because they're lazy — because every app pretends real life doesn't happen. Missed sessions, comebacks, injuries, crowded gyms, decision fatigue, invisible progress.

**What makes us different:** When life breaks the plan, we have an answer. Open app → app already knows what changed → execute → done.

---

## 2. Target Users & Pain Points

### Primary user

Gym-goer, 18–35, iPhone. Wants 3–5×/week, actually trains 1–3×/week. Has tried Hevy/Strong but quit because logging without guidance felt pointless. Globally distributed, but Thai is the launch market (App Store algorithm favours Thai apps to Thai users, based on prior app data).

### Not for (yet)
Competitive powerlifters · cardio athletes · CrossFit-specific training

### Secondary (Phase 4+)
Personal trainers managing 5–15 clients · Independent Thai gyms with churn problems

### The seven pain points we solve (and competition status)

| # | Pain | Existing apps | Our answer |
|---|---|---|---|
| 1 | 50% quit at 6 months, 80% at 90 days | Nobody owns this | **Comeback handling = headline feature** |
| 2 | Coming back after a break is hard | None handle this well | SmartSessionAdvisor + ComebackRampService |
| 3 | Injury = manually delete exercises | #1 reported missing feature in Hevy reviews | Sprint 8 injury substitution |
| 4 | Decision fatigue at the gym | Hevy/Strong don't tell you what to lift | "Zero decisions" Today screen |
| 5 | Invisible progress | All have charts, but hidden behind paywalls | Free plain-language progress |
| 6 | No recovery-aware programming | Gap — Fitbod, Boostcamp don't integrate HRV | Sprint 10 HRV/sleep adjustments |
| 7 | Premium paywalls hide basic insights | Hevy hides volume-per-muscle behind paywall | Generous free tier |

### Pain points we deliberately don't solve
- Form check / video analysis (separate product domain)
- Nutrition / macros (separate product domain — partner integration later)
- Social / community / streaks (kills anti-guilt principle)
- Group classes / cardio (not our user)

---

## 3. Core Value Proposition

```
Apple Fitness: how many calories you burned
Hevy / Strong: log it yourself, figure it out yourself
Fitbod / Slate: AI plan assuming you train perfectly every week
GymTrack:      what to lift today, even after 2 weeks off,
               even with a shoulder tweak, even with 4hr sleep
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
| AI V1 | Rule-based Swift | Offline, multi-lang, free |
| AI V2 | DEFERRED — see Future/Optional in Section 8 |
| Payments | StoreKit 2 + RevenueCat | Native subscriptions, regional pricing |
| Health | HealthKit (workout + HRV + sleep) | Calories, rings, recovery |
| i18n | String Catalogs | Both Thai + English are first-class |
| Crashes V1 | Apple built-in | Free |
| Crashes V2 | Crashlytics | Add when scale demands |
| Analytics | TelemetryDeck | Privacy-first, Swift native |
| CI/CD | Xcode Cloud | Auto TestFlight on push to main |
| Notifications | UserNotifications (smart, opt-in only) | 1/week max, pattern-based |

---

## 5. Design System

### Localization Strategy (UPDATED)

```
Both Thai and English are FIRST-CLASS languages.
Neither is a translation of the other — both written native.

How it works:
  String keys:        English format in code (e.g. "start_workout")
  Default display:    Device locale
                      → Thai device → Thai
                      → Anything else → English
  User override:      Settings → Language (ภาษาไทย / English)
  String Catalogs:    sourceLanguage = "en"
                      Locales: "th" (complete, native copy)
                              "en" (complete, native copy)

Why the shift from Thai-default?
  Old plan: app opens in Thai regardless of device
  New plan: respect device locale, English first-class
  Reason:   Worldwide ambition. Thai users still get Thai.
            International users get a native-feeling English app.
            Thai-first marketing still drives Thai acquisition.

Bilingual copy in UI:
  Critical moments (comeback card, welcome back, PR achievement)
  show both languages side-by-side, never one as a footnote.
```

### Approach

SwiftUI native design system. No Figma. Paper sketches for 4 key screens.

### Color Strategy

```
Base:   SwiftUI semantic colors (automatic dark/light mode)
Custom: TWO named colors defined in Assets.xcassets
        → AccentColor (primary interactive)
        → GymPurple   (special states)
```

### The Two Custom Colors

```swift
// AccentColor — electric lime #C8FF00
// Used for: primary buttons, toggles, progress rings, checkmarks,
//           normal training, completion ("you did it")

// GymPurple — #9B7FE8
// Used for: comeback cards, PR badges, deload indicators,
//           milestones, "welcome back" moments
//           Anything where the message is "this is different"
```

### Color Semantic Map

```
Lime   (#C8FF00) → Completion · Progress · Primary CTA · Normal training
Purple (#9B7FE8) → Comeback   · PRs      · Deload      · Milestones
Red    (system)  → Destructive · Delete  · Warning
Green  (system)  → Sparingly — lime is our green
```

### Custom Components

```
SetRowView           weight + reps + RPE + checkbox
RestTimerRingView    circular countdown ring (lime stroke on dark)
ComebackCardView     purple gradient card with bilingual copy
EasingBackBadge      small purple pill, appears on exercise rows in comeback mode
HowDidThatFeelPicker 3-button feeling input (Easy / Just right / Hard)
                     replaces RPE during comeback for accuracy
SubstituteActionSheet long-press menu: Substitute / Defer / Skip / Cancel
DeferredBadge        purple "⏭ Deferred" pill on reordered exercise rows
SubstituteOriginBadge "↩ Bench" pill showing what an exercise replaced
```

### Tap Targets: 48pt minimum — sweaty hands

### Anti-Guilt UX (concrete features, not vibes)

```
✓ "Welcome back" banner after 7+ days, purple, big, bilingual
✓ Streak shown ONLY if streak intact — never display broken streaks
✓ Last workout date in soft grey, never red/orange
✓ "Fresh start" framing replaces any "you missed X days"
✓ Empty states say "Ready when you are" not "You haven't worked out"
✓ No daily reminders, ever
✓ Max 1 push notification per week, ever (and opt-in only)
```

### Copy Principles

```
✅ Assumptive       "Welcome back" not "Are you back?"
✅ Concrete         "80% means 80kg today" not "starting light"
✅ Forward-looking  "2-week ramp" not "you missed 2 weeks"
✅ Quiet confidence "We've got you" not "You'll be fine!"
✅ Bilingual where it matters, never translation footnote

❌ Apologetic       "Sorry it's been a while..."
❌ Demanding        "It's been too long..."
❌ Vague            "Take it easy today"
❌ Performative     "You can do this! 💪🔥"
❌ Pity             "We know life gets busy..."
```

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
│                       ExperienceLevel, Goal, WeightUnit
├── Data/
│   ├── Remote/         SupabaseClient.swift, AuthService.swift
│   ├── Repository/     ProfileRepo, ExerciseRepo, ProgramRepo, WorkoutRepo
│   └── Services/       SmartSessionAdvisor, ComebackRampService,
│                       ProgressiveOverloadEngine, StallDetector,
│                       DeloadAdvisor, InjurySubstitutionService (S8),
│                       RecoveryAdvisor (S10), SmartNotificationEngine (S11)
├── Presentation/
│   ├── Auth/           SignInView
│   ├── Today/          TodayView + ViewModel + ComebackCardView
│   ├── Workout/        WorkoutSessionView + ViewModel + Components/
│   │                   (incl. EasingBackBadge, HowDidThatFeelPicker)
│   ├── Programs/       ProgramListView, ProgramBuilderView,
│   │                   ProgramDetailView, DayBuilderView, ExercisePickerView
│   ├── History/        HistoryView, SessionDetailView + ViewModel
│   ├── Progress/       ProgressView + ViewModel
│   ├── Onboarding/     OnboardingView + ViewModel
│   └── Settings/       SettingsView
└── Resources/          Localizable.xcstrings, Assets.xcassets,
                        Programs/ (template JSON bundles)
```

### Future Migration Path: SwiftData

**Triggers:** 5+ "lost workout" reports / >5% sessions without finish event / building watch app (Sprint 11)

**Migration cost:** ~3–4 days (repos abstract the data source)

---

## 7. Re-engagement Strategy

### The honest truth

**Software cannot force someone to the gym.** Apps don't make people go — people decide to go, then use apps. Our re-engagement strategy lowers friction when they're already considering it, and stays visible enough that they remember we exist.

### Three-layer re-engagement

```
Layer 1 — Passive presence (always on, no permission needed)
  Home Screen Widget          Sprint 11
  Lock Screen Widget (iOS 16+) Sprint 11
  Apple Watch Complication    Sprint 11
  
Layer 2 — Surgical notifications (opt-in, max 1/week)
  Smart pattern-based pushes  Sprint 11
  Triggered by usage gap, not time
  Every push has "less often" button
  
Layer 3 — Optional integrations (Phase 3+)
  Calendar block integration  Future
  Geofence soft-detect        Future (silent badge, not push)
```

### Smart notification rules (Sprint 11)

```
Default state:        OFF on install
Permission ask:       Only after first 3 workouts logged
                      (earned trust, not forced)
Max frequency:        1 per week, EVER
Trigger condition:    User has trained ≥2 sessions but gone ≥7 days quiet
Content pattern:      Bilingual, concrete, non-guilty
                      "You usually train Mondays around 7pm. 
                       30 mins today?"
Never sent:           If user has notifications disabled at OS level
                      If user dismissed previous push without opening
                      During 11pm-7am local time
"Less often" button:  Halves frequency to 1 per 2 weeks
"Stop" button:        Disables notifications entirely
```

### What we deliberately don't build

```
❌ Daily reminders          (kills retention industry-wide)
❌ Streak notifications     (violates anti-guilt principle)
❌ Friend / social pings    (social was cut from product)
❌ "You missed X days"      (guilt-trip, opposite of brand)
❌ Re-engagement emails     (email is dead for gym audience)
```

### Conversion model

```
NOT: push → workout
BUT: widget visible all week
   → user has gym thought on Tuesday
   → opens app
   → finds zero-friction workout ready (or comeback card if returning)
   → goes
```

Widget is the workhorse. Push is the surgical strike. Neither is daily.

---

## 8. Agile Roadmap

### Release Channels

```
TestFlight: every sprint push to main (CI/CD auto-deploys)
App Store:  every phase complete (batched for marketing stories)
```

### Sprint progress

```
✅ Sprint 1 — Foundation + Data    (7 hours)
✅ Sprint 2 — Custom Program Builder (10 hours)
⏳ Sprint 3 — next up
```

---

### PHASE 1 — "Real Life Works" → TestFlight (5 sprints, 3 remaining)

**Goal:** Full loop including the differentiator. Open app after 2 weeks off → app handles it gracefully.

---

**Sprint 1 — Foundation + Data** ✅ DONE | Effort: Medium (7h actual)
```
Spec: /specs/S01-foundation-data.md
Status: Complete. Auth, Supabase schema, 95 exercises seeded,
        all Codable models, repositories, sign-in screen.
```

---

**Sprint 2 — Custom Program Builder** ✅ DONE | Effort: Complex (10h actual)
```
Spec: /specs/S02-custom-program-builder.md
Status: Complete. ProgramListView, ProgramBuilderView,
        DayBuilderView, ExercisePickerView, set targets,
        reorder, active toggle, delete.
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

**Sprint 4 — Today + History + Nav + Anti-Guilt UX** | Effort: Medium
```
Spec: /specs/S04-today-history-nav.md

☐ TodayView — greeting, today's workout card, "Start" CTA
☐ TodayViewModel — active program + next day logic
☐ Anti-guilt features (concrete, not vibes):
  ☐ "Welcome back" banner after 7+ days
  ☐ Streak shown only if intact
  ☐ Last workout date soft grey
  ☐ Empty states reframe as "Ready when you are"
☐ HistoryView — past sessions, newest first
☐ SessionDetailView — sets per exercise
☐ Tab navigation: Today / Programs / History / Settings

Done: Full loop. Anti-guilt UX visible. CI/CD set up.
```

**→ SET UP Xcode Cloud CI/CD here**

---

**Sprint 5 — Smart Comeback (THE DIFFERENTIATOR)** | Effort: Complex
```
Spec: /specs/S05-smart-comeback.md (to be written)

This sprint ships the feature that defines the product.
After this sprint, open app after 14 days off → purple card,
ramped workout, "How did that feel?" picker.

☐ SmartSessionAdvisor service (pure Swift, 100% tested)
   Day-bucket logic: 0-2 / 3-6 / 7-13 / 14-20 / 21-41 / 42+
☐ ComebackRampService (pure Swift, 100% tested)
   Per-exercise ramp based on RPE feedback
☐ Basic ProgressiveOverloadEngine (RPE-based)
☐ ComebackCardView — purple gradient, bilingual TH/EN
☐ WorkoutSessionView comeback mode:
  ☐ "Easing back" badges on exercise rows
  ☐ Previous PR strikethrough
  ☐ HowDidThatFeelPicker replaces RPE (Easy/Just right/Hard)
☐ TelemetryDeck events: comeback_triggered, comeback_completed,
                        comeback_exit
☐ Haptics: light on set complete (vs normal medium),
           double-haptic burst on baseline-reached moment

Done: Force last workout date to 15 days ago → purple card appears,
      weights ramped, full comeback flow works end to end.
```

**→ RELEASE: TestFlight to 10 Thai + 10 international beta testers**

---

### PHASE 2 — "Polished" → App Store 1.0 (2 sprints)

**Goal:** Onboarding, both languages 100% complete, public launch.

---

**Sprint 6 — Onboarding + Templates + i18n + Brain Polish** | Effort: Medium
```
Spec: /specs/S06-onboarding-i18n.md

☐ OnboardingView — 3 questions → recommend template
☐ 3 starter templates as JSON bundles (see Section 10):
  ☐ Upper/Lower 4 days
  ☐ PPL 3 days
  ☐ Full Body 2 days
☐ Template → clone to user's account → fully editable
☐ "Browse Templates" entry in ProgramListView
☐ String Catalogs — Thai (complete) + English (complete)
☐ Both languages first-class, native copy in each
☐ Default to device locale (Thai device → Thai, else → English)
☐ Settings → Language toggle override
☐ StallDetector service + tests
☐ DeloadAdvisor service + tests
☐ TelemetryDeck — 10 core events instrumented
☐ App icon + launch screen

Done: New user → 3 questions → picks template → first workout.
      Both languages feel native. Brain handles stalls and deloads.
```

---

**Sprint 7 — App Store Ship** | Effort: Simple
```
Spec: /specs/S07-app-store-ship.md

☐ Screenshots (TH + EN, both for App Store)
☐ App Store description (both languages, native copy each)
☐ Privacy policy
☐ Final TestFlight → fix bugs from beta feedback
☐ Submit for review
☐ CHECKPOINT: review "lost workout" beta feedback for SwiftData decision

Done: App live. Free download. Public users in TH + worldwide.
```

**→ RELEASE: App Store 1.0**

---

### PHASE 3 — "Adaptive" → App Store 1.1 (3 sprints)

**Goal:** Handle injuries, gym variability, and recovery state. Make the "real life adaptation" promise complete.

---

**Sprint 8 — Injury Sub + Mid-Workout Substitute + Defer + More Templates** | Effort: Medium-Complex
```
INJURY (pre-workout, persistent until cleared)
☐ "Report injury" flow: select body part, app filters exercises
☐ Persistent injury flag affects future workouts until cleared

MID-WORKOUT FLOWS (two distinct behaviors)
☐ Long-press / swipe on exercise row → action sheet:
   🔄 Substitute (replace this exercise)
   ⏭️ Do this later (defer to end of session)
   ⏸️ Skip entirely
   
☐ SUBSTITUTE flow:
   ☐ Show ranked substitutes (same pattern, same primary muscle)
   ☐ Crowded-equipment aware (don't suggest barbell-incline 
      when user is fleeing barbell-bench)
   ☐ Familiarity-ranked (user's history-rich exercises first)
   ☐ Auto-calculate suggested weight from user history OR 
      biomechanics ratio (e.g. machine ≈ 0.85 × free weight)
   ☐ Show "↩ Bench" badge on substituted row (what it replaced)
   ☐ Completed sets before substitution stay logged as original
   
☐ DEFER flow:
   ☐ Confirm: "Move Bench Press to end of workout?"
   ☐ Reorder exercise to end of list
   ☐ Show purple "⏭ Deferred" badge
   ☐ Preserve any sets already done — resume at set N when returned
   ☐ End-of-workout reminder if deferred exercise still has 0 sets

SMART SUBSTITUTE RANKING (see Section 9 for algorithm)
☐ SubstituteRanker service + tests
☐ Familiarity score from user history
☐ Crowded-equipment filter
☐ Biomechanics weight ratio table

TEMPLATES
☐ 2 more starter templates added:
  ☐ PPL 6 days
  ☐ Bro Split 5 days
☐ Full onboarding quiz (5 questions → template match,
                       upgraded from 3 questions in Sprint 6)

TELEMETRY
☐ exercise_substituted (which rank position picked)
☐ exercise_deferred
☐ deferred_exercise_resumed
☐ deferred_exercise_skipped (workout ended without doing it)

Why this matters: Injury handling is the #1 reported missing
feature in Hevy reviews. "Substitute" and "Defer" are two 
distinct mental models — replacing an exercise vs putting it 
on hold. Both directly fulfill our tagline promise: "Gym 
crowded? We've got you." This is the brand moment where the 
"adapts to real life" pitch becomes demonstrable in one tap.

Done: Report shoulder injury → next workout swaps OHP for
      machine chest press. Mid-workout: tap Bench → Machine Press
      (substitute) or push to end of workout (defer) — both 
      work seamlessly with set history preserved.
```

---

**Sprint 9 — Progress Graphs** | Effort: Medium
```
☐ Swift Charts: weight over time per exercise
☐ Volume per week bar chart
☐ PR history timeline
☐ Plain-language wins (purple text):
  "Bench +15% in 8 weeks"
  "You're back to baseline after your break — well done"
☐ Volume per muscle group (FREE in our app —
   Hevy paywalls this; ours doesn't)

Done: ProgressView with real charts. Progress visible.
```

---

**Sprint 10 — HRV / Recovery Integration** | Effort: Medium
```
☐ Read HRV + sleep from HealthKit
☐ Recovery score calculation (low/normal/high)
☐ RecoveryAdvisor service + tests
☐ If recovery low → suggest deload OR shorter session
☐ Purple "your body says rest" card variant
☐ "I slept 4 hours, today is lighter" banner

Why this matters: Competitor gap. Fitbod, Boostcamp, Hevy
don't integrate HRV cleanly. Apple Watch data is already
there from Sprint 3. ~1 sprint of integration.

Done: Wear Watch overnight with bad sleep → app deloads today.
```

**→ RELEASE: App Store 1.1 — "Adapts to real life"**

---

### PHASE 4 — "Revenue" → App Store 1.2 (2 sprints)

---

**Sprint 11 — Subscription + Paywall + Watch + Widget + Smart Notifications** | Effort: Complex
```
☐ MIGRATION CHECKPOINT: add SwiftData if watch needs it
☐ RevenueCat + StoreKit 2 setup
☐ Pricing tiers (see Section 11):
  ☐ Pro ฿99/mo / ฿790/yr
  ☐ Pro Student ฿49/mo (.ac.th email verification)
  ☐ Pro Lifetime ฿2,990 (cap at 1,000 sales)
☐ Paywall UI with comeback feature as #1 hook
☐ watchOS rest timer (lime ring on wrist)
☐ Home Screen Widget — today's workout
☐ Lock Screen Widget — glanceable today's lift
☐ Apple Watch complication
☐ SmartNotificationEngine (max 1/week, opt-in, pattern-based)
☐ "Less often" / "Stop" buttons on every push
☐ Watch + Widget + advanced features gated behind Pro

Done: Subscriptions live. Re-engagement layer active.
      Pro users see comeback widget complication on Watch.
```

---

**Sprint 12 — PT Pro** | Effort: Complex
```
☐ PT Pro tier (฿390/mo, includes up to 20 clients,
                ฿15/client beyond 20)
☐ PT account creation flow
☐ Client invite (SMS / LINE share link)
☐ PT dashboard:
  ☐ Client list with last-trained, days quiet, key lifts trend
  ☐ "3 clients haven't trained in 5+ days" alerts
  ☐ One-tap "nudge all" → sends LINE/iMessage template
☐ Program assignment:
  ☐ One-click clone PT's template to client
  ☐ Client owns the copy, PT can edit with notification
☐ PT-only notes per client (injuries, history)
☐ Bangkok in-person distribution begins
   (see Section 12 for PT distribution playbook)

Done: 5 Bangkok PTs onboarded, managing 50+ free-tier users.
      B2B revenue line live.
```

**→ RELEASE: App Store 1.2 — Pro + PT Pro live**

---

### FUTURE / OPTIONAL — only if Pro conversion is healthy

Deprioritized from original roadmap:

```
- AI chat (Gemini / on-device)
  Reason: Rule-based engine IS our AI. Adds API costs,
          latency, English bias. Competitors do it badly.
          Revisit only if Pro users specifically request.

- Phase planning (Bulk/Cut/Maintain)
  Reason: <5% of users care. Defer until users ask.

- Muscle heatmap
  Reason: Slate has it. Hevy paywalls it. Not a differentiator.

- B2B gym partnership platform
  Reason: Separate product track. See Section 12 for
          when/how to build.

- Form check / video analysis
  Reason: Separate product domain.

- Nutrition integration
  Reason: Partner via HealthKit later, don't build.
```

---

### Sprint Tracking

| Sprint | Name | Status | Hours | Notes |
|--------|------|--------|-------|-------|
| 1 | Foundation + Data | ✅ | 7 | spec: S01 |
| 2 | Custom Program Builder | ✅ | 10 | spec: S02 |
| 3 | Logger + Timer | ⏳ | — | spec: S03 next |
| 4 | Today + History + Nav + Anti-Guilt | ☐ | — | |
| 5 | Smart Comeback (DIFFERENTIATOR) | ☐ | — | spec: S05 to write |
| 6 | Onboarding + Templates + i18n | ☐ | — | |
| 7 | App Store Ship | ☐ | — | |
| 8 | Injury Sub + Substitute + Defer | ☐ | — | algorithm-heavy |
| 9 | Progress Graphs | ☐ | — | |
| 10 | HRV / Recovery | ☐ | — | |
| 11 | Subscription + Watch + Widget + Notifications | ☐ | — | |
| 12 | PT Pro | ☐ | — | |

**Velocity note:** Sprints 1-2 averaged 8.5 hours. That's roughly 3-5x typical solo dev pace. Algorithm-heavy sprints (5, 8, 10) will likely take 15-20 hours each — budget accordingly.

---

## 9. Core Algorithms

All in `Data/Services/`. Pure Swift. No I/O. 100% unit tested.

### Progressive Overload (Sprint 5 basic, Sprint 6 polish)
```
RPE ≤ 7 + all reps  → +2.5kg (lime suggestion card)
RPE 7.5–8.5         → same weight, +1 rep
RPE ≥ 9             → deload 10%
3× same weight+reps → stall detected
```

### Smart Session Advisor (Sprint 5)
```
0–2 days   → continue normally
3–6 days   → reschedule missed days, pick up where left off
7–13 days  → comeback -10%wt -1set RPE ≤ 7  (purple card, 90%)
14–20 days → comeback -20%wt -1set RPE ≤ 7  (purple card, 80%)
21–41 days → comeback -30%wt ramp 10%/session (purple card, 70%)
42+ days   → near-restart -50%wt slow ramp (purple card, 60%)
```

### Comeback Ramp per exercise (Sprint 5)
```
"How did that feel?" picker maps to internal RPE:
  Easy 😌       → RPE 6.0
  Just right 🎯 → RPE 7.5
  Hard 😤       → RPE 9.0

Next session decision:
  RPE < 6.5   → ramp +15%
  RPE 6.5–7.5 → ramp +10%
  RPE 7.5–8.5 → hold weight, +reps
  RPE ≥ 8.5   → reduce 5%

Exit comeback mode:
  weight ≥ baseline AND RPE ≤ 7.5
  → 1 consolidation session at baseline
  → resume normal progressive overload
  → "you're all the way back" moment fires
```

### Injury Substitution (Sprint 8)
```
User reports: shoulder, knee, lower back, wrist, elbow, hip, ankle

Algorithm:
  For each exercise in today's workout:
    if exercise.primary_muscle ∈ affected_muscles
       OR exercise.secondary_muscles ∩ affected_muscles ≠ ∅:
      candidates = exercises WHERE
        movement_pattern = original.movement_pattern
        AND primary_muscle NOT IN affected_muscles
        AND all secondary_muscles NOT IN affected_muscles
      sub = candidates.first (sorted by user-history familiarity)
      replace original with sub, badge "Substituted"
```

### Mid-Workout Substitute Ranker (Sprint 8)
```
Triggered when user taps "Substitute" mid-session.
Different from injury substitution: this is gym-availability driven,
not body-state driven. User keeps full muscle range.

Inputs:
  original           the exercise being replaced
  user_history       all sets the user has ever logged
  crowded_equipment  set of equipment the user marked as "in use"
                     (optional — empty if user didn't specify)
  all_exercises      master library

Filter:
  candidates = all_exercises WHERE
    id ≠ original.id
    AND equipment NOT IN crowded_equipment
    AND movement_pattern = original.movement_pattern
    AND primary_muscle = original.primary_muscle

Rank (descending):
  1. familiarity = count of sets in user_history for this exercise
  2. tie-breaker: prefer different equipment from original
     (if user fled the barbell, machine > another barbell variant)
  3. tie-breaker: stable alphabetical

Weight suggestion for the substitute:
  if user has logged this substitute before:
    suggested = last_weight × performance_trend_factor
  else:
    suggested = original_target_weight × biomechanics_ratio[sub.equipment]
  
  biomechanics_ratio (approximate, tunable):
    barbell → machine_same_pattern    ≈ 0.85
    barbell → dumbbell_same_pattern   ≈ 0.40 (per side)
    barbell → cable_same_pattern      ≈ 0.75
    free weight → smith_machine       ≈ 0.95
    
  Show suggestion in transparent/grey until user confirms first set.
```

### Defer Logic (Sprint 8)
```
Triggered when user taps "Do this later" mid-session.

State change:
  exercise.deferred = true
  exercise.original_order = exercise.exercise_order
  exercise.exercise_order = max(all_orders) + 1
  exercise.completed_sets_before_defer = current_completed_count

UI implications:
  - Exercise moves visually to end of list
  - Purple "⏭ Deferred" badge appears on the moved row
  - When user reaches it later, set numbering RESUMES at N+1
    (not restart at 1)
  - Rest timer resets to fresh state (no leftover countdown)

End-of-workout check:
  if any exercise.deferred == true AND completed_sets < target_sets:
    show prompt: "Bench Press not finished — finish it or skip?"
    options: [Finish now]  [Skip — end workout]

Constraints:
  - Can defer multiple exercises in one session (they queue at end)
  - Cannot defer the LAST remaining exercise 
    (UI shows "you're at the end already")
  - Defer is reversible: long-press deferred exercise → "Bring back"
    moves it to next-up position
```

### Recovery Advisor (Sprint 10)
```
Inputs (HealthKit):
  hrv_today_ms, hrv_baseline_ms, sleep_hours, sleep_baseline_hours

Score:
  hrv_ratio = hrv_today / hrv_baseline
  sleep_ratio = sleep_hours / sleep_baseline
  combined = (hrv_ratio * 0.6) + (sleep_ratio * 0.4)

Decision:
  combined ≥ 0.9 → normal training, no adjustment
  combined 0.75–0.9 → "today's workout is normal but listen to body"
  combined 0.6–0.75 → suggest -10% weight OR -1 set per exercise
  combined < 0.6 → suggest deload session or rest day
```

---

## 10. Program Templates

Templates ship in Sprint 6 (3 starter) and Sprint 8 (2 additional). Each cloned to user account on selection.

### Starter (Sprint 6)
1. **Upper/Lower 4 days** — Intermediate, balanced strength + muscle
2. **PPL 3 days** — Beginner-Intermediate, each pattern once
3. **Full Body 2 days** — Beginner or time-constrained, minimum effective dose

### Additional (Sprint 8)
4. **PPL 6 days** — Intermediate-Advanced, maximum volume
5. **Bro Split 5 days** — Intermediate, dedicated muscle focus

*(Full exercise breakdowns for all 5 templates preserved from prior version — see Sprint 6 spec.)*

### Template Implementation Notes

```
Storage:  JSON files in app bundle
          /Resources/Programs/upper-lower-4day.json
          /Resources/Programs/ppl-3day.json
          /Resources/Programs/full-body-2day.json
          /Resources/Programs/ppl-6day.json
          /Resources/Programs/bro-split-5day.json

On user selection (Sprint 6 / 8):
  App reads JSON → creates Program + ProgramDays + ProgramExercises
  in Supabase → user owns the copy → can edit freely

Exercise matching:
  JSON references exercise by name_en
  On clone, app queries exercise table: WHERE name_en = ?
  Graceful fallback if exercise not found
```

---

## 11. Monetization

### Tier Structure

| Tier | Price | Includes |
|---|---|---|
| **Free** | ฿0 | Logger · custom programs · 3 templates · basic comeback ("80% on return" card) · HealthKit · rest timer · history · both languages |
| **Pro Monthly** | ฿99/mo | All free + injury substitution · advanced comeback ramp · HRV/recovery adjustments · Watch + Widget · all 5+ templates · mid-workout swap · progress graphs + volume analytics · CSV export · smart notifications |
| **Pro Annual** | ฿790/yr | Same as Pro Monthly, 33% discount |
| **Pro Student** | ฿49/mo or ฿390/yr | Same as Pro, requires .ac.th email verification |
| **Pro Lifetime** | ฿2,990 one-time | Same as Pro, capped at 1,000 sales then closed |
| **PT Pro** | ฿390/mo / ฿3,900/yr | Pro + client management (up to 20) · bulk nudges · client dashboard · PT-only notes · ฿15/client beyond 20 |

### Pricing rationale

```
฿99/mo       Below Spotify Thailand ฿149/mo psychological anchor
฿790/yr      Under Hevy ($35 ≈ ฿1,225) and Strong ($30 ≈ ฿1,050)
             Above Slate ($20 ≈ ฿700) — we deliver more
฿49 student  Mirrors Spotify Thailand student tier (฿79)
             Thai gym demographic skews 18-35, students are a big slice
฿2,990 LTD   For indie fans who hate subscriptions
             Funds development upfront, builds advocate base
฿390 PT      0.2-0.6% of typical Bangkok PT gross revenue
             Trivial ROI if it saves 3 hours/month admin
```

### International pricing

StoreKit + RevenueCat automatic regional pricing. Base ฿790/yr → roughly $19.99/$24.99 in US/EU.

### What's paywalled vs free — the philosophy

```
FREE:    Things every user needs to feel the product's value
         (logger, custom programs, basic comeback, language polish)
         
         The basic comeback card on Today is FREE — this is the viral
         hook. Let everyone experience the differentiator.

PRO:     Things that compound for active users
         (injury sub, HRV, advanced ramp curves, Watch, Widget)
         
         The advanced comeback features are paywalled — ramp curves,
         baseline-tracking, full periodization through the comeback.

PT PRO:  Things only PTs need (client management)
```

### Revenue projections

```
PHASE / YEAR              MILESTONE                  REVENUE
──────────────────────────────────────────────────────────────────
Year 1 Q1-Q2 (S1-S7)      Free, 5K MAU TH+intl      ฿0 (acquisition)
Year 1 Q3 (S11)           Pro launch, 1.5% conv     75 × ฿99 = ฿7K/mo
Year 1 Q4 (S12)           PT Pro, 20 PTs            +20 × ฿390 = ฿8K/mo
                                                    + ~150 free users joined
Year 2                    50K MAU @ 3% Pro          1,500 × ฿99 = ฿148K/mo
                          100 PTs                   100 × ฿390 = ฿39K/mo
                          5 gym pilots              5 × ฿2K = ฿10K/mo
                                                    TOTAL ~฿200K/mo
                                                    = ฿2.4M/yr (~$70K)
Year 3                    International scale       3x Year 2
                          + Android (if built)      ฿7-10M/yr (~$200-300K)
```

Realistic ceiling: indie-scale business. Not venture-scale. That's fine — it pays well, you own it, no investor pressure.

---

## 12. B2B Gym Partnership Track

Separate product line, defined now to avoid scope creep into B2C roadmap. **Build only when 5+ Thai gyms ask unprompted.**

### The opportunity

```
Thai gym landscape:
  2,499 registered fitness businesses in Thailand (2024)
  396 new ones in 2024 alone (33% YoY growth)
  99.4% small business / independent
  
Their #1 problem:
  50% member churn (industry standard)
  ฿1,300-4,300/month membership × half churning = real money lost
  
What we offer:
  Auto-detect inactive members → trigger comeback campaign
  Gym admin dashboard: see who's slipping
  Co-branded onboarding (gym logo on welcome screen)
  Members get the GymTrack app at no cost to them
```

### Pricing

```
฿20/member/month, minimum 50 members
= ฿1,000/mo minimum per gym
= ฿12,000/yr per gym minimum

TAM (Thailand only):
  2,499 gyms × avg ฿2,000/mo = ฿60M/yr potential
  Realistic 5-year capture at 5% = ฿3M/yr
```

### When to build

```
Trigger conditions (need ALL three):
  ☐ PT Pro is healthy (50+ paying PTs in TH)
  ☐ 5+ Thai gym owners have asked unprompted
  ☐ Core B2C app is stable post App Store launch

Estimated build effort:
  ~2 sprints (gym admin web dashboard + member tagging + 
              co-branded onboarding)
  
Distribution:
  Direct in-person sales in Bangkok
  PT Pro users become referrers ("my gym should use this")
```

### What it's NOT

```
❌ A gym CRM (Mindbody / Glofox / FitDEGREE territory)
❌ Class booking
❌ Billing / payments
❌ Door access / check-in

Stay narrow: we're the retention-and-comeback layer ON TOP of
their existing gym software. Not a replacement for it.
```

---

## 13. Marketing Plan

### Pre-launch (Phase 1 TestFlight)

```
Channels:
  TH:  TikTok, Facebook groups, LINE OA
  Intl: Reddit (r/Fitness, r/iOSdev), Twitter/X, IndieHackers
  
Content angle:
  "หยุดเล่นยิม 2 อาทิตย์ กลับมายังไง" / "How to come back after 2 weeks off"
  Build the brand BEFORE the app — own the comeback narrative
  
TestFlight beta:
  10 Thai + 10 international (mixed feedback streams)
  First 50 users get 3-month Pro free
```

### Launch (App Store 1.0)

```
Product Hunt launch (English-speaking world)
Thai community pushes:
  - Pantai fitness section
  - Fitness Facebook groups
  - LINE OpenChat for gym-goers
10 Thai micro-influencers (free Pro for 1 year)
```

### Growth (Phase 3+)

```
The comeback share card:
  After successful comeback (return to baseline weight),
  app generates a shareable card showing the curve:
  "I came back. Lost nothing." → purple/lime branded
  IG Story / TikTok loop

The crowded-gym angle (Sprint 8+):
  "Bench taken? Tap once. We'll swap it."
  TikTok-friendly — every gym-goer has this exact moment weekly
  Demo video: bench is busy → tap → machine press loaded with
  correct weight → no thinking required
  
PT-led distribution:
  Each PT brings 5-15 clients onto free tier
  
B2B gym deals (Year 2+):
  Direct sales to Bangkok gyms
  Each gym = 50-500 new users
```

### Anti-marketing principles

```
❌ Don't compete on tracker features (Hevy wins, doesn't matter)
❌ Don't claim to be "AI-powered" (Fitbod claims this, also doesn't matter)
✅ Own ONE narrative: "real life happens, the app handles it"
✅ Make the comeback the brand
```

---

## 14. Development Workflow & CI/CD

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

### CI/CD: Xcode Cloud (Sprint 4)

Push to `main` → Build + Test + Archive → TestFlight auto-deploy.

### Branching

```
main       → always deployable
feature/   → one branch per sprint
git push main → CI/CD ships to TestFlight
```

### Velocity expectations

```
Simple sprints (3-4 hours):  none on roadmap
Medium sprints (8-12 hours): S4, S6, S8, S9, S10
Complex sprints (15-25 hours): S3, S5, S11, S12

Algorithm-heavy = more testing = more time. Budget extra.
```

---

## 15. Decisions Made (and Rejected)

| Area | Chosen | Rejected | Why |
|---|---|---|---|
| Framework | SwiftUI | Flutter, RN | watchOS, Foundation Models |
| Backend | Supabase | Firestore | Relational data |
| Storage V1 | Supabase + in-memory | SwiftData hybrid | Over-engineered for V1 |
| Models | ONE Codable struct | DTO + @Model split | No mapping code |
| AI V1 | Rule-based | AI-first | Offline, multi-lang, free |
| AI chat (Gemini) | DEFERRED | Sprint 12 build | API costs, English bias, not core |
| Design | SwiftUI native | Figma | Solo dev, 3× faster |
| Crash V1 | Apple built-in | Sentry, Crashlytics | Free |
| Analytics | TelemetryDeck | Firebase/PostHog | Privacy, Swift |
| Architecture | MVVM + Repo + Service | UseCase/Coordinator | Lean |
| Folders | Layer + feature Presentation | Full feature-based | Solo dev clarity |
| Positioning | "Adapts to real life" | "Consistency coach" | More specific, owns comeback |
| Differentiator | Comeback handling (S5) | Was S5 of Phase 2 | Ship in Phase 1, headline feature |
| Default locale | Device locale | Thai-always | Worldwide ambition |
| Both languages | First-class native | EN as fallback | Worldwide quality |
| Social | Cut | Build social | Hevy owns this, violates anti-guilt |
| Streaks | Cut | Build streaks | Violates anti-guilt principle |
| Daily reminders | Cut | Build reminders | Kills retention industry-wide |
| Push frequency | Max 1/week, opt-in | Daily nudges | Respect over engagement-hacking |
| CI/CD | Xcode Cloud | GitHub Actions | Simplest, free |
| Release cadence | Sprint→TestFlight, Phase→App Store | Sprint→App Store | Marketing + review risk |
| Custom programs | Sprint 2 ✅ | Templates only | Dev tests own routine |
| Pre-built templates | Sprint 6 (3) + Sprint 8 (+2) | Sprint 8 only | First-time users need easy path |
| Injury substitution | Sprint 8 | Future | #1 reported missing feature |
| HRV integration | Sprint 10 | Future | Competitor gap, data already there |
| PT Pro | Sprint 12 | Sprint 13 | Highest revenue leverage |
| Phase planning | Future/Optional | Sprint 13 | <5% care, defer |
| Muscle heatmap | Future/Optional | Phase 4 | Not a differentiator |
| B2B gym partnership | Separate product, build later | Phase 5 add-on | Different motion entirely |
| Running expansion | REJECTED (don't build) | Adding running module to app | Different category, different competitors (Strava/NRC/Garmin), dilutes core moat. Revisit only at ฿5M+ ARR with explicit user demand and consider separate app, not unified |
| Mid-workout swap | TWO flows: Substitute + Defer (S8) | Single "swap" flow | Different mental models — replace entirely vs do later. Both fulfill "gym crowded? we've got you" tagline |
| Substitute ranking | Familiarity + crowded-equipment aware | Random or alphabetical | User picks #1 most of the time = ranking works |
| Defer set history | Preserved when exercise moves | Reset on defer | Sets that happened, happened — count them |
| Accent color | #C8FF00 Lime | Many alternatives | Gym energy, unique |
| Secondary color | #9B7FE8 Purple | None | Comeback/PR semantic |
| Pricing | ฿99/mo, ฿790/yr | ฿129/฿990 | Below Spotify TH anchor |
| Lifetime tier | ฿2,990 one-time, cap 1,000 | Subscription only | Funds dev, builds advocates |
| Student tier | ฿49/mo, .ac.th verify | Same price for all | Mirrors Spotify TH |

---

## 16. Open Decisions

```
☐ Final app name (placeholder "GymBros" until Sprint 7)
☐ Default unit kg (toggle to lb in Settings) — confirmed kg-default,
  add lb toggle by Sprint 11 paywall context
☐ Whether to include sound on haptic moments (currently haptic-only)
☐ Lifetime tier exact cap — 1,000 placeholder, may go lower (500)
```

---

## 17. Decision Log

### 2026-05-11 (session 9 — running expansion + mid-workout swap design)

- **Running expansion: REJECTED.** Considered adding running/cardio to the same app. Decided against:
  - Different category — competitors are Strava (100M users), Nike Run Club, Garmin Connect, Apple Fitness+. Bar to enter is far higher than lifting
  - Different core metrics (pace × distance vs weight × reps), different hardware needs (GPS + Watch mandatory), different session flow (continuous vs discrete sets)
  - Dilutes the "adapts to real life" moat — running doesn't have crowded-gym friction, injury-substitution doesn't translate (cross-training is a different domain), missed days are largely self-regulating for runners
  - Narrow-wins pattern: Strong, Strava, Hevy, AllTrails all won by staying narrow. Broad fitness apps lose
  - Revisit conditions (need ALL): ฿5M+ ARR on strength side, >30% of users asking in data, hire of dev with running-app experience. Even then, lean toward SEPARATE APP sharing only backend account
- **Better expansion directions if ambition strikes later**: powerlifting variant (1RM, percentages, peaking) · bodyweight/calisthenics mode · mobility/recovery side-app · expert programs beyond PT Pro
- **Mid-workout swap: EXPANDED into two distinct flows in Sprint 8**:
  - **Substitute**: replace exercise entirely (bench taken → machine press). Ranked candidates by familiarity + crowded-equipment awareness. Suggested weight calculated from user history or biomechanics ratio. Completed sets before substitution stay logged as original exercise
  - **Defer**: move exercise to end of session (bench taken now, do hammer curls first, come back to bench later). Set history preserved — resume at set N+1 when user returns. End-of-workout reminder if deferred exercise still has 0 sets
- **Substitute Ranker algorithm specified** in Section 9 — familiarity score, crowded-equipment filter, biomechanics weight ratio table (barbell→machine ≈ 0.85, barbell→dumbbell ≈ 0.40/side, barbell→cable ≈ 0.75, free→Smith ≈ 0.95)
- **Defer logic specified** in Section 9 — preserved set history, queueable across multiple exercises in one session, reversible via "Bring back" action
- **Sprint 8 effort upgraded**: Medium → Medium-Complex (now algorithm-heavy on top of UI work)
- **New custom components**: SubstituteActionSheet, DeferredBadge, SubstituteOriginBadge
- **Brand alignment**: this is the feature that makes "Gym crowded? We've got you" demonstrable in one tap. The crowded-gym promise was unfulfilled until now

### 2026-05-11 (session 8 — strategic refinement after Sprints 1-2)

- **Repositioned**: "the gym app that adapts to your real life" — comeback handling moved from Phase 2 → Phase 1 Sprint 5 as THE differentiator, not a Phase 2 reveal
- **Sprint 1-2 complete**: 7h + 10h actual (~3-5x typical solo pace — fast enough to outpace established competitors, watch out for AI-first new entrants)
- **Templates restructured**: 3 starter templates ship in Sprint 6 with onboarding (Upper/Lower, PPL 3d, Full Body 2d), 2 more in Sprint 8
- **Anti-guilt UX**: promoted from principle to concrete features in Sprint 4 (welcome back banner, streak hiding when broken, fresh-start framing)
- **Injury substitution**: added as Sprint 8 — #1 reported missing feature in Hevy reviews, data model already supports it from Sprint 1
- **HRV/recovery integration**: added as Sprint 10 — competitor gap (Fitbod, Boostcamp, Hevy don't integrate cleanly), HealthKit data already there
- **PT Pro moved**: from old Sprint 13 → Sprint 12, highest revenue leverage, Bangkok in-person distribution advantage
- **Gemini AI chat**: deprioritized to Future/Optional (rule-based engine IS our AI, API costs + English bias not worth it)
- **Phase planning (Bulk/Cut)**: deprioritized to Future/Optional (<5% of users care)
- **Muscle heatmap**: deprioritized (not a differentiator)
- **Worldwide focus**: confirmed. Default to device locale (was Thai-always). Both TH + EN are first-class native, not translation. Thai is still launch market via App Store algorithm bias. PT Pro stays Bangkok-focused for face-to-face distribution
- **Pricing**: ฿99/mo, ฿790/yr (down from ฿129/฿990 — below Spotify TH ฿149 anchor); added ฿49/mo student tier (.ac.th verify); added ฿2,990 lifetime (cap 1,000)
- **Re-engagement strategy defined**: widget-first (passive, always on), max 1 push/week (opt-in, pattern-based), no daily reminders ever, no streaks ever
- **B2B gym partnership track**: defined as separate product line in Section 12, build trigger requires PT Pro health + 5 unprompted gym requests + stable B2C launch
- **Roadmap**: 13 → 12 sprints to fight competitive velocity
- **Two open decisions remain**: final app name, sound vs haptic-only for special moments

### 2026-05-08 (session 7)

- **App name:** GymBros (placeholder, will rename before App Store launch)
- **Default unit:** kg. Toggle to lb deferred — add to Settings in a later sprint if needed
- **Localization (now superseded):** Thai-primary regardless of locale
- **Open decisions:** all resolved at that time ✅ (since revisited)

### 2026-05-08 (session 6)

- **Accent color locked:** #C8FF00 electric lime (primary), #9B7FE8 purple (comeback/PRs/deload)
- **Color semantics defined:** Lime = progress/go, Purple = special/different states
- **Program templates defined:** 5 templates
- **Dev's starter routine:** Upper/Lower 4 days
- **Templates storage:** JSON bundles in app, cloned to Supabase on user selection

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

**What we are:** The gym app that handles when life breaks the plan.

**Who we serve:** Inconsistent gym-goers, 18-35, worldwide with Thai-first launch.

**The gap:** Every other tracker assumes you show up perfectly. We don't.

**Headline feature:** Smart Comeback — open app after 2 weeks off, app already knows what to do (Sprint 5).

**Colors:** Lime (#C8FF00) for normal progress. Purple (#9B7FE8) for comeback / PRs / "this is different" moments. SwiftUI for everything else.

**Pricing:** ฿99/mo Pro · ฿790/yr · ฿49 student · ฿2,990 lifetime · ฿390 PT Pro.

**Architecture:** Presentation → Data → Model → Core. Services pure. Tests mandatory.

**Re-engagement:** Widget (passive) + max 1 push per week (surgical) + zero daily reminders ever.

**Next up:** Sprint 3 — Logger + Timer. Spec ready at /specs/S03-logger-timer.md.