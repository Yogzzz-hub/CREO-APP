import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth_session.dart';
import 'client_portal_access.dart';
import 'widgets/creo_bottom_nav.dart';
import 'widgets/creo_portal_drawer.dart';
import 'widgets/creo_top_header.dart';

/// The visible client portal while server-controlled setup remains incomplete.
class ClientPortalSetupShell extends StatefulWidget {
  const ClientPortalSetupShell({
    super.key,
    required this.session,
    required this.access,
    required this.onResume,
    required this.onRefresh,
    required this.onToggleTheme,
  });

  final AuthSession session;
  final ClientPortalAccess access;
  final VoidCallback onResume, onRefresh, onToggleTheme;

  @override
  State<ClientPortalSetupShell> createState() => _SetupShellState();
}

class _SetupShellState extends State<ClientPortalSetupShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String _page = 'Home';
  static const _tabs = ['Home', 'Review', 'Calendar', 'Inbox', 'Account'];

  Future<void> _openWeb(String path) async {
    try {
      final opened = await launchUrl(
        Uri.https('creo.yogalakshmibaskar20.workers.dev', path),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('Browser unavailable');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the website. Please try again.'),
          ),
        );
      }
    }
  }

  void _select(String key) {
    _scaffoldKey.currentState?.closeDrawer();
    if (key == 'logout') {
      widget.session.logout();
      return;
    }
    const pages = {
      'dashboard': 'Home',
      'review': 'Review',
      'calendar': 'Calendar',
      'chat': 'Inbox',
      'settings': 'Account',
      'billing': 'Billing',
      'brand': 'Brand DNA',
      'library': 'Library',
      'pod': 'Creative pod',
      'help': 'Help',
    };
    setState(() => _page = pages[key] ?? 'Home');
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.current!.user;
    final access = widget.access;
    final theme = Theme.of(context);
    final checklist = [
      ('Verify email', access.emailVerified),
      ('Service agreement', access.stage >= 2),
      ('Activate plan', access.subscriptionActive),
      ('Brand questionnaire', access.stage >= 4),
      ('Launch workspace', access.setupComplete),
    ];
    final index = _tabs.indexOf(_page);
    return Scaffold(
      key: _scaffoldKey,
      appBar: CreoTopHeader(
        userInitials: user.fullName.isEmpty
            ? 'CL'
            : user.fullName.substring(0, 1).toUpperCase(),
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        onSettingsTap: () => setState(() => _page = 'Account'),
        onProfileTap: () => setState(() => _page = 'Account'),
        onNotificationTap: widget.onResume,
        onThemeToggle: widget.onToggleTheme,
      ),
      drawer: CreoPortalDrawer(
        activeItem: 'dashboard',
        pendingReviewCount: 0,
        userName: user.fullName,
        userInitials: user.fullName.isEmpty
            ? 'CL'
            : user.fullName.substring(0, 1).toUpperCase(),
        onSelect: _select,
        onThemeToggle: widget.onToggleTheme,
        onSignOut: () => widget.session.logout(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _page == 'Home' ? 'Your Creo workspace' : _page,
              style: theme.textTheme.headlineLarge,
            ),
            const SizedBox(height: 16),
            if (_page == 'Account') ...[
              Text(user.fullName, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              SelectableText(user.email),
              const SizedBox(height: 16),
              const Text('Email verified'),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => widget.session.logout(),
                child: const Text('Sign out'),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        _page == 'Home' ? Icons.tune : Icons.lock_outline,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _page == 'Home'
                            ? 'Finish setting up your workspace'
                            : 'Complete setup to unlock $_page',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(access.lockReason),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: widget.onResume,
                        child: Text(access.nextAction),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onRefresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh saved progress'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_page == 'Home')
                for (final (label, done) in checklist)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      done ? Icons.check_circle_outline : Icons.lock_outline,
                    ),
                    title: Text(label),
                    subtitle: Text(done ? 'Complete' : 'Pending'),
                    onTap: done ? null : widget.onResume,
                  ),
              if (_page == 'Billing') ...[
                Text(
                  access.subscriptionActive
                      ? 'Payment confirmed. Your plan is active.'
                      : 'An active plan is required.',
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _openWeb('/portal/payments'),
                  child: const Text('Open billing on website'),
                ),
                const Text(
                  'Sign in on the website, then return here and refresh saved progress.',
                ),
              ],
              if (_page == 'Help' || _page == 'Inbox')
                OutlinedButton(
                  onPressed: () => _openWeb('/portal/support'),
                  child: const Text('Open support on website'),
                ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: CreoBottomNavBar(
          currentIndex: index < 0 ? 0 : index,
          pendingReviewCount: 0,
          inboxBadgeCount: 0,
          onTap: (index) => setState(() => _page = _tabs[index]),
        ),
      ),
    );
  }
}
