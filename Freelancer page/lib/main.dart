import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';

import 'data.dart';
import 'more.dart';
import 'ui.dart';
import 'work.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadTheme();
  runApp(const CreoFreelancer());
}

class CreoFreelancer extends StatelessWidget {
  const CreoFreelancer({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Creo Freelancer',
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
  int tab = 0, filter = 0, jump = 0;

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: changed, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final fixes = countIn(Status.revision);
    final tabs = [
      (Icons.work_outline, 'Work', fixes),
      (Icons.event_busy_outlined, 'Time off', 0),
      (Icons.chat_bubble_outline, 'Chat', 0),
      (Icons.person_outline, 'Profile', 0),
    ];
    // Not const: a const page is never rebuilt, so it would miss changes to the data.
    final pages = [WorkTab(initial: filter), TimeOffTab(), ChatTab(), ProfileTab()];
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
            Text('Freelancer', style: inter(14, w: FontWeight.w500, c: C.mist)),
          ]),
        ),
        actions: [
          // Tasks sent back for changes; opens the Revisions needed filter.
          IconButton(
            tooltip: 'Revisions needed',
            onPressed: () => setState(() {
              tab = 0;
              filter = buckets.indexOf(Status.revision);
              jump++;
            }),
            icon: Badge(isLabelVisible: fixes > 0, label: Text('$fixes'), child: Icon(Icons.notifications_outlined, color: C.mist2)),
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
          filter = 0;
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
