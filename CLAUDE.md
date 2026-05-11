# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Shared Agent Context

This repository keeps one shared agent instruction source. `CLAUDE.md` is the canonical file, and `AGENTS.md`, `AGENT.md`, and `GEMINI.md` must stay as symlinks to it so Claude Code, Codex, Gemini CLI, and other coding agents read the same project guidance, skills, rules, security policy, architecture, workflow, and localization requirements.

Codex command-approval rules live in `.codex/rules/default.rules`. Those rules are an extra enforcement layer for Codex; the durable cross-agent policy belongs in this shared Markdown file.

## Shared Rules and Skills

- Maintain shared agent guidance only in `CLAUDE.md`. Do not create divergent Claude-only, Codex-only, or Gemini-only Markdown instructions.
- Keep `AGENTS.md`, `AGENT.md`, and `GEMINI.md` as symlinks to `CLAUDE.md`. If any alias becomes a real file, replace it with a symlink before adding new guidance.
- Add or update skills, workflows, architecture rules, security rules, localization rules, and sprint rules in this shared file first.
- Use tool-specific files only for executable enforcement that cannot live in Markdown, such as `.codex/rules/default.rules`. Tool-specific rules must mirror this file and must not relax shared policy.
- Every agent should apply the same skill routing:
  - SwiftUI or iOS work: follow the Xcode, SwiftUI, design system, localization, and testing rules below.
  - Supabase work: follow the Supabase, secrets, error handling, auth, RLS, schema, and repository rules below.
  - Sprint work: read `.claude/GYMTRACK.md`, then the relevant `.claude/sprints/S[N]-name/spec.md`, then update `.claude/sprints/S[N]-name/plan.md` as described below.
  - Git or release work: inspect the diff first, preserve unrelated user changes, and never stage or commit secrets.
  - Error handling work: use the shared `AppError` / `ViewState` pipeline below and never expose raw SDK errors to SwiftUI.

## Project

**GymBros** — an iOS gym companion app for Thai users. Tagline: "มาแค่นี้พอ เราจะดูแลส่วนที่เหลือ" (Just show up. We'll handle the rest.)

The app name "GymBros" is a placeholder — it will be renamed before App Store launch.

Full product decisions, roadmap, and algorithm specs live in `.claude/GYMTRACK.md`. Sprint implementation specs and plans live together under `.claude/sprints/S[N]-name/`. Always read the relevant spec before implementing a sprint.

## Build & Test

This is an Xcode project. There is no CLI build step — open `Gymbros.xcodeproj` and build/run from Xcode, or use `xcodebuild`:

```bash
# Build
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build

# Run all tests
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'

# Run a single test class
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/CodableTests
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
Data/Repository/      ProfileRepo, ExerciseRepo, ProgramRepo, WorkoutRepo
Data/Services/        ProgressiveOverloadEngine, SmartSessionAdvisor,
                      ComebackRampService, StallDetector, DeloadAdvisor (Sprint 5+)
Presentation/         One folder per feature: Auth, Today, Workout, Programs,
                      History, Progress, Onboarding, Settings
Resources/            Localizable.xcstrings, Assets.xcassets
```

**Models** use `Codable` with explicit `CodingKeys` mapping camelCase Swift ↔ snake_case Supabase columns. Nested relationships (e.g. `Program.days`) are not in `CodingKeys` — they are populated client-side after separate fetches.

**ViewModels** use `@Observable` (iOS 17 Observation framework, not `ObservableObject`).

**Services** (`Data/Services/`) are pure Swift with no I/O — they take data in and return suggestions out. 100% unit-tested. See `.claude/GYMTRACK.md` §8 for the exact algorithms.

## Error Handling

All user-visible errors must flow through one typed pipeline. Never pass raw `Error.localizedDescription`, Supabase messages, SQL details, stack traces, or random debug strings directly to SwiftUI.

Required flow:

```
Data source / SDK throws
  -> ErrorMapper / interceptor normalizes the error
  -> Swift Result<Success, AppError>
  -> Repository returns the typed result or throws only AppError
  -> ViewModel maps AppError to feature-specific state
  -> SwiftUI renders localized error UI
```

### Error Types

Create shared error utilities under `Core/ErrorHandling/`:

- `AppError`: the single app-level domain error enum used outside the data layer.
- `Result<Success, AppError>`: use Swift's standard `Result` type for success/failure returns.
- `ViewState<Value>` or `LoadState<Value>`: common UI state enum with at least `.idle`, `.loading`, `.success(Value)`, `.empty` when needed, and `.error(AppError)`.
- `ErrorMapper`: the only place that converts unknown `Error` values into `AppError`.

Recommended shape:

```swift
enum ViewState<Value> {
    case idle
    case loading
    case success(Value)
    case empty
    case error(AppError)
}

enum AppError: Error, Equatable {
    case auth(AuthFailure)
    case api(APIErrorCode, statusCode: Int?)
    case network(NetworkFailure)
    case decoding
    case validation(ValidationFailure)
    case permissionDenied
    case notFound
    case conflict
    case rateLimited
    case cancelled
    case unknown(debugID: String)
}
```

Use Swift's standard `Result<Success, Failure>` from the standard library. Do not create custom result wrappers or feature-specific result types.

### Supabase Error Mapping

Supabase and Apple framework errors must be normalized before reaching repositories or ViewModels. Handle these families explicitly:

- Auth errors: missing session, expired/invalid token, Apple Sign-In cancellation, Apple credential failure, Supabase Auth API errors, PKCE/id-token exchange errors.
- PostgREST/Data API errors: JSON error body fields `code`, `message`, `details`, `hint`; HTTP statuses such as 400, 401, 403, 404, 409, 416, 429, 500, 503, 504; Postgres codes such as `23505` uniqueness violation, `23503` foreign key violation, `42501` insufficient privilege/RLS, and `PGRST` API/schema/auth codes.
- Storage errors: bucket/object not found, unauthorized, RLS denied, file too large, invalid path, upload/download failure.
- Edge Function errors: function returned 4xx/5xx, relay/network failure, fetch/unreachable failure.
- Realtime errors: channel join failure, authorization failure, connection loss, timeout.
- Client/runtime errors: `URLError`, `DecodingError`, `EncodingError`, `CancellationError`, Keychain errors, invalid local state, and validation failures.

Mapping rules:

- `CancellationError` and Apple Sign-In user cancellation should not show an error screen or alert.
- `401` / missing session -> `.auth(.sessionMissing)` and route to sign-in when appropriate.
- `403` / RLS / `42501` -> `.permissionDenied` with friendly copy, not database policy text.
- `404` / no row -> `.notFound` or `.empty` depending on whether empty data is valid for the feature.
- `409` / `23505` / one-active-program trigger conflicts -> `.conflict` with feature-specific recovery guidance.
- `429` -> `.rateLimited`.
- Transient network/server errors -> `.network(.temporary)` or `.api(..., statusCode: 503/504)` and show retry.
- Decoding/model mismatch -> `.decoding`; log debug details, show a generic localized message.
- Unknown errors -> `.unknown(debugID:)`; generate/log a debug ID and show generic localized copy.

### Layer Responsibilities

Data sources and SDK adapters:

- May call Supabase, Keychain, Apple APIs, URLSession, or local persistence.
- May throw raw SDK errors internally.
- Must map raw thrown errors with `ErrorMapper.map(error, context:)` before crossing into ViewModels.

Repositories:

- Expose `async -> Result<Value, AppError>` or `async throws -> Value` where the only thrown type is `AppError`.
- Do not return optional for failure. Optional is only for valid empty domain states.
- Do not construct user-facing strings.
- Attach structured context for logging only, such as operation name, table, function name, status code, Supabase code, and debug ID.
- Do not introduce `RepositoryError`; use `AppError` directly.

ViewModels:

- Own the source-of-truth UI state with `@Observable`.
- Use a common state enum instead of independent `isLoading`, `errorMessage`, and optional data flags for the same request.
- Convert repository results into `ViewState`.
- May map `AppError` into feature-specific actions, such as sign-out, retry, or returning to a previous screen.
- Must not expose raw `String` errors. Expose `AppError?` or `ViewState`.

SwiftUI views:

- Render from state declaratively: idle, loading, success, empty, error.
- Use shared localized error components for error banners, alerts, full-screen error views, and retry actions.
- Use `alert`, `ContentUnavailableView`, inline validation text, or a feature error view based on severity and task context.
- All title, message, recovery, retry, accessibility, and button strings must come from `Localizable.xcstrings` in both Thai and English.
- Never display raw Supabase messages, SQL hints, status codes, debug IDs, or `localizedDescription` to users. Debug IDs may appear only in developer logs unless explicitly designed for support.

### Logging

Log raw errors only in debug/developer channels. Logs may include operation context, Supabase code, HTTP status, and debug ID. Logs must not include access tokens, refresh tokens, authorization headers, Apple identity tokens, Supabase keys, service role keys, or personal health data.

## Swift Packages

- `supabase/supabase-swift` — Supabase client
- `kishikawakatsumi/KeychainAccess` — secure token storage

## Supabase

- Auth: Apple Sign-In only (via `signInWithIdToken`). Profile row is auto-created by a DB trigger on `auth.users` insert — do not create it manually in app code.
- One active program per user is enforced by a DB trigger — app code just sets `is_active = true`.
- All dates use ISO 8601 encoding.
- Supabase URL and anon key live in `Core/Constants.swift` under `AppConstants.Supabase`. In Sprint 1 these are hardcoded; use xcconfig for production.

## Secrets and Environment Configuration

- Never commit API keys, Supabase keys, service role keys, Apple credentials, tokens, `.env` files, local xcconfig files, or machine-specific environment settings to git.
- Keep real secrets in ignored local files such as `.env`, `supabase/.env`, `Secrets.xcconfig`, `Local.xcconfig`, or `Gymbros/Core/Secrets.swift`.
- Commit only safe examples or templates, such as `.env.example`, with placeholder values.
- Before staging or committing, check the diff for secrets and remove any accidental key, token, endpoint credential, or local environment value.
- If a secret was accidentally committed, treat it as compromised: rotate it immediately, remove it from history as needed, and document the cleanup.

## Data Safety and Approval

- **Mandatory Approval:** Every agent (Gemini CLI, Claude Code, Codex, etc.) MUST use `ask_user` or equivalent to obtain explicit confirmation BEFORE performing any "dangerous" operation.
- **Dangerous Operations include:**
    - Deleting or dropping database tables or schemas.
    - Wiping, truncating, or performing bulk deletions of production/development data.
    - Applying migrations that include `DROP`, `TRUNCATE`, or destructive `ALTER TABLE` statements.
    - Updating critical system configuration or high-impact metadata.
- **Protocol:** Explain the impact and potential risks of the operation clearly in the confirmation request. Do not proceed until the user has explicitly granted permission for that specific action.

## Design System

The app currently uses SwiftUI system and semantic colors only (e.g. `.systemBackground`, `.secondarySystemBackground`, `.primary`, `.secondary`, `.blue`, `.green`, `.red`, `.orange`, `.purple`). 

**Brand Colors (Future Use):**
The custom colors `AccentColor` (electric lime) and `GymPurple` (purple) are defined in the asset catalog for future brand identity. However, to ensure rapid MVP delivery and system-wide accessibility/contrast compliance, they must **not** be used in the current UI. Use adaptive system colors instead.

Minimum tap target: **48pt** (sweaty hands).

Custom components (only two): `SetRowView` and `RestTimerRingView`.

## Localization

Thai is the **primary supported** language for Thai users, and English is the fallback for everyone else. Default app language follows the device preferred language: use Thai when the device language is Thai; use English for all other device languages. English can also be user-selected later in Settings.

Every new screen, alert, button, label, error message, empty state, and accessibility string must be localized in both Thai and English at implementation time. Do not leave hardcoded user-facing strings in SwiftUI views, ViewModels, services, or repositories unless the text is a non-user-visible debug/developer string.

String Catalogs (`Localizable.xcstrings`) use `sourceLanguage = "en"` for key format and fallback behavior, with locales `th` (complete, mandatory Thai copy) and `en` (complete English copy).

## Development Workflow

### Starting a sprint

1. Read `.claude/GYMTRACK.md` → identify current sprint
2. Read `.claude/sprints/S[N]-name/spec.md` → the full implementation spec
3. Write or update the plan at `.claude/sprints/S[N]-name/plan.md` (not `docs/` or project root)
4. Implement task-by-task, marking each step `[x]` in the plan as it completes
5. Commit to main → Xcode Cloud → auto TestFlight

Sprints 1–4 complete Phase 1 ("Usable"). See `.claude/GYMTRACK.md` §7 for the full 13-sprint roadmap.

### Plan file conventions

- **Location:** `.claude/sprints/S[N]-name/plan.md` (e.g. `.claude/sprints/S02-program-builder/plan.md`)
- **Spec location:** `.claude/sprints/S[N]-name/spec.md`
- **Single source of truth:** Sprint specs and plans live only under `.claude/sprints/S[N]-name/`. Do not create sprint plans in `.claude/` root or sprint specs in `.claude/specs/`; remove old aliases if they reappear.
- **Format:** Checkbox steps `- [ ]` / `- [x]`. Mark each step done immediately after completing it — don't batch.
- **Status block:** Keep a `## CURRENT STATUS` section at the top of each plan with: what's done, last commit SHA, known deviations, and next step. Update it each session.
- **Simulator name:** The available simulator is **iPhone 17e** — always use `name=iPhone 17e` in xcodebuild commands, not `iPhone 16`.

### Task decomposition for parallel execution

For complex feature sprints split across parallel agents, use `.agents/skills/gymbros-parallel-sprint/SKILL.md`. The preferred default is no-protocol parallelization: the sprint `spec.md` and `plan.md` are the coordination contract, with **Spec Lock**, **Repo + ViewModel**, **View + Mock Data**, **Localization**, then **Wire + Verify** tasks. For simple screens, use a concrete `@Observable` ViewModel directly to keep delivery fast.

Do not create feature ViewModel protocols by default. Only use a protocol when the user explicitly requests it or when an existing repo pattern genuinely requires a shared compile-time contract before wiring.

```
Task 0 — Spec Lock (sequential)
  └── Define screen states, data shapes, concrete ViewModel surface,
      localization key families, acceptance tests, and task ownership.

Task 1 — Repo + ViewModel (parallel)
  └── Repository, payloads, services, concrete @Observable ViewModel,
      ViewState/AppError handling, persistence/recovery, and tests.

Task 2 — View + Mock Data (parallel)
  └── SwiftUI views, local mock/sample data, previews, accessibility,
      loading/error/empty/success states, and localized key usage.

Task 3 — Localization (parallel)
  └── Localizable.xcstrings keys and complete Thai/English copy.

Task 4 — Wire + Verify (sequential)
  └── Connect real ViewModel to views, remove or isolate mock runtime paths,
      run tests, smoke test, update plan status, and commit when requested.
```

**Rules:**
- Each parallel task must declare owned files, forbidden files, dependencies, verification command, and handoff notes in the sprint plan
- Agent 1 (Repo + ViewModel) must not touch UI files except unavoidable compile fixes documented in the plan
- Agent 2 (View + Mock Data) must produce buildable, previewable UI without depending on Agent 1 wiring
- The wire task is the only place the two sides touch
- Mark each task `[x]` in the plan immediately when done; update `CURRENT STATUS` block

### Xcode-specific rules

- **File system sync:** Xcode 16 auto-discovers files created on disk inside the project folder — no `project.pbxproj` edits needed.
- **Auto-generated color symbols:** Named colors in `Assets.xcassets` (e.g. `GymPurple.colorset`) generate `Color.gymPurple` automatically. Do NOT declare them manually in `AppTheme.swift` — it causes a `invalid redeclaration` build error.
- **Module name:** `Gymbros` (not `GymBros`) — use `@testable import Gymbros` in all tests.
- **Test framework:** Swift Testing (`import Testing`, `#expect(...)`, `@Suite`, `@Test`) — not XCTest.

Current status: **Sprint 3 ready to implement** — spec at `.claude/sprints/S03-logger-timer/spec.md`, plan at `.claude/sprints/S03-logger-timer/plan.md`.
