# app_flutter

## Running with the API

`flutter run` uses `https://creo-api-singapore.onrender.com`, the existing React
Pages API origin and Worker upstream (`../src/lib/http.ts`, `../../wrangler.jsonc`).
No API key or privileged proxy header is required for the password/bearer auth
contracts. Android's main manifest includes Internet permission for release builds
as well as debug builds.

For another supported environment, use:

```powershell
flutter run --dart-define=CREO_API_ORIGIN=https://your-supported-api-host
```

The value must be an HTTPS origin with no credentials, path, query or fragment.
Explicit invalid values fail closed; they never silently fall back to production.
Fully stop and rerun/rebuild an older installed app to pick up this change;
hot reload does not update build-time environment values. Live sign-in and role
destinations are separate from API-origin configuration and are not verified by
the fake-transport tests.

Connectivity check during this fix: the public Worker returned Cloudflare 403/1010
to the credential-free client, and the configured Render backend timed out on
public plans and unauthenticated profile GETs. These results do not verify live
sign-in; no account credentials were submitted. The default is grounded in the
existing deployment configuration, not a fabricated successful backend response.

## AS-02: session lifecycle verification

Implemented against the existing [authentication blueprint](../../docs/authentication-mobile-implementation-blueprint.md), limited to AUTH-06 and AS-02. AS-03 role-based destinations are not implemented. React, backend, OAuth, signup and recovery contracts were not changed; no dependencies were installed.

### Files in this slice

- `lib/main.dart`: app-level session gate, shared owner/repository injection, navigator reset on session end.
- `lib/src/core/auth_repository.dart`: existing injectable transport extended with typed JSON errors, raw authenticated requests, refresh and remote logout. No repository-side session adoption.
- `lib/src/core/auth_session.dart`: restoration, direct profile response, shared refresh, bounded safe-read replay, lifecycle state and logout generation/cache handling.
- `lib/src/core/session_store.dart`: refresh-only and legacy reads, explicit corruption, durable signed-out marker and partial-deletion reporting.
- `lib/src/features/auth/auth_screen.dart`: existing sign-in retained; session feedback and blocked-storage error handling only.
- `lib/src/features/auth/session_lifecycle_gate.dart`: branded startup/retry/logout states, resume observer and existing unavailable-destination boundary.
- `test/session_lifecycle_test.dart`: T09–T17/T27 unit and race cases.
- `test/session_lifecycle_gate_test.dart`: startup, retry, logout navigation, restricted session, simulated resume, accessibility/layout and local preview checks.
- `test/session_store_test.dart`: secure-storage adapter tests with a mocked platform, including failed legacy deletion.
- `test/widget_test.dart`: existing root configuration check adapted to the lifecycle listener.
- `README.md`: this execution/review record.

### Implemented lifecycle

- Startup mounts no app content until storage has been read and any saved identity has been validated. No artificial loading delay or pretend percentage.
- No credentials, valid access, expired access, refresh-only and unreadable storage are distinct cases. Legacy keys gain account identity only after a successful server profile response.
- `GET /api/v1/auth/me` is parsed as a direct profile. A null replacement token retains the existing mandatory-reset restricted access token.
- `POST /api/v1/auth/refresh` retains the existing refresh token. Concurrent renewals share one operation; delayed renewal cannot overwrite a newer profile-validation token.
- Eligible GET/HEAD/OPTIONS failures can replay once following an explicit 401. Auth-entry requests are never refreshed. Writes are not automatically replayed, including after ambiguous timeout. Ordinary resource 403 is not treated as an expired session.
- Refresh rejection and final `SESSION_REVOKED`/`ACCOUNT_SUSPENDED` errors end the local session. Offline/timeouts retain recoverable credentials and expose Retry without showing a cached user as freshly authorized.
- Logout immediately invalidates pending generations, drops the current profile, runs registered account-private cleanup and resets the navigator epoch. Local clearing does not wait for the best-effort remote acknowledgment.
- The durable signed-out marker prevents successfully tombstoned credentials from resurfacing when a legacy-key deletion fails. Persistent clearing failures remain explicit and block sign-in/restoration until cleanup is retried. A failed native marker write cannot be claimed to have cleared disk storage.
- A remote logout acknowledgment does not revoke every token or sign out other devices; no such guarantee is displayed.
- The existing app currently caches only session/form state. Consumers can register synchronous private-data cleanup with the owner; business caches/screens are not invented in this slice.

### Executed verification

- `dart format`: ten source/test files formatted; final `--output=none --set-exit-if-changed` check reported zero changes.
- `flutter analyze --no-pub`: **no issues found** after correcting test-only lint findings.
- `flutter test --no-pub --reporter expanded`: **74 tests passed**, including the existing AS-01 regression suite.
- Covered T09–T17 and T27 using deterministic fake HTTP/storage: no-credential startup, `/me`, expired/refresh-only credentials, concurrent refresh, one replay, auth-entry exclusion, refresh rejection versus timeout, resource denial, restricted token, logout during pending login/refresh, offline logout, account switching, corrupted/failed storage, simulated restart/resume and newer-profile/late-refresh ordering.
- Widget checks cover a narrow 320-pixel viewport and large text, real state-dependent feedback, no early app-content mount, Retry, deliberate local clear, and absence of a back path to the previous signed-in state.
- `build/as02-restoring.png` is generated and inspected as a **headless layout preview**. Flutter test fonts are used; this does not establish real-device typography or full visual parity.

### Code Review

**Verdict:** APPROVE for this bounded source slice. **Confidence:** MEDIUM.

Reviewed the actual AS-01 baseline against the AS-02 changes and new source, with attention to account ownership, generation invalidation, serialized storage, replay limits and preservation of existing entry points. No unresolved P0/P1 findings remain in that scope. Tests exposed a mobile feedback-placement defect; review exposed stale-refresh ordering; both were corrected and verified. Native secure-storage/lifecycle behavior and deployed API compatibility remain outside the executed evidence.

### Blocked / unverified

- At the AS-02 checkpoint no deployment origin had been confirmed. The later API-origin fix above now supplies the existing configured backend as the default; no live authentication mutation has been performed.
- Android/iOS device execution, Keystore/Keychain failures, true process death/resume, release networking permissions, TalkBack/VoiceOver, font rendering and measured animation performance are unverified. Adapter tests mock the secure-storage platform and lifecycle widget tests simulate events.
- Role destinations, platform/frontend role discrepancies, onboarding page locks and mandatory-reset screens still require their later approved slices. The signed-in boundary reports unavailable navigation and offers sign-out; it is not a dashboard.
- AUTH-06 remains **partial overall**: the listed source contracts and deterministic cases are verified, but full native/live parity is not claimed. Broader migration reports were not edited because this task permits changes only inside this Flutter app.
- The pre-existing landing-page overflow noted during AS-01 remains outside this slice.

The session foundation is ready for separately approved AS-03 integration, subject to its role-policy/destination decisions and the live/native blockers above. Stop at AS-02.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
