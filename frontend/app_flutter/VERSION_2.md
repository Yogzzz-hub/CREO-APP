# Version two: mobile-first entry and member navigation

The active application is `CREO-APP/frontend/app_flutter`, version `1.1.0+2`. React and backend source are unchanged.

## Preserved version one

Before version-two changes, the complete Flutter source/assets snapshot was saved to:

`D:/creo-main/backups/app_flutter-v1-20261114-115735.zip`

283 files were verified against SHA-256 hashes and ZIP integrity checks. The adjacent `.manifest.json` lists their hashes. Archive SHA-256: `84811d3b693f1422bd27087d15e131a3c21bd568b1d5b740fee9483cb0291ee8`.

Build caches, tool state, local credentials, signing keys and machine-specific configuration are excluded. Extract the archive into a separate directory to inspect/run version one without overwriting version two; install existing declared dependencies normally when restoring it. This is a source checkpoint, not a signed release or database backup.

## Entry logic and design

- Signed out: the Creo wordmark fades in with an eight-pixel rise over 900 ms, then opens sign-in. No landing page is mounted or exposed in the active app route map. Legacy landing source remains available for reference; the backup preserves its complete previous flow.
- Reduced motion: bypass the decorative movement and navigate immediately. Animation completion is guarded and cannot navigate twice after disposal.
- Saved session: the existing session gate validates credentials before showing the appropriate role workspace. Unavailable/expired/restricted sessions retain their existing retry, sign-in, mandatory-reset and onboarding rules. A splash does not bypass these checks or force a valid user to authenticate again.
- Signup, OTP, recovery and Google entry points remain within the existing authentication flow.

## Member workspace

Editor/designer accounts now enter `MemberWorkspaceShell` with Home, Tasks, Chat, Time off and Profile. Each tab mounts lazily and owns its own Navigator; switching retains its state/history. Detail routes stay inside the shell so the bottom bar remains available. Reselecting a tab returns it to its root. Back closes the active detail, then returns a non-Home tab to Home, then permits platform exit from Home. The binding observer handles the pre-existing session-gate navigator boundary.

The keyboard temporarily hides the bar to leave room for forms/composers. Existing scroll and form screens own keyboard insets. Home's former drawer is replaced by the tabs plus a More menu for Meetings, Instagram and sign-out. Notification-target task/channel IDs still open their original guarded destinations inside the shell. Logout continues through the shared session owner and clears protected navigation.

## Readability

Shared/admin/sales chip themes now explicitly pair warm selected surfaces with readable text and checkmarks. Filled-button text styles inherit their configured foreground rather than hardcoding page text color. Shared widgets derive a light palette correctly inside nested role themes. Enabled chip and filled-button label contrast is checked at 4.5:1 or better in rendered light/dark controls.

## Evidence

`test/v2_mobile_test.dart` covers cold login entry, reduced motion, effective rendered text contrast, retained member tab state, persistent detail navigation and Back behavior. The existing preview and workstation tests now exercise the bottom-tab workflow instead of the removed drawer. Rendered control captures are in ignored `build/v2-qa/`; they use bundled fonts and deterministic fixtures, not live-account evidence.

Final suite, analyzer, Android artifact and device results are reported with the delivery. Physical-device profiling and iOS execution are not established by widget tests or Android compilation. Existing backend/provider errors are not hidden by this UI update.

## Executed checks

- Full regression suite: 274 tests passed. Focused version-two tests: five passed, including rendered light/dark contrast and tab/detail/back behavior.
- Analyzer: no errors; the two existing BDE unnecessary-type-check warnings and informational diagnostics remain, so its exit status is nonzero.
- Android debug APK builds successfully with existing Kotlin/NDK warnings. Installation preserved the saved session; Android reported a launch timeout, and a subsequent screenshot confirmed the real login screen on emulator-5554. This observes the signed-out destination; live member-tab interaction is not claimed.
- Control and member-tab images were rendered using bundled fonts and inspected under `build/v2-qa/`. Native Android/iOS journey and physical-device performance coverage is not implied by fixture captures.

The final login wordmark is constrained to the available header width; the 320px/large-text/keyboard regression passes. After the last visual adjustment, all 16 authentication/version-two focused tests passed and the Android APK rebuilt successfully. The earlier full run passed 274 tests.

Final device delivery: install succeeded on emulator-5554; am start reported Status ok / COLD. A final screenshot confirmed the actual login screen with the white Creo wordmark and amber dot. The saved session was not cleared by the installation command.
