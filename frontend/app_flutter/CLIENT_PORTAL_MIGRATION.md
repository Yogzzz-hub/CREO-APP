# Client portal integration

The follow-up production audit and current active routes are recorded in [CLIENT_PORTAL_READINESS.md](CLIENT_PORTAL_READINESS.md). The inventory below preserves the initial migration checkpoint. Several demonstration routes described below have since been replaced by backend-backed pages.

## Scope and source

Source is `../../client portal/lib`, relative to this Flutter application. Destination is `lib/src/features/portal`. All 20 source screen/sheet files, seven shared widgets and two models have destination counterparts. `test/client_portal_test.dart` verifies this file coverage. Existing copies were reused.

The source application is a UI prototype. Its shell seeds sample clients and deliverables. Billing, calendar approval, tickets, brand uploads, profile changes and media playback include local simulations. Preserving these screens does not establish live backend parity.

## Entry and ownership

`lib/src/features/auth/session_lifecycle_gate.dart` already routes validated `client` and `client_owner` sessions into `ClientPortalScreen`. Backend role support remains authoritative. The existing mandatory-password-reset gate runs first.

`client_portal_screen.dart` now retains shared appearance preferences and provides a portal-local navigation stack, themed detail pages and Android nested-back handling. A persistent notice identifies the source demonstration workflows on every portal route. The main application's authentication owner and configured API origin are reused. The standalone Dio client, separate application root, Riverpod root and independent credential owner are not activated.

## Feature coverage

| ID | Source under client portal/lib | Destination under lib/src/features/portal | Integration state |
| --- | --- | --- | --- |
| CP01 | screens/home/home_dashboard_screen.dart | same relative path | Live dashboard parsing, real quotas/counts/plan, empty defaults, refresh/error feedback. Source upcoming-agenda and pod presentation still use sample content |
| CP02 | screens/review/* | same relative paths | Live list with cursor traversal; approval and textual revision requests through AuthSession; media theater, history and voice controls retain source prototype behavior |
| CP03 | screens/calendar/* | same relative paths | Source calendar and hook-selection UI preserved; demonstration workflow |
| CP04 | screens/library/* | same relative paths | Source library UI preserved; sample assets and local actions |
| CP05 | screens/inbox/* | same relative paths | Source inbox/ticket thread UI preserved; simulated messages |
| CP06 | screens/billing/* | same relative paths | Plan, invoice, comparison, negotiation and pause sheets preserved; checkout/payment actions remain demonstrations |
| CP07 | screens/brand/* | same relative paths | Brand DNA editor/upload UI preserved; local changes |
| CP08 | screens/settings/* | same relative paths | Profile/integrations/security UI preserved; settings sign-out now calls the real session boundary; other actions remain demonstrations |
| CP09 | screens/home/creative_pod_detail_screen.dart | same relative path | Source team detail UI preserved; sample team/booking behavior |
| CP10 | screens/support/* | same relative paths | Source support UI preserved; demonstration ticket workflow |
| CP11 | widgets/*, core/theme/* | same relative paths | Shared Inter typography, amber brand, light/dark appearance, adaptive toolbar, entrance/press motion with reduced-motion handling |

## Confirmed API contracts

- `GET /api/v1/portal/dashboard` reads `active_plan`, `pending_deliverable_count`, `open_ticket_count`, `ai_summary_line`, singular quota keys and `assigned_team`. Evidence in `../../backend/app/routers/portal_dashboard.py`.
- `GET /api/v1/portal/deliverables` uses `items`, `has_more` and `cursor_id`. Empty results clear previous items. Onboarding/subscription responses remain server-controlled. Evidence in `../../backend/app/routers/deliverables.py`.
- `POST /api/v1/deliverables/{id}/approve` and `POST /api/v1/deliverables/{id}/request-changes` use the existing authenticated transport. Text revisions send `rejection_comment`. Source service previously sent `feedback`. No write retry is added.
- Media fields, revision limits and scheduled dates follow `../../backend/app/services/deliverable_workflow.py` serialization. Server errors retain existing review data. Failed/uncertain reviews require successful refresh before another shell submission.

## Verification

Focused test coverage includes source file coverage, backend dashboard parsing, missing-plan/zero-quota behavior, revision/media fields, cursor pagination, exact revision payload, clearing empty deliverables, failed-load feedback and a 393-by-852 phone shell render. Session gate regression tests exercise the client destination at 320-by-640, restore, resume, logout, restricted sessions and storage failures. Older assertions expecting an unavailable client workspace were updated to the existing portal destination. Continuous status animation uses bounded test frames.

- `dart format` completed for changed Dart files.
- `flutter test --no-pub` passed all 200 tests.
- `flutter analyze --no-pub` reported zero errors and 144 diagnostics. Three warnings are existing unnecessary type checks in the admin/BDE services. Remaining diagnostics include SDK deprecations and lint information. Static analysis still exits unsuccessfully with these diagnostics.

Changed implementation files are `client_api_service.dart`, `client_portal_screen.dart`, `models/dashboard_model.dart`, `models/deliverable_model.dart`, `screens/main_shell_screen.dart`, `screens/home/home_dashboard_screen.dart`, `widgets/creo_animations.dart` and `widgets/creo_top_header.dart` under the portal destination. Tests added or updated are `test/client_portal_test.dart`, `test/session_lifecycle_gate_test.dart` and `test/auth_screen_test.dart`.

Live authenticated client flows, Android device navigation, iOS, payment SDK, uploads, media playback, large-text layouts across all source screens and full screenshot parity remain unverified. Full production parity requires replacing the explicitly identified prototype workflows with backend-backed implementations and validating each journey.

## Run

From `D:\creo-main\CREO-APP\frontend\app_flutter`, run `flutter run -d emulator-5554`. Sign in with an existing authorized client account. The normal session gate opens the portal. No test identity or automatic login is embedded.
