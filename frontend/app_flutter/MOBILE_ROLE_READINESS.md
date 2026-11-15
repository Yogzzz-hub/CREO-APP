# Mobile role and portal completion checkpoint

Scope: active `CREO-APP/frontend/app_flutter`, pulled reference revision `64878fd`. The older `creo-main/frontend/app_flutter` is not the migration target. Razorpay checkout is explicitly excluded. React and backend source were not changed.

## Connected implementation

| Area | Flutter evidence | Verification boundary |
|---|---|---|
| Member branding | `lib/src/features/splash/splash_screen.dart` CreoWordmark; workstation header/drawer | White word with amber dot in dark mode; contrasting word in light mode; parent-constrained header at large text/keyboard sizes |
| Role routing | `lib/src/features/auth/session_lifecycle_gate.dart` | Admin, sales/BDE, team lead, freelancer, editor/designer and client have separate destinations; unsupported roles cannot fall into the member workstation |
| Forced password update | `lib/src/features/auth/mandatory_password_page.dart`, `lib/src/core/auth_session.dart` | Restricted token preserved, proactive refresh, exact password bytes, one adoption owner, duplicate/late-result protection, resume/reset race covered |
| Incomplete client onboarding | `lib/src/features/onboarding/` | Authoritative server status, explicit terms consent, resumable questionnaire, logo upload/removal, brand generation/status, confirmed completion; no payment bypass |
| Client portal | `lib/src/features/portal/`, `CLIENT_PORTAL_READINESS.md` | Calendar slot hooks/revisions, deliverable approval idempotency, audio feedback, strategy edits/regeneration and authenticated approved-asset ZIP export added |
| Team Lead | `lib/src/features/team_lead/`, `ROLE_PROJECT_INTEGRATION.md` | Live pod, QA/reassignment, scoped task creation, client information, support and existing publishing/chat/account pages |
| Freelancer | `lib/src/features/freelancer/` and existing workstation freelancer pages | Imported bottom navigation wraps the existing authenticated work, time-off, chat and profile features |
| Admin | `lib/src/features/admin/`, `ADMIN_ROLE_READINESS.md` | Settings/profile, real provisioning and supported operational actions; consult the detailed ledger for remaining contract gaps |
| Workspace chat | `lib/src/features/workstation/workstation_hub_pages.dart` | Existing app-colored channel/message hierarchy, grouped authors, date separators, draft-preserving composer, attachments and reactions retained |

## Authorized live account checks

The supplied admin account authenticated as `super_admin`. The supplied BDE and client accounts returned HTTP 401; no password resets or repeated guessing were performed.

Six disposable accounts were created through the authorized admin endpoints, with credential emails disabled: editor, designer, team_lead, freelancer, sales and client. All six subsequently signed in with their expected role. The first editor creation timed out; an authoritative roster read confirmed absence before a reconciled creation succeeded. Other user accounts were not changed.

Successful live GET checks:

- Admin dashboard, settings, teams and support ticket queue: HTTP 200.
- Editor, designer and team-lead pod dashboard, own profile and `/api/v1/admin/leave`: HTTP 200.
- Freelancer own task feed and own profile: HTTP 200.
- Sales `/api/v1/bde/metrics` and `/api/v1/bde/leads`: HTTP 200.
- Client onboarding status, portal profile, portal calendar and own tickets: HTTP 200. Its onboarding status is stage 1, with terms required; portal dashboard HTTP 403 is the expected onboarding gate.

Early exploratory probes of `/api/v1/leave` and `/api/v1/bde/dashboard` returned 404; those are not the app's supported paths. The subsequent checks above used source-backed paths. These 404s are not app integration failures.

Credentials, sessions and raw QA output are stored only in ignored `.dart_tool/live_qa_*.json` files. They are not app assets, source imports or build defines. Do not commit or publish them. The QA accounts remain available for the owner; no billing, posting, legal acceptance or business-data mutation was executed as a verification step.

## Network and platform evidence

Native API origin remains `https://creo-api-singapore.onrender.com`. Anonymous `/api/v1/auth/me` returns JSON HTTP 401 there; the deployed Worker API path returned plain-text HTTP 403. No privileged proxy secret was added to the app. The deployed public frontend bundle was inspected as reference evidence; protected web journeys could not be automated because browser control was unavailable.

Android debug APK compiled and installed on the existing Android 16 emulator. Normal `lib/main.dart` launch and a populated live Team Lead pod screen were observed. Build/install success alone is not verification of every role's UI or every mutation. Native ZIP save-dialog completion, iOS execution, physical-device performance and release signing remain unverified.

## Remaining release blockers and parity gaps

1. Backend ticket creation lacks deliverable tenant ownership enforcement. Team-lead reassignment/support endpoints also need stronger server-side resource scope enforcement. Client filtering is not a security boundary. Backend fixes require separate work; Flutter does not bypass permissions to compensate.
2. Invoice responses have no PDF URL/download contract. A truthful invoice PDF cannot be manufactured from the current response.
3. Investor-relations mobile reports remain unavailable; the React destination and backend admin-only report authorization disagree. Unknown roles receive a safe unsupported-destination state.
4. Team-lead prototype-only task edit/archive, load balancing/CSV, some pod-management workflows are not all mapped to confirmed scoped APIs. See `ROLE_PROJECT_INTEGRATION.md`.
5. Onboarding Meta OAuth section H and some ancillary enum polish remain incomplete. Mobile payment checkout is excluded by request. No completed-client account was available for exhaustive live portal mutation checks.
6. Automatic pod-thread provisioning/realtime completeness and every Android/iOS role journey still require further verification. Full feature parity and production readiness are **not** claimed.

Detailed executed test counts and the final analyzer state are recorded below after integration verification.

## Final continuation checks (2026-11-14)

- `flutter test --no-pub`: 269 tests passed against the final source state, including the client-offboarding regression.
- `flutter analyze --no-pub`: zero errors; two existing BDE unnecessary-type-check warnings and informational diagnostics remain (288 total diagnostics in this run), so analyzer exit status is nonzero. No diagnostics were suppressed.
- `dart format` ran on changed files. Android full-app debug build succeeded; the final rebuild/install state is recorded in the delivery response.
- Team-lead leave/member operations and admin chat, sales and native CSV export are now connected as described in their detailed ledgers. Account status/removal controls no longer claim local-only changes as server actions.
- The Android tab-automation probe stalled and was canceled; its tabs are not counted as verified. The observed Home destination was restored. iOS/native save-dialog completion remain unverified.

Final Android artifact: build/app/outputs/flutter-apk/app-debug.apk built successfully after the 269-test run. Installation of this newest artifact was attempted, but emulator-5554 was disconnected (device not found). Earlier Android launch evidence applies to the preceding build; the final continuation changes have build/test evidence only.

