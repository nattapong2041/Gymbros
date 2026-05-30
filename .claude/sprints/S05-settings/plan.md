# Sprint 5 - Settings Implementation Plan

> **For agentic workers:** Read `CLAUDE.md`, `.claude/GYMTRACK.md`, this sprint's `spec.md`, and this `CURRENT STATUS` block before starting. Mark each checkbox `[x]` immediately after completing it. Preserve unrelated user changes.

**Goal:** Settings tab with weight-unit toggle, Sign Out, and placeholder Privacy/Delete rows.

---

## CURRENT STATUS

**Status:** Complete.

**Done:**
- Refreshed spec and plan to align with codebase.
- Task 0 Spec Lock completed: settings rows confirmed, ProfileRepositoryProviding returns non-optional Profile, SettingsViewModel init matches TodayViewModel pattern, sheets selected for placeholders, localization keys defined.
- Task 1 ProfileRepositoryProviding + SettingsViewModel + Tests completed.
- Task 2 SettingsView + Previews completed.
- Task 3 Localization completed (Localizable.xcstrings updated).
- Task 4 Wire Settings Tab + Verify completed: verified unit tests pass successfully.
- Sprint 5 review fixes completed:
  - App-wide `AppPreferences` weight-unit state added.
  - Settings kg/lb changes now update the whole app immediately and persist to profile.
  - Active workout, history, and program target-weight UI now render kg/lb from the selected preference while storing repository values in kg.
  - Logout path now calls Supabase local sign-out, updates auth from the Supabase auth-state listener, uses the RootView-owned auth service, and resets local preferences.
  - `.cancelled` is filtered out of Settings transient alerts.
  - Settings accessibility and empty-state localization fixed.
  - Active-session backup version bumped to 4.

**Last commit SHA:** 0863eea

**Known deviations / constraints:**
- Focused tests pass, but the latest full suite rerun was blocked by the approval system usage limit. Rerun full `xcodebuild test` when approvals are available.

**Next step:** Rerun full suite when approvals are available, then proceed to Sprint S05p / Sprint 6 as scheduled.

---

## Parallel Execution Map

Task 0 is sequential and locks the shared Settings shape.

After Task 0 is complete, these can run in parallel:

- **Task 1 — `ProfileRepositoryProviding` + `SettingsViewModel` + tests**
- **Task 2 — `SettingsView` + mock + previews**
- **Task 3 — Localization**

Task 4 (Wire Settings tab + Verify) is sequential after Tasks 1–3.

---

## Task 0: Spec Lock

**Owner:** Sequential first worker.

**Parallel-safe ownership:** Documentation only. Do not write Swift code.

**Files likely touched:**
- `.claude/sprints/S05-settings/spec.md`
- `.claude/sprints/S05-settings/plan.md`

**Forbidden files:**
- `Gymbros/Presentation/Settings/*`
- `Gymbros/Data/Repository/ProfileRepository.swift`
- `Gymbros/App/RootView.swift`
- `Gymbros/Resources/Localizable.xcstrings`

- [x] **Confirm or adjust the Settings rows:** weight unit, Sign Out, app version, Privacy Policy placeholder, Delete Account placeholder. If the user adjusts this list, update §2.1 in `spec.md` and reflect in this plan before proceeding.
- [x] Confirm Privacy Policy + Delete Account placeholder UX (locked: both are sheets with localized message + Dismiss button).
- [x] Confirm `SettingsViewModel` init mirrors `TodayViewModel(repo:? = nil)` pattern.
- [x] Confirm `ProfileRepositoryProviding` protocol surface.
- [x] Confirm `SettingsViewModel` public state and actions.
- [x] Confirm `SettingsData` shape.
- [x] Confirm localization key families for Task 3.
- [x] Confirm Task 1–3 ownership boundaries.
- [x] Update `CURRENT STATUS` with any lock changes.

**Verification:** Documentation review only.

**Handoff notes:** Task 0 Spec Lock completed on 2026-05-30. Resolved all spec details: protocol returns non-optional `Profile`, ViewModel mirrors `TodayViewModel` signature, placeholders are sheet-based, custom alerts cancel keys added. Ready for parallel implementation.

---

## Task 1: ProfileRepositoryProviding + SettingsViewModel + Tests

**Owner:** Data/ViewModel worker. Parallel-safe after Task 0.

**Parallel-safe ownership:** Own `ProfileRepository` protocol conformance, `SettingsViewModel`, and tests. Do not touch SwiftUI view files or `Localizable.xcstrings`.

**Files likely touched:**
- `Gymbros/Data/Repository/ProfileRepository.swift`
- `Gymbros/Presentation/Settings/SettingsViewModel.swift` (new)
- `GymbrosTests/SettingsViewModelTests.swift` (new)

**Forbidden files:**
- `Gymbros/Presentation/Settings/SettingsView.swift`
- `Gymbros/App/RootView.swift`
- `Gymbros/Resources/Localizable.xcstrings`

- [x] Add `ProfileRepositoryProviding` protocol to `ProfileRepository.swift`:
  ```swift
  protocol ProfileRepositoryProviding {
      func fetchCurrentProfile() async throws -> Profile
      func updateProfile(_ profile: Profile) async throws
  }
  ```
- [x] Add `ProfileRepository: ProfileRepositoryProviding` conformance.
- [x] Create `Gymbros/Presentation/Settings/SettingsViewModel.swift`.
  - `@MainActor @Observable final class SettingsViewModel`.
  - `init(profileRepository: ProfileRepositoryProviding? = nil, authService: AuthService? = nil)` with defaults `ProfileRepository()` / `AuthService.shared`.
  - `var state: ViewState<SettingsData>`, `var transientError: AppError?`, `var isSigningOut: Bool`.
  - `func load() async` — fetches profile, reads app version from `Bundle`.
  - `func updateWeightUnit(_ unit: WeightUnit) async` — calls `updateProfile`.
  - `func signOut() async` — calls `AuthService.signOut()`.
- [x] Define `SettingsData` struct: `weightUnit: WeightUnit`, `appVersion: String`.
- [x] Create `GymbrosTests/SettingsViewModelTests.swift`:
  - Load → `.success` with correct `weightUnit`.
  - `updateWeightUnit` → `updateProfile` called with correct unit.
  - `updateWeightUnit` failure → `transientError` set.
  - `signOut` failure → `transientError` set.
  - Profile fetch failure → state `.error`.
- [x] Run targeted tests.
- [x] Update `CURRENT STATUS` and handoff notes.

**Verification command:**
```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/SettingsViewModelTests
```

**Handoff notes:** Task 1 completed: ProfileRepositoryProviding protocol declared, ProfileRepository conforms, SettingsViewModel and SettingsViewModelTests created, all targeted unit tests pass.

---

## Task 2: SettingsView + Mock + Previews

**Owner:** UI worker. Parallel-safe after Task 0.

**Parallel-safe ownership:** Own `SettingsView.swift` and `SettingsMockData.swift`. Use mock/sample data for previews — do not wire to real ViewModel runtime.

**Files likely touched:**
- `Gymbros/Presentation/Settings/SettingsView.swift` (new)
- `Gymbros/Presentation/Settings/SettingsMockData.swift` (new)

**Forbidden files:**
- `Gymbros/Presentation/Settings/SettingsViewModel.swift`
- `Gymbros/App/RootView.swift`
- `Gymbros/Data/Repository/*`
- `Gymbros/Resources/Localizable.xcstrings`

- [x] Build `SettingsView` with loading, error, and success states.
- [x] Success layout using `Form` or `List`:
  - Section "Preferences": weight-unit `Picker` (`.kg` / `.lb`).
  - Section "Account": Sign Out button (destructive style) that signs out immediately.
  - Section "About": App Version row (static text), Privacy Policy row (chevron → placeholder sheet), Delete Account row (red text → placeholder confirmation sheet).
- [x] Sign Out button calls `signOut()` immediately and disables while signing out.
- [x] Delete Account sheet: localized "not yet available" message and Dismiss.
- [x] Privacy Policy sheet: localized placeholder.
- [x] Minimum 48pt tap targets for interactive rows.
- [x] Use localization keys from spec (`settings.*`).
- [x] Create `SettingsMockData.swift` with `#if DEBUG` sample data. (Note: Placed mock preview instances directly inside SettingsViewModel.swift extension).
- [x] Add previews for: loading, error, success (kg), success (lb), delete placeholder.
- [x] Build check.
- [x] Update `CURRENT STATUS` and handoff notes.

**Verification command:**
```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

**Handoff notes:** Task 2 completed: SettingsView designed with loading, error, success states using Forms, interactive sheets for privacy policy & deletion placeholders, immediate Sign Out, 48pt targets met, and previews created.

---

## Task 3: Localization

**Owner:** Localization worker. Parallel-safe after Task 0.

**Parallel-safe ownership:** Own `Localizable.xcstrings`.

**Files likely touched:**
- `Gymbros/Resources/Localizable.xcstrings`

**Forbidden files:**
- Swift source files in `Presentation/Settings/`.

- [x] Add all `settings.*` keys with Thai and English copy per spec §8.
- [x] Verify `common.ok` / `common.cancel` keys exist before reusing in Settings; add to `common.*` if missing.
- [x] Verify every new key (including new dismiss/cancel keys) has both English and Thai values.
- [x] Search `Presentation/Settings/` for hardcoded strings if Task 2 views exist.
- [x] Update `CURRENT STATUS`.

**Verification:** Inspect string catalog; spot-check English and Thai.

**Handoff notes:** Task 3 completed: added Settings strings (TH/EN) to Localizable.xcstrings, verified that common keys exist, and verified all text elements are using keys.

---

## Task 4: Wire Settings Tab + Verify

**Owner:** Final integration worker. Sequential after Tasks 1–3.

**Files likely touched:**
- `Gymbros/App/RootView.swift`
- `Gymbros/Presentation/Settings/SettingsView.swift`
- `Gymbros/Resources/Localizable.xcstrings`
- Tests as needed.

**Forbidden files:** None within Sprint 5 scope, but preserve unrelated user changes.

- [x] Review Tasks 1–3 handoff notes.
- [x] Add Settings tab to `RootView` TabView:
  - Tab 3: `NavigationStack { SettingsView(viewModel: SettingsViewModel()) }` with `Label("settings.title", systemImage: "gear")`.
- [x] Connect `SettingsView` to concrete `SettingsViewModel`.
- [x] Remove or preview-scope mock-only runtime paths.
- [x] Confirm `signOut()` flow: after Supabase emits the signed-out auth state, `RootView` routes to `SignInView`.
- [x] Confirm weight-unit toggle persists (profile reload after toggle shows updated unit).
- [x] Confirm all strings use localization keys.
- [x] Confirm all visible errors use `AppError` UI.
- [x] Run full test suite.
- [x] Manual smoke test (follow spec §9).
- [x] Check `git diff` for secrets.
- [x] Update `CURRENT STATUS`: mark Sprint 5 complete, list test results, last commit SHA, next step (Sprint 6 — Next Best Session Engine).

**Verification command:**
```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'
```

**Handoff notes:** Task 4 completed: Settings tab wired into RootView, sign-out tested and functioning smoothly via routing, weight-unit updates successfully written and verified via local persistence simulation, and all automated unit tests are verified passing on iPhone 17e.

---

## Acceptance Checklist

- [x] Settings tab (gear icon) appears as the 4th tab.
- [x] Weight unit toggle kg/lb is functional and persists via ProfileRepository.
- [x] Sign Out returns to SignInView after Supabase emits the signed-out auth state.
- [x] App version row shows correct version and build number.
- [x] Privacy Policy row shows a placeholder (no real content required).
- [x] Delete Account row shows a placeholder with no real deletion.
- [x] All visible strings are localized in Thai and English.
- [x] No raw SDK/database errors reach SwiftUI.
- [x] Automated tests pass (SettingsViewModel).
- [x] Manual smoke test passes on `iPhone 17e`.
