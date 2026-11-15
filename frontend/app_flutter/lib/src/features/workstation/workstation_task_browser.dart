import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'workstation_data.dart';

enum WorkstationTaskSort {
  due('Due date'),
  client('Brand A–Z'),
  title('Task A–Z');

  const WorkstationTaskSort(this.label);
  final String label;
}

/// Presentation-only filtering. Callers supply already authorized/scoped rows.
/// Always copies before sorting and never changes assignment or server status.
List<WorkstationTask> browseWorkstationTasks(
  Iterable<WorkstationTask> source, {
  String query = '',
  WorkstationTaskSort sort = WorkstationTaskSort.due,
  String stage = '',
  bool dueOnly = false,
  Set<String>? pinnedIds,
  DateTime? now,
}) {
  final needle = query.trim().toLowerCase();
  final clock = now ?? DateTime.now();
  final tomorrow = DateTime(clock.year, clock.month, clock.day + 1);
  final rows = source.where((task) {
    final shownStatus = switch (task.status) {
      'in_production' => 'in progress',
      'internal_qa' => 'in qa',
      'yet_to_do' => 'backlog',
      _ => '',
    };
    if (stage.isNotEmpty &&
        !(stage == 'backlog'
            ? const ['backlog', 'yet_to_do'].contains(task.status)
            : task.status == stage)) {
      return false;
    }
    if (dueOnly &&
        (task.due == null || !task.due!.toLocal().isBefore(tomorrow))) {
      return false;
    }
    if (pinnedIds != null && !pinnedIds.contains(task.id)) return false;
    return needle.isEmpty ||
        '${task.title} ${task.client} ${task.format.replaceAll('_', ' ')} ${task.status.replaceAll('_', ' ')} $shownStatus'
            .toLowerCase()
            .contains(needle);
  }).toList();
  int alphabetic(WorkstationTask a, WorkstationTask b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());
  rows.sort((a, b) {
    final primary = switch (sort) {
      WorkstationTaskSort.client => a.client.toLowerCase().compareTo(
        b.client.toLowerCase(),
      ),
      WorkstationTaskSort.title => alphabetic(a, b),
      WorkstationTaskSort.due =>
        a.due == null
            ? (b.due == null ? 0 : 1)
            : b.due == null
            ? -1
            : a.due!.compareTo(b.due!),
    };
    if (primary != 0) return primary;
    final title = alphabetic(a, b);
    return title != 0 ? title : a.id.compareTo(b.id);
  });
  return rows;
}

class WorkstationSearch extends StatelessWidget {
  const WorkstationSearch({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.fieldKey,
    this.label = 'Search tasks or brands',
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String fieldKey, label;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, value, _) => TextField(
      key: ValueKey(fieldKey),
      controller: controller,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: value.text.isEmpty
            ? null
            : IconButton(
                key: ValueKey('$fieldKey-clear'),
                tooltip: 'Clear task search',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.close),
              ),
      ),
    ),
  );
}

class WorkstationSortMenu extends StatelessWidget {
  const WorkstationSortMenu({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final WorkstationTaskSort value;
  final ValueChanged<WorkstationTaskSort> onChanged;

  @override
  Widget build(BuildContext context) => PopupMenuButton<WorkstationTaskSort>(
    tooltip: 'Sort deliverables',
    popUpAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    initialValue: value,
    onSelected: onChanged,
    itemBuilder: (context) => [
      for (final sort in WorkstationTaskSort.values)
        PopupMenuItem(value: sort, child: Text(sort.label)),
    ],
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(Icons.sort, size: 20, color: context.creo.accent),
            Text(
              'Sort: ${value.label}',
              style: TextStyle(color: context.creo.appInk, fontSize: 14),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Owns search/focus lifetime inside the existing keyboard-safe bottom sheet.
class WorkstationTaskBrowser extends StatefulWidget {
  const WorkstationTaskBrowser({
    super.key,
    required this.rows,
    required this.tileBuilder,
    this.caption,
  });
  final List<WorkstationTask> rows;
  final Widget Function(WorkstationTask task) tileBuilder;
  final String? caption;

  @override
  State<WorkstationTaskBrowser> createState() => _WorkstationTaskBrowserState();
}

class _WorkstationTaskBrowserState extends State<WorkstationTaskBrowser> {
  final _search = TextEditingController();
  WorkstationTaskSort _sort = WorkstationTaskSort.due;
  String _stage = '';
  int _visible = 20;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _change(VoidCallback operation) => setState(() {
    operation();
    _visible = 20;
  });

  @override
  Widget build(BuildContext context) {
    final rows = browseWorkstationTasks(
      widget.rows,
      query: _search.text,
      sort: _sort,
      stage: _stage,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.caption != null) ...[
          Text(
            widget.caption!,
            style: TextStyle(
              color: context.creo.appMist,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
        ],
        WorkstationSearch(
          controller: _search,
          fieldKey: 'queue-search',
          onChanged: (_) => _change(() {}),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final stage in const [
              ('', 'All'),
              ('in_production', 'In progress'),
              ('internal_qa', 'In QA'),
              ('backlog', 'Backlog'),
            ])
              ChoiceChip(
                label: Text(stage.$2),
                selected: _stage == stage.$1,
                onSelected: (_) => _change(() => _stage = stage.$1),
              ),
          ],
        ),
        WorkstationSortMenu(
          value: _sort,
          onChanged: (value) => _change(() => _sort = value),
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            '${rows.length} matching ${rows.length == 1 ? 'task' : 'tasks'}',
            style: TextStyle(color: context.creo.appMist, fontSize: 14),
          ),
        ),
        if (rows.isEmpty) ...[
          const SizedBox(height: 20),
          const Text('No tasks match this search and status.'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _change(() {
              _search.clear();
              _stage = '';
            }),
            child: const Text('Clear filters'),
          ),
        ] else ...[
          for (final task in rows.take(_visible)) widget.tileBuilder(task),
          if (rows.length > _visible) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => setState(() => _visible += 20),
              child: Text('Show more (${rows.length - _visible} remaining)'),
            ),
          ],
        ],
      ],
    );
  }
}
