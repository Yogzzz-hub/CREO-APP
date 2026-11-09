import 'package:flutter/material.dart';

import 'content.dart';
import 'data.dart';
import 'money.dart';
import 'ui.dart';

class TeamTab extends StatelessWidget {
  const TeamTab({super.key, this.initial = 0});
  final int initial;
  @override
  Widget build(BuildContext context) => TabPage(
        name: 'Team',
        initial: initial,
        tabs: const ['Pods', 'Workload', 'Leave', 'Clients', 'Pod lead', 'Sales team', 'Freelancers'],
        pages: [_Pods(), _Workload(), _Leave(), _Clients(), _PodLead(), _SalesTeam(), _Freelancers()],
      );
}

// ---------- People ----------

/// Adds a person. They get an invite link and set their own password; the admin never types or sees it.
Future<void> invitePerson(BuildContext context, Kind kind) async {
  final v = await formSheet(context, switch (kind) { Kind.staff => 'Add team member', Kind.sales => 'Add salesperson', Kind.freelancer => 'Add freelancer' }, [
    const F('Full name', required: true),
    const F('Email for the invite', required: true, hint: 'They set their own password from this link'),
    if (kind == Kind.staff) ...[const F('Role', hint: 'e.g. Video editor'), F('Pod', options: podNames)],
    if (kind != Kind.sales) const F('Skills', hint: 'e.g. Reels, motion, design'),
    if (kind == Kind.freelancer) const F('Rate, ₹ an hour', number: true),
    if (kind == Kind.sales) ...[const F('Target, ₹ a quarter', number: true), const F('Commission %', number: true)],
  ], 'Send invite');
  if (v == null) return;
  if (!validEmail(v['Email for the invite']!)) {
    if (context.mounted) toast(context, 'That email does not look right');
    return;
  }
  if (nameTaken([for (final p in people) p.name], v['Full name']!)) {
    if (context.mounted) toast(context, 'Someone named ${v['Full name']} already exists');
    return;
  }
  save(() => people.add(Person(v['Full name']!, v['Email for the invite']!, kind, role: v['Role'] ?? '', pod: v['Pod'] ?? '', skills: v['Skills'] ?? '')
    ..rate = toInt(v['Rate, ₹ an hour'])
    ..quota = toInt(v['Target, ₹ a quarter'])
    ..commission = toInt(v['Commission %'])));
  if (context.mounted) toast(context, 'Saved. The invite to ${v['Email for the invite']} goes out once the app is connected to the server.');
}

void openPerson(BuildContext context, Person p) => openPage(context, p.name, (c) => [
      Center(
          child: Column(children: [
        const SizedBox(height: 8),
        CircleAvatar(radius: 36, backgroundColor: C.raised, child: Text(initials(p.name), style: inter(24, w: FontWeight.w500, c: C.mist2))),
        const SizedBox(height: 12),
        Text(p.name, style: inter(22, w: FontWeight.w500)),
        Text([if (p.role.isNotEmpty) p.role, switch (p.kind) { Kind.staff => 'Team', Kind.sales => 'Sales', Kind.freelancer => 'Freelancer' }].join(' · '),
            style: inter(15, c: C.mist)),
        const SizedBox(height: 8),
        Status(p.active ? S.ok : S.bad, p.active ? 'Active' : 'Suspended'),
      ])),
      Rows([
        tile('Email', s: p.email),
        if (p.kind == Kind.staff) tile('Pod', s: p.pod.isEmpty ? 'Not in a pod' : p.pod),
        if (p.skills.isNotEmpty) tile('Skills', s: p.skills),
        if (p.kind == Kind.freelancer) tile('Rate', s: '${inr(p.rate)} an hour'),
        if (p.kind == Kind.sales) tile('Target and commission', s: '${inr(p.quota)} a quarter · ${p.commission}%'),
        if (p.kind != Kind.sales) tile('Open tasks', s: '${openTasks(p.name)}'),
        if (p.kind == Kind.sales) tile('Leads', s: '${leads.where((l) => l.rep == p.name).length} · ${leads.where((l) => l.rep == p.name && l.stage == 'Won').length} won'),
      ]),
      actions([
        if (p.kind == Kind.staff)
          small('Move pod', () async {
            final v = await formSheet(c, 'Move ${p.name}', [F('Pod', options: podNames, required: true, initial: p.pod)], 'Move');
            if (v != null) save(() => p.pod = v['Pod']!);
          }),
        small(p.active ? 'Suspend' : 'Reactivate', () => save(() => p.active = !p.active)),
        small('Remove', () async {
          if (await confirm(c, 'Remove ${p.name}? Their open tasks stay, unassigned.', 'Remove')) {
            save(() {
              for (final t in tasks.where((t) => t.who == p.name)) {
                t.who = 'Unassigned';
              }
              people.remove(p);
            });
            if (c.mounted) Navigator.pop(c);
          }
        }),
      ]),
    ]);

// ---------- Pods ----------
double podProgress(Pod p) {
  final mine = tasks.where((t) => t.pod == p.name).toList();
  return mine.isEmpty ? 0 : mine.where((t) => t.stage == Stage.done).length / mine.length;
}

class _Pods extends StatelessWidget {
  const _Pods();

  Future<void> newPod(BuildContext context) async {
    final v = await formSheet(context, 'New pod', [
      const F('Pod name', required: true, hint: 'e.g. Pod Alpha'),
      F('Pod lead', options: staffNames, required: true),
      const F('Hours per sprint', number: true, initial: '120'),
    ], 'Create pod');
    if (v == null) return;
    if (nameTaken(podNames, v['Pod name']!)) {
      if (context.mounted) toast(context, 'A pod named ${v['Pod name']} already exists');
      return;
    }
    save(() {
      pods.add(Pod(v['Pod name']!, v['Pod lead']!, toInt(v['Hours per sprint'])));
      people.where((p) => p.name == v['Pod lead']).firstOrNull?.pod = v['Pod name']!;
    });
  }

  void openPod(BuildContext context, Pod p) => openPage(context, p.name, (c) => [
        title(p.name),
        sub('Lead ${p.lead} · ${p.hours} hours a sprint'),
        meter(podProgress(p), C.accent),
        sec('Members'),
        if (p.members.isEmpty)
          empty('No members yet')
        else
          Rows([for (final m in p.members) tile(m.name, s: '${m.role.isEmpty ? 'Team' : m.role} · ${openTasks(m.name)} open tasks', lead: Initials(m.name), onTap: () => openPerson(c, m))]),
        sec('Stand-ups'),
        if (p.standups.isEmpty) empty('No stand-ups logged') else Rows([for (final s in p.standups.reversed) tile(s)]),
      ]);

  @override
  Widget build(BuildContext context) {
    final staff = peopleOf(Kind.staff);
    return page([
      const SizedBox(height: 4),
      Kv([('Pods', '${pods.length}'), ('People', '${staff.length}'), ('In today', '${staff.where((p) => p.active).length - onLeaveToday.length}')]),
      if (pods.isEmpty) empty('No pods yet. Add team members, then create a pod.'),
      for (final p in pods)
        InkWell(
          onTap: () => openPod(context, p),
          child: Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: inter(16, w: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('Lead ${p.lead} · ${p.members.length} people', style: inter(14, c: C.mist)),
              ])),
              Icon(Icons.chevron_right, color: C.mist),
            ]),
            meter(podProgress(p), C.accent),
            const SizedBox(height: 8),
            Text('Sprint ${(podProgress(p) * 100).round()}% done · ${tasks.where((t) => t.pod == p.name && t.stage != Stage.done).length} open tasks',
                style: inter(14, c: C.mist)),
          ])),
        ),
      if (staff.isNotEmpty) ...[
        sec('Everyone'),
        Rows([for (final m in staff) tile(m.name, s: [m.role, m.pod].where((x) => x.isNotEmpty).join(' · '), lead: Initials(m.name), onTap: () => openPerson(context, m))]),
      ],
      twoButtons(
        OutlinedButton(onPressed: () => newPod(context), child: const Text('New pod')),
        FilledButton(onPressed: () => invitePerson(context, Kind.staff), child: const Text('Add member')),
      ),
    ]);
  }
}

// ---------- Pod lead dashboard ----------
class _PodLead extends StatefulWidget {
  const _PodLead();
  @override
  State<_PodLead> createState() => _PodLeadState();
}

class _PodLeadState extends State<_PodLead> {
  int pick = 0;

  /// Moves one open to-do task from the busiest member to the least busy one.
  void balance(Pod p) {
    final m = p.members.where((m) => m.active).toList()..sort((a, b) => openTasks(b.name).compareTo(openTasks(a.name)));
    if (m.length < 2 || openTasks(m.first.name) - openTasks(m.last.name) < 2) return toast(context, 'Workload is already even');
    final t = tasks.where((t) => t.who == m.first.name && t.stage == Stage.todo).firstOrNull;
    if (t == null) return toast(context, '${m.first.name} has no to-do tasks to move');
    save(() => t.who = m.last.name);
    toast(context, 'Moved "${t.title}" to ${m.last.name}');
  }

  @override
  Widget build(BuildContext context) {
    if (pods.isEmpty) return page([const SizedBox(height: 16), empty('Create a pod first (Team, Pods)')]);
    final p = pods[pick.clamp(0, pods.length - 1)];
    final signOff = deliverables.where((d) => d.pod == p.name && d.state == Draft.review).toList();
    return page([
      Chips(labels: podNames, selected: pick.clamp(0, pods.length - 1), onSelect: (i) => setState(() => pick = i)),
      sec('Team and live workload'),
      if (p.members.isEmpty)
        empty('No members in ${p.name}')
      else
        Panel(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(children: [
              for (final (i, m) in p.members.indexed) ...[
                if (i > 0) const Divider(),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(children: [Expanded(child: Text(m.name, style: inter(16, w: FontWeight.w500))), Text('${openTasks(m.name)} tasks', style: inter(14, c: C.mist))]),
                ),
                meter(openTasks(m.name) / maxLoad, openTasks(m.name) >= overloadAt ? C.rose : C.peri),
                const SizedBox(height: 4),
              ],
            ])),
      sec('Waiting for lead sign-off'),
      if (signOff.isEmpty)
        empty('Nothing to sign off')
      else
        Rows([
          for (final d in signOff)
            tile(d.title,
                s: '${d.client} · ${d.format}',
                trail: small('Approve', () {
                  save(() => d.state = Draft.approved); // same as Approve in Review; only a withdraw touches posts
                  toast(context, 'Approved ${d.title}');
                })),
        ]),
      sec('Quick actions'),
      actions([
        small('Log stand-up', () async {
          final v = await formSheet(context, 'Stand-up for ${p.name}', [const F('What happened, what is next, what is blocked', required: true, lines: 4)], 'Log');
          if (v != null) save(() => p.standups.add('${dm(DateTime.now())}: ${v.values.first}'));
        }),
        small('Balance loads', () => balance(p)),
        small('Assign deliverable', () => newTask(context, pod: p.name), filled: true),
      ]),
    ]);
  }
}

// ---------- Workload ----------
class _Workload extends StatelessWidget {
  const _Workload();

  void rebalance(BuildContext context) {
    final busy = overloaded, free = workload.where((w) => w.$2 <= freeAt).toList();
    if (busy.isEmpty || free.isEmpty) return toast(context, 'Nobody to move tasks between');
    final from = busy.first.$1, to = free.last.$1;
    final move = tasks.where((t) => t.who == from && t.stage == Stage.todo).take(5).toList();
    save(() {
      for (final t in move) {
        t.who = to;
      }
    });
    toast(context, 'Moved ${move.length} tasks from $from to $to');
  }

  @override
  Widget build(BuildContext context) {
    final all = workload;
    final busy = overloaded;
    final free = all.where((w) => w.$2 <= freeAt).toList();
    Widget group(List<(String, int)> list, Color c, String none) => list.isEmpty
        ? empty(none)
        : Panel(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(children: [
              for (final (i, (name, n)) in list.indexed) ...[
                if (i > 0) const Divider(),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(children: [
                    Expanded(child: Text(name, style: inter(16, w: FontWeight.w500))),
                    Text('$n tasks${tasks.where((t) => t.who == name && t.stage != Stage.done && t.due.isBefore(today)).isEmpty ? '' : ' · ${tasks.where((t) => t.who == name && t.stage != Stage.done && t.due.isBefore(today)).length} late'}',
                        style: inter(14, c: C.mist)),
                  ]),
                ),
                meter(n / maxLoad, c),
                const SizedBox(height: 4),
              ],
            ]));
    return page([
      const SizedBox(height: 4),
      Kv([('On time', onTimeRate), ('Open tasks', '${tasks.where((t) => t.stage != Stage.done).length}'), ('Redo rate', revisionRate)]),
      sec('Too much work ($overloadAt or more tasks)'),
      group(busy, C.rose, 'Nobody has too much work'),
      sec('Free to take work ($freeAt or fewer)'),
      group(free, C.peri, 'Nobody is free right now'),
      sec('Everyone'),
      group(all, C.mist, 'No team members yet'),
      if (busy.isNotEmpty && free.isNotEmpty) mainButton("Move 5 of ${busy.first.$1.split(' ').first}'s tasks", () => rebalance(context)),
    ]);
  }
}

// ---------- Leave ----------
class _Leave extends StatefulWidget {
  const _Leave();
  @override
  State<_Leave> createState() => _LeaveState();
}

class _LeaveState extends State<_Leave> {
  int pick = 0;
  static const tabs = ['Pending', 'Approved', 'Rejected'];

  Future<void> apply() async {
    final v = await formSheet(context, 'Apply for time off', [
      F('Who', options: [me.name, ...staffNames], required: true, initial: me.name),
      const F('Start date', date: true, required: true),
      const F('End date', date: true, required: true),
      const F('Reason', lines: 2),
    ], 'Apply');
    if (v == null) return;
    final start = parseDate(v['Start date'])!, end = parseDate(v['End date'])!;
    if (end.isBefore(start)) {
      if (mounted) toast(context, 'The end date is before the start date');
      return;
    }
    save(() => leaves.add(Leave(v['Who']!, start, end, v['Reason']!)));
  }

  @override
  Widget build(BuildContext context) {
    final list = leavesIn(tabs[pick])..sort((a, b) => a.start.compareTo(b.start));
    final staff = peopleOf(Kind.staff).where((p) => p.active).length;
    return page([
      const SizedBox(height: 4),
      Kv([('Working', '${staff - onLeaveToday.length}'), ('On leave', '${onLeaveToday.length}'), ('Pending', '${pendingLeaves.length}')]),
      Chips(labels: [for (final t in tabs) '$t ${leavesIn(t).length}'], selected: pick, onSelect: (i) => setState(() => pick = i)),
      if (list.isEmpty) empty('No ${tabs[pick].toLowerCase()} requests'),
      for (final (i, l) in list.indexed)
        Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          tile(l.who, s: people.where((p) => p.name == l.who).firstOrNull?.pod ?? '', lead: Initials(l.who)),
          Text('${dm(l.start)}${l.days > 1 ? ' to ${dm(l.end)}' : ''} · ${l.days} day${l.days == 1 ? '' : 's'}', style: inter(16)),
          if (l.reason.isNotEmpty) Text('"${l.reason}"', style: inter(14, c: C.mist)),
          if (l.status == 'Pending')
            actions([
              small('Reject', () => save(() => l.status = 'Rejected')),
              small('Approve', () => save(() => l.status = 'Approved'), filled: i == 0),
            ]),
        ])),
      sec('On leave today'),
      if (onLeaveToday.isEmpty) empty('Everyone is in today') else Rows([for (final l in onLeaveToday) tile(l.who, s: 'Back ${dm(l.end.add(const Duration(days: 1)))}', lead: Initials(l.who))]),
      mainButton('Apply for time off', apply),
    ]);
  }
}

// ---------- Clients ----------
Future<void> onboardClient(BuildContext context) async {
  final v = await formSheet(context, 'Onboard a client', [
    const F('Brand name', required: true),
    const F('Contact name'),
    const F('Login email', required: true, hint: 'They get an invite link and set their own password'),
    const F('Industry', hint: 'e.g. D2C skincare'),
    F('Plan', options: [for (final p in plans) p.name]),
    F('Pod', options: podNames),
  ], 'Send invite');
  if (v == null) return;
  if (!validEmail(v['Login email']!)) {
    if (context.mounted) toast(context, 'That email does not look right');
    return;
  }
  if (nameTaken(clientNames, v['Brand name']!)) {
    if (context.mounted) toast(context, 'A client named ${v['Brand name']} already exists');
    return;
  }
  save(() => clients.add(Client(
      name: v['Brand name']!, contact: v['Contact name']!, email: v['Login email']!, industry: v['Industry']!, plan: v['Plan']!.isEmpty ? null : v['Plan'], pod: v['Pod']!)));
  if (context.mounted) toast(context, 'Saved. The invite to ${v['Login email']} goes out once the app is connected to the server.');
}

void openClient(BuildContext context, Client cl) => openPage(context, cl.name, (c) {
      final plan = planNamed(cl.plan);
      final now = DateTime.now();
      final mine = deliverables.where((d) => d.client == cl.name).toList();
      final thisMonth = mine.where((d) => d.date.year == now.year && d.date.month == now.month);
      final bills = invoices.where((v) => v.client == cl.name).toList()..sort((a, b) => b.date.compareTo(a.date));
      return [
        title(cl.name),
        sub([cl.industry, cl.contact, cl.email].where((x) => x.isNotEmpty).join(' · ')),
        const SizedBox(height: 8),
        Status(cl.paid ? S.ok : S.wait, cl.paid ? 'Paid · ${cl.upi ? 'UPI or bank' : 'Card'}' : 'Not paid yet'),
        Kv([('Plan', cl.plan ?? '—'), ('A month', cl.paid ? inr(cl.fee) : '—'), ('Pod', cl.pod.isEmpty ? '—' : cl.pod)]),
        actions([
          small(cl.paid ? 'Mark not paid' : 'Mark as paid', () => save(() => cl.paid = !cl.paid), filled: !cl.paid),
          if (cl.paid) small(cl.upi ? 'Paid by card' : 'Paid by UPI', () => save(() => cl.upi = !cl.upi)),
          small('Invoice', () => newInvoice(c, client: cl.name)),
          small('Change plan or pod', () async {
            final v = await formSheet(c, 'Plan and pod', [
              F('Plan', options: [for (final p in plans) p.name], initial: cl.plan ?? ''),
              F('Pod', options: podNames, initial: cl.pod),
            ], 'Save');
            if (v != null) {
              save(() {
                cl.plan = v['Plan']!.isEmpty ? null : v['Plan'];
                cl.customFee = null;
                cl.pod = v['Pod']!;
              });
            }
          }),
        ]),
        sec('This month'),
        Kv([
          for (final (f, quota) in [('Posts', plan?.posts), ('Reels', plan?.reels), ('Stories', plan?.stories)])
            (f, '${thisMonth.where((d) => '${d.format}s' == f || (f == 'Stories' && d.format == 'Story')).length}${quota == null ? '' : ' of $quota'}'),
        ]),
        sec('Brand DNA'),
        Rows([
          tile('Fonts', s: cl.fonts.isEmpty ? 'Not added' : cl.fonts),
          tile('Brand colours', s: cl.colours.isEmpty ? 'Not added' : cl.colours),
          tile('Audience and tone', s: cl.audience.isEmpty ? 'Not added' : cl.audience),
          tile('Instagram', s: cl.instagram.isEmpty ? 'Not connected' : cl.instagram),
        ]),
        actions([
          small('Edit brand DNA', () async {
            final v = await formSheet(c, 'Brand DNA', [
              F('Fonts', initial: cl.fonts, hint: 'e.g. Inter Display 700, Inter 400'),
              F('Brand colours', initial: cl.colours, hint: 'e.g. #D2965A, #0A0908'),
              F('Audience and tone', initial: cl.audience, lines: 3),
              F('Instagram handle', initial: cl.instagram, hint: '@brand'),
            ], 'Save');
            if (v != null) {
              save(() => cl
                ..fonts = v['Fonts']!
                ..colours = v['Brand colours']!
                ..audience = v['Audience and tone']!
                ..instagram = v['Instagram handle']!);
            }
          }),
        ]),
        sec('Deliverables'),
        if (mine.isEmpty) empty('No drafts for ${cl.name} yet') else Rows([for (final d in mine) tile(d.title, s: '${d.format} · ${dm(d.date)}')]),
        sec('Invoices'),
        if (bills.isEmpty) empty('No invoices yet') else Rows([for (final v in bills) tile('#${v.number} · ${v.scope}', s: dm(v.date), trail: money(v.amount))]),
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: OutlinedButton(
            onPressed: () async {
              if (await confirm(c, 'Remove ${cl.name} and cancel their plan?', 'Remove')) {
                save(() => clients.remove(cl));
                if (c.mounted) Navigator.pop(c);
              }
            },
            child: Text('Remove client', style: inter(16, w: FontWeight.w500, c: C.rose)),
          ),
        ),
      ];
    });

class _Clients extends StatefulWidget {
  const _Clients();
  @override
  State<_Clients> createState() => _ClientsState();
}

class _ClientsState extends State<_Clients> {
  int pick = 0;
  String q = '';
  @override
  Widget build(BuildContext context) {
    final list = (pick == 0 ? paidClients : unpaidClients).where((c) => matches(q, [c.name, c.industry, c.email])).toList();
    return page([
      SearchBox('Search brand, industry or email', (v) => setState(() => q = v)),
      Chips(labels: ['Paid ${paidClients.length}', 'Not paid ${unpaidClients.length}'], selected: pick, onSelect: (i) => setState(() => pick = i)),
      if (list.isEmpty)
        empty(pick == 0 ? 'No paying clients yet' : 'No unpaid clients')
      else
        Rows([
          for (final c in list)
            tile(c.name,
                s: [c.plan ?? 'No plan', if (c.pod.isNotEmpty) c.pod].join(' · '),
                lead: Initials(c.name),
                trail: c.paid ? money(c.fee) : const Icon(Icons.chevron_right),
                onTap: () => openClient(context, c)),
        ]),
      if (pick == 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
          child: Row(children: [Expanded(child: Text('Total a month', style: inter(16, c: C.mist))), Text(inr(mrr), style: inter(22, w: FontWeight.w500))]),
        ),
      mainButton('Onboard a client', () => onboardClient(context)),
    ]);
  }
}

// ---------- Sales team ----------
class _SalesTeam extends StatelessWidget {
  const _SalesTeam();
  @override
  Widget build(BuildContext context) {
    final reps = peopleOf(Kind.sales);
    final won = leads.where((l) => l.stage == 'Won').fold(0, (s, l) => s + l.value);
    return page([
      const SizedBox(height: 4),
      Kv([('People', '${reps.length}'), ('Won', inr(won)), ('Pipeline', inr(pipelineValue))]),
      if (reps.isEmpty) empty('No salespeople yet'),
      for (final r in reps)
        InkWell(
          onTap: () => openPerson(context, r),
          child: Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Initials(r.name),
              const SizedBox(width: 12),
              Expanded(child: Text(r.name, style: inter(16, w: FontWeight.w500))),
              Status(r.active ? S.ok : S.bad, r.active ? 'Active' : 'Suspended'),
            ]),
            const SizedBox(height: 12),
            Text(
                '${leads.where((l) => l.rep == r.name).length} leads · ${leads.where((l) => l.rep == r.name && l.stage == 'Won').length} won · target ${inr(r.quota)} · ${r.commission}% commission',
                style: inter(14, c: C.mist)),
          ])),
        ),
      mainButton('Add salesperson', () => invitePerson(context, Kind.sales)),
    ]);
  }
}

// ---------- Freelancers ----------
class _Freelancers extends StatelessWidget {
  const _Freelancers();
  @override
  Widget build(BuildContext context) {
    final list = peopleOf(Kind.freelancer);
    return page([
      const SizedBox(height: 4),
      Kv([('Freelancers', '${list.length}'), ('Open tasks', '${list.fold(0, (s, f) => s + openTasks(f.name))}'), ('Access', 'Own tasks')]),
      Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Freelancers only see the tasks given to them, never client billing or other work.', style: inter(14, c: C.mist))),
      if (list.isEmpty) empty('No freelancers yet'),
      for (final f in list)
        InkWell(
          onTap: () => openPerson(context, f),
          child: Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Initials(f.name),
              const SizedBox(width: 12),
              Expanded(child: Text(f.name, style: inter(16, w: FontWeight.w500))),
              Status(f.active ? S.ok : S.bad, f.active ? 'Active' : 'Suspended'),
            ]),
            const SizedBox(height: 12),
            Text('${f.skills.isEmpty ? 'No skills listed' : f.skills} · ${inr(f.rate)} an hour · ${openTasks(f.name)} open tasks', style: inter(14, c: C.mist)),
          ])),
        ),
      twoButtons(
        OutlinedButton(onPressed: () => newTask(context, freelance: true), child: const Text('Assign task')),
        FilledButton(onPressed: () => invitePerson(context, Kind.freelancer), child: const Text('Add freelancer')),
      ),
    ]);
  }
}
