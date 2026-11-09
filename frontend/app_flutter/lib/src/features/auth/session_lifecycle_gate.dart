import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/auth_session.dart';
import '../../core/app_appearance.dart';

/// Authenticated content cannot mount before server validation. The signed-in
/// view is the existing unavailable-destination boundary, not a fake dashboard.
class SessionLifecycleGate extends StatefulWidget {
  const SessionLifecycleGate({
    super.key,
    required this.session,
    required this.child,
  });
  final AuthSession session;
  final Widget child;

  @override
  State<SessionLifecycleGate> createState() => _SessionLifecycleGateState();
}

class _SessionLifecycleGateState extends State<SessionLifecycleGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.session.phase == SessionPhase.uninitialized) {
        unawaited(widget.session.restore());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(widget.session.resume());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final session = widget.session;
      if (session.phase == SessionPhase.signedOut) return widget.child;
      final busy = [
        SessionPhase.uninitialized,
        SessionPhase.restoring,
        SessionPhase.clearing,
      ].contains(session.phase);
      final ready = session.phase == SessionPhase.authenticated;
      final clearing = session.phase == SessionPhase.clearing;
      final clearFailed = [
        'STORAGE_CLEAR_FAILED',
        'CACHE_CLEAR_FAILED',
      ].contains(session.issue?.code);
      final restricted = session.current?.user.mustResetPassword == true;
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (CreoAppearanceScope.maybeOf(context) != null)
                      const Align(
                        alignment: Alignment.centerRight,
                        child: CreoThemeToggle(showTooltip: false),
                      ),
                    Text(
                      'creo.',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 32),
                    if (busy) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: MediaQuery.disableAnimationsOf(context)
                            ? const Icon(
                                Icons.hourglass_top,
                                semanticLabel: 'In progress',
                              )
                            : const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(),
                              ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Semantics(
                      liveRegion: true,
                      header: true,
                      child: Text(
                        clearing
                            ? 'Signing out on this device'
                            : busy
                            ? 'Checking your session'
                            : ready
                            ? (restricted
                                  ? 'Password update required'
                                  : 'You’re signed in')
                            : 'Your session needs attention',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      busy
                          ? 'Please wait. Your account is being checked safely.'
                          : ready
                          ? DestinationIntent.forUser(
                              session.current!.user,
                            ).blocker!
                          : session.issue?.code == 'API_NOT_CONFIGURED'
                          ? 'Sign-in is not available in this build yet.'
                          : session.issue?.message ??
                                'Unable to restore your session. Your saved credentials have not been discarded.',
                    ),
                    if (!busy) ...[
                      const SizedBox(height: 24),
                      if (!ready)
                        OutlinedButton(
                          onPressed: () => clearFailed
                              ? session.logout(notifyServer: false)
                              : session.restore(),
                          child: Text(clearFailed ? 'Retry sign-out' : 'Retry'),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => session.logout(notifyServer: ready),
                        child: Text(
                          ready
                              ? 'Sign out on this device'
                              : 'Clear saved session and sign in',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
