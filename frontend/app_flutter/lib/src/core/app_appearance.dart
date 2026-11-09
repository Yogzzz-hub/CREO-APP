import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

typedef ReadAppearance = Future<String?> Function();
typedef WriteAppearance = Future<void> Function(String value);

/// Appearance is device-local and independent of account/session storage.
class CreoAppearance extends ChangeNotifier {
  CreoAppearance({ReadAppearance? read, WriteAppearance? write})
    : _read = read ?? (() => _storage.read(key: _key)),
      _write = write ?? ((value) => _storage.write(key: _key, value: value));

  static const _storage = FlutterSecureStorage();
  static const _key = 'creo_theme_v1';
  static final shared = CreoAppearance();
  final ReadAppearance _read;
  final WriteAppearance _write;
  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;
  Future<void> _writes = Future<void>.value();
  bool _changed = false;

  Future<void> restore() async {
    try {
      final saved = await _read().timeout(const Duration(seconds: 2));
      if (!_changed && saved == 'light') {
        _mode = ThemeMode.light;
        notifyListeners();
      }
    } catch (_) {
      // An unavailable preference never blocks authentication or startup.
    }
  }

  Future<bool> toggle() {
    _changed = true;
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final value = _mode == ThemeMode.light ? 'light' : 'dark';
    notifyListeners();
    // Rapid taps persist in selection order, even on slow device storage.
    final result = _writes.then((_) async {
      try {
        await _write(value);
        return true;
      } catch (_) {
        return false;
      }
    });
    _writes = result.then((_) {});
    return result;
  }
}

class CreoAppearanceScope extends InheritedNotifier<CreoAppearance> {
  const CreoAppearanceScope({
    super.key,
    required CreoAppearance appearance,
    required super.child,
  }) : super(notifier: appearance);
  static CreoAppearance? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<CreoAppearanceScope>()
      ?.notifier;
}

class CreoThemeToggle extends StatelessWidget {
  const CreoThemeToggle({super.key, this.showTooltip = true});
  final bool showTooltip;
  @override
  Widget build(BuildContext context) {
    final appearance = CreoAppearanceScope.maybeOf(context);
    if (appearance == null) return const SizedBox.shrink();
    final light = appearance.mode == ThemeMode.light;
    final label = light ? 'Switch to dark mode' : 'Switch to light mode';
    return IconButton.outlined(
      key: const ValueKey('appearance-toggle'),
      tooltip: showTooltip ? label : null,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      icon: Icon(
        light ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
        semanticLabel: showTooltip ? null : label,
      ),
      onPressed: () async {
        final saved = await appearance.toggle();
        if (!saved && context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text(
                'Theme changed. This device could not save your preference.',
              ),
            ),
          );
        }
      },
    );
  }
}
