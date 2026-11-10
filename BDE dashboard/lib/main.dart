import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';

import 'crm.dart';
import 'data.dart';
import 'more.dart';
import 'pipeline.dart';
import 'ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadTheme();
  runApp(const CreoBde());
}

class CreoBde extends StatelessWidget {
  const CreoBde({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Creo BDE',
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
                color: C.ground, child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: child)))),
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0, crmSub = 0, jump = 0;

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: changed, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final due = dueTodayCount + overdueCount;
    final tabs = [
      (Icons.view_kanban_outlined, 'Pipeline', 0),
      (Icons.track_changes_outlined, 'CRM', due),
      (Icons.sell_outlined, 'Plans', 0),
      (Icons.chat_bubble_outline, 'Chat', 0),
      (Icons.event_outlined, 'Leave', 0),
    ];
    // Not const: a const page is never rebuilt, so it would miss changes to the data.
    final pages = [PipelineTab(), CrmTab(initial: crmSub), PlansTab(), ChatTab(), LeaveTab()];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        shape: Border(bottom: BorderSide(color: C.line)),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: 'creo', style: inter(22, w: FontWeight.w500)),
              TextSpan(text: '.', style: inter(22, w: FontWeight.w500, c: C.accent)),
            ])),
            const SizedBox(width: 12),
            Text('BDE', style: inter(14, w: FontWeight.w500, c: C.mist)),
          ]),
        ),
        actions: [
          // Follow-ups due today or late; opens the CRM follow-up queue.
          IconButton(
            tooltip: 'Follow-ups due',
            onPressed: () => setState(() {
              tab = 1;
              crmSub = 3;
              jump++;
            }),
            icon: Badge(isLabelVisible: due > 0, label: Text('$due'), child: Icon(Icons.notifications_outlined, color: C.mist2)),
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
            opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(a), child: child)),
        child: KeyedSubtree(key: ValueKey('$tab-$jump'), child: pages[tab]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() {
          tab = i;
          crmSub = 0;
        }),
        destinations: [
          for (final (icon, label, n) in tabs)
            // A small dot, not a number: the bell already gives the count.
            NavigationDestination(icon: Badge(isLabelVisible: n > 0, smallSize: 8, child: Icon(icon)), label: label, tooltip: ''),
        ],
      ),
    );
  }
}
