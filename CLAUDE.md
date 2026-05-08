# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**GymBros** — an iOS gym companion app for Thai users. Tagline: "มาแค่นี้พอ เราจะดูแลส่วนที่เหลือ" (Just show up. We'll handle the rest.)

The app name "GymBros" is a placeholder — it will be renamed before App Store launch.

Full product decisions, roadmap, and algorithm specs live in `.claude/GYMTRACK.md`. Sprint implementation specs live in `.claude/specs/`. Always read the relevant spec before implementing a sprint.

## Build & Test

This is an Xcode project. There is no CLI build step — open `Gymbros.xcodeproj` and build/run from Xcode, or use `xcodebuild`:

```bash
# Build
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run all tests
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single test class
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:GymbrosTests/CodableTests
```

Minimum deployment target: **iOS 17.0**. Language: **Swift**. UI: **SwiftUI**.

## Architecture

Pattern: **MVVM + Repository + Service**

```
Presentation  →  Data + Model + Core
Data          →  Model + Core
Model         →  Core
Core          →  nothing
```

**Folder layout** (inside the `GymBros` target):

```
App/                  GymBrosApp.swift, RootView.swift
Core/                 AppTheme.swift, Constants.swift, Extensions/
Model/                Codable structs (Profile, Exercise, Program, ProgramDay,
                      ProgramExercise, WorkoutSession, WorkoutSet)
Model/Enums/          MovementPattern, MuscleGroup, Equipment, ExperienceLevel,
                      Goal, WeightUnit, TrainingPhase
Data/Remote/          SupabaseClient.swift, AuthService.swift
Data/Repository/      ProfileRepo, ExerciseRepo, ProgramRepo, WorkoutRepo, RepositoryError
Data/Services/        ProgressiveOverloadEngine, SmartSessionAdvisor,
                      ComebackRampService, StallDetector, DeloadAdvisor (Sprint 5+)
Presentation/         One folder per feature: Auth, Today, Workout, Programs,
                      History, Progress, Onboarding, Settings
Resources/            Localizable.xcstrings, Assets.xcassets
```

**Models** use `Codable` with explicit `CodingKeys` mapping camelCase Swift ↔ snake_case Supabase columns. Nested relationships (e.g. `Program.days`) are not in `CodingKeys` — they are populated client-side after separate fetches.

**ViewModels** use `@Observable` (iOS 17 Observation framework, not `ObservableObject`).

**Services** (`Data/Services/`) are pure Swift with no I/O — they take data in and return suggestions out. 100% unit-tested. See `.claude/GYMTRACK.md` §8 for the exact algorithms.

## Swift Packages

- `supabase/supabase-swift` — Supabase client
- `kishikawakatsumi/KeychainAccess` — secure token storage

## Supabase

- Auth: Apple Sign-In only (via `signInWithIdToken`). Profile row is auto-created by a DB trigger on `auth.users` insert — do not create it manually in app code.
- One active program per user is enforced by a DB trigger — app code just sets `is_active = true`.
- All dates use ISO 8601 encoding.
- Supabase URL and anon key live in `Core/Constants.swift` under `AppConstants.Supabase`. In Sprint 1 these are hardcoded; use xcconfig for production.

## Design System

Two custom named colors defined in `Assets.xcassets` and aliased in `Core/AppTheme.swift`:

| Color | Hex | Semantic use |
|---|---|---|
| `AccentColor` / `.gymAccent` | `#C8FF00` electric lime | Primary CTAs, progress, completion, normal training |
| `GymPurple` / `.gymPurple` | `#9B7FE8` purple | Comeback mode, PRs, deload, milestones |

All other colors use SwiftUI semantic colors (`systemBackground`, `secondarySystemBackground`, `.primary`, `.secondary`).

Minimum tap target: **48pt** (sweaty hands).

Custom components (only two): `SetRowView` and `RestTimerRingView`.

## Localization

Thai is the **primary supported** language for Thai users, and English is the fallback for everyone else. Default app language follows the device preferred language: use Thai when the device language is Thai; use English for all other device languages. English can also be user-selected later in Settings.

Every new screen, alert, button, label, error message, empty state, and accessibility string must be localized in both Thai and English at implementation time. Do not leave hardcoded user-facing strings in SwiftUI views, ViewModels, services, or repositories unless the text is a non-user-visible debug/developer string.

String Catalogs (`Localizable.xcstrings`) use `sourceLanguage = "en"` for key format and fallback behavior, with locales `th` (complete, mandatory Thai copy) and `en` (complete English copy).

## Development Workflow

### Starting a sprint

1. Read `.claude/GYMTRACK.md` → identify current sprint
2. Read `.claude/specs/S[N]-name.md` → the full implementation spec
3. Write the plan to `.claude/S[N]-plan.md` (not `docs/` or project root)
4. Implement task-by-task, marking each step `[x]` in the plan as it completes
5. Commit to main → Xcode Cloud → auto TestFlight

Sprints 1–4 complete Phase 1 ("Usable"). See `.claude/GYMTRACK.md` §7 for the full 13-sprint roadmap.

### Plan file conventions

- **Location:** `.claude/S[N]-plan.md` (e.g. `.claude/S02-plan.md`)
- **Format:** Checkbox steps `- [ ]` / `- [x]`. Mark each step done immediately after completing it — don't batch.
- **Status block:** Keep a `## CURRENT STATUS` section at the top of each plan with: what's done, last commit SHA, known deviations, and next step. Update it each session.
- **Simulator name:** The available simulator is **iPhone 17e** — always use `name=iPhone 17e` in xcodebuild commands, not `iPhone 16`.

### Task decomposition for parallel execution

Every feature follows four phases. The parallel phase (2) is where speed comes from.

```
Phase 1 — Models (sequential)
  └── Task: Codable structs + enums + unit tests
           Output: types every downstream task shares

Phase 1b — Contract (sequential, part of the same task or its own)
  └── Define the ViewModel protocol that the View will code against
      This is a Swift protocol listing state properties + async action methods
      Both parallel agents use this as their shared interface

Phase 2 — Parallel (dispatch both at once once Phase 1 is committed)
  ├── Agent 1 — Data + ViewModel
  │     Repository (Supabase queries) + real @Observable ViewModel
  │     ViewModel conforms to the protocol from Phase 1b
  │
  └── Agent 2 — View + Stub
        SwiftUI View coded entirely against the protocol (not the concrete class)
        Includes a lightweight PreviewViewModel (struct, no async) for #Preview
        View must compile and preview without Agent 1's files existing

Phase 3 — Wire (sequential, after both agents report done)
  └── Task: swap stub for real ViewModel in the View's @State initializer
            run full build + tests + simulator smoke check
            commit
```

**The protocol pattern** (use this shape for every feature ViewModel):

```swift
// Phase 1b — define this before parallel work starts
protocol ProgramBuilderProtocol: Observable {
    var programs: [Program] { get }
    var isLoading: Bool { get }
    func loadPrograms() async
    func createProgram(name: String) async throws
}

// Phase 2 Agent 1 — real implementation
@Observable final class ProgramBuilderViewModel: ProgramBuilderProtocol { ... }

// Phase 2 Agent 2 — stub for previews only
@Observable final class PreviewProgramBuilderViewModel: ProgramBuilderProtocol {
    var programs: [Program] = Program.samples
    var isLoading = false
    func loadPrograms() async {}
    func createProgram(name: String) async throws {}
}

// View — typed against protocol, never the concrete class
struct ProgramBuilderView<VM: ProgramBuilderProtocol>: View {
    @State var vm: VM
    ...
}

// Phase 3 wiring — one line change in call site
ProgramBuilderView(vm: ProgramBuilderViewModel())
```

**Rules:**
- Agent 2 (View) must produce a buildable, previewable file with zero imports from Agent 1's files
- Agent 1 (Data+VM) must not touch any UI files
- The wire task is the only place the two sides touch
- Mark each task `[x]` in the plan immediately when done; update `CURRENT STATUS` block

### Xcode-specific rules

- **File system sync:** Xcode 16 auto-discovers files created on disk inside the project folder — no `project.pbxproj` edits needed.
- **Auto-generated color symbols:** Named colors in `Assets.xcassets` (e.g. `GymPurple.colorset`) generate `Color.gymPurple` automatically. Do NOT declare them manually in `AppTheme.swift` — it causes a `invalid redeclaration` build error.
- **Module name:** `Gymbros` (not `GymBros`) — use `@testable import Gymbros` in all tests.
- **Test framework:** Swift Testing (`import Testing`, `#expect(...)`, `@Suite`, `@Test`) — not XCTest.

Current status: **Sprint 1 in progress** — spec at `.claude/specs/S01-foundation-data.md`, plan at `.claude/sprint1-plan.md`.
