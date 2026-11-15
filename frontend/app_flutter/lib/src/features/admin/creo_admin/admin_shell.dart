import 'dart:async';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';

import '../../../core/auth_session.dart';
import '../../../core/app_appearance.dart';
import 'admin_api_service.dart';
import 'content.dart';
import 'data.dart';
import 'inbox.dart';
import 'money.dart';
import 'profile.dart';
import 'team.dart';
import 'ui.dart';

class AdminShellScreen extends StatelessWidget {
  const AdminShellScreen({super.key, this.session, this.onSignOut});
  final AuthSession? session;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final appearance = CreoAppearanceScope.maybeOf(context);
    if (appearance != null)
      lightMode.value = appearance.mode == ThemeMode.light;
    if (session?.current?.user != null) {
      final user = session!.current!.user;
      if (user.fullName.trim().isNotEmpty) {
        me.name = user.fullName.trim();
      }
      if (user.email.trim().isNotEmpty) {
        me.email = user.email.trim();
      }
      me.role = user.role.toLowerCase() == 'super_admin'
          ? 'Super Admin'
          : 'Admin';
    }
    return Theme(
      data: creoTheme(),
      child: ThemeWave(
        key: waveKey,
        child: ColoredBox(
          color: C.ground,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Shell(session: session, onSignOut: onSignOut),
            ),
          ),
        ),
      ),
    );
  }
}

class CreoAdmin extends StatelessWidget {
  const CreoAdmin({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Creo admin',
    debugShowCheckedModeBanner: false,
    scrollBehavior: const MaterialScrollBehavior().copyWith(
      dragDevices: PointerDeviceKind.values.toSet(),
    ),
    theme: creoTheme(),
    themeAnimationDuration: Duration.zero,
    builder: (_, child) => ThemeWave(
      key: waveKey,
      child: ColoredBox(
        color: C.ground,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: child,
          ),
        ),
      ),
    ),
    home: const Shell(),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key, this.session, this.onSignOut});
  final AuthSession? session;
  final VoidCallback? onSignOut;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  String? _boundAccountId;
  // Sub-tab each tab opens at, and a counter that rebuilds the tabs so a new sub-tab takes effect.
  final subs = [0, 0, 0, 0, 0, 0];
  int jump = 0;

  @override
  void initState() {
    super.initState();
    widget.session?.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  @override
  void didUpdateWidget(covariant Shell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session?.removeListener(_onSessionChanged);
      widget.session?.addListener(_onSessionChanged);
      _onSessionChanged();
    }
  }

  @override
  void dispose() {
    widget.session?.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    final nextId = widget.session?.current?.user.id;
    if (nextId == _boundAccountId) return;
    _boundAccountId = nextId;
    if (nextId == null) {
      currentAdminApi = null;
      clients.clear();
      people.clear();
      tickets.clear();
      pods.clear();
      leaves.clear();
      channels.clear();
      tasks.clear();
      deliverables.clear();
      posts.clear();
      invoices.clear();
      negotiations.clear();
      leads.clear();
      serverMrr = null;
    } else {
      currentAdminApi = AdminApiService(widget.session!);
      final user = widget.session!.current!.user;
      if (user.fullName.trim().isNotEmpty) me.name = user.fullName.trim();
      if (user.email.trim().isNotEmpty) me.email = user.email.trim();
      me.role = user.role.toLowerCase() == 'super_admin'
          ? 'Super Admin'
          : 'Admin';
      unawaited(currentAdminApi!.refreshAll());
    }
    changed.value++;
  }

  void go(int t, [int sub = 0]) => setState(() {
    tab = t;
    subs[t] = sub;
    jump++;
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: changed,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final tabs = [
      (Icons.home_outlined, 'Home', decisionCount),
      (Icons.layers_outlined, 'Content', drafts(Draft.review).length),
      (Icons.payments_outlined, 'Money', waitingProposals.length),
      (Icons.group_outlined, 'Team', pendingLeaves.length),
      (Icons.inbox_outlined, 'Inbox', openTickets.length),
      (Icons.person_outline, 'Profile', 0),
    ];
    final pages = [
      Home(go: go),
      ContentTab(initial: subs[1]),
      MoneyTab(initial: subs[2]),
      TeamTab(initial: subs[3]),
      InboxTab(initial: subs[4]),
      Profile(key: ValueKey(changed.value), onSignOut: widget.onSignOut),
    ];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        shape: Border(bottom: BorderSide(color: C.line)),
        // Scales down on narrow phones so the four header buttons always fit.
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'creo',
                      style: inter(22, w: FontWeight.w500),
                    ),
                    TextSpan(
                      text: '.',
                      style: inter(22, w: FontWeight.w500, c: C.accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Admin',
                style: inter(14, w: FontWeight.w500, c: C.mist),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Things that need you',
            onPressed: () => go(0),
            icon: Badge(
              isLabelVisible: decisionCount > 0,
              label: Text('$decisionCount'),
              child: Icon(Icons.notifications_outlined, color: C.mist2),
            ),
          ),
          // Sun in dark mode, moon in light mode, like the website.
          IconButton(
            tooltip: lightMode.value ? 'Dark mode' : 'Light mode',
            onPressed: () => unawaited(_toggleTheme(context)),
            icon: Icon(
              lightMode.value
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
              color: C.mist2,
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Settings(onSignOut: widget.onSignOut),
              ),
            ),
            icon: Icon(Icons.settings_outlined, color: C.mist2),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Profile',
              onPressed: () => go(5),
              icon: CircleAvatar(
                radius: 18,
                backgroundColor: C.raised,
                child: Text(
                  initials(me.name),
                  style: inter(13, w: FontWeight.w500, c: C.mist2),
                ),
              ),
            ),
          ),
        ],
      ),
      // Fade and rise when switching tabs; off when the phone asks for reduced motion.
      body: Column(
        children: [
          // ── Loading / error banner ─────────────────────────────────────
          if (currentAdminApi?.isLoading == true)
            LinearProgressIndicator(
              minHeight: 2,
              color: C.accent,
              backgroundColor: C.ground,
            ),
          if (currentAdminApi?.error != null &&
              currentAdminApi?.isLoading == false)
            Material(
              color: C.rose.withAlpha(30),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_outlined, size: 16, color: C.rose),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Could not reach server – pull down to retry',
                        style: inter(13, c: C.rose),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // ── Page body ─────────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: C.accent,
              backgroundColor: C.surface,
              onRefresh: () async {
                await currentAdminApi?.refreshAll();
              },
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, .03),
                      end: Offset.zero,
                    ).animate(a),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey('$tab-$jump'),
                  child: pages[tab],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          for (final (icon, label, n) in tabs)
            // A small dot, not a number: the bell and each tab's own page already give the count.
            NavigationDestination(
              icon: Badge(
                isLabelVisible: n > 0,
                smallSize: 8,
                child: Icon(icon),
              ),
              label: label,
              tooltip: '',
            ),
        ],
      ),
    );
  }
}

Future<void> _toggleTheme(BuildContext context) async {
  final appearance = CreoAppearanceScope.maybeOf(context);
  if (appearance == null) return toggleTheme();
  final saved = await appearance.toggle();
  lightMode.value = appearance.mode == ThemeMode.light;
  if (!saved && context.mounted)
    toast(
      context,
      'Theme changed, but this device could not save the preference.',
    );
}

class Home extends StatelessWidget {
  const Home({super.key, required this.go});
  final void Function(int tab, [int sub]) go;

  @override
  Widget build(BuildContext context) {
    final review = drafts(Draft.review);
    final leave = pendingLeaves.firstOrNull;
    final n = decisionCount;
    Widget decision(
      IconData icon,
      Color color,
      String t,
      String s,
      int tab,
      int sub,
    ) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: C.surface,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: C.raised,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          title: Text(t, style: inter(16, w: FontWeight.w500)),
          subtitle: Text(s),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => go(tab, sub),
        ),
      ),
    );

    // One card per area of the web admin dashboard: its key numbers and a link to each of its pages.
    Widget section(
      String name,
      String about,
      List<(String, String)> nums,
      List<(String, int, int)> links,
    ) => Panel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: inter(18, w: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(about, style: inter(14, c: C.mist)),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final (k, v) in nums)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k, style: inter(13, c: C.mist)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(v, style: inter(20, w: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          // Quiet text links to each page of the area, on one line under a hairline.
          // Shifted left by the button padding so the first label lines up with the title.
          Transform.translate(
            offset: const Offset(-8, 0),
            child: Wrap(
              children: [
                for (final (label, t, s) in links)
                  TextButton(
                    onPressed: () => go(t, s),
                    style: TextButton.styleFrom(
                      foregroundColor: C.mist2,
                      minimumSize: const Size(48, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: inter(14, w: FontWeight.w500),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label),
                        Icon(Icons.chevron_right, size: 16, color: C.mist),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final now = DateTime.now();
    final scheduled = deliverables
        .where((d) => d.date.year == now.year && d.date.month == now.month)
        .length;

    // ── Live KPIs from server (fall back to local computed values) ─────
    final dash = currentAdminApi?.liveDashboard;
    final kpi = dash?['kpi_data'] as Map<String, dynamic>?;
    final liveMrr = kpi != null
        ? (kpi['mrr_minor'] != null
              ? (kpi['mrr_minor'] as num).toInt() ~/ 100
              : mrr)
        : mrr;
    final liveActive = kpi != null
        ? ((kpi['active_clients'] as num?)?.toInt() ?? paidClients.length)
        : paidClients.length;
    final liveAvg = liveActive > 0 ? inr(liveMrr ~/ liveActive) : '—';
    final liveSla = kpi != null
        ? (kpi['sla_percent'] != null
              ? '${(kpi['sla_percent'] as num).toStringAsFixed(1)}%'
              : null)
        : null;
    final liveNewLeads = kpi != null
        ? ((kpi['new_leads_this_month'] as num?)?.toInt())
        : null;

    return page([
      title('Today'),
      sub(
        '${shortDate(DateTime.now())} · ${n == 0 ? 'nothing needs you' : '$n thing${n == 1 ? '' : 's'} need you'}',
      ),
      if (n > 0) sec('Needs your decision'),
      if (review.isNotEmpty)
        decision(
          Icons.check_box_outlined,
          C.mist2,
          'Review ${review.length} drafts',
          formatCounts(review),
          1,
          0,
        ),
      if (leave != null)
        decision(
          Icons.event_outlined,
          C.mist2,
          pendingLeaves.length == 1
              ? '${leave.who.split(' ').first} asked for leave'
              : '${pendingLeaves.length} leave requests',
          '${dm(leave.start)} · ${leave.days} day${leave.days == 1 ? '' : 's'}',
          3,
          2,
        ),
      if (waitingProposals.isNotEmpty)
        decision(
          Icons.request_quote_outlined,
          C.mist2,
          '${waitingProposals.length} plan proposal${waitingProposals.length == 1 ? '' : 's'} waiting',
          '${waitingProposals.first.client}: ${inr(waitingProposals.first.proposed)} a month',
          2,
          1,
        ),
      if (overloaded.isNotEmpty)
        decision(
          Icons.error_outline,
          C.rose,
          '${overloaded.length} people are overloaded',
          '${overloaded.first.$1.split(' ').first} has ${overloaded.first.$2} tasks open',
          3,
          1,
        ),
      sec('Your agency'),
      section(
        'Revenue',
        'Monthly revenue, plans and sales',
        [
          ('This month', inr(liveMrr)),
          ('Active clients', '$liveActive'),
          ('Average', liveAvg),
        ],
        [('Revenue', 2, 0), ('Plans', 2, 1), ('Sales', 2, 2)],
      ),
      section(
        'Team',
        'Pods, workload and leave',
        [
          ('Pods', '${pods.length}'),
          ('People', '${peopleOf(Kind.staff).length}'),
          ('Leave requests', '${pendingLeaves.length}'),
        ],
        [('Pods', 3, 0), ('Workload', 3, 1), ('Leave', 3, 2)],
      ),
      section(
        'Content',
        'Drafts, schedule, tasks and Instagram',
        [
          ('To review', '${review.length}'),
          ('Scheduled', '$scheduled'),
          ('Tasks to do', '${tasksIn(Stage.todo).length}'),
        ],
        [
          ('Review', 1, 0),
          ('Calendar', 1, 1),
          ('Tasks', 1, 2),
          ('Publish', 1, 3),
        ],
      ),
      section(
        'Clients',
        'Paid and unpaid accounts',
        [
          ('Paid', '$liveActive'),
          ('Not paid', '${unpaidClients.length}'),
          if (liveNewLeads != null)
            ('New leads', '$liveNewLeads')
          else
            ('Total', '${liveActive + unpaidClients.length}'),
        ],
        [('Clients', 3, 3)],
      ),
      section(
        'Support',
        'Client tickets and team chat',
        [
          ('Open', '${openTickets.length}'),
          if (liveSla != null)
            ('SLA', liveSla)
          else
            ('Solved today', '$solvedToday'),
          ('First reply', avgFirstReply),
        ],
        [('Support', 4, 1), ('Chat', 4, 0)],
      ),
    ]);
  }
}
