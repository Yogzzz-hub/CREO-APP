import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/auth_session.dart';
import '../../core/app_appearance.dart';
import '../workstation/member_workspace_shell.dart';
import '../freelancer/freelancer_workspace_page.dart';
import '../team_lead/team_lead_page.dart';
import 'mandatory_password_page.dart';
import '../admin/creo_admin/admin_shell.dart';
import '../bde/creo_bde/bde_shell.dart';
import '../portal/client_portal_screen.dart';

/// Authenticated content cannot mount before server validation. The signed-in
/// Editors/designers enter the workstation only after server validation.
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
      if (ready && restricted)
        return _BackForwardingNavigator(
          key: ValueKey((session, session.current!.user.id, 'password-reset')),
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => MandatoryPasswordPage(session: session),
          ),
        );
      if (ready && !restricted && session.current?.user != null) {
        final current = session.current!.user;
        final role = current.role.toLowerCase();

        return _BackForwardingNavigator(
          key: ValueKey((session, current.id, role)),
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) {
              if (role == 'admin' || role == 'super_admin') {
                return AdminShellScreen(
                  session: session,
                  onSignOut: () => session.logout(notifyServer: true),
                );
              } else if (role == 'bde' ||
                  role == 'sales' ||
                  role == 'bde_head') {
                return BdeShellScreen(
                  session: session,
                  onSignOut: () => session.logout(notifyServer: true),
                );
              } else if (role == 'client' || role == 'client_owner') {
                return ClientPortalScreen(
                  session: session,
                  onSignOut: () => session.logout(notifyServer: true),
                );
              } else if (role == 'freelancer') {
                return FreelancerWorkspacePage(session: session);
              } else if (role == 'team_lead') {
                return TeamLeadPage(session: session);
              } else if (role == 'editor' || role == 'designer') {
                return MemberWorkspaceShell(session: session);
              }
              return Scaffold(
                appBar: AppBar(title: const Text('Workspace unavailable')),
                body: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        DestinationIntent.forUser(current).blocker ??
                            'This role has no verified mobile workspace.',
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: () => session.logout(notifyServer: true),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }
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

/// The signed-in workspace runs in a [Navigator] built above the app's root
/// navigator (in `MaterialApp.builder`), so the Android back button never
/// reaches it. Listen for back here so it pops the workspace's own pages (and
/// runs their PopScopes) before the app is closed.
class _BackForwardingNavigator extends StatefulWidget {
  const _BackForwardingNavigator({super.key, required this.onGenerateRoute});
  final RouteFactory onGenerateRoute;

  @override
  State<_BackForwardingNavigator> createState() =>
      _BackForwardingNavigatorState();
}

class _BackForwardingNavigatorState extends State<_BackForwardingNavigator>
    with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async =>
      await _navigator.currentState?.maybePop() ?? false;

  @override
  Widget build(BuildContext context) =>
      Navigator(key: _navigator, onGenerateRoute: widget.onGenerateRoute);
}
