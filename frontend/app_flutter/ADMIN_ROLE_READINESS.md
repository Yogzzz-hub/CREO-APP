# Admin mobile readiness ledger

Scope: active Flutter app `CREO-APP/frontend/app_flutter`. This ledger records the current source-backed admin behavior and limitations. It does not claim that all admin modules are complete.

## Wired to authenticated APIs

| Area | Mobile behavior | Server contract |
| --- | --- | --- |
| Profile | Loads `/api/v1/users/me`; edits full name and phone using the shared `AuthSession` profile update. | Authenticated profile endpoints. Role and email are read-only. |
| Roles and access | Displays the server role catalog and team, BDE, freelancer rosters. Creates only editor, designer, team lead, sales, and freelancer accounts through their specific admin endpoints. | `GET /api/v1/admin/teams`, `/bde`, `/freelancers`; `POST /admin/teams`, `/admin/bde/onboard`, `/admin/freelancers`. UI cannot assign privileged roles. |
| Agency notifications | Reads and updates email/WhatsApp flags. | `GET` and `POST /api/v1/admin/settings`. |
| Clients | Onboards a client through the admin endpoint and reloads the returned server UUID. Empty API results clear stale rows. | `POST /api/v1/admin/clients/onboard`, `GET /api/v1/admin/clients`. |
| Support | Loads tickets and messages, replies, and changes ticket status. | `/api/v1/admin/support/tickets` and its `/messages` and `/status` routes. |
| Leave | Lists, creates, approves, and rejects requests. | `/api/v1/admin/leave` routes. |
| Tasks | Creates general or freelancer tasks and moves tasks between supported server states; roster IDs are sent to the API. | `/api/v1/tasks`, `/api/v1/tasks/kanban`, `/api/v1/tasks/{id}/move`, `/api/v1/admin/freelancers/{id}/assign`. |
| Deliverables | Lists, approves, requests revisions, resumes, and withdraws with a reason. | `/api/v1/admin/deliverables`, status route, and `/api/v1/deliverables/{id}/withdraw`. |
| Money | Loads confirmed paid subscription/installment/add-on rows as read-only transaction records. Proposal create/update is server-backed and suppresses email delivery. | `GET /api/v1/admin/transactions`, `GET/POST /api/v1/admin/negotiations`, `PATCH /api/v1/admin/negotiations/{id}`. |
| Appearance | Uses the app's shared appearance state and persistence. | Existing app appearance service. |

Create calls guard duplicate in-flight and uncertain writes. After a timeout or server error, the form stays populated and the user is asked to refresh the relevant roster before retrying. Generated credentials are not shown, persisted, or logged by the UI; account creation asks the server to send them.

## Explicitly unavailable in this mobile surface

| Action | Current behavior / reason |
| --- | --- |
| Invoice creation | Not available here. `/api/v1/admin/transactions` is a read-only list of confirmed paid records; mobile no longer creates synthetic invoices. The invoice action explains the billing-service limitation. |
| Global plan edits | Blocked with an explanation. No server plan UUID/catalog and admin plan update contract is wired in this screen. |
| Plan/pod change for a client | Not yet wired. A plan update route exists but the mobile plan catalog has no server IDs; pod assignment has no confirmed compatible client endpoint in this scope. |
| Client payment toggles/provider selection | Must not be inferred locally. Payment state is server-derived; provider setup remains in web admin. Razorpay setup is intentionally excluded. |
| Proposal email | Creation sends `send_email: false`; only a server-side proposal record is created. |
| Draft-only creation and calendar publishing | Requires an uploaded deliverable/task and publishing service state. Draft/schedule-only forms report that no matching endpoint is available. |
| Chat channels/direct messages | Connected to the shared authenticated WorkstationHubPage; local-only admin chat removed. |
| Sales | Server-backed admin lead search/list/create and stage updates now use `/api/v1/bde/leads`. Legacy local-only sales UI was removed. Activity timeline/touchpoint editing is still incomplete in this admin surface. |
| Pod/workload/stand-up management | Pod creation, movement, balancing, stand-up notes, and workload reassignment are local-only in this screen; no matching verified admin write endpoint is connected. |
| Staff suspend/reactivate/remove | Local status flips/removal are disabled. Suspension endpoint needs server tenant-scope review; compatible removal/reactivation contracts remain unresolved. |
| Client brand DNA editing/offboarding | Offboarding now uses a loaded server UUID, explicit confirmation and POST `/api/v1/admin/clients/{id}/offboard`, then verifies the result and reloads clients. Brand DNA editing remains incomplete. No live offboarding was executed. |

## Verification

`flutter test test/admin_backend_test.dart` passes the focused account provisioning, ambiguous-write retry guard, and empty-list clearing tests. Run date: 2026-11-14. Focused analysis completes without errors; analyzer reports existing style/deprecation infos plus a context-across-async informational warning in profile UI. No live account mutation was performed by this implementation task.

CSV export now uses the native document-save channel with UTF-8 text/csv, explicit cancellation and error feedback; financial data is not copied to the clipboard. Admin service writes are bound to session generation as well as account ID. `admin_completion_test.dart` covers CSV cancellation, confirmed lead mutations, uncertain creation across reopening and client offboarding.

## Client subscription activation connection — 2026-11-14

The client detail payment toggle in `creo_admin/team.dart` previously changed `Client.paid` only in memory. It is replaced by `Manage client activation`, which opens `client_access_page.dart`. The page loads authoritative client detail from GET /api/v1/admin/clients/{client_id} and client-scoped plans from GET /api/v1/payments/plans?client_id={client_id}. It submits the selected server plan, activation method and notes to the existing POST /api/v1/admin/clients/{client_id}/bypass-payment endpoint only after confirmation.

The roster now reads client_id, real plan names and monthly_price. Refresh preserves Client object identity so already-open detail views receive updated subscription status. Payment-method toggles that only changed local state were removed from the activation controls. Admin and super_admin roles are checked before reads and writes, together with session generation/account checks. Backend authorization remains authoritative. Duplicate, malformed and uncertain activation responses never become optimistic success. Confirmed activations cannot be resubmitted through the same service.

The form explicitly explains that the backend creates a 30-day manual subscription, records the selected plan amount and sends a payment-approved email. Test access adds TEST ACCESS - NO PAYMENT RECEIVED to admin notes. Client onboarding remains server-controlled. After activation the client refreshes progress or signs in again and completes required brand/team/calendar setup. No live subscription was created and no personal account was activated while implementing or testing this connection.

Focused verification passed 19 admin/onboarding/portal tests. Logs are under build/client-activation-tests.log. Additional full-suite/build results are recorded after completion below. Static analysis reported no errors, two existing BDE warnings and informational notices. The source changes are inside frontend/app_flutter and consume the existing backend.

Final verification for the activation connection passed all 306 Flutter tests and the Android debug APK build. The deployed Render OpenAPI advertises the admin client roster/detail, bypass-payment, payment plans and onboarding status endpoints used by this flow. This confirms route availability, with live authenticated activation and end-to-end client progression still unverified.

### Subscription status after re-login

The roster now treats an explicit subscription_status as authoritative, with active/trialing indicating an active subscription and null/inactive statuses indicating no active subscription. Older responses without this field retain the prior stage fallback. A new regression verifies server activation followed by logout, clearing local roster state, fresh admin restoration and re-fetching the roster. Four additional cases reject stale onboarding progress for canceled, incomplete, past_due and null subscription status. All 16 focused admin tests passed. Targeted static analysis passed. Actual account activation and a physical-device reinstall remain unverified because no Android target was connected.
