# Staff and Freelancer source inventory

Source baseline: preserved React checkout `D:/creo-main/creo-main/frontend/src`;
current server contracts `D:/creo-main/CREO-APP/backend`. Flutter destination is
`D:/creo-main/CREO-APP/frontend/app_flutter`. Source inspection establishes behavior
and gaps; it does not establish live API, Android/iOS or animation equivalence.
Existing feature inventory, parity matrix, backend map, roadmap and authentication
blueprint in the preserved checkout's `docs` were reused.

## Route and role boundary

React `app/App.tsx:1012`–1055 maps workstation/member overview, tasks, schedule,
settings, chat, freelancer tasks/leave/settings. Handoff aliases redirect to tasks;
publishing aliases redirect to `/admin/publishing` (line 956). `/slack` is a
role-aware redirect, including freelancer direct conversations.

Backend `app/models/enums.py:22` recognizes editor, designer, team_lead, admin,
super_admin and freelancer among the wider application roles. `app/core/rbac.py`
defines StaffActor, FreelancerActor, FreelancerOrStaffActor, LeaveApplicantActor.
React aliases `video_editor`, `graphic_designer`, `team_member`, `lead`, `freelance`
are not independent authorization grants. Lead/admin-specific management homes
remain separate from the member workstation; shared features must still honor
actual role and resource permissions.

## Feature and interaction register

All React paths below are relative to `frontend/src`; server paths are relative
to `backend/app`. Status of implementation/verification belongs in the final
parity ledger, not inferred from this source register.

| ID | Confirmed feature / interaction | React evidence | Contract / rule |
|---|---|---|---|
| SF-S01 | Overview load, retry, no-data, account header, logout | `pages/admin/MemberOverviewPage.tsx:61`; `components/workstation/MemberMobileDashboard.tsx`; `components/admin/AdminTopHeader.tsx` | GET `/api/v1/admin/pod-dashboard`, direct object; existing auth/session owner |
| SF-S02 | Active and due-today/overdue counts, due ordering | `MemberOverviewPage.tsx:74`–130 | Derived returned tasks, not invented totals |
| SF-S03 | Personal/pod and active/archived scopes | `MemberOverviewPage.tsx:130`–151 | Creative-role ownership fallback IDs, assignee ID/email/name |
| SF-S04 | Feedback notes, team peers, task targeting | `MemberOverviewPage.tsx:223`–280; `lib/creative-roles.ts` | Returned QA/rejection feedback; selected task ID navigates into board |
| SF-S05 | Media inspection and file links | `MemberOverviewPage.tsx:119`; `components/ops/DeliverableMedia.tsx` | Actual uploaded media only; no fake cut URL |
| SF-S06 | Meeting platform choice, custom URLs/code, copy, save/reset | `MemberOverviewPage.tsx:185`–218, 286–347 | Browser-local preferences; safe mobile account-scoped persistence needed |
| SF-S07 | Dashboard upload task selection, notes and progress | `MemberOverviewPage.tsx:411`–489; `lib/deliverables-api.ts:263` | Same production upload workflow as board |
| SF-S08 | Task board four stages and targeted task scroll | `pages/admin/MemberTaskBoardPage.tsx:161`–224; `components/workstation/MemberMobileTaskBoard.tsx` | backlog→Assigned; in_production→Production; internal_qa→QA; client_review/ready_to_publish/completed→Review |
| SF-S09 | Board search, client filter, urgency and due sort | `MemberTaskBoardPage.tsx:208`, 355–400 | Search title/client/format; high priority near SLA, negative hours or revision |
| SF-S10 | Own assigned plus role-eligible unassigned board tasks | `lib/creative-roles.ts`; `MemberTaskBoardPage.tsx:184` | Editor reel/story/shoot_day; designer static_post/carousel; assigned-to-other excluded from personal board |
| SF-S11 | Start/claim queued task | `lib/deliverables-api.ts:212`; `MemberMobileTaskBoard.tsx:431` | POST `/api/v1/deliverables/tasks/{id}/start`; server authorization and assignment remain authoritative |
| SF-S12 | New-task form and optional start-now | `MemberTaskBoardPage.tsx:286`–352; `lib/deliverables-api.ts:333` | POST `/api/v1/tasks`; client_id, deliverable_type, title, brief?, due_date:null or date, raw_footage_url?, target_duration?, audio_notes?, hook?, reference_url?; optional separate start; do not replay ambiguous writes |
| SF-S13 | Production brief, footage/reference, hook/audio/format guidance | `MemberTaskBoardPage.tsx`; `MemberMobileTaskBoard.tsx:312` | Actual blueprint and returned task fields, not project placeholders |
| SF-S14 | QA/client feedback text and voice note | `MemberTaskBoardPage.tsx:106`–136; `components/portal/VoicePlayer.tsx` | qa_rejected vs revision_requested; actual voice_note_url/duration |
| SF-S15 | File choice, validation, previews, progress, errors | `lib/deliverables-api.ts:162`–204 | MP4/MOV/PNG/JPEG/WEBP/GIF; image10MiB/video500MiB; nonempty and video≥1KiB |
| SF-S16 | Upload intent, direct storage upload, confirmation, fallback | `lib/deliverables-api.ts:263`–315 | POST `/deliverables/tasks/{id}/upload-intent` {mime_type,file_size_bytes}; presigned PUT no app bearer; POST `/submit` {storage_key,mime_type,file_size_bytes,notes:null}; multipart POST `/upload` fallback |
| SF-S17 | Self-QA checklist notes and revision re-upload | `MemberTaskBoardPage.tsx:64`, 262–282 | Five optional checks summarized into notes; do not require all checked or approve own QA |
| SF-S18 | Leave history and request form | `pages/admin/MemberSchedulePTOPage.tsx:17`–29 | GET/POST `/api/v1/admin/leave`; dates yyyy-MM-dd, trimmed reason; display is_self only |
| SF-S19 | Cancel leave and upcoming assignments | `MemberSchedulePTOPage.tsx:29`–60 | DELETE `/admin/leave/{id}` when can_cancel; backend enforces own pending request; upcoming own tasks exclude completed/ready_to_publish |
| SF-S20 | Profile read/edit and readonly identity | `pages/admin/MemberSettingsPage.tsx:43`–108 | GET/PATCH `/api/v1/users/me` {full_name,phone}; direct returned profile; not SessionResponse; no independent token adoption |
| SF-S21 | Pod/team details and meeting link in settings | `MemberSettingsPage.tsx`; `lib/ops-api.ts:520` | Existing dashboard contract; no new settings endpoint |
| SF-F01 | Assigned freelancer tasks with briefs/links/media | `pages/freelancer/FreelancerTasksPage.tsx`; `lib/freelancer-api.ts:162` | GET `/api/v1/admin/freelancer/my-tasks`; direct list; normalize blueprint and latest deliverable |
| SF-F02 | Pending/review/revision/completed tabs and counts | `FreelancerTasksPage.tsx:62`–97 | Match normalized status sets; source does not require separate freelancer dashboard |
| SF-F03 | Financial summary and milestone information | `FreelancerTasksPage.tsx:99`–140 | React defaults missing fee to4500 and calls completed "Paid" without payment evidence; mobile must distinguish reported fees from verified payment |
| SF-F04 | Start working | `FreelancerTasksPage.tsx:142`; `lib/freelancer-api.ts:204` | PATCH `/api/v1/admin/freelancer/tasks/{id}/start-work` |
| SF-F05 | File submission / re-upload / revision | `FreelancerTasksPage.tsx:155`–184; `lib/freelancer-api.ts:212` | Multipart POST `/admin/freelancer/tasks/{id}/upload-content` file + optional notes |
| SF-F06 | External link submission and notes | `FreelancerTasksPage.tsx:185`–220 | POST `/admin/freelancer/submit-work` {task_id,deliverable_id?,asset_url,submission_notes?}; keep draft after error |
| SF-F07 | Deliverable history and versions | `FreelancerTasksPage.tsx:555`; `components/portal/DeliverableHistoryModal.tsx` | GET `/api/v1/deliverables/{deliverableId}/history`; do not substitute task ID as deliverable ID when absent |
| SF-F08 | Time-off/blackout form, category, active periods/history | `pages/freelancer/FreelancerLeavePage.tsx` | Shared leave endpoints; reason `[Freelancer Blackout: ${category}] ${trimmedReason}` |
| SF-F09 | Contractor profile/settings and password-recovery entry | `pages/freelancer/FreelancerSettingsPage.tsx` | GET/PATCH `/users/me`; shared recovery modal; rate-card text is not writable backend rate configuration |
| SF-H01 | Role-scoped channels and direct contacts, search/filter | `pages/admin/SlackChatPage.tsx:264`,312,452 | GET `/chat/channels`, `/chat/contacts`; freelancer gets no channels, only server-permitted contacts |
| SF-H02 | Channel/direct message history and send | `SlackChatPage.tsx:891`,1128–1222 | GET `/chat/messages?channel=...` or other_user_id; POST `{channel,message}` or `{recipient_id,message,thread_type:'direct'}`; max10000 chars |
| SF-H03 | Attachment upload, media opening/download | `SlackChatPage.tsx:1143`; `routers/chat.py:465` | POST `/chat/upload` multipart file; generic files1B–50MiB; returned attachment_url/name/type/size included in message |
| SF-H04 | Emoji insertion, local reactions, copy | `SlackChatPage.tsx:1820`–1924 | Reactions are local React state; no reaction API found; never imply server synchronization |
| SF-H05 | Live invalidation, polling, reconnect/resume | `SlackChatPage.tsx:1035`–1104 | Web polls2s plus WebSocket `/chat/ws/{user.id}` subprotocols creo-chat + access token; foreground polling is an explicit mobile approximation, not full realtime parity |
| SF-H06 | Lead/admin custom group form and member picker | `SlackChatPage.tsx:825`–864; `routers/chat.py:364` | POST `/chat/groups` {name,desc,member_ids,is_pod_channel}; role gated; name2–60/description255 |
| SF-P01 | Publishing queue/status/client filters and100-row paging | `components/ops/PublishingPanel.tsx:731`; `pages/admin/PublishingPage.tsx` | GET `/publishing/jobs?offset=...&client_id?...&status?...`; GET `/admin/clients` for filter; foreground5s refresh |
| SF-P02 | Publishing detail, connection, caption, version, errors/permalink | `PublishingPanel.tsx:130`–438 | GET `/publishing/deliverables/{id}`; can_manage/can_approve come from server; staff cannot approve as client |
| SF-P03 | Custom/calendar schedule, timezone and DST fold | `PublishingPanel.tsx:190`–234,552–672; `routers/publishing.py:123` | POST `/deliverables/{id}/schedule`; {local_time?,timezone,fold:null|0|1,caption,media_type}; omit local_time to use calendar; Stories caption empty; max2200 |
| SF-P04 | Pause/resume/cancel/retry/reconcile/publish-now/use-calendar | `PublishingPanel.tsx:436`–551; `routers/publishing.py:287` | POST `/publishing/deliverables/{id}/action` {action}; post-now/pause lead+, retry/reconcile admin; confirmations; no live production mutations as tests |
| SF-P05 | Publishing history and calendar planning | `PublishingPanel.tsx:153`,674; `PublishingPage.tsx:15` | GET `/publishing/deliverables/{id}/history`; POST `/publishing/plan-calendar` lead/admin only with120s timeout |
| SF-N01 | Notification list/read/delete/clear and linked destination | `components/ui/NotificationMenu.tsx:52`–198 | GET `/notifications` {unread_count,items}; PATCH `/{id}/read`; DELETE `/{id}`; POST `/mark-all-read`; DELETE collection; do not treat failed optimistic mutation as confirmed success |

## Known source defects, incomplete behavior and security constraints

- `MemberAssetHandoffQAPage.tsx` is an unused static prototype; routed handoff
  redirects to the real task board. Its sample CSV, packages, playback time and
  success-only dispatch are not production contracts.
- Overview log-hours and handoff-confirm handlers show success-only toasts with
  no API/persistence. Weekly32.5/40h,14.5PTO and fixed leave dates are source
  placeholders. Missing backend support must remain explicit, not fabricated.
- Overview quick-reply hardcodes `pod-beta-team`; feedback dismissals and React
  chat caches use unscoped localStorage keys. Mobile uses actual returned scoped
  channels and must isolate/clear account-private data.
- Freelancer start-work/upload-content server handlers (`routers/admin.py`
  approximately7856/7874 in the current checkout) check role but retrieve task by
  ID without assignment ownership. Submit-work does verify assigned_to. The app
  must restrict actions to actual returned own tasks; UI restrictions do not fix
  this server defect. Backend remediation/verification remains a release concern.
- Freelancer file response may contain relative `/static/...` URLs; resolve only
  through the configured supported API origin. Never attach auth to arbitrary
  external presigned storage/media URLs.
- Freelancer earnings fallback4500 and "Approved & Paid" have no returned payment
  settlement evidence. Display actual known fee and approval separately.
- Staff leave backend validates against UTC date despite its `ist_today` variable
  name. Use the contract date basis consistently; overlap errors remain server-owned.
- Chat backend limits history to200 messages without a pagination contract. Do
  not invent cursor endpoints. Source WebSocket channel broadcast scoping must
  be reviewed server-side before making confidentiality claims.
- Account mandatory reset blocks every workspace; only auth/me/logout and reset
  endpoints remain accessible. Existing session owner controls refresh/logout,
  credential storage and late-response invalidation.

## Motion source contract and mobile mapping

- `styles/tokens.css:552`: fadeIn200ms ease-out; scaleUp250ms
  cubic-bezier(0.16,1,0.3,1), opacity0→1, scale.95→1, y8→0.
- Overview desktop metric cards: `MemberOverviewPage.tsx:556`–621, opacity/y10,
 300ms, delays50/100/150ms. Mobile dashboard is a separate component and should
 not acquire decorative desktop-only sequences accidentally.
- Mobile task board uses focus/border/color transitions, active scales.98/.95,
  and urgency pulse (`MemberMobileTaskBoard.tsx:245`,299,435); no distinct mobile
  Framer entrance is declared.
- Freelancer leave has button tap.96, hover1.02 and card hovery−2; sectionsy10 and
  status AnimatePresencey−8 (`FreelancerLeavePage.tsx:30`,114,175,207,329).
- Freelancer task submission/history overlays use fade/zoom classes; normal
  cards are not continuously animated. Reduced-motion should settle immediately,
  retain status/progress text and preserve taps/back navigation.
- Native route/sheet mechanics and bounded foreground polling are deliberate
  platform adaptations. Their timing/interaction equivalence and frame budgets
  require rendered Android evidence; compilation alone is insufficient.
