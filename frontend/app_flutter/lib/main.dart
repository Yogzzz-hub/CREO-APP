import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'src/core/app_theme.dart';
import 'src/core/app_appearance.dart';
import 'src/features/landing/landing_page.dart';
import 'src/features/auth/auth_screen.dart';
import 'src/core/auth_session.dart';
import 'src/features/auth/session_lifecycle_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CreoAppearance.shared.restore();
  runApp(const CreoApp());
}

class CreoApp extends StatelessWidget {
  const CreoApp({
    super.key,
    this.session,
    this.appearance,
    this.initialRoute = '/',
  });
  final AuthSession? session;
  final CreoAppearance? appearance;
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    final owner = session ?? AuthSession.shared;
    final colors = appearance ?? CreoAppearance.shared;
    final routes = <String, WidgetBuilder>{
      '/': (context) => const LandingPage(),
      '/login': (context) => AuthScreen(
        defaultView: 'signin',
        session: owner,
        repository: owner.repository,
        sessionMessage:
            owner.issue?.message ??
            (owner.navigationEpoch > 0 ? 'Signed out on this device.' : null),
      ),
      '/signup': (context) => AuthScreen(
        defaultView: 'signup',
        session: owner,
        repository: owner.repository,
      ),
    };
    return ListenableBuilder(
      listenable: Listenable.merge([owner, colors]),
      builder: (context, _) => MaterialApp(
        key: ValueKey(owner.navigationEpoch),
        title: 'Creo',
        debugShowCheckedModeBanner: false,
        theme: buildCreoTheme(brightness: Brightness.light),
        darkTheme: buildCreoTheme(),
        themeMode: colors.mode,
        themeAnimationDuration:
            (MediaQuery.maybeOf(context)?.disableAnimations == true ||
                WidgetsBinding
                    .instance
                    .platformDispatcher
                    .accessibilityFeatures
                    .disableAnimations)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        initialRoute: owner.navigationEpoch > 0 ? '/login' : initialRoute,
        onGenerateInitialRoutes: (name) => [
          MaterialPageRoute<void>(
            settings: RouteSettings(name: name),
            builder: routes[name] ?? routes['/']!,
          ),
        ],
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                Theme.of(context).brightness == Brightness.light
                ? Brightness.dark
                : Brightness.light,
            statusBarBrightness: Theme.of(context).brightness,
            systemNavigationBarColor: context.creo.appBase,
            systemNavigationBarIconBrightness:
                Theme.of(context).brightness == Brightness.light
                ? Brightness.dark
                : Brightness.light,
          ),
          child: CreoAppearanceScope(
            appearance: colors,
            child: SessionLifecycleGate(
              session: owner,
              child: child ?? const SizedBox(),
            ),
          ),
        ),
        routes: routes,
      ),
    );
  }
}
