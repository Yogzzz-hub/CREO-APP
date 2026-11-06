import 'package:flutter/material.dart';

import 'data.dart';
import 'ui.dart';

class ContentTab extends StatelessWidget {
  const ContentTab({super.key, this.initial = 0});
  final int initial;
  @override
  Widget build(BuildContext context) => TabPage(
      name: 'Content', initial: initial, tabs: const ['Review', 'Calendar', 'Tasks', 'Publish'], pages: [_Review(), _Calendar(), _Tasks(), _Publish()]);
}

const _draftNames = ['To review', 'Changes asked', 'Approved', 'Published'];

/// New draft form. Shared by Review and Calendar.
Future<void> newDraft(BuildContext context, {DateTime? on}) async {
  if (clients.isEmpty) return toast(context, 'Add a client first (Team, Clients)');
  final v = await formSheet(context, 'New draft', [
    const F('Title', required: true, hint: 'e.g. Biryani in 30 seconds'),
    F('Client', options: clientNames, required: true),
    const F('Format', options: formats, required: true),
    F('Pod', options: podNames),
    F('Posting date', date: true, required: true, initial: on?.toIso8601String().substring(0, 10) ?? ''),
  ], 'Add draft');
  if (v == null) return;
  save(() => deliverables.add(Deliverable(v['Title']!, v['Client']!, v['Format']!, v['Pod']!, parseDate(v['Posting date'])!)));
  if (context.mounted) toast(context, 'Draft added for review');
}

void _setDraft(BuildContext context, Deliverable d, Draft to, String msg) {
  save(() {
    final withdrawing = d.state == Draft.published && to == Draft.approved;
    d.state = to;
    if (to == Draft.published) posts.add(Post(d.title, d.client, d.date, 'Published', source: d));
    // Only a withdraw cancels, and only this draft's own published posts.
    if (withdrawing) {
      for (final p in posts.where((p) => p.source == d && p.status == 'Published')) {
        p.status = 'Canceled';
      }
    }
  });
  toast(context, msg);
}

Future<void> _addNote(BuildContext context, Deliverable d) async {
  final v = await formSheet(context, 'Note on ${d.title}', [const F('Note', required: true, lines: 3)], 'Save note');
  if (v != null) save(() => d.notes.add(v['Note']!));
}

/// The buttons for a draft, by its state. The first card on a screen gets the filled button.
List<Widget> _draftActions(BuildContext context, Deliverable d, {bool filled = true}) => switch (d.state) {
      Draft.review => [
          small('Note', () => _addNote(context, d)),
          small('Ask for changes', () => _setDraft(context, d, Draft.revision, 'Sent back for changes')),
          small('Approve', () => _setDraft(context, d, Draft.approved, 'Approved'), filled: filled),
        ],
      Draft.revision => [small('Back to review', () => _setDraft(context, d, Draft.review, 'Back in review'), filled: filled)],
      Draft.approved => [small('Publish', () => _setDraft(context, d, Draft.published, 'Published'), filled: filled)],
      Draft.published => [small('Withdraw', () => _setDraft(context, d, Draft.approved, 'Withdrawn'))],
    };

S _draftStatus(Draft d) => switch (d) { Draft.review => S.wait, Draft.revision => S.bad, _ => S.ok };

void _openDraft(BuildContext context, Deliverable d) => openPage(context, d.title, (c) => [
      title(d.title),
      sub('${d.client} · ${d.format}${d.pod.isEmpty ? '' : ' · ${d.pod}'}'),
      const SizedBox(height: 10),
      Status(_draftStatus(d.state), _draftNames[d.state.index]),
      Panel(child: Text('Posts on ${longDate(d.date)}', style: inter(16))),
      actions(_draftActions(c, d)),
      sec('Notes'),
      if (d.notes.isEmpty) empty('No notes yet.') else Rows([for (final n in d.notes) tile(n)]),
    ]);

class _Review extends StatefulWidget {
  const _Review();
  @override
  State<_Review> createState() => _ReviewState();
}

class _ReviewState extends State<_Review> {
  int pick = 0;
  String q = '';
  @override
  Widget build(BuildContext context) {
    final list = drafts(Draft.values[pick]).where((d) => matches(q, [d.title, d.client, d.format, d.pod])).toList();
    return page([
      SearchBox('Search title, client or format', (v) => setState(() => q = v)),
      Chips(
        labels: [for (final d in Draft.values) '${_draftNames[d.index]} ${drafts(d).length}'],
        selected: pick,
        onSelect: (i) => setState(() => pick = i),
      ),
      if (list.isEmpty) empty('No drafts here yet.'),
      for (final (i, d) in list.indexed)
        Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: () => _openDraft(context, d),
            child: Row(children: [
              Container(
                width: 44,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: C.raised, borderRadius: BorderRadius.circular(10)),
                child: Text(d.format == 'Post' ? '4:5' : '9:16', style: inter(11, w: FontWeight.w600, c: C.mist)),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.title, style: inter(16, w: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('${d.client} · ${d.format} · ${dm(d.date)}${d.notes.isEmpty ? '' : ' · ${d.notes.length} notes'}', style: inter(14, c: C.mist)),
              ])),
              Icon(Icons.chevron_right, color: C.mist),
            ]),
          ),
          actions(_draftActions(context, d, filled: i == 0)),
        ])),
      mainButton('New draft', () => newDraft(context)),
    ]);
  }
}

class _Calendar extends StatefulWidget {
  const _Calendar();
  @override
  State<_Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<_Calendar> {
  bool agenda = false;
  DateTime day = today;

  Widget dayCell(DateTime d, {bool showName = false}) {
    final n = deliverables.where((x) => sameDay(x.date, d)).length;
    final on = sameDay(d, day);
    return Expanded(
        child: Semantics(
      button: true,
      label: '${longDate(d)}, $n posts',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => day = d),
        child: Container(
          height: 52,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: on ? C.text : null, borderRadius: BorderRadius.circular(12)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${d.day}', style: inter(15, c: on ? C.ground : C.text)),
            Text(n == 0 ? ' ' : '$n', style: inter(11, w: FontWeight.w600, c: on ? C.ground : C.accent)),
          ]),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final inMonth = deliverables.where((d) => d.date.year == day.year && d.date.month == day.month);
    final first = DateTime(day.year, day.month, 1);
    final daysInMonth = DateTime(day.year, day.month + 1, 0).day;
    final lead = first.weekday - 1;
    final upcoming = deliverables.where((d) => !d.date.isBefore(today)).toList()..sort((a, b) => a.date.compareTo(b.date));
    final ofDay = deliverables.where((d) => sameDay(d.date, day)).toList();
    Widget dayRow(Deliverable d) => tile(d.title,
        s: '${d.client} · ${d.format}', trail: Status(_draftStatus(d.state), _draftNames[d.state.index]), onTap: () => _openDraft(context, d));
    return page([
      const SizedBox(height: 4),
      Kv([for (final f in formats) ('${f}s', '${inMonth.where((d) => d.format == f).length}')]),
      Chips(labels: const ['Month', 'Agenda'], selected: agenda ? 1 : 0, onSelect: (i) => setState(() => agenda = i == 1)),
      if (!agenda)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(children: [
            IconButton(
                tooltip: 'Back',
                onPressed: () => setState(() => day = DateTime(day.year, day.month - 1, 1)),
                icon: const Icon(Icons.chevron_left)),
            Expanded(child: Text('${monthName(day)} ${day.year}', textAlign: TextAlign.center, style: inter(16, w: FontWeight.w600))),
            IconButton(
                tooltip: 'Next',
                onPressed: () => setState(() => day = DateTime(day.year, day.month + 1, 1)),
                icon: const Icon(Icons.chevron_right)),
          ]),
        ),
      if (!agenda)
        Row(children: [for (final l in const ['M', 'T', 'W', 'T', 'F', 'S', 'S']) Expanded(child: Text(l, textAlign: TextAlign.center, style: inter(12, c: C.mist)))]),
      if (!agenda)
        for (var w = 0; w < ((lead + daysInMonth) / 7).ceil(); w++)
          Row(children: [
            for (var i = 0; i < 7; i++)
              if (w * 7 + i - lead + 1 case final d when d >= 1 && d <= daysInMonth)
                dayCell(DateTime(day.year, day.month, d))
              else
                const Expanded(child: SizedBox(height: 56)),
          ]),
      if (!agenda) ...[
        sec('${longDate(day)} · ${ofDay.length} items'),
        if (ofDay.isEmpty) empty('Nothing scheduled.') else Rows([for (final d in ofDay) dayRow(d)]),
      ] else ...[
        sec('Coming up'),
        if (upcoming.isEmpty) empty('Nothing scheduled.') else Rows([for (final d in upcoming) tile(d.title, s: '${dm(d.date)} · ${d.client} · ${d.format}', onTap: () => _openDraft(context, d))]),
      ],
      mainButton('Schedule a post', () => newDraft(context, on: agenda ? null : day)),
    ]);
  }
}

/// Create task form. [freelance] limits the assignee list to freelancers.
Future<void> newTask(BuildContext context, {bool freelance = false, String pod = ''}) async {
  final who = freelance ? [for (final p in peopleOf(Kind.freelancer)) p.name] : staffNames;
  if (who.isEmpty) return toast(context, freelance ? 'Add a freelancer first (Team, Freelancers)' : 'Add a team member first (Team, Pods)');
  if (clients.isEmpty) return toast(context, 'Add a client first (Team, Clients)');
  final v = await formSheet(context, freelance ? 'Assign a freelancer' : 'Create task', [
    const F('Task title', required: true, hint: 'e.g. Story set, festive offer'),
    F('Client', options: clientNames, required: true),
    F('Assign to', options: who, required: true),
    F('Pod', options: podNames, initial: pod),
    const F('Priority', options: priorities, initial: 'Medium'),
    const F('Due date', date: true, required: true),
  ], freelance ? 'Assign' : 'Create task');
  if (v == null) return;
  save(() => tasks.add(Task(v['Task title']!, v['Client']!, v['Assign to']!, v['Pod']!, v['Priority']!, parseDate(v['Due date'])!)));
  if (context.mounted) toast(context, 'Task added');
}

void _moveTask(Task t, Stage to) => save(() {
      t.stage = to;
      t.doneAt = to == Stage.done ? DateTime.now() : null;
    });

void _openTask(BuildContext context, Task t) => openPage(context, t.title, (c) => [
      title(t.title),
      sub('${t.client} · ${t.who}'),
      Kv([('Stage', stageNames[t.stage.index]), ('Priority', t.priority), ('Due', dm(t.due))]),
      sec('Move to'),
      actions([
        for (final s in Stage.values)
          if (s != t.stage) small(stageNames[s.index], () => _moveTask(t, s), filled: s.index == t.stage.index + 1),
      ]),
    ]);

class _Tasks extends StatefulWidget {
  const _Tasks();
  @override
  State<_Tasks> createState() => _TasksState();
}

class _TasksState extends State<_Tasks> {
  int pick = 0;
  String q = '';
  @override
  Widget build(BuildContext context) {
    final list = tasksIn(Stage.values[pick]).where((t) => matches(q, [t.title, t.client, t.who])).toList()..sort((a, b) => a.due.compareTo(b.due));
    return page([
      SearchBox('Search tasks, people, clients', (v) => setState(() => q = v)),
      Chips(
        labels: [for (final s in Stage.values) '${stageNames[s.index]} ${tasksIn(s).length}'],
        selected: pick,
        onSelect: (i) => setState(() => pick = i),
      ),
      if (list.isEmpty)
        empty('No tasks here yet.')
      else
        Rows([
          for (final t in list)
            tile(t.title,
                s: '${t.client} · ${t.who} · due ${dm(t.due)}',
                lead: Initials(t.who),
                trail: t.stage != Stage.done && t.due.isBefore(today) ? const Status(S.bad, 'Late') : null,
                onTap: () => _openTask(context, t)),
        ]),
      twoButtons(
        OutlinedButton(onPressed: () => newTask(context, freelance: true), child: const Text('Freelancer')),
        FilledButton(onPressed: () => newTask(context), child: const Text('Create task')),
      ),
    ]);
  }
}

class _Publish extends StatefulWidget {
  const _Publish();
  @override
  State<_Publish> createState() => _PublishState();
}

class _PublishState extends State<_Publish> {
  int pick = 0; // 0 = all, then postStatuses[pick - 1]

  void planFromCalendar() {
    final fresh = deliverables.where((d) => d.state == Draft.approved && !posts.any((p) => p.source == d && p.status != 'Canceled')).toList();
    save(() => posts.addAll([for (final d in fresh) Post(d.title, d.client, d.date, 'Approved, needs a time', source: d)]));
    toast(context, fresh.isEmpty ? 'No new approved drafts to plan' : 'Added ${fresh.length} posts to the queue');
  }

  void openPost(Post p) => openPage(context, p.title, (c) => [
        title(p.title),
        sub('${p.client} · ${longDate(p.when)}'),
        Panel(child: Text(p.status, style: inter(16, w: FontWeight.w600))),
        // Published and Canceled are final: nothing can move them back.
        if (p.finished)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text('This post is ${p.status.toLowerCase()}. No more changes.', style: inter(15, c: C.mist)))
        else
          actions([
          small('Schedule', () async {
            final v = await formSheet(c, 'Schedule ${p.title}', [F('Date', date: true, required: true, initial: p.when.toIso8601String().substring(0, 10))], 'Schedule');
            if (v != null) {
              save(() {
                p.when = parseDate(v['Date'])!;
                p.status = 'Scheduled';
              });
            }
          }, filled: true),
          if (p.status != 'Paused') small('Pause', () => save(() => p.status = 'Paused')),
          if (p.status != 'Canceled') small('Cancel', () => save(() => p.status = 'Canceled')),
        ]),
      ]);

  @override
  Widget build(BuildContext context) {
    final failed = posts.where((p) => p.status == 'Publishing failed').toList();
    final list = (pick == 0 ? posts.toList() : posts.where((p) => p.status == postStatuses[pick - 1]).toList())..sort((a, b) => a.when.compareTo(b.when));
    return page([
      for (final p in failed)
        Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Status(S.bad, 'Failed to publish'),
          const SizedBox(height: 6),
          Text('${p.title} · ${p.client} · ${dm(p.when)}', style: inter(15, c: C.mist2)),
          actions([small('Retry', () => save(() => p.status = 'Scheduled'), filled: true)]),
        ])),
      Chips(
        labels: ['All ${posts.length}', for (final s in postStatuses) '$s ${posts.where((p) => p.status == s).length}'],
        selected: pick,
        onSelect: (i) => setState(() => pick = i),
      ),
      if (list.isEmpty)
        empty('No posts here. Approved drafts can be added with the button below.')
      else
        Rows([for (final p in list) tile(p.title, s: '${p.client} · ${dm(p.when)}', trail: Text(p.status, style: inter(13, c: C.mist)), onTap: () => openPost(p))]),
      mainButton('Plan posts from calendar', planFromCalendar),
    ]);
  }
}
