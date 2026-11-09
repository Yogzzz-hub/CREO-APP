import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'screens/main_shell_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system navigation & status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: CreoClientApp(),
    ),
  );
}

class CreoClientApp extends StatefulWidget {
  const CreoClientApp({super.key});

  @override
  State<CreoClientApp> createState() => _CreoClientAppState();
}

class _CreoClientAppState extends State<CreoClientApp> {
  ThemeMode _themeMode = ThemeMode.dark; // Dark mode by default matching Creo Obsidian

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Creo Client Portal',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: CreoTheme.lightTheme,
      darkTheme: CreoTheme.darkTheme,
      home: MainShellScreen(onToggleTheme: _toggleTheme),
    );
  }
}

