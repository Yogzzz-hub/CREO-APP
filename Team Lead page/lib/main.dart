import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'clients.dart';
import 'data.dart';
import 'home.dart';
import 'more.dart';
import 'review.dart';
import 'tasks.dart';
import 'ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadTheme();
  runApp(const CreoTeamLead());
}

class CreoTeamLead extends StatelessWidget {
  const CreoTeamLead({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Creo Team Lead',
    debugShowCheckedModeBanner: false,
    // Let mouse drags scroll horizontal rows (chips, tab bars) on web, like touch does.
    scrollBehavior: const MaterialScrollBehavior().copyWith(dragDevices: PointerDeviceKind.values.toSet()),
    theme: creoTheme(),
    // Colours in [C] switch at once, so the theme must too; the wave in [ThemeWave] is the animation.
    themeAnimationDuration: Duration.zero,
    // On a wide browser window, keep the phone layout centred.
    builder: (_, child) => ThemeWave(
      key: waveKey,
      child: ColoredBox(
        color: C.ground,
        child: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: child),
        ),
      ),
    ),
    home: const Shell(),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0, jump = 0;

  void go(int i) => setState(() {
    tab = i;
    jump++;
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: changed, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final queue = inStage(Stage.review).length;
    final tabs = [
      (Icons.space_dashboard_outlined, 'Home', toDecide.length),
      (Icons.fact_check_outlined, 'Review', queue),
      (Icons.view_kanban_outlined, 'Tasks', blocked.length),
      (Icons.storefront_outlined, 'Clients', 0),
      (Icons.menu, 'More', 0),
    ];
    // Not const: a const page is never rebuilt, so it would miss changes to the data.
    final pages = [HomeTab(go: go), ReviewTab(), TasksTab(), ClientsTab(), MoreTab()];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        shape: Border(bottom: BorderSide(color: C.line)),
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
                'Team lead',
                style: inter(14, w: FontWeight.w500, c: C.mist),
              ),
            ],
          ),
        ),
        actions: [
          // Work waiting for the lead's sign-off; opens Review.
          IconButton(
            tooltip: 'Waiting for sign-off',
            onPressed: () => go(1),
            icon: Badge(
              isLabelVisible: queue > 0,
              label: Text('$queue'),
              child: Icon(Icons.notifications_outlined, color: C.mist2),
            ),
          ),
          // Sun in dark mode, moon in light mode, like the website.
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: lightMode.value ? 'Dark mode' : 'Light mode',
              onPressed: toggleTheme,
              icon: Icon(lightMode.value ? Icons.dark_mode_outlined : Icons.light_mode_outlined, color: C.mist2),
            ),
          ),
        ],
      ),
      // Fade and rise when switching tabs; off when the phone asks for reduced motion.
      body: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(a),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey('$tab-$jump'), child: pages[tab]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          for (final (icon, label, n) in tabs)
            // A small dot, not a number: the bell already gives the count.
            NavigationDestination(
              icon: Badge(isLabelVisible: n > 0, smallSize: 8, child: Icon(icon)),
              label: label,
              tooltip: '',
            ),
        ],
      ),
    );
  }
}
