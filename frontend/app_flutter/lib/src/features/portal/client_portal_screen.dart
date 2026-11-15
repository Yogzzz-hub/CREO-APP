import 'package:flutter/material.dart';
import '../../core/auth_session.dart';
import '../../core/app_appearance.dart';
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
    return Theme(
      data: mode == ThemeMode.dark ? CreoTheme.darkTheme : CreoTheme.lightTheme,
      child: Column(
        children: [
          Expanded(
            child: NavigatorPopHandler<Object?>(
              onPopWithResult: (result) =>
                  _navigatorKey.currentState?.pop(result),
              child: Navigator(
                key: _navigatorKey,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => MainShellScreen(
                    onToggleTheme: _toggleTheme,
                    session: widget.session,
                    onSignOut: widget.onSignOut,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
