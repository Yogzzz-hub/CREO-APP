import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth_session.dart';
import '../../core/app_appearance.dart';
import '../../core/auth_repository.dart';
import '../onboarding/client_onboarding_page.dart';
import 'client_portal_access.dart';
import 'client_portal_setup_shell.dart';
import 'core/theme/app_theme.dart';
import 'screens/main_shell_screen.dart';

class ClientPortalScreen extends StatefulWidget {
  const ClientPortalScreen({super.key, required this.session, this.onSignOut});

  final AuthSession session;
  final VoidCallback? onSignOut;

  @override
  State<ClientPortalScreen> createState() => _ClientPortalScreenState();
}

class _ClientPortalScreenState extends State<ClientPortalScreen> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  ThemeMode _themeMode = ThemeMode.dark;
  ClientPortalAccess? _access;
  String? _accessError;
  bool _loadingAccess = true;
  bool _openingSetup = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAccess());
  }

  Future<void> _loadAccess() async {
    final session = widget.session;
    final generation = session.beginReadGeneration;
    if (mounted)
      setState(() {
        _loadingAccess = true;
        _accessError = null;
      });
    try {
      if (session.phase != SessionPhase.authenticated ||
          session.current?.user.mustResetPassword == true ||
          !{'client', 'client_owner'}.contains(session.current?.user.role)) {
        throw const HttpError(
          status: 403,
          code: 'PORTAL_FORBIDDEN',
          message: 'Sign in with your client account.',
        );
      }
      final status = await session.request('GET', '/api/v1/onboarding/status');
      if (!mounted || !session.isCurrent(generation)) return;
      final stage = status['stage'];
      final subscription = stage is int && stage >= 3
          ? await session.request('GET', '/api/v1/payments/subscription')
          : null;
      final access = ClientPortalAccess.fromJson(
        status,
        subscription: subscription,
      );
      if (!mounted || !session.isCurrent(generation)) return;
      setState(() => _access = access);
    } catch (error) {
      if (!mounted || !session.isCurrent(generation)) return;
      setState(
        () => _accessError = error is HttpError
            ? error.message
            : 'Your workspace access could not be verified. Please retry.',
      );
    } finally {
      if (mounted && session.isCurrent(generation))
        setState(() => _loadingAccess = false);
    }
  }

  Future<void> _resumeSetup() async {
    if (_openingSetup) return;
    _openingSetup = true;
    if ((_access?.stage ?? 0) >= 3 && _access?.subscriptionActive == false) {
      try {
        final opened = await launchUrl(
          Uri.https('creo.yogalakshmibaskar20.workers.dev', '/portal/payments'),
          mode: LaunchMode.externalApplication,
        );
        if (!opened) throw StateError('Browser unavailable');
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Could not open billing. Please try again.'),
            ),
          );
        }
      } finally {
        _openingSetup = false;
      }
      return;
    }
    try {
      await _navigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => ClientOnboardingPage(
            session: widget.session,
            onCompleted: () => unawaited(_completeSetup()),
          ),
        ),
      );
    } finally {
      _openingSetup = false;
      if (mounted) await _loadAccess();
    }
  }

  Future<void> _completeSetup() async {
    await widget.session.restore();
    if (!mounted) return;
    final navigator = _navigatorKey.currentState;
    if (_openingSetup && navigator != null && navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    } else {
      await _loadAccess();
    }
  }

  void _toggleTheme() {
    final appearance = CreoAppearanceScope.maybeOf(context);
    if (appearance != null) {
      appearance.toggle();
      return;
    }
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = CreoAppearanceScope.maybeOf(context)?.mode ?? _themeMode;
    final access = _access;
    return Theme(
      data: mode == ThemeMode.dark ? CreoTheme.darkTheme : CreoTheme.lightTheme,
      child: _loadingAccess || _accessError != null || access == null
          ? Scaffold(
              body: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'creo.',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_loadingAccess) ...[
                          if (!MediaQuery.disableAnimationsOf(context))
                            const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          const Text('Checking your workspace access'),
                        ] else ...[
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _accessError ??
                                  'Your workspace access could not be verified.',
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _loadAccess,
                            child: const Text('Retry'),
                          ),
                          TextButton(
                            onPressed: () => widget.session.logout(),
                            child: const Text('Sign out'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: NavigatorPopHandler<Object?>(
                    onPopWithResult: (result) =>
                        _navigatorKey.currentState?.pop(result),
                    child: Navigator(
                      key: _navigatorKey,
                      onDidRemovePage: (_) {},
                      pages: [
                        MaterialPage<void>(
                          child: !access.emailVerified
                              ? ClientOnboardingPage(
                                  session: widget.session,
                                  onEmailVerified: () =>
                                      unawaited(_loadAccess()),
                                  onCompleted: () =>
                                      unawaited(_completeSetup()),
                                )
                              : access.canUseWorkspace
                              ? MainShellScreen(
                                  onToggleTheme: _toggleTheme,
                                  session: widget.session,
                                  onSignOut: widget.onSignOut,
                                )
                              : ClientPortalSetupShell(
                                  session: widget.session,
                                  access: access,
                                  onResume: () => unawaited(_resumeSetup()),
                                  onRefresh: () => unawaited(_loadAccess()),
                                  onToggleTheme: _toggleTheme,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
