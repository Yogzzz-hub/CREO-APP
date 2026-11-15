# Staff and Freelancer migration delivery ledger

Updated 2026-11-10. React reference: `D:/creo-main/creo-main/frontend/src`.
Flutter implementation: `D:/creo-main/CREO-APP/frontend/app_flutter`.
Backend contracts inspected read-only: `D:/creo-main/CREO-APP/backend`.
The earlier reports in `D:/creo-main/creo-main/docs` were reused. This is the
current scoped implementation ledger; older reports describe their own baseline.

## Progress and evidence boundary

- [x] SF-01: source routes, roles, workflows, contracts and incomplete prototypes inventoried in [SF_WORKSTATION_INVENTORY.md](SF_WORKSTATION_INVENTORY.md).
- [x] SF-02: existing theme, session owner, structure and shared transport preserved; responsive cards/forms/sheets and complete asynchronous states added.
- [x] SF-03: staff task stages, creation/start, delivery/QA submission, leave, profile, meetings, feedback and workspace integrations implemented.
- [x] SF-04: separate freelancer assignment/delivery/history/leave/settings/navigation implemented.
- [x] SF-05: bounded native motion, press feedback, interruptions and reduced-motion behavior implemented and tested where noted below.
- [x] SF-06: production repositories use existing authenticated contracts; separate debug-only fixtures cannot contact live hosts.
- [ ] SF-07: deterministic verification and Android compilation are available; live backend journeys, native runtime, full visual/motion parity, iOS and performance signoff remain open.

`VERIFIED` is used only for an explicitly executed scenario. A passing fixture
test does not verify a feature's live API or platform parity. No feature group
below is declared fully equivalent across Android/iOS and React.

## Feature parity matrix

React paths below are relative to `frontend/src`; full source/contract references
for every stable ID are in the inventory. Flutter paths are relative to `lib/src/features/workstation`.
"Contract tested" means deterministic fake transport, not a production request.

| IDs / React source | Flutter implementation | UI parity | Interaction parity | API parity | Animation parity | Tests / evidence | Status |
|---|---|---|---|---|---|---|---|
| SF-S01–S03: `pages/admin/MemberOverviewPage.tsx`, `components/workstation/MemberMobileDashboard.tsx` | `workstation_page.dart`, `workstation_data.dart` | Branded responsive overview, scopes, actual counts; hours/PTO balance unavailable | Filters, search, pins, refresh, protected logout | GET pod dashboard contract tested; live unverified | Existing entrance retained; native rendering unverified | `workstation_test.dart`, `workstation_interactions_test.dart`; `build/sf-home.png` | PARTIAL |
| SF-S04–S05: overview feedback/team/media | `workstation_page.dart`, `workstation_meetings_page.dart` preference queue | Returned notes/members; external secure media inspection | Task targeting, account-scoped persistent dismissal/restore; safe channel selection for replies | Actual scoped channel/message APIs; dismissal is local preference, matching source ownership | Bounded sheets; inline web media replaced by OS/browser viewing | `workstation_feedback_test.dart`, existing dashboard tests | PARTIAL |
| SF-S06: overview Meet/Zoom configuration | `workstation_meetings_page.dart` | Meet/Zoom/code/custom link fields, save/reset/copy feedback | Encrypted account preferences, serialized saves/logout cleanup | Source has no meeting API; no endpoint invented | Provider opening respects native reduced motion | `workstation_meetings_test.dart` | PARTIAL; native provider/clipboard unverified |
| SF-S07–S11: `MemberTaskBoardPage.tsx`, `MemberMobileTaskBoard.tsx`, `lib/creative-roles.ts` | `workstation_task_page.dart`, `workstation_task_repository.dart` | Four stages retain all six backend buckets; own/role-eligible tasks | Search, client/priority filters, due sort, detail targeting and start | Existing POST `/deliverables/tasks/{id}/start`; server resource rules remain authoritative | Native navigation; source-style press feedback; no decorative list loop | `workstation_task_test.dart`; `build/sf-task-board.png` | PARTIAL |
| SF-S12–S14: board create/brief/feedback | Same task page/repository | Complete source form fields, QA/client feedback, real footage/voice/reference links | Create + optional separate start; partial creation and ambiguous outcomes require reconciliation | POST `/tasks` exact fields; no automatic write replay | Native forms/sheets; external voice playback differs from inline web player | Task contract and race tests | PARTIAL |
| SF-S15–S17: `lib/deliverables-api.ts`, board submission | `workstation_files.dart`, task page/repository; Android/iOS bridges | File name/size/spec guidance, native preview, five optional checks, transfer/server-confirmation states | Native selection, validation, streamed multipart upload; input retention and duplicate guards | Uses existing server-side `/upload` fallback. React's presigned PUT optimization is not implemented | Bounded progress and press feedback; OS preview instead of inline preview | Multipart/header/payload/limit tests; Android debug compilation | PARTIAL; native selection/preview and live upload unverified |
| SF-S18–S19: `MemberSchedulePTOPage.tsx` | `workstation_account_pages.dart`, account repository | Upcoming assignments, dates, reason, history | Create/cancel eligible own requests; UTC date basis; server overlap errors | GET/POST/DELETE `/admin/leave` contract tested | Native date picker and feedback | `workstation_account_test.dart` | PARTIAL |
| SF-S20–S21: `MemberSettingsPage.tsx` / session boundary | Account pages/repository; `../../core/auth_session.dart` | Profile, read-only email/role, team details | Profile save updates same owner safely; password reset gate preserved | GET/PATCH `/users/me` direct profile + access token; metadata retained, storage rollback checked | Native focus/feedback | Account + session lifecycle tests | PARTIAL |
| SF-F01–F07: `pages/freelancer/FreelancerTasksPage.tsx`, `lib/freelancer-api.ts` | `freelancer_page.dart`, `freelancer_repository.dart`, shared file adapter | Assignments, actual known fees, source status tabs, brief/media/history | Start, cloud-link/file delivery, draft retention, reconciliation, own-task candidates | Exact my-tasks/start/submit-work/upload-content/history contracts tested | Native navigation/submission sheets; embedded playback approximate | `freelancer_test.dart`, `workstation_preview_test.dart` | PARTIAL; server ownership defect is a release blocker |
| SF-F08–F09: freelancer leave/settings | Account pages/repository | Blackout categories, history, contractor profile/security | Dates/category prefix, cancellation, OTP verification/reset with same-account adoption | Existing shared leave/profile/recovery endpoints | Native keyboard/focus; reduced-motion sheets | Account tests include full deterministic recovery journey | PARTIAL |
| SF-H01–H04: `pages/admin/SlackChatPage.tsx` | `workstation_hub_pages.dart`, hub repository | Channels/DMs/search, messages, attachments, emoji/local reactions/copy | Only server-returned threads; freelancer channel exclusion, send/duplicate/uncertain-write guards | Existing chat reads/messages/upload contracts; generic attachments ≤50 MiB | Native conversation routes and feedback | `workstation_hub_test.dart` | PARTIAL |
| SF-H05–H06: chat invalidation/groups | Same hub files | Foreground refresh states; role-gated group/member form | Poll/resume/dispose lifecycle; actual permitted group creation | 5-second foreground polling replaces React's WebSocket + 2-second polling; this is an explicit approximation | Background work stops; no animation-owned writes | Hub lifecycle/permission tests | PARTIAL; full realtime parity unverified |
| SF-P01–P05: `PublishingPage.tsx`, `components/ops/PublishingPanel.tsx` | Hub pages/repository publishing screens | Status/client filters, 100-row paging, detail/history, caption/timezone/DST form | Server `can_manage` gates, custom/calendar schedule, confirmations and role-limited actions | Existing jobs/detail/schedule/action/history/plan-calendar contracts; ambiguous writes stay blocked | Native sheets and visible state feedback | Hub/publishing tests; no real publishing performed | PARTIAL |
| SF-N01: `components/ui/NotificationMenu.tsx` | Notifications page/repository | Read/unread list, empty/error states | Mark read/all-read, delete/clear, allowlisted related destinations | Existing `/notifications` operations; no failed optimistic success | Native route/dialog; reduced-motion loading alternative | `workstation_notifications_test.dart` | PARTIAL; native/live unverified |
| All workspace roles/session/private data | Session lifecycle gate, core session/repository | Restoring, restricted, denied, recoverable failure states | Logout invalidates generation immediately; late results cannot adopt; preference cleanup is awaited/retryable | Same bearer/refresh owner; direct array responses preserved as `items`; multipart uses same injected client | No protected content before validation | Existing AS-01/AS-02 + new async cleanup tests | VERIFIED for executed deterministic scenarios; live/platform UNVERIFIED |

The register intentionally includes source-only/incomplete behavior: log-hours,
PTO balance and the unused `MemberAssetHandoffQAPage.tsx` mock do not have working
production contracts. Flutter does not fabricate those mutations, totals or
handoff successes. Lead/admin/sales/platform business dashboards are separate
products and remain at their existing destination boundaries.

## Security and integration constraints

1. **Existing backend defect:** freelancer start/upload handlers in `backend/app/routers/admin.py` load a task by ID without checking its assignment. Flutter limits candidates to the current session's server-returned assignments, but that does not fix server authorization. Backend remediation/verification is outside the allowed edit scope and required before release signoff.
2. Native API origin remains the existing supported HTTPS configuration in `auth_repository.dart`; no proxy secret, identity header, test credential or privileged key was added. Actual credentials/live compatibility were not supplied or verified.
3. Restricted mandatory-password-reset sessions cannot enter either workspace. No admin/lead privilege or unsupported React role alias is inferred locally.
4. Authenticated writes are never automatically replayed after ambiguous completion. Per-session mutation journals/read candidates and UI generations reject stale results. New-task create/start handles partial success explicitly.
5. HTTPS public/media URLs resolve against the configured API origin when relative. App bearer tokens are not attached to external media viewers. HTTPS-only link opening/submission is a documented security adaptation from permissive web strings.
6. Flutter's authenticated session/storage implementation remains the only credential owner. Profile token updates preserve account identity and existing metadata; cache cleanup failures remain visible at the stable sign-out boundary with Retry.
7. Development entrypoints have debug guards, explicit banners, in-memory credential/appearance/account preferences and a fixture transport that refuses live hosts. Production `main.dart` does not import the fixture transport or preview entrypoints.

## Motion and accessibility

- Source timing/trigger inventory is in `SF_WORKSTATION_INVENTORY.md`; native route/date-picker/media mechanics are platform adaptations, not pixel/timing equivalence claims.
- Press feedback uses source mobile scale feedback with a bounded 150 ms transition; cancellation/app pause restores the visual state, and reduced motion keeps scale at one with zero duration.
- Existing dashboard entrance does not restart for filtering/theme changes. Sheets, dialogs and progress retain readable information with reduced motion.
- Layout tests include 280 px phones, typical phones, landscape/tablet, both themes, 200% text and keyboard insets as scoped by each test. Screenshots prove only the captured browser viewport/state. TalkBack/VoiceOver, Android gesture behavior, iOS rendering and profile-mode frame timings remain unverified.

## Verification log

Final executed commands/results are recorded in `.dart_tool/sf-final-analyze.log`,
`.dart_tool/sf-final-tests.log` and `.dart_tool/sf-android-build.log`. These local
build logs are ignored artifacts, not source evidence for successful live APIs.
Final executed results (2026-11-10):

- `dart format lib test`: completed; final format check reported no further changes.
- `flutter analyze --no-pub`: **No issues found**.
- `flutter test --no-pub --reporter expanded`: **192 tests passed** (complete suite, including the existing authentication/session regressions).
- `flutter build apk --debug --no-pub`: **succeeded** after final notification/feedback integration; `build/app/outputs/flutter-apk/app-debug.apk` is the normal authenticated application, not the fixture entrypoint.
- `adb devices`: no connected targets. Android runtime/picker/Keystore checks are **BLOCKED**, not passed.

Rendered Flutter fixture evidence: `build/sf-home.png`, `build/sf-task-board.png`, `build/sf-freelancer.png`
(393×852 browser viewport). Protected React live comparison is blocked by the
unavailable authenticated reference environment. `emulator-5554` was disconnected
at the last check; no emulator was wiped, no app uninstalled and no user data cleared.
iOS cannot be compiled or executed with the available Windows tooling.

## Changed files in this assignment

Under `frontend/app_flutter`:

- `android/app/src/main/kotlin/com/example/app_flutter/MainActivity.kt`; `ios/Runner/AppDelegate.swift`: native document selection, bounded cache copies/cleanup and OS media preview.
- `lib/src/core/auth_repository.dart`, `auth_session.dart`: array/multipart transport, safe public media resolution, profile adoption and awaited/retryable private-preference cleanup.
- `lib/src/features/auth/session_lifecycle_gate.dart`: protected staff/freelancer navigation with current profile updates.
- `lib/src/features/workstation/workstation_data.dart`, `workstation_page.dart`: source task buckets/metadata and live feature navigation, quick replies, feedback/preferences.
- New workstation files: `workstation_task_repository.dart`, `workstation_task_page.dart`, `workstation_account_repository.dart`, `workstation_account_pages.dart`, `workstation_meetings_page.dart`, `freelancer_repository.dart`, `freelancer_page.dart`, `workstation_hub_repository.dart`, `workstation_hub_pages.dart`, `workstation_notifications_repository.dart`, `workstation_notifications_page.dart`, `workstation_files.dart`, `workstation_motion.dart`, `workstation_preview_fixtures.dart`.
- `lib/workstation_journey_preview.dart`: separate debug fixture entrypoint; existing `workstation_preview.dart` remains available.
- Updated tests: `test/auth_contract_test.dart`, `session_lifecycle_test.dart`, `workstation_test.dart`.
- New tests: `test/freelancer_test.dart`, `workstation_account_test.dart`, `workstation_meetings_test.dart`, `workstation_hub_test.dart`, `workstation_notifications_test.dart`, `workstation_task_test.dart`, `workstation_feedback_test.dart`, `workstation_motion_test.dart`, `workstation_preview_test.dart`.
- This ledger and `SF_WORKSTATION_INVENTORY.md`; the existing migration matrix receives a scoped handoff entry.

Pre-existing landing/authentication/dashboard work, generated plugin files and
unrelated changes (including the separate Client Portal project) were preserved.
No React/backend files, dependencies, folder locations or release configuration
were changed. Nothing was committed, pushed or published.

## Run and next verification

From `D:/creo-main/CREO-APP/frontend/app_flutter`:

```powershell
flutter run -d emulator-5554
# Authenticated app: real editor/designer/freelancer session required.

flutter run -d emulator-5554 -t lib/workstation_journey_preview.dart
# Clearly labelled, isolated sample staff journey.

flutter run -d emulator-5554 -t lib/workstation_journey_preview.dart --dart-define=PREVIEW_ROLE=freelancer
```

The isolated browser preview is served locally at `http://127.0.0.1:5178/`;
`?role=freelancer` selects its fixture freelancer workspace. This URL role selector
exists only in the debug fixture entrypoint and cannot select a live account.

Before release: repair/verify backend freelancer ownership, exercise native file
selection/cancel/large-file handling, real role-scoped API journeys and sign-out
on Android; run iOS compilation/device/VoiceOver checks; compare protected React
and Flutter frames/flows; profile representative scroll/upload/chat scenarios.
Do not infer release readiness from this implementation or its unit test count.
