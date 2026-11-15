import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/auth_session.dart';
import '../../core/app_theme.dart';
import 'workstation_page.dart';
import 'workstation_data.dart';
import 'workstation_task_page.dart';
import 'workstation_hub_pages.dart';
import 'workstation_account_pages.dart';
import 'workstation_meetings_page.dart';

class MemberNavigationScope extends InheritedWidget {
  const MemberNavigationScope({
    super.key,
    required this.select,
    required super.child,
  });
  final ValueChanged<int> select;
  static MemberNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MemberNavigationScope>();
  @override
  bool updateShouldNotify(MemberNavigationScope oldWidget) => false;
}

/// Independent, lazily mounted tab histories. Detail routes stay above the bar.
class MemberWorkspaceShell extends StatefulWidget {
  const MemberWorkspaceShell({super.key, required this.session});
  final AuthSession session;
  @override
  State<MemberWorkspaceShell> createState() => _MemberShellState();
}

class _MemberShellState extends State<MemberWorkspaceShell>
    with WidgetsBindingObserver {
  final keys = List.generate(5, (_) => GlobalKey<NavigatorState>());
  final visited = <int>{0};
  int selected = 0;
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
  Future<bool> didPopRoute() async {
    await back();
    return true;
  }

  void select(int value) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (selected == value) {
      keys[value].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() {
      selected = value;
      visited.add(value);
    });
  }

  Future<void> back() async {
    if (await (keys[selected].currentState?.maybePop() ?? Future.value(false)))
      return;
    if (selected != 0) {
      select(0);
      return;
    }
    await SystemNavigator.pop();
  }

  Widget root(int index) => switch (index) {
    1 => WorkstationTaskPage(session: widget.session),
    2 => WorkstationHubPage(session: widget.session),
    3 => WorkstationSchedulePage(session: widget.session, freelancer: false),
    4 => WorkstationSettingsPage(session: widget.session, freelancer: false),
    _ => WorkstationPage(
      user: widget.session.current!.user,
      session: widget.session,
      load: WorkstationRepository(widget.session).load,
      onSignOut: () => logoutWorkstationSession(
        widget.session,
        store: WorkstationMeetingScope.maybeOf(context),
      ),
    ),
  };
  @override
  Widget build(BuildContext context) => MemberNavigationScope(
    select: select,
    child: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: IndexedStack(
          index: selected,
          children: [
            for (var i = 0; i < 5; i++)
              if (visited.contains(i))
                TickerMode(
                  enabled: i == selected,
                  child: Navigator(
                    key: keys[i],
                    onGenerateRoute: (_) =>
                        MaterialPageRoute<void>(builder: (_) => root(i)),
                  ),
                )
              else
                const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
            ? null
            : NavigationBar(
                key: const Key('member-bottom-navigation'),
                height: MediaQuery.textScalerOf(context).scale(1) > 1.3
                    ? 100
                    : 80,
                backgroundColor: context.creo.appSurface,
                indicatorColor: context.creo.accent.withValues(alpha: .16),
                selectedIndex: selected,
                onDestinationSelected: select,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.space_dashboard_outlined),
                    selectedIcon: Icon(Icons.space_dashboard),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.checklist_outlined),
                    label: 'Tasks',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.chat_bubble_outline),
                    label: 'Chat',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.event_outlined),
                    label: 'Time off',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    label: 'Profile',
                  ),
                ],
              ),
      ),
    ),
  );
}
