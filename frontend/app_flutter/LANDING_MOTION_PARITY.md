# Landing motion migration verification

Scope: the actual React `/` route in `frontend/src/app/App.tsx` renders `frontend/src/pages/public/HomePage.tsx` on all viewport sizes. The separate `MobileLandingPage.tsx` is not routed and is not the animation reference. Paths below are relative to the project root unless prefixed with this app's `lib/` or `test/`.

## Source inventory and Flutter mapping

| ID | React evidence and trigger | Flutter mapping | Status and limits |
|---|---|---|---|
| LM01 | `HomePage.tsx` IntroMark/HomeContent: 460svh sticky hero, dot scale `170^ramp(p,0,.12)`, glyph fade 0–.045, overlay fade .12–.165; reversible scroll | `landing_motion.dart`: `LandingHeroFrame`, `LandingHeroDelegate`, `LandingHeroPainter`; native scroll controls progress, no timed mount stagger | Implemented ranges; custom-painted visual approximation. |
| LM02 | `components/stage3d/scenes.ts`: device appearance .1–.32, turn .12–.58, lid .34–.58, dive .6–.82, screen dim .76–.85 | Native Canvas laptop/phones/chrome mark/stars and amber-to-dark stage | Approximate. No Three.js lighting, reflection maps, depth or exact meshes. Screen/photo detail differs. |
| LM03 | `ScrollFlipText.tsx`: character X rotation -100°→0, y .42em→0, opacity finishes at70% of each interval; hero .8–.95 | `LandingFlipText`; per-character transforms, word wrapping, consolidated heading semantics | Implemented formula; typography uses existing Flutter font fallback because Inter is not bundled. |
| LM04 | `components/motion/index.tsx` Reveal: once at88% viewport, 28px up/fade,850ms cubic(.16,1,.3,1) | `LandingReveal` + scroll measurement/controller; state retained when scrolling away/back | Deterministic widget coverage. Reduced motion immediate. |
| LM05 | `HomePage.tsx` pod: select by click/hover/focus, color300ms, image600ms fade/1.15→1; description350ms wait/±12px | Existing pod selector updated; exact source image URLs; `LandingRoleDescription` latest-selection-wins transition | Implemented; network images have explicit unavailable fallback. Hover/focus plus touch selection. |
| LM06 | `scenes.ts`: blocks/coins assembly/burst, mailbox door/flag, megaphone turn/pulse, narrow footer device | `LandingScene` custom-painted scroll props | Approximate geometry/lighting; desktop-only bubble omitted on phones as in source. Time-based bob/pulse not reproduced exactly. |
| LM07 | `PortalDemo.tsx`: three local asset approve/change/undo states, progress600ms, statuses220ms, card500ms border; viewport mask1.3s/scale1.06 | `LandingPortalDemo`, `LandingReveal(mask:true)` | Local demo implemented, explicitly marked local. No server mutation. Photo URLs reused from source; shader/beam/hover spring are not equivalent. |
| LM08 | `HomePage.tsx`: first FAQ open; one open at a time, plus45°/350ms, height+fade450ms expo | Existing FAQ control with updated timing/reduced motion | Implemented animation timings; platform screen-reader verification remains outstanding. |
| LM09 | `StagePieces.tsx` pressed button, cancellation/release; `SmoothScroll.tsx` programmatic1.4s, native touch momentum | `LandingPressFeedback`; source-backed pressed scale, pointer cancel/release; native scrolling and1.4s anchor navigation | Native adaptation; no Lenis dependency. |
| LM10 | `PublicLayout.tsx`, `IntroLoader.tsx`, `Navbar.tsx`: shared intro/route curtain, mobile menu stagger/hide, page transition | Existing Flutter navigation boundary retained | Missing shared intro/curtain/mobile-menu motion. Existing sign-in/signup routes and back stack retained; no fake destinations added. |
| LM11 | `DistortImage.tsx`: pointer shader only on fine-hover non-reduced-motion devices | Static source image on touch | Source-supported touch behavior; desktop pointer shader missing. |
| LM12 | `StagePieces.tsx` sample CTA reports success only after actual `/api/v1/public/sample` POST | Existing Flutter form inputs retained; unsupported fabricated success replaced with explicit request-not-sent notice | Backend sample request remains missing; no fabricated successful response. |

## Changed application files

- `lib/src/features/landing/landing_page.dart`: existing landing integration, source-supported sections and anchor navigation, responsive layouts, selector/FAQ timing; removed unrelated ambient orb loop and hero mount stagger.
- `lib/src/features/landing/landing_motion.dart`: scroll progress, text flips, viewport reveals, native stage painters and touch feedback.
- `lib/src/features/landing/landing_portal_demo.dart`: source image rendering, local portal interactions and interruptible pod description.
- `test/landing_motion_test.dart`: focused progress, lifecycle, interactions, navigation and responsive/reduced-motion regression coverage.
- `LANDING_MOTION_PARITY.md`: this inventory and verification record.

No React, backend, authentication/session implementation, dependencies or application configuration are changed by this slice. Existing theme retained. Existing Flutter pod/plan marketing copy still differs from routed React copy in places; this motion slice does not establish content parity.

## Verification boundaries

### Delivery illustration and format-selector polish

User-requested visual refinement of the existing “Delivered every week” mailbox
and formats section: `landing_motion.dart` adds an ivory shaded shell, recessed
arched opening, hinges/rivets, a projected door and handle, a raised flag,
layered folded envelopes, and a contact shadow. Motion remains scrubbed by scroll
and reverses with it. The existing door range .15–.7 remains; individual envelopes
reveal progressively through .78. Reduced motion uses the existing static pose.
This is an enhanced native illustration, not exact React Three.js geometry.

`landing_deliverables.dart` preserves all four category names and the existing
titles/descriptions while replacing the plain row with a clearly labelled
illustrative preview. Categories wrap, have minimum touch targets and native
selected semantics, and retain the LandingPage-owned selection. Category changes
use a 240ms fade/short slide, skipped for reduced motion. Preview artwork is
decorative and not a playable video/private asset. The previous inactive chevron
is removed; existing work/portal actions and unavailable-destination feedback are
unchanged. No API, auth/session, package or application configuration changes.

`test/delivery_section_test.dart`: 8 tests cover rapid/return selection, retained
copy, narrow 280px layouts at 100%/200% text, both themes, mailbox forward/back
scrolling, reduced motion and no perpetual ticker. Full suite **117 passed**;
analysis clean; formatting applied. Android API36 debug build/run and actual
category switching were checked at 393×852 logical pixels. Captures include
`build/delivery-mailbox-light.png`, `build/delivery-preview-dark.png`, and
`build/delivery-preview-light.png`. iOS, native screen readers and profile-mode
performance remain unverified; full animation parity is not claimed.

Flutter's Android installer encountered insufficient emulator storage and
automatically uninstalled/reinstalled the previous debug app before succeeding.
Emulator-local preferences/session data may have reset; backend data and account
records were not changed. Original emulator display settings were restored.

### Parent-constrained text and widget sizing

The landing viewport now comes from its SafeArea parent's `LayoutBuilder`, not
the full `MediaQuery` window. Hero and section heading base sizes respond to the
available local width while preserving system text scaling and readable minimum
sizes. Full text wraps; it is not silently truncated or globally scaled down.
The sample CTA uses a minimum height and vertical padding instead of a fixed
50-pixel box, allowing enlarged labels to determine button height.

`test/parent_constraints_test.dart` adds eight checks with a 1024×900 window
containing smaller 280×520 and 480×300 parents. Landing tests verify actual hero
height, scrolling/layout and label containment at 100%/200% text. Sign-in tests
exercise both themes at 200%, including actual submit-button taps and long
server-error feedback through fake transport. No live credentials were submitted.
Full suite: **109 passed**; `flutter analyze --no-pub`: **no issues**.

Fresh native rendering is unverified for this refinement: the Android rebuild
requested NDK27 installation and was stopped, while attaching to the existing
debug app failed with a missing DevFS cache directory. No SDK/configuration
repair or backend/application-flow change is part of this layout slice.

### Appearance and bounded UI refinement

React evidence: `frontend/index.html` and `frontend/src/lib/theme.tsx` default to
dark and persist a binary light/dark choice; `components/ui/ThemeToggle.tsx`
provides the switch on landing/auth. Light tokens come from
`styles/brand-theme.css:70–116`: ivory #F5EEE3, raised #FBF7F0, espresso #2B1E15,
muted #6E5F50, bronze #8A5A2B. `styles/stage-tones.css:30–40` deliberately keeps
the cinematic hero dark in both themes.

Flutter now uses `CreoPalette` ThemeExtension and contextual landing/auth colors,
with source-backed fixed hero, laptop/phone material, amber brand panel and
Google-mark colors. `app_appearance.dart` owns only device appearance, defaults
dark and saves `creo_theme_v1` through the already installed secure-storage adapter.
Read failures retain the default; save failures retain the selected in-memory
mode with actionable feedback. Writes serialize and late preference reads cannot
override a new selection. Session records, token ownership and logout behavior
are unchanged. Startup bounds preference reads to avoid blocking on broken storage.

Existing landing, sign-in/signup and session feedback surfaces expose a 48px
accessible mode control. Theme changes retain Navigator identity, form input,
focus and scroll state; the session navigation epoch remains its existing owner.
OS reduced motion skips the theme transition. Session-gate controls use a semantic
label without requiring a Navigator overlay before authentication is resolved.
The compact header has intentional branding/theme and action rows, visible ruled
form fields, adaptive system bars and consistent selected/error/status colors.
No new business screen, dependency or backend/React change is included.

`test/appearance_test.dart` adds 9 checks for saved/read-failed preference,
ordered writes/late-read rejection, save failure, measured color contrast,
preserved sign-in credentials/Navigator/session owner, both modes and 200% text
at 320×740 and 852×393. Full suite: **101 passed**; analysis: **no issues**.
The existing startup/logout/retry/session checks also pass. This proves the
bounded Flutter behavior, not completion of signup/OAuth/business journeys.

Android API36 debug screenshots at 393×852 logical pixels include
`build/theme-dark-landing.png`, `build/theme-light-landing.png`,
`build/theme-light-pricing.png` and `build/theme-light-signin.png`. Appearance was
changed through the real controls, without credentials or production mutations.
An Android force-stop/relaunch restored the saved light preference; the observed
restart frame is `build/theme-restored-light.png`. A dark sign-in comparison is
`build/theme-dark-signin.png`. The original emulator size/density were restored
after these checks.
Light/dark iOS rendering, native screen-reader operation and profile performance
remain unverified. Full WebGL/feature parity is not claimed.

### Requested readability and laptop refinement

The subsequent user request authorizes larger typography and richer laptop detail
beyond the initial native approximation. Landing captions now use at least 14
logical pixels, supporting copy generally 16–18, and auth labels increase from 10
to 14 with less tracking. Auth secondary controls increase from 11–13 to 14–15;
shared control labels use 16. System text scaling stays enabled. Auth field label
and hint rows wrap rather than forcing enlarged text into one line.

The scroll-driven laptop adds a shaded metal bezel/deck, hinge caps, camera,
speaker grilles, tapered highlighted keycaps, spacebar, trackpad and chassis lip.
The screen includes a richer illustrative portal with sidebar, batch progress,
review cards and status labels, plus a subtle lid-dependent reflection. The dive
centres on the display and dims it over the existing .76–.85 progress range before
the headline. Existing opening/dive thresholds, reversal and reduced-motion
behavior remain; no packages or autonomous animation loops were added.

This remains a decorative Canvas approximation, with illustrative preview artwork;
it is not a live dashboard or exact React WebGL material/photography parity.
The full suite passes 92 tests, including painting closed/opening/open/dive frames
and existing 200% text, narrow/landscape, navigation and auth/session regressions.
Profile-mode frame timing and iOS verification remain outstanding.

Android debug visual checks for this refinement used the existing API36 emulator
at 393×852 logical pixels. Larger landing controls and sign-in labels were
inspected, along with opening and fully opened laptop frames; captured artifacts
are `build/readability-landing.png`, `build/readability-signin.png`,
`build/laptop-detail-opening.png` and `build/laptop-detail-dive.png`. The last
artifact shows the open/display approach, not proof of every dive frame. Final
analysis reports no issues. These visual checks do not establish frame-time
performance or full WebGL equivalence. The original emulator display settings
were restored after verification.

The focused tests cover hero forward/reverse and elapsed-time stability, once reveal, rapid role selection and reduced-motion interruption, portal approve/change/undo,320×740/393×852/852×393 at200% text with motion on/off, and named auth navigation with repeated taps/pop. Widget tests use deterministic HTTP behavior and do not prove remote image delivery or native rendering/performance.

Source captures: `build/react-landing-{initial,device,headline,principles,pod}.png`, Chrome mobile393×852 at scroll offsets0/1200/2700/3600/5100. Android captures/build execution are recorded in the final verification report; screenshot presence alone is not proof that an interaction passed.

No profile-mode frame-time measurements, lower-end physical Android test, VoiceOver/TalkBack run or iOS simulator/device run has established smoothness or full visual parity. WebGL effects remain approximate; required shared effects remain missing as listed above. No full-parity claim is made.

## Executed verification — 2026-11-06

- `dart format --output=none --set-exit-if-changed lib/src/features/landing test/landing_motion_test.dart`: four files checked, zero changes, exit0.
- `flutter analyze --no-pub`: no issues found, exit0. Log: `.dart_tool/landing-analyze.log`.
- `flutter test --no-pub --reporter expanded`: **90 tests passed**, including the74 existing auth/session tests and16 landing tests. No exception or missed-tap warning in the final log: `.dart_tool/landing-full-test.log`.
- Landing regressions additionally check actual repeated FAQ toggles with motion enabled/disabled and Pricing destination headings below the measured wrapping header at100%/200% text. Reduced motion bypasses size interpolation entirely; initial dive-cue bounds are checked at all three responsive viewports. Navigation anchor offsets use measured header height rather than a fixed assumption.
- Coordinator executed `flutter run --no-pub -d emulator-5554` and Android screenshot/swipe/tap checks on the existing Android16/API36 emulator, debug mode,393×852 logical viewport (786×1704 pixels/density320). Initial composition, device/opening and headline scroll states, final Pricing anchor visibility, sign-in entry and back navigation were inspected. No credentials were entered or live authentication mutation performed. Original emulator display settings were restored after capture.
- Native artifacts: `build/flutter-landing-initial.png`, `build/flutter-landing-device.png`, `build/flutter-landing-device-open.png`, `build/flutter-landing-scroll.png`, `build/flutter-landing-pricing.png`, `build/flutter-landing-signin.png`. Source captures above support comparison; the native Canvas stage remains visibly approximate.
- Android build succeeded while reporting the existing NDK26-versus-plugin27 version warning; no configuration or package change was made. Debug logs included skipped startup frames, so this run provides **no frame-budget/performance sign-off**. Profile-mode sustained scrolling and lower-end devices remain unverified, as do native reduced-motion/landscape/TalkBack and iOS cases.
- Independent bounded design evaluation was performed; this does not elevate missing/shared effects or approximate WebGL rendering to full parity.

## Postbox and laptop image refinement — verified 2026-11-09

The user-requested refinement replaces the flat postbox drawing with the bounded
perspective mesh in `lib/src/features/landing/landing_mailbox_3d.dart`. Its arched
extruded shell, recessed opening, hinged door and handle, side flag, paper
thickness, envelope folds and contact shadow share projected 3D coordinates and
depth sorting. Scroll drives the pose deterministically and reversibly; no
elapsed-time animation loop was introduced. Staging follows React
`frontend/src/components/stage3d/scenes.ts` and `models.ts`: flag movement precedes
door opening and envelope release. This is a Canvas approximation of the React
WebGL scene, not full material/rendering parity.

`lib/src/features/landing/landing_motion.dart` now paints three locally bundled
images inside the opening laptop display. `assets/landing/SOURCES.md` traces
them to the existing React portfolio assets. Their photographic provenance is
unconfirmed, and they are decorative previews rather than live customer data.
`pubspec.yaml` registers the assets without adding packages. Image decoding is
bounded to 512 pixels on both dimensions, reused across scroll updates, and
released safely on replacement/disposal. Failed loads retain the illustrative
fallback. Reduced motion skips starting decorative photo decoding.

Executed verification:

- `dart format --output=none --set-exit-if-changed` on the two affected Dart
  implementation files and `test/landing_realism_test.dart`: zero changes.
- `flutter analyze --no-pub`: no issues found.
- `flutter test --no-pub --reporter expanded`: **123 tests passed**, including
  six new checks for source staging, both-theme mesh reversal, image reuse,
  late-response/disposal safety, decode failure, reduced motion and actual
  bundled-image resolution/size limits. Existing auth/session, navigation,
  parent sizing and 200% text tests remain passing.
- Generated and visually inspected `build/mailbox-perspective-preview.png` and
  `build/laptop-pictures-preview.png`. These are widget-rendered geometry/image
  previews; test fallback typography and the debug banner are not native design
  evidence. They show the new mesh and the three loaded pictures.
- `flutter build apk --debug --no-pub`: succeeded; Gradle completed in 138.6
  seconds and produced `build/app/outputs/flutter-apk/app-debug.apk`. This
  verification built the APK without installing it or clearing device data.

No React/backend or authentication behavior was changed for this refinement.
Native interaction verification of this latest mesh/image revision, iOS,
TalkBack/VoiceOver and profile-mode frame timings remain unverified. Earlier
Android screenshots document earlier revisions and do not establish those
checks for this revision. Full parity and measured smoothness are not claimed.
