# Flutter publication checkpoint — 2026-11-15

This checkpoint preserves the current main mobile application, not a production-readiness certification.

Verification before publication:
- `flutter analyze --no-pub`: failed; 288 issues including portal test references to removed `portal_workspace_page.dart`.
- Full Flutter test suite: 269 passed, 9 failed (including four test-file load failures and session lifecycle UI failures).
- Android/iOS release builds and complete client onboarding were not verified for this checkpoint.

Follow-up: reconcile portal tests with the current portal architecture, resolve lifecycle layout/test failures, rerun analysis and tests, and verify client onboarding and portal access on device.
