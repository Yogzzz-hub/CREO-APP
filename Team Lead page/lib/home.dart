// Pod dashboard (/admin/pod-dashboard on the site) and the forms it shares with other tabs.
import 'package:flutter/material.dart';

import 'data.dart';
import 'save_csv.dart' if (dart.library.js_interop) 'save_csv_web.dart';
import 'ui.dart';

// ---------- Shared forms ----------
Future<void> addMemberForm(BuildContext context) async {
  final v = await formSheet(context, 'Add pod member', [
    F('Name', required: true, check: memberNameProblem),
    const F('Role', required: true, hint: 'e.g. Senior Video Editor'),
  ], 'Add to pod');
  if (v == null || !context.mounted) return;
  addMember(v['Name']!, v['Role']!);
  toast(context, '${v['Name']} added to ${pod.name}');
}

/// Assign Deliverable on the site: title, format, client, specialist.
Future<void> assignForm(BuildContext context, {Member? to}) async {
  if (clients.isEmpty) return toast(context, 'Add a client first, on the Clients tab');
  final v = await formSheet(context, 'Assign task', [
    const F('Task title', required: true, hint: 'e.g. 3D product loop animation (15s)'),
    F('Format', options: [for (final f in Format.values) f.label], required: true, initial: Format.reel.label),
    F('Client', options: [for (final c in clients) c.name], required: true, initial: clients.length == 1 ? clients.first.name : ''),
    F('Specialist', options: [for (final m in members) m.name], required: true, initial: to?.name ?? (members.length <= 2 ? members.last.name : '')),
    const F('Due date', date: true),
    const F('Brief', lines: 3),
  ], 'Assign');
  if (v == null || !context.mounted) return;
  final due = parseDate(v['Due date']);
  if (due != null && due.isBefore(today)) return toast(context, 'The due date is in the past');
  final who = members.firstWhere((m) => m.name == v['Specialist']);
  assign(
    title: v['Task title']!,
    client: clients.firstWhere((c) => c.name == v['Client']),
    format: Format.values.firstWhere((f) => f.label == v['Format']),
    who: who,
    due: due,
    brief: v['Brief']!,
  );
  toast(context, onLeave(who, today) ? 'Assigned. ${who.name} is on leave today' : 'Assigned to ${who.name}');
}

Future<void> standupForm(BuildContext context) async {
  final v = await formSheet(context, 'Log ${pod.name} standup', [
    const F('Attendance, blockers and commitments', required: true, lines: 4, hint: 'All members present. No critical blockers.'),
  ], 'Save standup');
  if (v == null || !context.mounted) return;
  save(() => standups.insert(0, Standup(v['Attendance, blockers and commitments']!)));
  toast(context, 'Standup saved');
}

Future<void> revisionForm(BuildContext context, Task t) async {
  final v = await formSheet(context, 'Request revision', [
    const F('Notes for the creative', required: true, lines: 4, hint: 'What to change, and why'),
  ], 'Send back');
  if (v == null || !context.mounted) return;
  requestRevision(t, v['Notes for the creative']!);
  toast(context, 'Sent back to ${t.who.name}');
}

Future<void> exportTasks(BuildContext context) async {
  if (tasks.isEmpty) return toast(context, 'No tasks to export yet');
  final done = await saveCsv('creo-pod-report.csv', tasksCsv());
  if (context.mounted) toast(context, done);
}

/// Current tasks of one member, from the roster.
void openWorkload(BuildContext context, Member m) => openPage(context, '${m.name} workload', (c) {
  final open = openTasks(m);
  return [
    title(m.name),
    sub('${m.role} · ${load(m)}% load${onLeave(m, today) ? ' · on leave today' : ''}'),
    if (open.isEmpty) empty('No open tasks'),
    for (final t in open)
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t.title, style: inter(16, w: FontWeight.w500)),
                ),
                stageTag(t.stage),
              ],
            ),
            const SizedBox(height: 4),
            Text('${t.client.name} · ${t.format.label}${t.due == null ? '' : ' · due ${dm(t.due!)}'}', style: inter(14, c: t.late ? C.rose : C.mist)),
          ],
        ),
      ),
    mainButton('Assign task to ${m.name}', () => assignForm(c, to: m)),
  ];
});

// ---------- Dashboard ----------
class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.go});

  /// Jumps to a bottom tab: 1 Review, 2 Tasks, 3 Clients.
  final ValueChanged<int> go;

  @override
  Widget build(BuildContext context) {
    final queue = inStage(Stage.review);
    final urgent = queue.where((t) => t.late).length;
    final pending = toDecide;
    return page([
      Text(
        'Active shift · ${me.name}',
        style: inter(14, w: FontWeight.w500, c: C.accent2),
      ),
      title(pod.name),
      sub(standupLoggedToday ? 'Standup logged today' : 'Standup not logged yet today'),
      twoButtons(
        OutlinedButton(onPressed: () => standupForm(context), child: const Text('Log standup')),
        FilledButton(onPressed: () => assignForm(context), child: const Text('Assign task')),
      ),
      Kv([('Capacity', '$activeToday/${members.length}'), ('To review', '${queue.length}'), ('Leave asks', '${pending.length}')]),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          [
            '${members.isEmpty ? 0 : activeToday * 100 ~/ members.length}% of the pod working today',
            if (urgent > 0) '$urgent overdue in review',
            if (startingTomorrow > 0) '$startingTomorrow leave from tomorrow',
          ].join(' · '),
          style: inter(13, c: urgent > 0 ? C.rose : C.mist),
        ),
      ),

      // Roster
      Row(
        children: [
          Expanded(child: sec('Team roster · ${plural(members.length, 'member')}')),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: TextButton(
              onPressed: () {
                final n = balanceLoads();
                toast(context, n == 0 ? 'Loads are already balanced' : 'Moved ${plural(n, 'backlog task')}');
              },
              child: Text(
                'Balance loads',
                style: inter(14, w: FontWeight.w500, c: C.accent2),
              ),
            ),
          ),
        ],
      ),
      Rows([
        for (final m in members)
          ListTile(
            leading: initials(m.name),
            title: Text(m.lead ? '${m.name} (you)' : m.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${m.role}${onLeave(m, today) ? ' · on leave' : ''}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Meter(load(m))),
                    const SizedBox(width: 12),
                    Text('${plural(openTasks(m).length, 'task')} · ${load(m)}%', style: inter(13, c: C.mist)),
                  ],
                ),
              ],
            ),
            trailing: Icon(Icons.chevron_right, color: C.mist),
            onTap: () => openWorkload(context, m),
          ),
      ]),
      actions([small('Add member', () => addMemberForm(context))]),

      // Sign-off
      sec('Waiting for your sign-off'),
      if (queue.isEmpty) empty('Nothing to review. Work sent for QA shows here.'),
      for (final t in queue.take(3)) SignOffCard(t, onOpen: () => go(1)),
      if (queue.length > 3) actions([small('See all ${queue.length}', () => go(1))]),

      // Leave
      sec('Leave requests'),
      if (pending.isEmpty) empty('No leave requests waiting'),
      for (final l in pending) LeaveCard(l),

      // Clients
      sec('Client velocity'),
      if (clients.isEmpty)
        empty('No clients yet')
      else
        Panel(
          child: Column(
            children: [
              for (final c in clients.take(4))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(c.name, style: inter(15), overflow: TextOverflow.ellipsis),
                      ),
                      Expanded(flex: 3, child: Meter(burn(c))),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${burn(c)}%',
                          textAlign: TextAlign.end,
                          style: inter(13, c: C.mist),
                        ),
                      ),
                    ],
                  ),
                ),
              if (clients.length > 4)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(onPressed: () => go(3), child: const Text('All clients')),
                ),
            ],
          ),
        ),

      sec('Quick actions'),
      twoButtons(
        OutlinedButton(onPressed: () => go(2), child: const Text('Task queue')),
        OutlinedButton(onPressed: () => exportTasks(context), child: const Text('Export CSV')),
      ),
    ]);
  }
}

/// A task waiting for the lead, with the two decisions. Approve opens the checklist on Review.
class SignOffCard extends StatelessWidget {
  const SignOffCard(this.t, {super.key, required this.onOpen});
  final Task t;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('${t.client.name} · ${t.who.name}', style: inter(14, c: C.mist)),
            ),
            if (t.due != null) Text(dm(t.due!), style: inter(13, c: t.late ? C.rose : C.mist)),
          ],
        ),
        const SizedBox(height: 4),
        Text(t.title, style: inter(16, w: FontWeight.w500)),
        Text('${t.format.label} · v${t.version}', style: inter(14, c: C.mist)),
        actions([small('Request revision', () => revisionForm(context, t)), small('Review', onOpen, filled: true)]),
      ],
    ),
  );
}

class LeaveCard extends StatelessWidget {
  const LeaveCard(this.l, {super.key});
  final Leave l;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            initials(l.who.name, r: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Text(l.who.name, style: inter(16, w: FontWeight.w500)),
            ),
            stateTag(l.status),
          ],
        ),
        const SizedBox(height: 8),
        Text('${l.days == 1 ? dm(l.start) : '${dm(l.start)} to ${dm(l.end)}'} · ${dayCount(l.days)}', style: inter(14, c: C.mist2)),
        if (l.reason.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l.reason, style: inter(14, c: C.mist)),
          ),
        if (l.status == 'Pending' && l.who != me)
          actions([
            small('Decline', () async {
              if (await confirm(context, 'Decline ${l.who.name}\'s leave?', 'Decline')) decide(l, false);
            }),
            small('Approve leave', () {
              decide(l, true);
              toast(context, 'Leave approved for ${l.who.name}');
            }, filled: true),
          ]),
      ],
    ),
  );
}
