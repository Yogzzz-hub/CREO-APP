import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';

/// Light or dark theme. Dark is the default, like the website. Saved under `light` so it survives a reload.
final lightMode = ValueNotifier(false);

Future<void> loadTheme() async => lightMode.value = (await SharedPreferences.getInstance()).getBool('light') ?? false;

final waveKey = GlobalKey<ThemeWaveState>();

/// Switch theme and rebuild every screen, including pages pushed on top, since they read [C] directly.
Future<void> toggleTheme() async {
  final wave = waveKey.currentState;
  final old = await wave?.snapshot();
  void mark(Element e) {
    e.markNeedsBuild();
    e.visitChildren(mark);
  }

  lightMode.value = !lightMode.value;
  wave?.play(old);
  WidgetsBinding.instance.rootElement?.visitChildren(mark);
  (await SharedPreferences.getInstance()).setBool('light', lightMode.value);
}

/// Theme change animation: a picture of the old theme slides off downwards behind a wavy edge,
/// so the new theme fills the screen from top to bottom. Skipped when the phone asks for reduced motion.
class ThemeWave extends StatefulWidget {
  const ThemeWave({super.key, required this.child});
  final Widget child;
  @override
  State<ThemeWave> createState() => ThemeWaveState();
}

class ThemeWaveState extends State<ThemeWave> with SingleTickerProviderStateMixin {
  final _shot = GlobalKey();
  late final _run = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) setState(() => _old = null);
    });
  ui.Image? _old;

  Future<ui.Image?> snapshot() async {
    if (MediaQuery.disableAnimationsOf(context)) return null;
    final box = _shot.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    return box?.toImage(pixelRatio: MediaQuery.devicePixelRatioOf(context));
  }

  void play(ui.Image? old) {
    if (old == null) return;
    _old?.dispose();
    setState(() => _old = old);
    _run.forward(from: 0);
  }

  @override
  void dispose() {
    _run.dispose();
    _old?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        RepaintBoundary(key: _shot, child: widget.child),
        if (_old != null)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _run,
              builder: (_, _) => ClipPath(
                  clipper: _Wave(Curves.easeInOutCubic.transform(_run.value)), child: RawImage(image: _old, fit: BoxFit.fill)),
            ),
          ),
      ]);
}

/// Keeps the part of the old picture below a sine wave whose line moves from above the top to below the bottom.
class _Wave extends CustomClipper<Path> {
  _Wave(this.t);
  final double t;
  @override
  Path getClip(Size size) {
    const a = 28.0;
    double y(double x) => t * (size.height + 2 * a) - a + a * math.sin(x / size.width * 3 * math.pi + t * 4 * math.pi);
    final path = Path()..moveTo(0, y(0));
    for (var x = 0.0; x <= size.width; x += 6) {
      path.lineTo(x, y(x));
    }
    return path
      ..lineTo(size.width, y(size.width))
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_Wave old) => old.t != t;
}

/// Creo palette, dark and light, taken from the website's theme. Only these colours are used in the app.
/// Dark contrast on [surface]: text 14.7:1, mist 7.7:1, accent 6.7:1, rose 6.4:1, peri 8.5:1.
abstract final class C {
  static Color _p(int dark, int light) => Color(lightMode.value ? light : dark);
  static Color get ground => _p(0xFF0A0908, 0xFFE9DFCF);
  static Color get base => _p(0xFF0F0E0C, 0xFFF5EEE3);
  static Color get surface => _p(0xFF1F1C19, 0xFFFBF7F0);
  static Color get raised => _p(0xFF282420, 0xFFF2E9DC);
  static Color get line => _p(0xFF3A342D, 0xFFD8C8B2);
  static Color get text => _p(0xFFF5EEE3, 0xFF2B1E15);
  static Color get mist => _p(0xFFB9AD9C, 0xFF6E5F50);
  static Color get mist2 => _p(0xFFD6CBBB, 0xFF54473B);
  static Color get accent => _p(0xFFD2965A, 0xFF7E5228);
  static Color get accent2 => _p(0xFFDDA56C, 0xFF7E5228);
  static Color get onAccent => _p(0xFF1A120C, 0xFFFBF7F0);
  static Color get peri => _p(0xFFA9B8D4, 0xFF172338);
  static Color get rose => _p(0xFFD98A7A, 0xFF9A3F2F);
}

TextStyle inter(double size, {FontWeight w = FontWeight.w400, Color? c}) =>
    TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: w,
        // Inter is a variable font: set the weight axis too so bold really renders bold.
        fontVariations: [FontVariation('wght', w.value.toDouble())],
        color: c ?? C.text,
        fontFeatures: const [FontFeature.tabularFigures()]);

ThemeData creoTheme() {
  final dark = !lightMode.value;
  final base = ThemeData(brightness: dark ? Brightness.dark : Brightness.light, useMaterial3: true, fontFamily: 'Inter');
  final btnText = inter(16, w: FontWeight.w600);
  return base.copyWith(
    scaffoldBackgroundColor: C.ground,
    colorScheme: (dark ? ColorScheme.dark : ColorScheme.light)(
        primary: C.accent, onPrimary: C.onAccent, secondary: C.peri, surface: C.surface, onSurface: C.text, error: C.rose, outline: C.line),
    textTheme: base.textTheme.apply(bodyColor: C.text, displayColor: C.text),
    dividerTheme: DividerThemeData(color: C.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(backgroundColor: C.ground, surfaceTintColor: Colors.transparent, scrolledUnderElevation: 0),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.base,
      surfaceTintColor: Colors.transparent,
      indicatorColor: C.raised,
      height: 76,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected)
          ? inter(12, w: FontWeight.w600)
          : inter(12, c: C.mist)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? C.accent : C.mist)),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            backgroundColor: C.accent, foregroundColor: C.onAccent, minimumSize: const Size(48, 52), shape: const StadiumBorder(), textStyle: btnText)),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            foregroundColor: C.text, disabledForegroundColor: C.mist, minimumSize: const Size(48, 52), shape: const StadiumBorder(), side: BorderSide(color: C.line, width: 1.5), textStyle: btnText)),
    listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.zero, minVerticalPadding: 10, iconColor: C.mist, titleTextStyle: inter(16, w: FontWeight.w500), subtitleTextStyle: inter(14, c: C.mist)),
    snackBarTheme: SnackBarThemeData(backgroundColor: C.raised, contentTextStyle: inter(15), behavior: SnackBarBehavior.floating),
    badgeTheme: BadgeThemeData(backgroundColor: C.rose, textColor: C.onAccent, textStyle: inter(11, w: FontWeight.w700)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surface,
      labelStyle: inter(15, c: C.mist),
      hintStyle: inter(15, c: C.mist),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.accent, width: 1.5)),
      errorStyle: inter(13, c: C.rose),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: C.base, surfaceTintColor: Colors.transparent, showDragHandle: true),
    dialogTheme: DialogThemeData(backgroundColor: C.raised, surfaceTintColor: Colors.transparent),
    datePickerTheme: DatePickerThemeData(backgroundColor: C.raised, surfaceTintColor: Colors.transparent),
  );
}

void toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(msg)));

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;
  @override
  // Material, not a coloured box, so tap ripples on rows inside stay visible.
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
          color: C.surface, borderRadius: BorderRadius.circular(20), clipBehavior: Clip.antiAlias, child: Padding(padding: padding, child: child)));
}

Widget title(String t) => Padding(padding: const EdgeInsets.only(top: 4), child: Text(t, style: inter(28, w: FontWeight.w600)));
Widget sub(String t) => Padding(padding: const EdgeInsets.only(top: 4), child: Text(t, style: inter(16, c: C.mist)));
Widget sec(String t) => Padding(padding: const EdgeInsets.only(top: 20, bottom: 0), child: Text(t, style: inter(14, w: FontWeight.w600, c: C.mist)));

/// A status is always an icon plus a word, never colour alone.
class Status extends StatelessWidget {
  const Status(this.s, this.label, {super.key});
  final S s;
  final String label;
  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (s) {
      S.ok => (Icons.check_circle_outline, C.peri),
      S.bad => (Icons.error_outline, C.rose),
      S.wait => (Icons.schedule, C.accent2),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(label, style: inter(14, w: FontWeight.w500, c: color)),
    ]);
  }
}

/// "Sarah Connor" -> "SC", "Admin" -> "AD".
String initials(String name) {
  final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.length > 1 ? '${parts[0][0]}${parts[1][0]}' : parts[0].substring(0, parts[0].length < 2 ? 1 : 2)).toUpperCase();
}

class Initials extends StatelessWidget {
  const Initials(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(radius: 20, backgroundColor: C.raised, child: Text(initials(name), style: inter(14, w: FontWeight.w600, c: C.mist2)));
  }
}

/// Rows separated by dividers inside one panel.
class Rows extends StatelessWidget {
  const Rows(this.tiles, {super.key});
  final List<Widget> tiles;
  @override
  Widget build(BuildContext context) => Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Column(children: ListTile.divideTiles(context: context, tiles: tiles).toList()));
}

ListTile tile(String t, {String? s, Widget? lead, Widget? trail, VoidCallback? onTap}) =>
    ListTile(title: Text(t), subtitle: s == null ? null : Text(s), leading: lead, trailing: trail, onTap: onTap);

Widget money(int n, {double size = 16}) => Text(inr(n), style: inter(size));

/// Numbers in one panel, split by thin lines.
class Kv extends StatelessWidget {
  const Kv(this.items, {super.key});
  final List<(String, String)> items;
  @override
  Widget build(BuildContext context) => Panel(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
          child: Row(children: [
        for (final (i, (k, v)) in items.indexed) ...[
          if (i > 0) const VerticalDivider(width: 1),
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(k, style: inter(13, c: C.mist)),
                    const SizedBox(height: 2),
                    // Shrinks long amounts (₹2,25,000) to one line instead of wrapping a digit.
                    FittedBox(
                        fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(v, maxLines: 1, style: inter(20, w: FontWeight.w600))),
                  ]))),
        ],
      ])));
}

Widget meter(double v, Color c) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: LinearProgressIndicator(value: v, minHeight: 8, color: c, backgroundColor: C.raised, borderRadius: BorderRadius.circular(4)));

/// Selectable filter chips. Selected chip is ivory with dark text.
class Chips extends StatelessWidget {
  const Chips({super.key, required this.labels, required this.selected, required this.onSelect});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(spacing: 8, children: [
        for (final (i, l) in labels.indexed)
          ChoiceChip(
            label: Text(l),
            selected: i == selected,
            onSelected: (_) => onSelect(i),
            showCheckmark: false,
            labelStyle: inter(15, w: i == selected ? FontWeight.w600 : FontWeight.w400, c: i == selected ? C.ground : C.mist2),
            selectedColor: C.text,
            backgroundColor: C.ground,
            side: i == selected ? BorderSide.none : BorderSide(color: C.line, width: 1.5),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          ),
      ])));
}

/// A tab with a title and pill sub-tabs at the top (Content, Money, Team, Inbox).
class TabPage extends StatelessWidget {
  const TabPage({super.key, required this.name, required this.tabs, required this.pages, this.initial = 0});
  final String name;
  final int initial;
  final List<String> tabs;
  final List<Widget> pages;
  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: tabs.length,
      initialIndex: initial,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: title(name)),
        Container(
          margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(999)),
          child: TabBar(
            isScrollable: tabs.length > 4,
            tabAlignment: tabs.length > 4 ? TabAlignment.start : null,
            tabs: [for (final t in tabs) Tab(height: 40, child: Padding(padding: EdgeInsets.symmetric(horizontal: tabs.length > 4 ? 14 : 0), child: Text(t)))],
            indicator: BoxDecoration(color: C.raised, borderRadius: BorderRadius.circular(999), border: Border.all(color: C.line, width: 1.5)),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: C.text,
            unselectedLabelColor: C.mist,
            labelStyle: inter(14, w: FontWeight.w600),
            unselectedLabelStyle: inter(14),
            labelPadding: EdgeInsets.zero,
            splashBorderRadius: BorderRadius.circular(999),
          ),
        ),
        Expanded(child: TabBarView(children: pages)),
      ]));
}

/// Scrollable body with the page gutter.
Widget page(List<Widget> children) =>
    ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: children);

Widget twoButtons(Widget a, Widget b) =>
    Padding(padding: const EdgeInsets.only(top: 14), child: Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]));

/// Shown where a list has nothing yet. Keeps the frame so the screen does not jump.
Widget empty(String text) =>
    Panel(padding: const EdgeInsets.all(20), child: Text(text, style: inter(15, c: C.mist), textAlign: TextAlign.center));

/// Search field for the top of a list.
class SearchBox extends StatelessWidget {
  const SearchBox(this.hint, this.onChanged, {super.key});
  final String hint;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: TextField(
          onChanged: onChanged,
          style: inter(16),
          decoration: InputDecoration(
              hintText: hint, prefixIcon: Icon(Icons.search, color: C.mist), border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(999)), borderSide: BorderSide.none))));
}

/// One field in a [formSheet]. Give [options] for a dropdown, [date] for a date picker.
class F {
  const F(this.label, {this.options, this.required = false, this.date = false, this.number = false, this.lines = 1, this.initial = '', this.hint = ''});
  final String label, initial, hint;
  final List<String>? options;
  final bool required, date, number;
  final int lines;
}

/// A form in a bottom sheet. Returns the values by label, or null if closed.
/// Dates come back as yyyy-mm-dd.
Future<Map<String, String>?> formSheet(BuildContext context, String heading, List<F> fields, String action) =>
    showModalBottomSheet<Map<String, String>>(context: context, isScrollControlled: true, builder: (_) => _FormSheet(heading, fields, action));

class _FormSheet extends StatefulWidget {
  const _FormSheet(this.heading, this.fields, this.action);
  final String heading, action;
  final List<F> fields;
  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  final key = GlobalKey<FormState>();
  late final values = {for (final f in widget.fields) f.label: f.initial};

  @override
  Widget build(BuildContext context) {
    String? need(F f, String? v) => f.required && (v == null || v.trim().isEmpty)
        ? '${f.label} is needed'
        : f.number && (v ?? '').isNotEmpty && int.tryParse(v!) == null
            ? 'Numbers only'
            : f.number && (int.tryParse(v ?? '') ?? 0) < 0
                ? 'Must be 0 or more'
                : null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: key,
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
          Text(widget.heading, style: inter(22, w: FontWeight.w600)),
          for (final f in widget.fields)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: f.options != null
                  ? DropdownButtonFormField<String>(
                      initialValue: f.options!.contains(values[f.label]) ? values[f.label] : null,
                      items: [for (final o in f.options!) DropdownMenuItem(value: o, child: Text(o))],
                      onChanged: (v) => values[f.label] = v ?? '',
                      validator: (v) => need(f, v),
                      dropdownColor: C.raised,
                      style: inter(16),
                      decoration: InputDecoration(labelText: f.required ? '${f.label} *' : f.label),
                    )
                  : f.date
                      ? FormField<String>(
                          initialValue: values[f.label],
                          validator: (v) => need(f, v),
                          builder: (s) => InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              final d = await showDatePicker(
                                  context: context, firstDate: DateTime(2024), lastDate: DateTime(2030), initialDate: DateTime.tryParse(s.value ?? '') ?? DateTime.now());
                              if (d == null) return;
                              final v = d.toIso8601String().substring(0, 10);
                              values[f.label] = v;
                              s.didChange(v);
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                  labelText: f.required ? '${f.label} *' : f.label, errorText: s.errorText, suffixIcon: Icon(Icons.event, color: C.mist)),
                              child: Text((s.value ?? '').isEmpty ? 'Pick a date' : dm(DateTime.parse(s.value!)), style: inter(16)),
                            ),
                          ),
                        )
                      : TextFormField(
                          initialValue: values[f.label],
                          minLines: f.lines,
                          maxLines: f.lines,
                          keyboardType: f.number ? TextInputType.number : null,
                          style: inter(16),
                          onChanged: (v) => values[f.label] = v,
                          validator: (v) => need(f, v),
                          decoration: InputDecoration(labelText: f.required ? '${f.label} *' : f.label, hintText: f.hint.isEmpty ? null : f.hint),
                        ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: FilledButton(
                onPressed: () {
                  if (key.currentState!.validate()) Navigator.pop(context, {for (final e in values.entries) e.key: e.value.trim()});
                },
                child: Text(widget.action)),
          ),
        ]),
      ),
    );
  }
}

/// Opens a detail screen with a back bar. [build] runs again after every change.
void openPage(BuildContext context, String name, List<Widget> Function(BuildContext) build) => Navigator.push(
    context,
    MaterialPageRoute(
        builder: (_) => ListenableBuilder(
            listenable: changed,
            builder: (c, _) => Scaffold(appBar: AppBar(title: Text(name, style: inter(18, w: FontWeight.w600))), body: page(build(c))))));

/// Asks before something that cannot be undone.
Future<bool> confirm(BuildContext context, String question, String action) async =>
    await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: Text(question, style: inter(18, w: FontWeight.w600)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel', style: inter(15, c: C.mist2))),
                TextButton(onPressed: () => Navigator.pop(c, true), child: Text(action, style: inter(15, w: FontWeight.w600, c: C.rose))),
              ],
            )) ??
    false;

/// Small pill-shaped button used for actions inside cards.
Widget small(String label, VoidCallback onTap, {bool filled = false}) => filled
    ? FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(minimumSize: const Size(48, 44), padding: const EdgeInsets.symmetric(horizontal: 16), textStyle: inter(14, w: FontWeight.w600)),
        child: Text(label))
    : OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 44), padding: const EdgeInsets.symmetric(horizontal: 16), textStyle: inter(14, w: FontWeight.w600)),
        child: Text(label));

Widget actions(List<Widget> buttons) => Padding(padding: const EdgeInsets.only(top: 12), child: Wrap(spacing: 8, runSpacing: 8, children: buttons));

/// A full-width primary button with the standard top gap.
Widget mainButton(String label, VoidCallback onTap) => Padding(padding: const EdgeInsets.only(top: 14), child: FilledButton(onPressed: onTap, child: Text(label)));

DateTime? parseDate(String? v) => v == null || v.isEmpty ? null : DateTime.tryParse(v);
int toInt(String? v) => int.tryParse(v ?? '') ?? 0;
