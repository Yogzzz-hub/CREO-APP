# Member workstation — Android-first dashboard

Current handoff (2026-11-10): the implementation now extends this initial member
dashboard checkpoint with staff/freelancer workflows, account/leave/meetings,
chat, publishing and notifications. See [SF_WORKSTATION_PARITY.md](SF_WORKSTATION_PARITY.md)
and [SF_WORKSTATION_INVENTORY.md](SF_WORKSTATION_INVENTORY.md) for current mappings,
executed verification and remaining live/platform/security blockers. The table
and results below preserve the earlier dashboard-only baseline.

## Preserved initial checkpoint

Scope: member dashboard only, in the newly pulled `frontend/app_flutter` app.
The preserved pre-pull app, React source, backend and separate Admin/Client apps
are unchanged. No new packages, backend endpoints or permission roles are added.

## Evidence and implementation

React evidence is in the original checkout `D:/creo-main/creo-main`:

- `frontend/src/pages/admin/MemberOverviewPage.tsx`: dashboard loading/error,
  task ordering/scoping, personal/pod and active/archived filters, feedback,
  upload/meeting/quick-reply entry points.
- `frontend/src/components/workstation/MemberMobileDashboard.tsx`: mobile
  header, cards, quick actions, deliverables and feedback/team tabs.
- `frontend/src/components/workstation/WorkstationSidebar.tsx`: navigation.
- `frontend/src/lib/creative-roles.ts`: assignment fallbacks and backlog formats.
- `frontend/src/lib/ops-api.ts`: direct `GET /api/v1/admin/pod-dashboard` response.
- `backend/app/routers/admin.py:get_pod_dashboard`, and
  `backend/app/core/rbac.py:StaffActor`: authenticated, server-scoped staff access.

The new checkout has backend evidence at the same relative backend paths. The
current backend permits editor/designer/team-lead/admin/super-admin for this API;
React's `team_member`/video-role aliases are not confirmed backend enum values.
This slice automatically opens the member home only for `editor` and `designer`.
Other role homes stay at their existing explicit unavailable boundary. A required
password reset continues to block dashboard access.

| ID | React capability | Flutter mapping / status |
| --- | --- | --- |
| WS-01 | Mobile header, menu, notifications, account | Implemented; real returned notices, account sheet, existing theme toggle |
| WS-02 | Active counts and due tasks | Derived from returned assigned tasks; overdue/today labelled "Due by today" |
| WS-03 | Weekly hours, remaining PTO, next leave | **Partial**: React hardcodes 32.5/40h, 14.5 days and a fixed date. Flutter shows unavailable values; the dashboard API supplies none of these fields |
| WS-04 | Personal/pod scope, active/archived, due ordering | Implemented; IDs, assignee IDs, email/name fallbacks retained; archived uses React's completed group |
| WS-05 | Browse task queue | Read-only active tasks and eligible unassigned backlog; ownership/format rules retained. Claim/move operations remain missing |
| WS-06 | Deliverable inspection and uploaded media | Detail sheet and existing HTTPS media link via installed url_launcher; no fabricated file URL |
| WS-07 | Upload, versioning, QA handoff | **Missing**; entry explains mobile unavailability. No simulated upload/progress/success |
| WS-08 | Lead feedback and team tab | Returned feedback and pod members displayed; all feedback remains reachable; no fabricated online presence |
| WS-09 | Slack quick reply and chat | **Missing**; Workspace Hub entry explains unavailability. React hardcodes `pod-beta-team`, which is not a confirmed tenant-safe channel mapping for all users |
| WS-10 | Meetings | Existing Google Meet/Zoom join pages open through external launcher. Custom links/persistence and schedule remain missing; no fake countdown/active meeting |
| WS-11 | Schedule/PTO, Instagram, account settings | **Missing** destination screens; retained navigation entries explain unavailability. Basic signed-in account display exists |
| WS-12 | Session/refresh/logout | Existing session owner/transport reused; protected Navigator provides sheets/dialogs and is removed on logout/session invalidation |
| WS-13 | Refresh, timeout, denied, empty and malformed data | Typed response parsing, retry, shared refresh, retained data labelled stale after recoverable errors; access failures discard cached dashboard data |
| WS-14 | Entrance motion | Single 240ms ease-out fade, never restarted by filtering/theme updates. Reduced motion jumps to final state and disables sheet animation; no continuous decorative loops |

## Boundaries and files

- `lib/src/features/workstation/workstation_data.dart`: typed contract parsing,
  repository using `AuthSession.request`, sorting/scoping, lifecycle-safe loader.
- `lib/src/features/workstation/workstation_page.dart`: adaptive dashboard,
  accessible wrapping controls, scrollable drawer/sheets and platform back.
- `lib/src/features/auth/session_lifecycle_gate.dart`: authenticated editor/
  designer destination with a protected Navigator; other existing states retained.
- `lib/src/core/auth_session.dart`: marks only implemented member destinations
  as available. Existing refresh/adoption/storage/logout algorithms are unchanged.
- `lib/src/features/auth/auth_screen.dart`: avoids a null blocker in successful
  member sign-in status. Signup/OAuth/recovery journeys are unchanged.
- `lib/workstation_preview.dart`: explicitly labelled **debug-only** fixture
  renderer. Does not read/adopt credentials, call APIs, or write session storage.
  Appearance writes are in-memory. Production `lib/main.dart` does not import it.
- `test/workstation_test.dart`: contract, data/race, layout and session-boundary
  tests using deterministic fake transport/storage.

## Running

Normal app: `flutter run -d emulator-5554`. A validated editor/designer session
opens the real dashboard loader. Live credentials/backend are still required.

UI preview: `flutter run -d emulator-5554 -t lib/workstation_preview.dart`.
This deliberately uses sample data with a persistent "Not signed in" banner;
it does not establish live sign-in or API integration. Never use that entrypoint
for a production release. No protected dashboard route is exposed to signed-out
users in the normal application.

## Verification

Executed 2026-11-09:

- `dart format`: implementation and tests formatted. Final analyzer reports
  **no issues**.
- `flutter test --no-pub --reporter expanded`: **107 passed**. The 19 new
  workstation tests cover response parsing, assignment/backlog rules, exact
  session-authenticated GET contract, role/reset rejection, shared refresh,
  timeout/retry, forbidden-data clearing, logout during a pending read, disposed
  results, filters/detail sheets, authenticated navigation/logout, and layouts
  at 280x520 / 393x852 / 852x393 / 1280x900 with 200% text in both themes.
  The appearance control is included in the responsive test header. The old
  intent test now expects available destinations only for editor/designer;
  other role expectations remain blocked.
- Dark and light rendered Dart views were inspected in Chrome. The visible
  theme control was exercised and the sample task count remained intact.
  Artifacts: `build/workstation-dart-phone.png` and
  `build/workstation-dart-phone-light.png`. These are browser screenshots of
  the debug fixture entrypoint, not Android or production-data evidence.
- Both debug APK entrypoints build: authenticated app (`lib/main.dart`) and
  labelled UI preview (`lib/workstation_preview.dart`). Deliverable artifacts:
  `build/app/outputs/flutter-apk/workstation-app-debug.apk` and
  `build/app/outputs/flutter-apk/workstation-preview-debug.apk`.
- Existing Android 16/API36 emulator: `adb install -r` failed for insufficient
  internal storage. No uninstall, data clear or display override was performed.
- A separate task-owned Pixel 5/API36 emulator was created from an already
  installed image, with data stored on D. The preview installed and its Dart
  service started, but Android System UI became unresponsive during startup.
  The host had about 600 MiB free physical memory at the diagnostic check.
  This establishes neither working Android interaction nor performance. The
  temporary emulator was stopped and removed; the original target was preserved.

Live authenticated dashboard API compatibility, Android interaction/Keystore
behavior, physical-device frame timings, TalkBack and iOS remain unverified.
No full workstation parity or smoothness claim is made. No production account,
token, backend, React source or database was changed for this implementation.

## Requested interaction improvements — 2026-11-09

Applied Flutter UI Patterns, Flutter Mobile Design and Flutter Motion Engineering
to this dashboard only. These are requested mobile UX additions over the React
reference; the API contract, role boundary, session and task ownership/status
rules are unchanged. No new dependencies are used.

| ID | Interaction | Behavior and boundary |
| --- | --- | --- |
| WS-15 | Dashboard and queue search | Local, case-insensitive task/brand/format/status search; visible status names are searchable; live result count, clear action and a truthful no-match state. Searches the full supplied list, including rows not yet displayed |
| WS-16 | Sort and filters | Due date, brand A–Z, task A–Z; active-status and due-by-today filters combine with existing personal/pod and active/archived scopes. Undated tasks sort last; loaded lists are never mutated |
| WS-17 | Pins and Undo | Pin/unpin a deliverable for this visit; pinned-only filter and latest-action Undo. In-memory IDs only, cleared when this page/account/role changes. No server favourites, persistence or task-status mutation is claimed |
| WS-18 | Active card shortcut | Opens the personal active view, clears stale view filters and scrolls to the deliverables. 260ms ease-out scroll; immediate with reduced motion |
| WS-19 | Task queue exploration | Searchable/filterable/sortable sheet with 20-row display batches and Show more. Full-list search is independent of the displayed batch; detail sheet Back preserves the queue query |
| WS-20 | Explicit refresh | A visible Refresh action complements pull-to-refresh and uses the existing shared loader; searching/pinning/sorting does not issue API calls |
| WS-21 | Keyboard and motion | Close the keyboard before opening a sheet or using the dashboard shortcut. Drag dismisses search keyboard; sheets retain inset-safe scrolling. Brand wordmark scales as a single logo so 200% body text plus keyboard does not overflow the header. Pin feedback is a bounded 160ms transition, skipped with reduced motion; menu/sheet motion also respects that preference |

Files added: `lib/src/features/workstation/workstation_task_browser.dart` and
`test/workstation_interactions_test.dart`. The existing page and one prior
widget-test scroll target were updated. `workstation_task_browser.dart` contains
the pure view filter, shared search/sort controls and state-owned queue search.

Verification: final `flutter analyze --no-pub` reports **no issues**;
`flutter test --no-pub --reporter expanded` reports **116 passed**, including
nine interaction tests. Executed cases include rapid pin input/Undo, no extra
data fetch during searching, combined filters, source-list immutability,
search/sort preservation through a real theme change, search beyond the first
20 rows, queue/detail platform Back and the 280-wide, 200%-text keyboard case.
Existing session, permission, parent sizing and logout checks remain passing.

Android runtime/performance and live-backend limits above still apply. The
debug fixture preview is a separate entrypoint; these additions do not complete
upload, task claiming/status changes, Slack, PTO or settings integrations.

Both Android debug APKs were rebuilt from this interaction revision. The local
web preview was recompiled and reopened in a fresh task-owned Chrome session
after its previous renderer stalled. Inspected rendered artifacts include
`build/workstation-interactive-home.png` (archived/pod view with search, sort and
pin controls) and `build/workstation-interactive-controls.png` (task/feedback
area after scrolling). The images use the labelled debug fixtures. They do not
establish Android or live API behavior. No emulator reset or package installation
was performed during this interaction refinement.
