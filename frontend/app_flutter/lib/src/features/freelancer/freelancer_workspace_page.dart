import 'package:flutter/material.dart';
import '../../core/auth_session.dart';
import '../workstation/freelancer_page.dart';
import '../workstation/workstation_account_pages.dart';
import '../workstation/workstation_hub_pages.dart';

/// The incoming project's thumb-reachable navigation around the live workspace.
class FreelancerWorkspacePage extends StatefulWidget {
  const FreelancerWorkspacePage({super.key, required this.session});
  final AuthSession session;
  @override
  State<FreelancerWorkspacePage> createState() =>
      _FreelancerWorkspacePageState();
}

class _FreelancerWorkspacePageState extends State<FreelancerWorkspacePage> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: switch (_tab) {
      1 => WorkstationSchedulePage(session: widget.session, freelancer: true),
      2 => WorkstationHubPage(session: widget.session),
      3 => WorkstationSettingsPage(session: widget.session, freelancer: true),
      _ => FreelancerPage(session: widget.session),
    },
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (value) => setState(() => _tab = value),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.work_outline), label: 'Work'),
        NavigationDestination(
          icon: Icon(Icons.event_busy_outlined),
          label: 'Time off',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          label: 'Chat',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    ),
  );
}
