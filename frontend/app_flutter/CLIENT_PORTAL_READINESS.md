# Client portal and Workspace Hub readiness

## Current outcome

The authenticated portal uses backend data for its dashboard, review list and history, per-slot calendar concepts, support threads, account profile, brand assets, approved library, subscription details, plans and assigned pod. Calendar hook decisions, audio-file feedback, and approved-asset ZIP export now use authenticated backend contracts. These routes no longer open the standalone prototype's simulated workflows. Existing prototype files remain available as migration references.

Release readiness is partial. Test and screenshot evidence below covers deterministic transports. Live client tenant permissions, gateway checkout, provider callbacks and platform capabilities require additional evidence.

## Feature evidence

| Feature | Active Flutter evidence | Backend evidence under backend/app | Verification and gaps |
| --- | --- | --- | --- |
| Dashboard | `screens/home/home_dashboard_screen.dart`, `client_api_service.dart` | `routers/portal_dashboard.py`, GET `/portal/dashboard` | Real counts, quotas, plan, assigned team and recent activity; sample agenda/identities removed. Light/dark fixture screenshots inspected |
| Review | `screens/portal_review_page.dart`, `portal_repository.dart` | `routers/deliverables.py`, `services/deliverable_workflow.py` | Real search/status filters, detail, version history, safe media links, idempotency-key approvals and textual revisions. Native audio-file selection uploads multipart `audio` to `/deliverables/{id}/upload-voice-note`, then sends the returned URL with revision feedback. Live microphone recording and inline native video remain incomplete |
| Calendar | `screens/portal_workspace_page.dart`, `portal_repository.dart` | `routers/calendar.py`, GET `/calendar/entries`, `/portal/calendar`, POST `/calendar/slots/{id}/approve-concept`, `/request-changes`, `/portal/cycles/{id}/approve`, `/comment`, `/portal/shoots/{id}/request-reschedule` | Per-slot server blueprints and hook choices now support actual concept approval and revision notes; cycle approval, comments, shoot days and timezone-aware reschedule requests remain. Calendar month grid remains incomplete |
| Inbox/support | same page, `PortalTicketPage` | `routers/tickets.py` | Real list, search, creation with priority, threaded reads and replies. Drafts survive failure. Manual refresh. Client pod thread appears if returned by the server; automatic thread provisioning and realtime delivery remain incomplete |
| Account | same page, `PortalActionSheet` | `routers/portal_dashboard.py`, GET/PUT `/portal/profile`, POST `/portal/change-password` | Server profile, actual status, profile/password updates, password visibility, secure byte-preserving password requests and real sign-out. Backend HTTP-200 application errors are rejected. Native provider management remains incomplete |
| Brand | same page | `routers/portal_dashboard.py`, `/portal/brand-dna`, `/portal/profile`, `/onboarding/questionnaire`, `/portal/brand-dna/regenerate`, `/portal/brand/upload`, `/portal/brand/files/{id}` | Actual strategy, editable summary/audience/voice, regeneration from saved onboarding sections A–E, native file selection/upload/open/delete |
| Library | same page, `client_api_service.dart`, `../workstation/workstation_files.dart` | `routers/deliverables.py`, GET `/portal/deliverables/download-zip` | Server-approved assets, search, preview/download links, authenticated ZIP bytes saved through Android/iOS document-save UI. Native share-sheet option and on-device platform validation remain incomplete |
| Billing | same page | `routers/payments.py`, `routers/portal_dashboard.py` | Actual subscription, invoices, plans, pause requests/resume and plan consultation. No simulated payment success. Mobile Razorpay checkout, confirmation and add-on purchasing await dependency approval and sandbox verification |
| Creative pod | same page | `routers/portal_dashboard.py` | Assigned roster, actual availability/bookings, server-validated call booking and conflict/error handling |
| Member branding | `../workstation/workstation_page.dart`, `../splash/splash_screen.dart` | Existing shared Creo mark | Header and drawer reuse the login's amber circular mark |
| Hub conversations | `../workstation/workstation_hub_pages.dart` | Existing `workstation_hub_repository.dart` contracts | Channel/DM sections, avatars, consecutive-sender grouping, local timestamps, date separators, attachment/emoji actions and jump-to-latest. Existing server-scoped threads, draft retention, ambiguous-send journal and foreground polling preserved. Reactions remain explicitly local to the view |

Paths in the Flutter evidence column are relative to `lib/src/features/portal`.

## Ownership and write safety

`PortalRepository` uses the existing `AuthSession` and its transport, refresh, secure storage and generation boundary. It checks the authenticated client role and account generation before and after each request. No second token owner is activated.

Non-idempotent pending/ambiguous writes are shared across reopened repositories for the current session generation. A lost or malformed response does not silently become success or trigger an automatic retry. Deterministically rejected requests may be corrected. Idempotent profile PUT permits explicit user retry. Drafts remain visible after errors. Account errors show recovery controls without inventing connection/profile values when no server data was loaded.

## Release blockers found in source

1. **Backend resource authorization needs review.** `backend/app/routers/tickets.py`, `create_ticket`, loads `payload.deliverable_id` and changes its linked task without checking that the deliverable belongs to the requesting client. The mobile create-request form sends no deliverable or assignee ID. A server-level tenant test and correction are required before exposing that optional API capability. No cross-account mutation was attempted.
2. **Two-factor protection is unverified.** `backend/app/routers/portal_dashboard.py`, `toggle_two_factor`, stores a `brand_dna.two_fa_enabled` preference. Source search found no corresponding authentication enforcement. The mobile account screen omits the prototype's simulated protection toggle and invented active-device sessions.
3. **Invoice PDF output is not available from the current backend contract.** Subscription data exposes invoice id, date, amount, plan and status, but no PDF URL or download endpoint. Flutter has no PDF-generation dependency or invoice-native bridge; do not invent an invoice document. Razorpay checkout/provider parity remains excluded pending explicit SDK and sandbox approval.
4. **Live integration evidence is missing.** No production authentication, billing, posting, support or scheduling mutations were executed. Test fixtures cannot establish live server tenant isolation or gateway reconciliation.

## Executed verification

- `flutter test --no-pub` passed all 224 tests after the timer, form and routing changes. The final light-theme color adjustment was followed by 24 passing production/visual checks. The final portal/chat focused run passed 43 checks.
- `portal_production_test.dart` covers exact profile/password/support/calendar payloads, HTTP-200 application rejection, concurrent/uncertain writes across reopened pages, account isolation, logout during a read, draft retention, and all seven domain pages at 320 logical pixels with 200% text in both themes.
- `portal_completion_test.dart` covers per-slot entries, selected-hook approval and revision payloads, server-confirmed UI success, upload multipart field/auth scope, revision voice URL, idempotency keys, authenticated ZIP bytes and native save-channel payload.
- Focused run: `flutter test --no-pub test/portal_completion_test.dart test/portal_production_test.dart` passed 29 tests. Targeted `dart analyze` reported no errors; its diagnostics are informational style/deprecation notices.
- Android `ACTION_CREATE_DOCUMENT` and iOS document export use the existing workstation-files channel; native system dialogs and iOS execution still need device validation. Save cancellation is surfaced without claiming success.
- `portal_visual_test.dart` renders populated client and chat states in both themes plus a recoverable account error. Actual bundled Inter and Material icon fonts are loaded for these captures.
- Screenshot artifacts are under ignored `build/portal-qa/`. They use isolated test identities and deterministic responses. They are not live-account evidence.
- Existing hub tests cover narrow phones with the keyboard open, duplicate sends, failed-send drafts, stale responses, background/resume and server permissions. A narrow composer regression was corrected during this change.
- A delayed entrance timer was changed to a cancellable timer so it cannot survive screen disposal.
- Static analysis has no errors. Its latest full run reported 161 diagnostics, including three existing admin/BDE warnings and SDK deprecation/lint information, keeping its exit status nonzero.
- Android debug APK build, installation and `lib/main.dart` launch succeeded on `emulator-5554`, Android 16. The existing saved BDE session restored. Client/member device journeys were not exercised with a live account. `build/portal-qa/android-main.png` records the normal-app launch. A final hot reload applied the light-theme correction successfully.
- Existing Kotlin-version and NDK-version build warnings remain. Device startup logs are debug evidence; physical-device frame performance and release signing are unverified.
- Measured foreground/background contrast ratios are 5.87:1 for the portal light interactive text on white, 6.77:1 for light error text on white, 7.58:1 for amber on the dark base, and 7.26:1 for dark text on the amber plan surface.

## Artemis skill

Installed and validated at `C:/Users/nandhakumar/.agents/skills/artemis-mobile-qa/SKILL.md`. It follows the documented observe, execute and inspect-evidence workflow and distinguishes Artemis execution from alternative Flutter/ADB evidence. Upstream sources are the [Artemis repository](https://github.com/google/artemis), its [MCP documentation](https://github.com/google/artemis/blob/main/mcp_server/README.md) and [testing rules](https://github.com/google/artemis/blob/main/mcp_server/rules.md).

Artemis MCP tools are not connected in this session. Its runtime, model-provider credentials and global configuration have not been installed or altered. Existing Flutter tooling and the already selected Android emulator provide the current verification path. iOS and physical-device performance are unverified.

## GitHub portal and main-app integration verification — 2026-11-14

Compared all 33 Dart files under `client portal/lib` in `Yogzzz-hub/CREO-APP` at `68af39b15260de39388debdcd19ca6e5b0e1a028`. All 27 screen, widget and model files have counterparts in `lib/src/features/portal`. The standalone entry point and Dio/storage ownership are supplied by the normal app's `main.dart`, `AuthSession`, `ClientApiService` and `PortalRepository`. GitHub's standalone shell contains simulated profile, sign-out and payment feedback. Existing authenticated integrations were preserved. File correspondence establishes inventory coverage only.

The normal app now recognizes `/portal` through the existing lifecycle gate. Signed-out access opens sign-in. Both `client` and `client_owner` enter the portal after password login, subject to the existing mandatory-reset and onboarding gates. The shell retains visited tab widgets, review search and scroll state. Unvisited tabs load on demand and hidden tab tickers are disabled.

| Scope | Evidence | Result |
| --- | --- | --- |
| Password login and logout through main.dart for both client roles | `test/client_portal_app_test.dart` | Verified with injected HTTP transport and in-memory session storage |
| Home, Review, Calendar, Inbox and Account bottom navigation | Same test | Verified, including review search after switching tabs |
| Library, Brand DNA, Plan & billing, Creative pod and Help destinations, and back navigation | Same test | Verified, including backend request paths |
| Theme change inside the normal app | Same test | Verified |
| Profile, support, calendar, review approval/revision, voice-file upload, ZIP export, failures and account isolation | Existing `portal_production_test.dart`, `portal_completion_test.dart`, `client_portal_test.dart` | Deterministic checks passed |
| Narrow screens and large text in both themes | Existing portal production/visual tests | Passed. Fixture frames under `build/portal-qa` |
| Whole app regression | `flutter test --no-pub` | 291 passed, including 3 new main-app tests |
| Static analysis | `flutter analyze --no-pub` | No errors. 318 diagnostics including two existing BDE unnecessary-type-check warnings and informational notices |

Logs are under ignored `build/portal-integration-full-tests.log`, `build/portal-app-tests.log` and `build/portal-integration-analyze.log`. Live tenant behavior, native file dialogs, iOS, inline video/microphone capture, provider account management, realtime chat, calendar month-grid and invoice PDF gaps listed above remain open. Razorpay remains excluded. No claim of full production parity follows from these tests.

Android verification for this update: `flutter build apk --debug --no-pub` passed. The APK installed successfully on the existing `emulator-5554` without clearing its app data. The initial `am start -W` wait timed out during slow emulator startup, then the process rendered the normal sign-in screen. Screenshot inspected at `build/portal-qa/portal-integration-android.png`. This is startup evidence. Live client authentication and portal mutations were not exercised on the device. Existing Kotlin and NDK version warnings remain.
