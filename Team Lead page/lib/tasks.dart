// Task queue (/lead/tasks on the site): the pod's sprint board as one list with stage and format filters.
import 'package:flutter/material.dart';

import 'data.dart';
import 'home.dart';
import 'review.dart';
import 'ui.dart';

class TasksTab extends StatefulWidget {
  const TasksTab({super.key});
  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  int stage = 0, format = 0;
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = Stage.values[stage];
    final shown = inStage(s).where((t) => (format == 0 || t.format == Format.values[format - 1]) && matches(q, [t.title, t.client.name, t.who.name])).toList();
    final active = tasks.where((t) => t.stage != Stage.dispatched).length;
    return page([
      title('Task queue'),
      sub('${pod.name} sprint · lead ${me.name}'),
      Kv([('Active', '$active'), ('In QA', '${inStage(Stage.review).length}'), ('Blocked', '${blocked.length}')]),
      twoButtons(
        OutlinedButton(onPressed: () => exportTasks(context), child: const Text('Export report')),
        FilledButton(onPressed: () => assignForm(context), child: const Text('Assign task')),
      ),
      if (blocked.isNotEmpty) ...[
        sec('Blockers'),
        for (final t in blocked)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline, size: 18, color: C.rose),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t.blocker, style: inter(15, w: FontWeight.w500)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${t.title} · ${t.client.name} · ${t.who.name}', style: inter(14, c: C.mist)),
                actions([small('Clear blocker', () => setBlocker(t, '')), small('Re-route', () => rerouteForm(context, t))]),
              ],
            ),
          ),
      ],
      Chips(labels: [for (final st in Stage.values) '${st.label} ${inStage(st).length}'], selected: stage, onSelect: (i) => setState(() => stage = i)),
      Chips(labels: ['All formats', for (final f in Format.values) f.label], selected: format, onSelect: (i) => setState(() => format = i)),
      SearchBox('Search task, client or person', (v) => setState(() => q = v)),
      if (shown.isEmpty) empty(tasks.isEmpty ? 'No tasks yet. Assign one to a pod member.' : 'No tasks here'),
      for (final t in shown) TaskCard(t),
    ]);
  }
}

Future<void> rerouteForm(BuildContext context, Task t) async {
  final others = members.where((m) => m != t.who).toList();
  if (others.isEmpty) return toast(context, 'Add another pod member first');
  final v = await formSheet(context, 'Re-route task', [
    F('Send to', options: [for (final m in others) '${m.name} · ${load(m)}% load'], required: true),
  ], 'Re-route');
  if (v == null || !context.mounted) return;
  final to = others.firstWhere((m) => v['Send to']!.startsWith('${m.name} · '));
  reassign(t, to);
  toast(context, 'Re-routed to ${to.name}');
}

Future<void> blockForm(BuildContext context, Task t) async {
  final v = await formSheet(context, 'Mark blocked', [const F('What is it waiting on?', required: true, hint: 'e.g. client copy sign-off')], 'Mark blocked');
  if (v == null || !context.mounted) return;
  setBlocker(t, v['What is it waiting on?']!);
}

class TaskCard extends StatelessWidget {
  const TaskCard(this.t, {super.key});
  final Task t;

  String get age {
    final h = DateTime.now().difference(t.created).inHours;
    return h < 24 ? '${h}h' : dayCount(h ~/ 24);
  }

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(t.client.name, style: inter(14, c: C.mist)),
            ),
            stageTag(t.stage),
          ],
        ),
        const SizedBox(height: 4),
        Text(t.title, style: inter(16, w: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          [t.format.label, t.who.name, if (t.version > 0) 'v${t.version}', if (t.due != null) 'due ${dm(t.due!)}', 'open $age'].join(' · '),
          style: inter(14, c: t.late ? C.rose : C.mist),
        ),
        if (t.blocker.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Tag(Icons.error_outline, 'Blocked: ${t.blocker}', C.rose)),
        actions([
          ...switch (t.stage) {
            Stage.backlog => [small('Start', () => startTask(t), filled: true)],
            Stage.progress => [
              small('Send to QA', () {
                sendToQa(t);
                toast(context, 'v${t.version} is in your review queue');
              }, filled: true),
              if (t.blocker.isEmpty) small('Mark blocked', () => blockForm(context, t)),
            ],
            Stage.review => [small('Inspect', () => openReview(context, t), filled: true)],
            Stage.dispatched => [small('History', () => openReview(context, t))],
          },
          if (t.stage != Stage.dispatched) small('Re-route', () => rerouteForm(context, t)),
        ]),
      ],
    ),
  );
}
