# Sprint 5 - Settings Implementation Plan

> **For agentic workers:** Read `CLAUDE.md`, `.claude/GYMTRACK.md`, this sprint's `spec.md`, and this `CURRENT STATUS` block before starting. Mark each checkbox `[x]` immediately after completing it. Preserve unrelated user changes.

**Goal:** Settings tab with weight-unit toggle, Sign Out, and placeholder Privacy/Delete rows.

---

## CURRENT STATUS

**Status:** Not started. Spec and plan created 2026-05-18.

**Done:** Nothing yet.

**Last commit SHA:** (update when Sprint 4 completes)

**Known deviations / constraints:**
- Use simulator `iPhone 17e` in all `xcodebuild` commands.
- Module name is `Gymbros`.
- Tests use Swift Testing (`import Testing`, `#expect`, `@Suite`, `@Test`), not XCTest.
- Xcode 16 auto-discovers files under `Gymbros/`; do not edit `project.pbxproj`.
- Whole app uses SwiftUI system and semantic colors only.
- Sprint 5 adds the 4th tab (Settings). Sprint 4 introduced the 3-tab shell.
- No real account deletion, no real privacy policy content, no language toggle.
- Settings row list in §2.1 is inferred — **confirm or adjust at Task 0** before any code lands.

**Next step:** Start at Task 0 — Spec Lock.

---

## Parallel Execution Map

Task 0 is sequential and locks the shared shape (including row confirmation).

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

- [ ] **Confirm or adjust the Settings rows:** weight unit, Sign Out, app version, Privacy Policy placeholder, Delete Account placeholder. If the user adjusts this list, update §2.1 in `spec.md` and reflect in this plan before proceeding.
- [ ] Confirm `ProfileRepositoryProviding` protocol surface.
- [ ] Confirm `SettingsViewModel` public state and actions.
- [ ] Confirm `SettingsData` shape.
- [ ] Confirm localization key families for Task 3.
- [ ] Confirm Task 1–3 ownership boundaries.
- [ ] Update `CURRENT STATUS` with any lock changes.

**Verification:** Documentation review only.

**Handoff notes:** Add when complete.

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

- [ ] Add `ProfileRepositoryProviding` protocol to `ProfileRepository.swift`:
  ```swift
  protocol ProfileRepositoryProviding {
      func fetchCurrentProfile() async throws -> Profile?
      func updateProfile(_ profile: Profile) async throws
  }
  ```
- [ ] Add `ProfileRepository: ProfileRepositoryProviding` conformance.
- [ ] Create `Gymbros/Presentation/Settings/SettingsViewModel.swift`.
  - `@MainActor @Observable final class SettingsViewModel`.
  - `init(profileRepository: any ProfileRepositoryProviding, authService: AuthService)`.
  - `var state: ViewState<SettingsData>`, `var transientError: AppError?`, `var isSigningOut: Bool`.
  - `func load() async` — fetches profile, reads app version from `Bundle`.
  - `func updateWeightUnit(_ unit: WeightUnit) async` — calls `updateProfile`.
  - `func signOut() async` — calls `AuthService.signOut()`.
- [ ] Define `SettingsData` struct: `weightUnit: WeightUnit`, `appVersion: String`.
- [ ] Create `GymbrosTests/SettingsViewModelTests.swift`:
  - Load → `.success` with correct `weightUnit`.
  - `updateWeightUnit` → `updateProfile` called with correct unit.
  - `updateWeightUnit` failure → `transientError` set.
  - `signOut` failure → `transientError` set.
  - Profile fetch failure → state `.error`.
- [ ] Run targeted tests.
- [ ] Update `CURRENT STATUS` and handoff notes.

**Verification command:**
```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/SettingsViewModelTests
```

**Handoff notes:** Add when complete.

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

- [ ] Build `SettingsView` with loading, error, and success states.
- [ ] Success layout using `Form` or `List`:
  - Section "Preferences": weight-unit `Picker` (`.kg` / `.lb`).
  - Section "Account": Sign Out button (destructive style) with confirmation alert.
  - Section "About": App Version row (static text), Privacy Policy row (chevron → placeholder sheet), Delete Account row (red text → placeholder confirmation sheet).
- [ ] Sign Out confirmation alert: localized title, message, and action buttons.
- [ ] Delete Account sheet: localized "not yet available" message and Dismiss.
- [ ] Privacy Policy sheet: localized placeholder.
- [ ] Minimum 48pt tap targets for interactive rows.
- [ ] Use localization keys from spec (`settings.*`).
- [ ] Create `SettingsMockData.swift` with `#if DEBUG` sample data.
- [ ] Add previews for: loading, error, success (kg), success (lb), sign-out confirmation, delete placeholder.
- [ ] Build check.
- [ ] Update `CURRENT STATUS` and handoff notes.

**Verification command:**
```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

**Handoff notes:** Add when complete.

---

## Task 3: Localization

**Owner:** Localization worker. Parallel-safe after Task 0.

**Parallel-safe ownership:** Own `Localizable.xcstrings`.

**Files likely touched:**
- `Gymbros/Resources/Localizable.xcstrings`

**Forbidden files:**
- Swift source files in `Presentation/Settings/`.

- [ ] Add all `settings.*` keys with Thai and English copy per spec §8.
- [ ] Verify every new key has both English and Thai values.
- [ ] Search `Presentation/Settings/` for hardcoded strings if Task 2 views exist.
- [ ] Update `CURRENT STATUS`.

**Verification:** Inspect string catalog; spot-check English and Thai.

**Handoff notes:** Add when complete.

---

## Task 4: Wire Settings Tab + Verify

**Owner:** Final integration worker. Sequential after Tasks 1–3.

**Files likely touched:**
- `Gymbros/App/RootView.swift`
- `Gymbros/Presentation/Settings/SettingsView.swift`
- `Gymbros/Resources/Localizable.xcstrings`
- Tests as needed.

**Forbidden files:** None within Sprint 5 scope, but preserve unrelated user changes.

- [ ] Review Tasks 1–3 handoff notes.
- [ ] Add Settings tab to `RootView` TabView:
  - Tab 3: `NavigationStack { SettingsView() }` with `Label("settings.title", systemImage: "gear")`.
- [ ] Connect `SettingsView` to concrete `SettingsViewModel(profileRepository:authService:)`.
- [ ] Remove or preview-scope mock-only runtime paths.
- [ ] Confirm `signOut()` flow: after sign-out, `RootView` auth state change routes to `SignInView`.
- [ ] Confirm weight-unit toggle persists (profile reload after toggle shows updated unit).
- [ ] Confirm all strings use localization keys.
- [ ] Confirm all visible errors use `AppError` UI.
- [ ] Run full test suite.
- [ ] Manual smoke test (follow spec §9).
- [ ] Check `git diff` for secrets.
- [ ] Update `CURRENT STATUS`: mark Sprint 5 complete, list test results, last commit SHA, next step (Sprint 6 — Next Best Session Engine).

**Verification command:**
```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'
```

**Handoff notes:** Add when complete.

---

## Acceptance Checklist

- [ ] Settings tab (gear icon) appears as the 4th tab.
- [ ] Weight unit toggle kg/lb is functional and persists via ProfileRepository.
- [ ] Sign Out shows confirmation then returns to SignInView.
- [ ] App version row shows correct version and build number.
- [ ] Privacy Policy row shows a placeholder (no real content required).
- [ ] Delete Account row shows a placeholder with no real deletion.
- [ ] All visible strings are localized in Thai and English.
- [ ] No raw SDK/database errors reach SwiftUI.
- [ ] Automated tests pass (SettingsViewModel).
- [ ] Manual smoke test passes on `iPhone 17e`.
