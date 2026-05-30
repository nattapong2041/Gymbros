# Sprint 5 - Settings

> Detailed implementation spec for coding agents.
> Reference: `.claude/GYMTRACK.md` Section 9 - Phase 1, Sprint 5

---

## Overview

**Goal:** Give a signed-in user a Settings tab with functional Sign Out, weight-unit toggle, and placeholder rows for Privacy Policy and Account Deletion.

**Primary acceptance test:** A Settings tab (4th tab) appears in the TabView. Tapping Sign Out returns to the sign-in screen. Toggling the weight unit between kg and lb persists via `ProfileRepository.updateProfile`. App version row shows the correct build number. Privacy Policy and Delete Account rows are present but show placeholder UI.

**Effort estimate:** Simple.

**Dependencies:** Sprint 4 is complete. The `TabView` shell exists in `RootView`. `ProfileRepository.fetchCurrentProfile()` and `updateProfile(_:)` exist. `AuthService` has a sign-out method.

---

## 1. Requirements

### Must Have

```text
✓ Settings tab (4th tab, gear icon) added to RootView TabView
✓ SettingsView rows:
  ✓ Weight unit toggle: kg / lb — functional, persists via ProfileRepository
  ✓ Sign Out — functional, calls AuthService, returns to SignInView
  ✓ App version + build number (static, read from Bundle)
  ✓ Privacy Policy — placeholder (sheet or empty view)
  ✓ Delete Account — placeholder (sheet or empty view, no actual deletion)
✓ SettingsViewModel (@Observable)
  ✓ Loads current profile to read weightUnit
  ✓ Updates weightUnit via ProfileRepository.updateProfile
  ✓ Calls AuthService.signOut
  ✓ ViewState<SettingsData> + transientError: AppError?
✓ ProfileRepositoryProviding protocol for test injection
✓ All visible strings localized in Thai and English
✓ All user-visible errors flow through AppError/ViewState
✓ App builds and tests pass on iPhone 17e simulator
```

### Out of Scope

```text
✗ Language toggle (i18n sprint, Sprint 7)
✗ Real account deletion or data wipe
✗ Real privacy policy content
✗ Notification preferences
✗ Profile editing (name, avatar)
✗ Subscription / paywall (Sprint 12)
```

---

## 2. Existing Foundation To Reuse

```text
Gymbros/Data/Repository/ProfileRepository.swift     — fetchCurrentProfile(), updateProfile(_:)
Gymbros/Data/Remote/AuthService.swift               — signOut() or sign-out method
Gymbros/Model/Profile.swift                         — weightUnit: WeightUnit
Gymbros/Model/Enums/WeightUnit.swift                — .kg / .lb
Gymbros/Core/ErrorHandling/AppError.swift
Gymbros/Core/ErrorHandling/ViewState.swift
Gymbros/Core/ErrorHandling/ErrorMapper.swift
Gymbros/Presentation/Programs/ErrorAlertModifier.swift — .transientErrorAlert
Gymbros/App/RootView.swift                          — TabView to receive 4th tab
Gymbros/Resources/Localizable.xcstrings
```

Rules:

- Use concrete `@Observable` ViewModel.
- Add `ProfileRepositoryProviding` protocol for test injection only.
- Whole app uses SwiftUI system and semantic colors only.

---

## 2.1 Spec Lock Decisions

Task 0 locks these decisions before parallel work starts:

**Settings rows (confirm or adjust at Task 0):**
- Weight unit: segmented control or `Picker` with `.kg` / `.lb` using `WeightUnit` enum. Persists immediately on change via `updateProfile`.
- Sign Out: destructive-styled button. Calls `AuthService.signOut()` immediately. `AuthService` listens to Supabase auth-state changes and updates `currentUser` from the emitted session, so `RootView` re-evaluates auth state and shows `SignInView`.
- App version: read from `Bundle.main.infoDictionary["CFBundleShortVersionString"]` and `CFBundleVersion`. Static `Text`, no interaction.
- Privacy Policy: button presents a Sheet with localized "Privacy Policy coming soon." message and a Dismiss button. No real URL or WKWebView this sprint.
- Delete Account: button that presents a confirmation sheet with a "Not available yet" message. No actual deletion logic.

**`ProfileRepositoryProviding` protocol:**
- Protocol with `fetchCurrentProfile() async throws -> Profile` and `updateProfile(_ profile: Profile) async throws`.
- `ProfileRepository` conforms to it.
- `SettingsViewModel` takes `any ProfileRepositoryProviding` for test injection.

**Sign-out flow:**
- `SettingsViewModel.signOut() async` calls the auth service.
- On Supabase `.signedOut` auth-state emission, `AuthService.currentUser` becomes nil, and `RootView` observes auth state change and transitions to `SignInView` automatically.
- On error, set `transientError`.

**`SettingsData`:**
```text
weightUnit: WeightUnit
appVersion: String     // e.g. "1.0.0 (42)"
```

---

## 3. Product Flow

```text
App launch (authenticated)
→ RootView → TabView
     Tab 0 — Today
     Tab 1 — Programs
     Tab 2 — History
     Tab 3 — Settings (new)
          SettingsView
               Weight unit: kg / lb toggle
               Sign Out → returns to SignInView
               App Version (static)
               Privacy Policy → placeholder sheet
               Delete Account → placeholder confirmation sheet
```

---

## 4. SettingsViewModel

```swift
@MainActor
@Observable
final class SettingsViewModel {
    var state: ViewState<SettingsData> = .idle
    var transientError: AppError?
    var isSigningOut: Bool

    init(profileRepository: ProfileRepositoryProviding? = nil,
         authService: AuthService? = nil)
    // Note: Defaults match TodayViewModel pattern — ProfileRepository() and AuthService.shared.
    func load() async
    func updateWeightUnit(_ unit: WeightUnit) async
    func signOut() async
}
```

`SettingsData`:
```text
weightUnit: WeightUnit
appVersion: String
```

---

## 5. ProfileRepositoryProviding

```swift
protocol ProfileRepositoryProviding {
    func fetchCurrentProfile() async throws -> Profile
    func updateProfile(_ profile: Profile) async throws
}
```

`ProfileRepository` must conform to `ProfileRepositoryProviding`.

---

## 6. UI Requirements

### SettingsView

States:
- `.loading`: progress indicator while profile loads.
- `.error(AppError)`: retry UI.
- `.success(SettingsData)`: full settings list.

Layout (use `Form` or `List`):

```
Section "Preferences" (or unlabelled):
  Picker / SegmentedControl: kg | lb

Section "Account":
  Sign Out button (red/destructive)

Section "About":
  App Version   [1.0.0 (42)]
  Privacy Policy [chevron / disclosure]
  Delete Account [red text, chevron]
```

- Sign Out calls `signOut()` immediately and disables the row while the sign-out task is running.
- Delete Account shows a sheet with "Account deletion is not yet available. Contact support." and a Dismiss button.
- Privacy Policy shows a placeholder sheet or navigates to a placeholder view.
- Minimum 48pt tap targets.

---

## 7. Repository Contract

### Existing (reuse)

```swift
// ProfileRepository
func fetchCurrentProfile() async throws -> Profile
func updateProfile(_ profile: Profile) async throws
```

### New (Task 1 adds)

```swift
protocol ProfileRepositoryProviding {
    func fetchCurrentProfile() async throws -> Profile
    func updateProfile(_ profile: Profile) async throws
}
```

`ProfileRepository: ProfileRepositoryProviding` conformance added.

---

## 8. Localization

Add complete Thai and English copy for these key families:

```text
settings.title                    // "Settings" / "ตั้งค่า"
settings.weight_unit.label        // "Weight unit" / "หน่วยน้ำหนัก"
settings.weight_unit.kg           // "kg"
settings.weight_unit.lb           // "lb"
settings.sign_out.button          // "Sign Out" / "ออกจากระบบ"
settings.privacy_policy.dismiss   // "Dismiss" / "ปิด"
settings.delete_account.dismiss   // "Dismiss" / "ปิด"
settings.app_version.label        // "Version" / "เวอร์ชัน"
settings.privacy_policy.label     // "Privacy Policy" / "นโยบายความเป็นส่วนตัว"
settings.privacy_policy.placeholder // "Privacy Policy coming soon." / "กำลังจะมา"
settings.delete_account.label     // "Delete Account" / "ลบบัญชี"
settings.delete_account.placeholder // "Account deletion is not yet available. Contact support."
settings.section.preferences      // "Preferences" / "การตั้งค่า"
settings.section.account          // "Account" / "บัญชี"
settings.section.about            // "About" / "เกี่ยวกับ"
accessibility.settings.weight_unit // "Weight unit, currently %@"

Note: Task 3 must verify common.ok and common.cancel already exist in Localizable.xcstrings before reusing; if missing, add under common.*.
```

---

## 9. Testing And Acceptance

### Automated tests

SettingsViewModel (mock `ProfileRepositoryProviding`):
- Load → state `.success` with correct `weightUnit` matching the fetched profile.
- `updateWeightUnit(.lb)` → calls `updateProfile` with updated unit.
- `updateWeightUnit` failure → `transientError` is set.
- `signOut()` success → `isSigningOut` becomes false (auth state handled by RootView).
- `signOut()` failure → `transientError` is set.
- Profile fetch failure → state `.error`.

### Manual smoke test

```text
1. Sign in. Settings tab (gear icon) appears as the 4th tab.
2. Tap Settings. Weight unit shows current setting.
3. Toggle weight unit to lb. Navigate away and back. lb persists.
4. Tap Privacy Policy. Placeholder sheet appears.
5. Tap Delete Account. Placeholder sheet appears with no destructive action.
6. Tap Sign Out. Confirmation alert appears.
7. Confirm sign out. App returns to SignInView.
8. Sign in again. Weight unit preference persists.
```

Build/test:

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'
```
