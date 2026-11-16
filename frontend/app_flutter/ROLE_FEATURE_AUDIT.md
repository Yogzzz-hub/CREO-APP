# Mobile role and feature audit

Audit date: 2026-11-15. Target: `CREO-APP/frontend/app_flutter`.

**The app is not fully production-ready.** Role navigation and many repository operations have automated coverage, but the current client portal and parts of BDE still contain UI-only workflows. A successful APK build does not establish functional parity.

This report supersedes completion claims in older readiness documents for the current source. Their dated test results remain historical evidence, not current verification. The active workspace has Git HEAD `64878fdec176adbccd03241edcaaf11d390a9764` plus substantial existing uncommitted migration work. The earlier published app checkpoint was `1a7ec467`; the APK workflow at `7a333eb4` built that checkpoint. This audit's changes are local and have not been pushed.

## Evidence and limits

- Tests run against the normal `main.dart` app, shared `AuthSession`, injected HTTP responses and in-memory credential/appearance storage. No test credentials are embedded in source.
- Role smoke coverage: admin, super_admin, bde, sales, bde_head, client, client_owner, editor, designer, freelancer, team_lead. Each is mounted with both light and dark app preferences; tests check the rendered theme and local logout. Standard `NavigationBar` destinations are tapped. Client custom bottom tabs and drawer routes are exercised separately by `client_portal_app_test.dart`.
- Role aliases prove the Flutter gate's mapping only; this run does not establish that the hosted backend provisions every alias.
- `adb devices` returned no connected devices. No Android device interaction, iOS execution, TalkBack/VoiceOver, native file dialog, live user provisioning, payment, publishing, leave approval or production data mutation was performed.
- Existing unit/widget tests supply additional populated/error/race scenarios. Passing fixture tests do not establish live permissions, tenant isolation, provider delivery, performance or complete feature coverage.
- No React, backend, standalone role project, dependency or application configuration was changed by this audit. Razorpay remains excluded by the earlier instruction.

## Small fixes made

| ID | Defect and impact | Correction / evidence |
|---|---|---|
| FIX-01 | Client header overflow at 320px caused five lifecycle UI tests to fail. | `widgets/creo_top_header.dart`: constrain and scale the wordmark within its allotted space. All `session_lifecycle_gate_test.dart` cases now pass. |
| FIX-02 | Client retainer/date, billing shortcut and upcoming-calendar text overflowed at 360px. | `screens/home/home_dashboard_screen.dart`: wrap metadata/actions and constrain shortcut text. Client role smoke cases pass in both themes. No full large-text audit is implied. |
| FIX-03 | Successful empty deliverable refresh left previous rows visible. | `screens/main_shell_screen.dart::_loadLive`: always adopt the service's current deliverable list, including empty lists. Existing empty-refresh contract test retained. |
| FIX-04 | Client approval/revision calls bypassed the existing response validation, per-session write journal and approval idempotency header. An HTTP-200 rejection or mismatched response could look successful. | `client_api_service.dart` delegates to `PortalRepository`; review actions reject duplicates, application rejection and mismatched IDs. Added regression cases in `role_feature_audit_test.dart`. |
| FIX-05 | Review completion called `setState` after disposal and could claim scheduling after mere approval. | `screens/main_shell_screen.dart`: guard mounted state before updating; report approval confirmation without claiming dispatch. |
| FIX-06 | Portal gate accepted client_owner while its repository rejected that same role. Service reads also bypassed the repository's role guard. | `portal_repository.dart::check` accepts the same two client roles as the gate. Service reads use that guard. Regression verifies client_owner access and staff rejection before transport. Server authorization remains authoritative. |
| FIX-07 | A test awaited void Navigator.pop, selected an ambiguous Navigator, and used shared native appearance storage. | `test/client_portal_app_test.dart`: pop the route containing the destination and inject an isolated appearance store. Both client-role login/navigation tests pass. No assertion was removed. |
| FIX-08 | Client profile/password and security controls claimed changes without making requests. | `screens/settings/account_settings_screen.dart`: unconnected profile/password/revoke actions now explicitly say no change occurred; simulated 2FA toggle disabled. These features remain incomplete, not implemented by this correction. Regression covers profile, revoke and disabled 2FA feedback. |
| FIX-09 | Shell messages claimed campaign approval/dispatch or checkout opening without doing either. | `screens/main_shell_screen.dart`: replace those messages with truthful unavailable/no-submission feedback. The calendar callback currently is not a server implementation. |
| FIX-10 | BDE theme was separate from the app preference, so a light-mode login could open a dark workspace. | `bde/creo_bde/bde_shell.dart`: read and toggle shared appearance when hosted in the main app; preserve standalone fallback. Rendered theme assertions cover all three BDE aliases. |
| FIX-11 | BDE account-private global lists could survive a role/logout transition and be displayed before the next account's fetch completed. | BDE shell binds private lists to session identity/generation; clears them for a different owner and when an ended session disposes its shell; detaches the global service. Same-generation restoration retains local drafts. Regression checks lead/message clearing and service detachment after BDE/sales/head logout. This does not add durable draft storage. |

Paths in FIX-01–09 are relative to `lib/src/features/portal`, except explicit `test/` references.

## Role and feature checklist

Statuses: **tested subset** means the named deterministic scenarios pass; **partial** means some source paths are connected but important functionality is missing; **UI-only** means the visible workflow has no matching server call; **unverified** means no adequate current execution evidence. No row means every feature works in production.

| Role / page group | Current behavior and evidence | Status / remaining boundary |
|---|---|---|
| Shared sign-in and session lifecycle | `auth_contract_test.dart`, `auth_screen_test.dart`, `session_lifecycle_test.dart`, `session_lifecycle_gate_test.dart`, `role_session_completion_test.dart`: payloads, refresh sharing, restore/logout, restricted reset, stale results and cleanup. | Tested subset; live cold restart/resume and storage failure on Android/iOS unverified this pass. |
| Google sign-in | `android_google_sign_in_test.dart`, `google_flow_test.dart`, `google_sign_in_test.dart`: native/backend exchange, cancellation, project mismatch and late results. | Tested subset; current CI APK certificate registration and live OAuth not exercised. A new CI debug certificate may require a new authorized Android SHA-1. |
| Admin / super admin entry and all six tabs | `admin/creo_admin/admin_shell.dart`; new role smoke tests open Home, Content, Money, Team, Inbox, Profile and sign out. | Tested subset, in both themes with empty fixtures. This does not exercise every modal. |
| Admin profile, notifications, staff/client creation, support, leave | `admin_api_service.dart`; `admin_backend_test.dart`, `admin_completion_test.dart`. | Tested subset of actual contracts, error/uncertain-write safeguards and roster refresh. Live account creation and login with delivered credentials unverified. |
| Admin client activation | `client_access_page.dart`; `admin_client_activation_test.dart` covers server plans/detail, explicit confirmation, subscription status after re-login and stale responses. | Tested subset; a real subscription approval/email was not executed this pass. |
| Admin content/tasks and money | `content.dart`, `money.dart`, `admin_api_service.dart`: review/task/proposal mutations and transaction reads have connected paths. | Partial: draft-only creation, plan edits and several operations are unavailable. See ADM-01. |
| Admin settings and team/pod operations | `profile.dart`, `team.dart`, `money.dart`. | Partial: account/profile controls differ from tenant/provider/plan/pod administration. Not every settings item is a working integration. |
| BDE / sales / bde_head entry and five tabs | `bde_shell.dart`; new tests open Pipeline, CRM, Plans, Chat, Leave and sign out. | Tested subset: routing, rendering, theme and local logout only. Do not infer business-operation success from those tests. |
| BDE lead list, metrics, plans, lead creation/stage/activity | `bde_api_service.dart` issues existing `/bde/leads`, `/bde/metrics`, `/plans` requests. | Partial: response/error handling and local fallbacks remain; see BDE-01–04. No live lead mutation performed. |
| BDE proposals, negotiation, chat, leave, imports/referrals | `creo_bde/more.dart`, `crm.dart`, `data.dart`. | UI-only/local in several write paths. These are not complete admin-visible submissions or delivered messages. |
| Client / client_owner login and navigation | `client_portal_app_test.dart`: password login through main app, five bottom tabs, Library/Brand/Billing/Pod/Help drawer routes, back and theme toggle. | Tested subset; onboarding gate remains required. |
| Client onboarding | `onboarding_integration_test.dart`; `client_onboarding_page.dart`, repository. | Tested subset: consent, payment gate, questionnaire resume/preservation, malformed/uncertain saves. Full live onboarding/Meta integration unverified. |
| Client home and review data | `client_api_service.dart`, `client_portal_test.dart`, new review guard tests. | Partial: real dashboard/deliverable reads and approval/revision contracts; media, history and some dashboard details are incomplete. |
| Client calendar, inbox/support, billing, library, brand, creative pod | Individual files under `portal/screens/`. | UI-only or partial; see CL-01–07. Navigable screens are not proof that saved server data is shown. |
| Client profile and security | `screens/settings/account_settings_screen.dart`. | Incomplete; misleading feedback corrected, but profile/password saves still not connected in this screen. 2FA is unavailable. |
| Editor / designer workstation | `workstation_page.dart`, task page/repository, member shell; `workstation_*_test.dart`, `v2_mobile_test.dart`. | Tested subset: scopes/search/filter, task start/create/delivery contract, navigation retention, drafts, failure and logout cases. Native upload/media performance unverified. |
| Workspace chat, publishing, notifications, leave and profile | Hub/account/notifications pages and repositories; corresponding workstation tests. | Tested subset of requests, permissions, duplicates, errors and lifecycle. Foreground polling differs from web realtime. OS file/provider flows and live authorization unverified. |
| Freelancer work, history, delivery, leave, chat, profile | `freelancer_workspace_page.dart`, `workstation/freelancer_page.dart`, `freelancer_repository.dart`; `freelancer_test.dart`, account/hub/preview tests. | Tested subset. Native delivery and server assignment enforcement need live verification. |
| Team lead Home, Review, Tasks, Clients, More | `team_lead_page.dart`, repository/forms/people page; `team_lead_test.dart`, `team_lead_people_test.dart`, new role smoke tests. | Tested subset: QA, scoped task creation/reassignment, support and people/leave contracts. Client mutation, task metadata/archive, balancing and CSV remain partial/missing. |
| Unknown or restricted role | Lifecycle and role-session tests. | Tested subset: unsupported role blocked and mandatory-reset session kept out of workspaces. Backend resource authorization is separately unverified. |

## Unresolved issues, with reproduction and next action

### High priority

| ID | Evidence / reproduction | User impact and required correction |
|---|---|---|
| QA-01 | Run the full test suite. `portal_completion_test.dart`, `portal_production_test.dart`, `portal_visual_test.dart` import absent `screens/portal_workspace_page.dart` and reference `PortalSection`. | All three files fail to compile, including their repository and widget cases. Recover/map the old acceptance behavior into the current screens and migrate the tests without dropping assertions. A dummy page or deleted tests would conceal missing functionality. Existing reports claiming these current tests pass are stale. |
| CL-01 | Open client Calendar. `content_calendar_screen.dart` has no session/repository; quotas are literal zero, schedule is an empty local view, month chevrons have no handlers and Month/Agenda does not load server entries. | Real campaign/slot state and concept-hook approvals/revisions are unavailable. Connect `/portal/calendar` and `/calendar/entries` through existing repository methods; verify the saved hook/slot IDs and errors. Not a small text/layout fix. |
| CL-02 | Open client Inbox, type a support ticket and submit. `inbox_shell_screen.dart::_openNewTicketModal` closes the form and reports success without a request; chat send/filter handlers are empty. `help_support_screen.dart::_submitNewTicket` inserts a local generated ticket. | A user can believe support or chat was sent when it was not. Replace local operations with authenticated ticket/thread/chat contracts, retain drafts and require server confirmation. No live message/ticket was submitted during this audit. |
| CL-03 | Open client Profile/Security and save/change password. The settings screen still has no repository-backed profile/password operation. | The attempted change is not saved. Feedback now explicitly discloses this. Connect profile load/save and password change with validation, duplicate guards, exact password bytes and server-error retention before marking complete. |
| CL-04 | Inspect `brand_dna_screen.dart`: save changes local fields; success snackbar has no backend write. `plan_bargain_modal.dart` and `pause_plan_modal.dart::_submit` use delayed local success. | Brand/pricing/pause requests can look committed without persistence or notification. Wire confirmed existing contracts, or disable/label the action pending implementation. No billing/plan mutations made. |
| BDE-01 | `creo_bde/more.dart`: proposal negotiation inserts in `negotiations`, chat send appends `Msg`, leave request/withdraw inserts/removes local rows. | Messages, admin negotiation and leave approval queue are not actually updated. Implement server confirmation and resource/role checks; reproduce with reload and a second account. A tab smoke test cannot verify these flows. |
| BDE-02 | `crm.dart`: proposal save, CSV import, referral creation and several follow-up changes operate through local `data.dart` stores. | Records can disappear on process restart or logout; no server persistence is established. Clearly separate intentionally local drafts from submitted business records and add contract tests before enabling submission claims. |
| BDE-03 | `bde_api_service.dart::logActivity` adds a local activity first, then catches a failed POST without rethrowing/removing it. `updateLeadStage` can mutate rows with null IDs locally. | A failed/unsaved action may appear recorded. Add confirmed-response and reconciliation behavior with duplicate/uncertain-write handling; preserve drafts instead of claiming success. |
| SEC-01 | Settings previously simulated 2FA and remote-session revocation. The former is now disabled and latter reports no change. | Real MFA enrollment/enforcement and other-device revocation remain unverified. A stored preference cannot be treated as authentication protection. Requires a real backend-supported design, not a local switch. |
| LIVE-01 | No device was connected and no live cross-role business test was run. Prior ledgers `SF_WORKSTATION_PARITY.md` and `ROLE_PROJECT_INTEGRATION.md` flag server resource-ownership concerns. | Production signoff still requires authorized server-side tenant/assignment tests for freelancer tasks, lead assignment/support and client tickets. Historical findings need revalidation against the deployed revision; this audit does not claim to have reproduced or fixed them. |

### Medium priority / incomplete experience

| ID | Evidence / reproduction | Remaining work |
|---|---|---|
| CL-05 | `asset_library_screen.dart::_allAssets` starts empty and is never populated from server data; download shows feedback without transferring a file. | Populate from approved deliverables and use authenticated archive/native save support. Distinguish unavailable data from a confirmed empty library. |
| CL-06 | `creative_pod_detail_screen.dart` maintains local team/slot state and booking selection; `deliverable_detail_theater_screen.dart` has local playback/recording booleans and empty action handlers. | Load real pod/availability; confirm bookings; implement or explicitly disable media/voice/history/download functions. No camera/microphone/booking verification performed. |
| CL-07 | `main_shell_screen.dart` replaces the active tab subtree instead of retaining visited tabs; current drawer secondary headers lack a dedicated tested back affordance. | Search/form/scroll state can reset when switching tabs. Add state retention with lifecycle/permission safety; verify Android Back and explicit back controls on actual device. |
| CL-08 | Portal controls include fixed 32px header hit targets, 64px bottom items and several fixed-height search fields. Portal motion uses delayed/infinite controllers without complete reduced-motion handling. | Needs an independent accessibility/reflow/motion pass at 280px, landscape, keyboard-open and 200% text. The old seven-page reflow/visual suite is currently blocked by QA-01. This audit's 320/360px fixes are not a whole-app accessibility signoff. |
| ADM-01 | `creo_admin/team.dart` explicitly blocks pod reassignment/account status/removal without verified contracts; `money.dart` blocks plan editing; `content.dart` blocks draft-only creation. Earlier admin readiness ledger also lists local pod/workload/stand-up behavior. | Complete source-backed workflows individually. Do not infer that the settings page implements tenant administration, payment/provider setup or every team operation. Invoice/plan/pod/publishing controls require separate verification. |
| BDE-04 | `bde_api_service.dart` has metrics/plan reads that catch errors; `data.dart` has hardcoded plan prices and leave allowance; several local stage variants map onto fewer backend states. | Avoid presenting fallback pricing/allowances as account-confirmed values. Validate real catalogs, stage semantics and all error states. Remaining unnecessary-type-check analyzer warnings are non-functional cleanup, not proof of correctness. |
| TL-01 | `ROLE_PROJECT_INTEGRATION.md` and current lead screens provide no complete task metadata/archive, client mutation, workload balancing or CSV path. | Keep those incomplete functions explicit; confirm contract and permission ownership before implementation. Existing QA/people tests cover only their declared subsets. |
| NATIVE-01 | CI APK uses generated debug signing; no local Android target or iOS runtime tested this pass. | Register the actual certificate when testing Google sign-in; perform file picker/save, media, permissions, cold restart, background/resume, keyboard and accessibility checks on Android, then iOS. Production signing is separate. |

## Verification commands and evidence

Commands run from `frontend/app_flutter`:

```text
flutter test --no-pub --reporter expanded
flutter test --no-pub test/session_lifecycle_gate_test.dart test/client_portal_app_test.dart test/client_portal_test.dart
flutter test --no-pub test/role_feature_audit_test.dart
flutter analyze --no-pub
dart analyze
dart format --output=none --set-exit-if-changed <the 10 changed Dart files>
adb devices
```

- Baseline full suite: **269 passed, 9 failed**, including four test-file compilation failures.
- Focused lifecycle/client run after fixes: **21 passed**.
- Final full suite on the final source: **302 passed, 3 failed** (exit 1, 1m36s). All three failures are test-file compilation failures under QA-01; no runnable test failed. Their unexecuted cases are not counted as passing coverage.
- New role/contract/security suite: **26 passed**, including the final BDE cache cleanup assertions inside the full run.
- Final `flutter analyze --no-pub`: **287 diagnostics: 11 errors, 2 warnings, 274 infos** (exit 1). The errors are in the three missing-page test files; both warnings are existing unnecessary BDE type checks. No errors were reported in `lib/`. No suppressions/exclusions or removed assertions were introduced.
- Final targeted formatting check: **10 files, no changes required** (exit 0).
- Android target inventory: **no devices attached**. No new APK build or Android/iOS runtime verification was executed in this audit; the earlier GitHub build result applies to the earlier published source.

Logs (ignored build artifacts): `build/role-audit-baseline-tests.log`, `role-audit-baseline-analyze.log`, `role-audit-focused.log`, `role-audit-smoke.log`, `role-audit-final-tests.log`, `role-audit-final-analyze.log`. Logs are diagnostics, not live-account evidence.

Bounded implementation review traced the changed service calls through the existing session/response/write journal, checked mounted guards, constrained layout parent data, shared appearance ownership, and BDE account-generation cleanup. Same-generation restoration retains local BDE draft lists; a different owner/generation cannot reuse them at entry. This review does not resolve the independently listed larger workflow gaps. Tests were not skipped, weakened or deleted to turn CI green.

## Files changed by this audit

All paths are relative to this Flutter app; existing unrelated workspace changes were preserved.

```text
lib/src/features/portal/client_api_service.dart
lib/src/features/portal/portal_repository.dart
lib/src/features/portal/widgets/creo_top_header.dart
lib/src/features/portal/screens/main_shell_screen.dart
lib/src/features/portal/screens/home/home_dashboard_screen.dart
lib/src/features/portal/screens/settings/account_settings_screen.dart
lib/src/features/bde/creo_bde/bde_shell.dart
test/client_portal_app_test.dart
test/client_portal_test.dart
test/role_feature_audit_test.dart
ROLE_FEATURE_AUDIT.md
```

## Next implementation order

1. Reconcile QA-01 with the actual client portal; restore the original acceptance behavior in current screens rather than adding a test-only page.
2. Complete client profile/password and support ticket creation/read/reply as small server-confirmed slices, then calendar/brand/billing/library/pod/media.
3. Replace BDE local submission paths with existing authenticated contracts, starting with leave and chat, then proposals/imports/activities.
4. Resolve/revalidate server authorization concerns with the backend owner and run authorized two-account tests before production release.
5. Run connected Android and iOS acceptance checks and rerun the complete quality pipeline. Do not label all roles/features complete until the open rows have evidence.

## Admin Workspace Hub follow-up — 2026-11-16

The reported admin Hub error was reproduced using the authorized test account against `https://creo-api-singapore.onrender.com`. Sign-in returned HTTP 200 with the super_admin role. GET `/api/v1/chat/channels` returned HTTP 200 with five rows. GET `/api/v1/chat/contacts` returned HTTP 500. Response values containing identities, credentials or conversations were excluded from retained diagnostics.

Two defects were identified.

1. `workstation_hub_pages.dart::_HubState.reload` loaded both lists with one failing Future.wait and cleared both on either error. It now captures each section's result independently, keeps successful conversations accessible, names the failed section and supports Retry. Initial deep-linked conversations wait for their own section to load successfully.
2. `backend/app/routers/chat.py::get_chat_contacts` used invalid PostgreSQL role literals including lead, video_editor, graphic_designer, copywriter, specialist and freelance. The backend's declared UserRole enum uses team_lead, editor, designer and freelancer for these account categories. The local patch replaces three invalid filters with supported enum members. The live backend repository, `Yogzzz-hub/creo`, contains the original invalid filters. The deployed server exception traceback was unavailable, so deployment and a repeated authenticated GET are still required to confirm live recovery.

Verification completed locally.

- `flutter test --no-pub test/workstation_hub_test.dart` passed all **16 tests**, including four new admin/super_admin partial-failure, usable-conversation and Retry recovery cases.
- `dart analyze lib/src/features/workstation/workstation_hub_pages.dart` exited successfully with no errors or warnings and six existing informational notices.
- `python -m pytest tests/test_chat_contact_role_contract.py -q -p no:cacheprovider` passed **1 test**. This checks contact-query role literals against the actual enum source, without a database connection.
- The same regression check against the original backend source failed on unsupported role `lead`, confirming it detects the removed defect.
- This follow-up modifies the shared Flutter Hub, its existing tests, the backend contacts implementation, one backend regression test and this report. Earlier unrelated local changes remain present in the workspace.
- Publication/deployment and on-device verification are pending. ADB currently lists an Android emulator. The user's physical phone remains unavailable to this tooling. The Flutter improvement and backend correction have not been published.


## 2026-11-16 — Verified client preview and setup redirects

Implemented the requested access sequence:
1. Unverified clients remain on email verification; refreshing confirmed verification opens the portal preview.
2. Verified clients can enter the branded portal and see setup progress. Review, calendar, chat, library, creative pod and production data stay locked.
3. Resume setup opens the existing agreement/questionnaire/finalization forms. Payment opens the existing HTTPS web checkout; no mobile payment success is invented and no session token is forwarded to the website.
4. Production workspace opens only when GET /api/v1/onboarding/status confirms stage 8 plus is_complete=true and GET /api/v1/payments/subscription confirms an active, non-expired subscription.
5. Completing setup refreshes the existing session owner and updates the root portal route. Refresh and return from browser allow server progress to be checked again; a separate website sign-in may be needed.

Source evidence: Yogzzz-hub/creo main, frontend/src/components/auth/RequireOnboardingComplete.tsx, frontend/src/lib/useOnboardingGate.ts, frontend/src/lib/portal-navigation-locks.ts, PortalLayout.tsx, ResumeOnboardingBanner.tsx and PortalDashboardPage.tsx. Browser automation could not connect to the supplied deployed portal, so live rendered web parity was not verified; actual web source was inspected instead.

Primary Flutter changes: lib/src/features/portal/client_portal_access.dart, client_portal_setup_shell.dart, client_portal_screen.dart; lib/src/features/onboarding/client_onboarding_page.dart; lib/src/features/auth/session_lifecycle_gate.dart; lib/src/core/auth_session.dart. Cancellable entrance timers and flexible dashboard links prevent disposal/layout regressions. Bottom navigation uses bundled Inter and adapts labels for large text.

Verification: focused client/auth/onboarding/role suite: **72 passed**. Full Flutter suite: **319 passed, 3 compile failures** in the same pre-existing portal_completion_test.dart, portal_production_test.dart and portal_visual_test.dart, which reference absent portal_workspace_page.dart / PortalSection. Flutter analyze: 293 findings, including the same 11 missing-test-page errors and 2 pre-existing BDE warnings; no application-library errors. Dart format executed. Deterministic fixtures cover stages 0–8, active/expired/malformed subscriptions, denied production reads, retry, email-confirmation redirect, setup completion, and 320px / 200% text in both themes.

Limits: live checkout, paid entitlement changes, actual email delivery and physical Android/iOS return-to-app verification were not performed. No backend or React changes were made for this client-flow slice. Changes are local and have not been published or installed on the phone.


## Publication verification — 2026-11-16

Merged with CREO-APP/main at 97493a41 before publishing. Preserved upstream team-lead sign-out, portal setup/call components and repaired legacy portal tests; adapted the visual fixture to provide explicit completed onboarding and active subscription responses. This supersedes the earlier local-tree test limitation: the exact merged publication tree passes **all 336 Flutter tests**. Flutter analyze reports **0 errors**, with 282 existing warning/informational findings. No React/backend files or workflow changes are included in this app-only publication.
