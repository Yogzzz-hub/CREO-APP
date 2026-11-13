// Client allocations (/lead/clients on the site): the pod's retainers and this month's quota burn.
import 'package:flutter/material.dart';

import 'data.dart';
import 'home.dart';
import 'save_csv.dart' if (dart.library.js_interop) 'save_csv_web.dart';
import 'tasks.dart';
import 'ui.dart';

class ClientsTab extends StatefulWidget {
  const ClientsTab({super.key});
  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<ClientsTab> {
  int filter = 0;
  String q = '';

  bool waiting(Client c) => inStage(Stage.review).any((t) => t.client == c);

  Future<void> add() async {
    final v = await formSheet(context, 'Add client', [
      F('Brand name', required: true, check: (s) => nameTaken(clients.map((c) => c.name), s) ? 'Already a client' : null),
      F('Plan', options: plans.keys.toList(), required: true, initial: 'Growth'),
      F('Contact email', check: (s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s) ? null : 'Enter a valid email'),
    ], 'Add client');
    if (v == null || !mounted) return;
    save(() => clients.add(Client(v['Brand name']!, v['Plan']!, email: v['Contact email']!)));
    toast(context, '${v['Brand name']} added to ${pod.name}');
  }

  Future<void> export() async {
    if (clients.isEmpty) return toast(context, 'No clients to export yet');
    final done = await saveCsv('creo-pod-clients.csv', clientsCsv());
    if (mounted) toast(context, done);
  }

  @override
  Widget build(BuildContext context) {
    final used = clients.fold(0, (s, c) => s + Format.values.fold(0, (n, f) => n + delivered(c, f)));
    final shown = clients.where((c) => (filter == 0 || waiting(c)) && matches(q, [c.name, c.plan, c.email])).toList();
    return page([
      title('Clients'),
      sub('${pod.name} · ${plural(clients.length, 'retainer')}'),
      Kv([('Clients', '${clients.length}'), ('Quota used', '$used/$podQuota'), ('To sign off', '${inStage(Stage.review).length}')]),
      twoButtons(OutlinedButton(onPressed: export, child: const Text('Export report')), FilledButton(onPressed: add, child: const Text('Add client'))),
      Chips(labels: ['All ${clients.length}', 'Pending QA ${clients.where(waiting).length}'], selected: filter, onSelect: (i) => setState(() => filter = i)),
      SearchBox('Search clients', (v) => setState(() => q = v)),
      if (shown.isEmpty) empty(clients.isEmpty ? 'No clients yet. The admin allocates retainers to your pod.' : 'No match'),
      for (final c in shown) _ClientCard(c),
    ]);
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard(this.c);
  final Client c;
  @override
  Widget build(BuildContext context) => Panel(
    padding: EdgeInsets.zero,
    child: InkWell(
      onTap: () => openClient(context, c),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                initials(c.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: inter(16, w: FontWeight.w500)),
                      Text(c.plan, style: inter(14, c: C.mist)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: C.mist),
              ],
            ),
            const SizedBox(height: 12),
            quotaRow(c),
            const SizedBox(height: 12),
            Meter(burn(c)),
          ],
        ),
      ),
    ),
  );
}

/// Reels, stories and posts delivered this month against the plan.
Widget quotaRow(Client c) => Row(
  children: [
    for (final (label, done, of) in [
      ('Reels', delivered(c, Format.reel), c.quota.reels),
      ('Stories', delivered(c, Format.story), c.quota.stories),
      ('Posts', delivered(c, Format.post) + delivered(c, Format.carousel), c.quota.posts),
    ])
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: inter(13, c: C.mist)),
            Text('$done/$of', style: inter(16, w: FontWeight.w500)),
          ],
        ),
      ),
  ],
);

void openClient(BuildContext context, Client c) => openPage(context, c.name, (ctx) {
  final work = tasks.where((t) => t.client == c).toList();
  return [
    title(c.name),
    sub('${c.plan}${c.email.isEmpty ? '' : ' · ${c.email}'}'),
    Panel(child: Column(children: [quotaRow(c), const SizedBox(height: 12), Meter(burn(c))])),
    Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text('${burn(c)}% of this month\'s quota delivered', style: inter(13, c: C.mist)),
    ),
    twoButtons(
      OutlinedButton(
        onPressed: () async {
          final v = await formSheet(ctx, 'Change plan', [F('Plan', options: plans.keys.toList(), required: true, initial: c.plan)], 'Save');
          if (v != null) save(() => c.plan = v['Plan']!);
        },
        child: const Text('Change plan'),
      ),
      FilledButton(onPressed: () => assignForm(ctx), child: const Text('Assign task')),
    ),
    sec('Work for ${c.name}'),
    if (work.isEmpty) empty('No tasks for this client yet'),
    for (final t in work) TaskCard(t),
  ];
});
