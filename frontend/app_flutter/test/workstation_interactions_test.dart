import 'package:app_flutter/src/core/app_appearance.dart';
import 'package:app_flutter/src/core/app_theme.dart';
import 'package:app_flutter/src/features/workstation/workstation_data.dart';
import 'package:app_flutter/src/features/workstation/workstation_page.dart';
import 'package:app_flutter/src/features/workstation/workstation_task_browser.dart';
import 'package:app_flutter/workstation_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkstationTask row(
  String id,
  String title,
  String client, {
  DateTime? due,
  String status = 'in_production',
}) => WorkstationTask(
  id: id,
  title: title,
  client: client,
  format: 'reel',
  status: status,
  due: due,
);

void main() {
  test(
    'search matches visible status/title/brand, sorting never mutates loaded rows',
    () {
      final source = [row('b', 'Zebra', 'Bravo'), row('a', 'Alpha', 'Acme')];
      expect(browseWorkstationTasks(source, query: ' ACME ').single.id, 'a');
      expect(browseWorkstationTasks(source, query: 'in progress').length, 2);
      expect(browseWorkstationTasks(source, query: '[.*]'), isEmpty);
      expect(
        browseWorkstationTasks(
          source,
          sort: WorkstationTaskSort.client,
        ).map((t) => t.id),
        ['a', 'b'],
      );
      expect(
        browseWorkstationTasks(
          source,
          sort: WorkstationTaskSort.title,
        ).map((t) => t.id),
        ['a', 'b'],
      );
      expect(source.map((t) => t.id), ['b', 'a']);
    },
  );

  test('due filter, QA filter and pin filter compose without adding tasks', () {
    final source = [
      row('old', 'Old', 'Brand', due: DateTime(2030, 1, 1)),
      row(
        'today',
        'Today',
        'Brand',
        due: DateTime(2030, 1, 2, 23),
        status: 'internal_qa',
      ),
      row('future', 'Future', 'Brand', due: DateTime(2030, 1, 3)),
      row('none', 'Undated', 'Brand'),
    ];
    expect(
      browseWorkstationTasks(
        source,
        dueOnly: true,
        now: DateTime(2030, 1, 2),
      ).map((t) => t.id),
      ['old', 'today'],
    );
    expect(
      browseWorkstationTasks(
        source,
        dueOnly: true,
        stage: 'internal_qa',
        pinnedIds: {'today'},
        now: DateTime(2030, 1, 2),
      ).single.id,
      'today',
    );
    expect(browseWorkstationTasks(source, pinnedIds: {}), isEmpty);
    expect(
      browseWorkstationTasks(source, pinnedIds: {'unknown-account-task'}),
      isEmpty,
    );
  });

  Future<void> mount(
    WidgetTester tester, {
    double scale = 1,
    bool reduced = false,
    Size size = const Size(393, 852),
    LoadWorkstation? load,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final appearance = CreoAppearance(
      read: () async => null,
      write: (_) async {},
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
    });
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: appearance,
        builder: (context, _) => MaterialApp(
          theme: buildCreoTheme(brightness: Brightness.light),
          darkTheme: buildCreoTheme(),
          themeMode: appearance.mode,
          builder: (context, child) => CreoAppearanceScope(
            appearance: appearance,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: reduced,
              ),
              child: child!,
            ),
          ),
          home: WorkstationPage(
            user: workstationPreviewUser,
            load: load ?? loadWorkstationPreview,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> show(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  final search = find.byKey(const Key('deliverables-search'));

  testWidgets('search and clear update real results without reloading data', (
    tester,
  ) async {
    var loads = 0;
    await mount(
      tester,
      load: () {
        loads++;
        return loadWorkstationPreview();
      },
    );
    await show(tester, search);
    await tester.enterText(search, 'behind');
    await tester.pumpAndSettle();
    expect(find.text('1 matching deliverable'), findsOneWidget);
    expect(find.byKey(const Key('task-preview-3')), findsOneWidget);
    expect(find.byKey(const Key('task-preview-1')), findsNothing);
    await tester.enterText(search, 'no matching work');
    await tester.pumpAndSettle();
    expect(find.text('No matching deliverables'), findsOneWidget);
    await tester.tap(find.byKey(const Key('deliverables-search-clear')));
    await tester.pumpAndSettle();
    expect(find.text('2 matching deliverables'), findsOneWidget);
    expect(loads, 1);
  });

  testWidgets('pin filtering and Undo work without opening task details', (
    tester,
  ) async {
    await mount(tester);
    final pin = find.byKey(const Key('pin-preview-3'));
    await show(tester, pin);
    for (var tap = 0; tap < 5; tap++) {
      await tester.tap(pin);
    }
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(pin).isSelected, true);
    expect(find.text('Deliverable details'), findsNothing);
    final filter = find.byKey(const Key('filter-pinned'));
    await show(tester, filter);
    await tester.tap(filter);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-preview-1')), findsNothing);
    expect(find.byKey(const Key('task-preview-3')), findsOneWidget);
    await show(tester, pin);
    await tester.tap(pin);
    await tester.pumpAndSettle();
    expect(find.text('No matching deliverables'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-preview-3')), findsOneWidget);
    expect(tester.widget<IconButton>(pin).isSelected, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sort and search survive a real light/dark change', (
    tester,
  ) async {
    await mount(tester);
    final sort = find.byKey(const Key('deliverables-sort'));
    await show(tester, sort);
    await tester.tap(sort);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Task A–Z'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<WorkstationSortMenu>(sort).value,
      WorkstationTaskSort.title,
    );
    await show(tester, search);
    await tester.enterText(search, 'behind');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appearance-toggle')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, 'behind');
    expect(
      tester.widget<WorkstationSortMenu>(sort).value,
      WorkstationTaskSort.title,
    );
    expect(find.byKey(const Key('task-preview-3')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('queue search, task details and platform Back retain the query', (
    tester,
  ) async {
    await mount(tester);
    final browse = find.byKey(const Key('browse-tasks'));
    await show(tester, browse);
    await tester.tap(browse);
    await tester.pumpAndSettle();
    final queueSearch = find.byKey(const Key('queue-search'));
    await show(tester, queueSearch);
    await tester.enterText(queueSearch, 'launch');
    await tester.pumpAndSettle();
    expect(find.text('1 matching task'), findsOneWidget);
    final task = find.byKey(const Key('task-preview-4'));
    await show(tester, task);
    await tester.tap(task);
    await tester.pumpAndSettle();
    expect(find.text('Deliverable details'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Your task queue'), findsOneWidget);
    expect(tester.widget<TextField>(queueSearch).controller!.text, 'launch');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'narrow large-text search and keyboard-safe queue can close while focused',
    (tester) async {
      await mount(tester, size: const Size(280, 640), scale: 2, reduced: true);
      await show(tester, search);
      await tester.enterText(search, 'behind');
      await tester.pumpAndSettle();
      final browse = find.byKey(const Key('browse-tasks'));
      await show(tester, browse);
      await tester.tap(browse);
      await tester.pumpAndSettle();
      final queue = find.byKey(const Key('queue-search'));
      await show(tester, queue);
      await tester.showKeyboard(queue);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      await tester.enterText(queue, 'launch');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('queue-search')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('queue search includes tasks beyond the first visible batch', (
    tester,
  ) async {
    await mount(
      tester,
      load: () async => WorkstationData(
        podName: 'Bulk Pod',
        inProduction: List.generate(
          30,
          (index) => WorkstationTask(
            id: 'bulk-$index',
            client: 'Sample brand',
            title: 'Bulk task ${index.toString().padLeft(2, '0')}',
            format: 'reel',
            status: 'in_production',
            assignedTo: workstationPreviewUser.id,
          ),
        ),
      ),
    );
    final browse = find.byKey(const Key('browse-tasks'));
    await show(tester, browse);
    await tester.tap(browse);
    await tester.pumpAndSettle();
    final queue = find.byKey(const Key('queue-search'));
    await show(tester, queue);
    await tester.enterText(queue, 'task 29');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-bulk-29')), findsOneWidget);
    await tester.tap(find.byKey(const Key('queue-search-clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-bulk-29')), findsNothing);
    final more = find.text('Show more (10 remaining)');
    await show(tester, more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-bulk-29')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'active task card resets active filters and scrolls without motion when requested',
    (tester) async {
      await mount(tester, reduced: true);
      await show(tester, search);
      await tester.enterText(search, 'no match');
      await tester.pumpAndSettle();
      final active = find.text('ACTIVE TASKS');
      await show(tester, active);
      await tester.tap(active);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(find.text('2 matching deliverables'), findsOneWidget);
      expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('scope-mine'))).selected,
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
