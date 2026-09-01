# Google Sign-In — Design

> Status: **Approved** 2026-08-31. Code + unit tests implemented same session.
> Google Cloud console config done 2026-09-01. Remaining: one Supabase dashboard
> toggle (see "Console setup") and the manual smoke test. This reverses the
> "Apple Sign-In only" rule in `CLAUDE.md` and `.claude/GYMTRACK.md`.

## Problem

Apple Sign-In is the only way into GymBros, and it gates the entire app. Thai
users overwhelmingly have Google accounts, and Apple's Hide My Email
(`@privaterelay.appleid.com`) makes support and account recovery harder. Adding
Google as a second provider lowers the wall on the one screen everyone hits
first.

## Scope

**In:** the sign-in screen and its supporting layers — `SignInView`,
`SignInViewModel`, `AuthService`, error types, the `GoogleSignIn-iOS` SDK seam,
localization, and the first `SignInViewModel` unit tests. Plus one adjacent win:
capturing the provider's full name into `profiles.name` (Google supplies it in
`raw_user_meta_data`; Apple delivers it once, on first authorization).

**Out:** Settings "Linked accounts" / manual identity linking (beta); a Settings
row showing the current provider; any other provider; renaming the app.

## Architecture

The existing Apple flow is already the right shape, so Google is a sibling path,
not a new subsystem:

```
SignInView (Apple button | Google button)
  → SignInViewModel   nonce pair, pendingProvider, cancellation, last-used
    → AuthService.signIn(provider:idToken:accessToken:nonce:email:fullName:)
      → client.auth.signInWithIdToken(provider: .apple | .google)
```

New units, each with one job:

| Unit | Layer | Responsibility |
|---|---|---|
| `NonceGenerator` | Core | `randomNonceString()` + `sha256()`, shared by both providers (extracted from `SignInViewModel`) |
| `AuthProvider` | Model | `.apple` / `.google`; keeps `Supabase.Provider` out of Presentation |
| `LastUsedAuthProviderStore` | Core | `UserDefaults`-backed "which provider last succeeded" |
| `GoogleCredentialProvider` | Data/Remote | wraps `GIDSignIn`; returns `GoogleCredential`. Protocol `GoogleCredentialProviding` is the test seam (SDK adapter, not a feature-VM protocol) |
| `UIApplication.topViewController` | Core/Extensions | presenting VC for the Google sheet |

## Nonce contract

Verification stays **on** (`Skip nonce check` = OFF in the Supabase dashboard).
`GIDSignIn` v9 exposes `signIn(withPresenting:hint:additionalScopes:nonce:)`, and
`OpenIDConnectCredentials.nonce` is documented as "the **hash** of this value is
compared to the value in the ID token." So:

- Provider (Apple `request.nonce` / Google `nonce:`) ← `NonceGenerator.sha256(raw)`
- Supabase (`signInWithIdToken(nonce:)`) ← `raw`

Google also needs `accessToken` passed — its ID token carries an `at_hash` claim.

## Error handling

`AuthFailure`'s Apple-named cases were renamed to serve both providers:
`appleCredentialMissing` → `credentialMissing`, `appleSignInCancelled` →
`signInCancelled`. `credentialExchangeFailed` gained dedicated localization keys
(it previously fell through to `error.unknown.*`).

Cancellation detection stays in `SignInViewModel.isUserCancellation(_:)` (as it
already did for Apple) — it must not reach `ErrorMapper`, because `Core` cannot
import an SDK. It covers `ASAuthorizationError.canceled` and
`GIDSignInError.canceled`. Cancellation → `.idle`, never an error.

## Profile name

`private.handle_new_user()` already reads `raw_user_meta_data->>'full_name'`, so
Google users get `profiles.name` from the trigger. `AuthService.syncProfile`
additionally backfills `name` **only when still null** (`.is("name", value: nil)`)
so a user-set name is never clobbered, and requests `.fullName` from Apple so its
one-time name delivery is no longer discarded.

## UI

Stock components ("Apple provides the glass; we provide the color"). The button
`VStack` grows to: Apple button (filled, prominent — also satisfies App Store
guideline 4.8), Google button (outlined, secondary), a "same method you signed up
with" hint, then the existing inline error. A subtle "Last used" caption sits
under whichever button `LastUsedAuthProviderStore` names — plain
`.caption2`/`.secondary`, **not** `BrandSparkBadge` (lime is reserved, and
dark-on-lime small text is banned).

The Google button is hand-built to match the Apple button's dimensions rather
than importing `GoogleSignInSwift`'s `GoogleTouch` button (Roboto + corner radius
clash beside `SignInWithAppleButton`). The multicolour **G** is
`Assets.xcassets/GoogleG.imageset` (vector, Original rendering — never
accent-tinted). Google's guidelines permit a custom button when the G is
unmodified and the wording exact.

`viewModel.pendingProvider` drives per-button progress and disables both while a
sign-in is in flight — `.loading` rendered nothing before, acceptable with one
button, not with two.

## Console setup

Google Cloud side — **done 2026-09-01** (consent screen, iOS OAuth client, Web
OAuth client). IDs are live in `AppConstants.GoogleSignIn` and `Info.plist`
(`GIDClientID`, `GIDServerClientID`, the reversed-ID `CFBundleURLTypes` entry);
`AppConstants.GoogleSignIn.isConfigured` now returns true, so the Google button
is shown.

Remaining manual step — **Supabase Dashboard → Auth → Providers → Google**:

- Enable the provider.
- **Client IDs** field = `39794716614-6qqln4liinrna3fl6rsbujkuoa1ohdm7.apps.googleusercontent.com,39794716614-37objb4nnf99jrh8ombgod4gps8v6bj3.apps.googleusercontent.com`
  (web ID first, then iOS ID, comma-separated, no spaces).
- If the form requires an **OAuth Client ID / Secret** to save, use the **Web**
  client's ID and its secret (the secret lives only here, never in the repo).
- **Skip nonce check** stays **OFF**.
- Confirm the Web client's *Authorized redirect URI* in Google Cloud is the
  Supabase callback: `https://mkeoidoakzmsgjslihvf.supabase.co/auth/v1/callback`.

The `private.handle_new_user()` trigger already reads
`raw_user_meta_data->>'full_name'` (verified 2026-09-01), which Supabase's Google
provider populates — so Google users get `profiles.name` with no schema change.

## Known limitation (documented, not solved)

A user who signed up with **Apple + Hide My Email** has a
`@privaterelay.appleid.com` address. Supabase auto-links identities **only when
emails match**, so signing in with Google creates a **second, empty account** —
no programs, no history. The "Last used" marker plus the hint line prevent the
common case; they do not eliminate it. The eventual fix is Supabase manual
identity linking (beta) surfaced in Settings — out of scope here, recorded so it
has a starting point.

## Verification

- Unit (`** TEST SUCCEEDED **`, iPhone 17e, 2026-09-01): `NonceGeneratorTests`,
  `LastUsedAuthProviderStoreTests`, `AuthProviderTests` (raw-value stability,
  `allCases`, Codable round-trip), `SignInViewModelTests` (Google
  success / credential failure / auth-exchange failure / cancellation /
  non-cancellation GID error → error / in-flight `pendingProvider` + `.loading` /
  re-entrancy / raw-vs-hashed nonce; Apple `prepareAppleSignIn` scopes + hashed
  nonce, Apple cancel → idle, Apple non-cancel → mapped error;
  `isUserCancellation` positive + negative), updated `ErrorHandlingTests`.
  `GoogleCredentialProvider`'s real `GIDSignIn` call is deliberately untested —
  that is the point of the `GoogleCredentialProviding` seam.
- Manual — **Google sign-in verified end-to-end on 2026-09-01** (fresh sign-in →
  Today, on device). Still to exercise: relaunch stays signed in; cancel → idle,
  no red error; sign out → "Last used" under Google; airplane mode → localized
  error; rest-timer deep link still opens; new Apple ID → `profiles.name`
  populated; Thai + large Dynamic Type, light + dark.
- DB: `select id, email, name from public.profiles order by created_at desc limit 3;`
  after a Google sign-in confirms the trigger picked up `full_name`. Apple name
  backfill confirmed live 2026-09-01 (`profiles.name` went from null → set).

## Related

- `.claude/GYMTRACK.md` tech-stack table, §9
- `CLAUDE.md` — Supabase / Secrets / Design System sections
- `docs/superpowers/specs/2026-07-25-brand-identity-design.md` (button/brand rules)
