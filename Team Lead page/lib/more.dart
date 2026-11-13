// The rest of the team lead's menu: Leave & Schedule (/lead/schedule), Calendar (/admin/calendar),
// Instagram Connect (/admin/publishing), Workspace Hub (/slack), Support Desk (/admin/support)
// and Settings (/workstation/settings).
import 'package:flutter/material.dart';

import 'data.dart';
import 'home.dart';
import 'review.dart';
import 'ui.dart';

class MoreTab extends StatelessWidget {
  const MoreTab({super.key});
  @override
  Widget build(BuildContext context) {
    final openTickets = tickets.where((t) => t.open).length;
    return page([
      title('More'),
      sec('Team'),
      Rows([
        tile(
          'Leave & schedule',
          s: toDecide.isEmpty ? 'Requests and leave history' : '${toDecide.length} waiting for you',
          lead: const Icon(Icons.event_busy_outlined),
          onTap: () => pushPage(context, 'Leave & schedule', () => LeavePage()),
        ),
        tile(
          'Calendar',
          s: 'Deliverables by due date',
          lead: const Icon(Icons.calendar_month_outlined),
          onTap: () => pushPage(context, 'Calendar', () => CalendarPage()),
        ),
        tile(
          'Instagram queue',
          s: 'Scheduled publishing',
          lead: const Icon(Icons.send_outlined),
          onTap: () => pushPage(context, 'Instagram queue', () => PublishingPage()),
        ),
      ]),
      sec('Operations & support'),
      Rows([
        tile('Workspace hub', s: 'Chat', lead: const Icon(Icons.chat_bubble_outline), onTap: () => pushPage(context, 'Workspace hub', () => ChatPage())),
        tile(
          'Support desk',
          s: openTickets == 0 ? 'No open tickets' : '$openTickets open',
          lead: const Icon(Icons.support_agent_outlined),
          onTap: () => pushPage(context, 'Support desk', () => SupportPage()),
        ),
      ]),
      sec('Account'),
      Rows([tile('Settings', s: me.name, lead: const Icon(Icons.settings_outlined), onTap: () => pushPage(context, 'Settings', () => SettingsPage()))]),
    ]);
  }
}

// ---------- Leave & schedule ----------
class LeavePage extends StatelessWidget {
  const LeavePage({super.key});

  Future<void> request(BuildContext context) async {
    final v = await formSheet(context, 'Log leave', [
      F('Who', options: [for (final m in members) m.lead ? '${m.name} (you)' : m.name], required: true, initial: '${me.name} (you)'),
      const F('Start date', date: true, required: true),
      const F('End date', date: true, required: true),
      const F('Reason', lines: 2),
    ], 'Send request');
    if (v == null || !context.mounted) return;
    final start = DateTime.parse(v['Start date']!), end = DateTime.parse(v['End date']!);
    if (start.isBefore(today)) return toast(context, 'Leave cannot start in the past');
    if (end.isBefore(start)) return toast(context, 'The end date is before the start date');
    final who = members.firstWhere((m) => v['Who'] == m.name || v['Who'] == '${m.name} (you)');
    final l = Leave(who, start, end, v['Reason']!);
    save(() => leaves.insert(0, l));
    toast(context, who == me ? 'Sent to the admin: ${dayCount(l.days)}' : 'Added to your requests: ${dayCount(l.days)}');
  }

  @override
  Widget build(BuildContext context) {
    final mine = leaves.where((l) => l.who == me && l.status == 'Pending').toList();
    final past = leaves.where((l) => l.status != 'Pending').toList();
    final away = members.where((m) => onLeave(m, today)).toList();
    return page([
      sub(away.isEmpty ? 'Everyone in ${pod.name} is working today' : 'On leave today: ${away.map((m) => m.name).join(', ')}'),
      mainButton('Log leave', () => request(context)),
      sec('Waiting for you'),
      if (toDecide.isEmpty) empty('No requests from the pod'),
      for (final l in toDecide) LeaveCard(l),
      sec('Your requests'),
      if (mine.isEmpty) empty('None pending. Your leave is approved by the admin.'),
      for (final l in mine) LeaveCard(l),
      sec('Leave history'),
      if (past.isEmpty) empty('No decided requests yet'),
      if (past.isNotEmpty)
        Rows([for (final l in past) tile(l.who.name, s: l.days == 1 ? dm(l.start) : '${dm(l.start)} to ${dm(l.end)}', trail: stateTag(l.status))]),
    ]);
  }
}

// ---------- Calendar ----------
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime month = DateTime(today.year, today.month);
  DateTime day = today;
  int format = 0;

  List<Task> on(DateTime d) => tasks.where((t) => t.due != null && sameDay(t.due!, d) && (format == 0 || t.format == Format.values[format - 1])).toList();

  @override
  Widget build(BuildContext context) {
    final inMonth = tasks.where((t) => t.due != null && t.due!.year == month.year && t.due!.month == month.month).toList();
    final ready = inMonth.where((t) => t.stage == Stage.dispatched).length;
    final first = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday % 7; // Sunday first, like the site
    final picked = on(day);
    return page([
      Kv([('This month', '${inMonth.length}'), ('Approved', inMonth.isEmpty ? '0%' : '${ready * 100 ~/ inMonth.length}%')]),
      Chips(labels: ['All', for (final f in Format.values) f.label], selected: format, onSelect: (i) => setState(() => format = i)),
      Panel(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    monthName(month),
                    textAlign: TextAlign.center,
                    style: inter(16, w: FontWeight.w500),
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Row(
              children: [
                for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                  Expanded(
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: inter(12, c: C.mist),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [for (var i = 0; i < lead; i++) const SizedBox(), for (var n = 1; n <= days; n++) _day(DateTime(month.year, month.month, n))],
            ),
          ],
        ),
      ),
      sec('${dm(day)} · ${plural(picked.length, 'item')}'),
      if (picked.isEmpty) empty('Nothing due this day'),
      if (picked.isNotEmpty)
        Rows([
          for (final t in picked)
            tile(t.title, s: '${t.client.name} · ${t.format.label} · ${t.who.name}', trail: stageTag(t.stage), onTap: () => openReview(context, t)),
        ]),
    ]);
  }

  Widget _day(DateTime d) {
    final n = on(d).length;
    final sel = sameDay(d, day);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => day = d),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: sel ? C.text : null,
          borderRadius: BorderRadius.circular(8),
          border: sameDay(d, today) && !sel ? Border.all(color: C.accent) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${d.day}',
              style: inter(14, w: sel ? FontWeight.w500 : FontWeight.w400, c: sel ? C.ground : C.text),
            ),
            // A count, not just a dot, so it does not rely on colour.
            Text(
              n == 0 ? '' : '$n',
              style: inter(11, w: FontWeight.w500, c: sel ? C.ground : C.accent2),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Instagram queue ----------
class PublishingPage extends StatefulWidget {
  const PublishingPage({super.key});
  @override
  State<PublishingPage> createState() => _PublishingPageState();
}

class _PublishingPageState extends State<PublishingPage> {
  int filter = 0;

  Future<void> addPost() async {
    final ready = readyToSchedule;
    if (ready.isEmpty) return toast(context, 'Approve work on Review first. Only approved work can publish.');
    final v = await formSheet(context, 'Schedule a post', [
      // Numbered, so two tasks with the same client and title stay distinct.
      F('Approved work', options: [for (final (i, t) in ready.indexed) '${i + 1}. ${t.client.name} · ${t.title}'], required: true),
      const F('Publish at', date: true, time: true, required: true),
    ], 'Schedule');
    if (v == null || !mounted) return;
    final at = DateTime.parse(v['Publish at']!);
    final t = ready[int.parse(v['Approved work']!.split('.').first) - 1];
    if (!schedule(t, at)) return toast(context, 'Pick a time in the future');
    toast(context, 'Scheduled for ${when(at)}');
  }

  @override
  Widget build(BuildContext context) {
    final shown = slots.where((s) => filter == 0 || s.status == Post.values[filter - 1]).toList()..sort((a, b) => a.at.compareTo(b.at));
    return page([
      sub('Publishing times are separate from due dates. Only approved work can publish.'),
      mainButton('Schedule a post', addPost),
      Chips(labels: ['All ${slots.length}', for (final p in Post.values) p.label], selected: filter, onSelect: (i) => setState(() => filter = i)),
      if (shown.isEmpty) empty('Nothing in the queue'),
      for (final s in shown)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(s.task.client.name, style: inter(14, c: C.mist)),
                  ),
                  Text(
                    s.status.label,
                    style: inter(13, w: FontWeight.w500, c: C.accent2),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${s.task.title} · ${s.task.format.label} · v${s.task.version}', style: inter(16, w: FontWeight.w500)),
              Text(when(s.at), style: inter(14, c: C.mist)),
              if (s.status == Post.scheduled || s.status == Post.paused)
                actions([
                  if (s.status == Post.scheduled) small('Pause', () => save(() => s.status = Post.paused)),
                  if (s.status == Post.paused) small('Resume', () => save(() => s.status = Post.scheduled)),
                  small('Mark published', () => save(() => s.status = Post.published)),
                  small('Cancel', () async {
                    if (await confirm(context, 'Cancel this post?', 'Cancel post')) save(() => s.status = Post.canceled);
                  }),
                ]),
            ],
          ),
        ),
    ]);
  }
}

// ---------- Support ----------
class SupportPage extends StatefulWidget {
  const SupportPage({super.key});
  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  int view = 0, priority = 0;

  Future<void> raise() async {
    if (clients.isEmpty) return toast(context, 'Add a client first, on the Clients tab');
    final v = await formSheet(context, 'New ticket', [
      F('Client', options: [for (final c in clients) c.name], required: true),
      const F('Issue', required: true, lines: 3),
      const F('Priority', options: ['Urgent', 'High', 'Medium'], required: true, initial: 'Medium'),
    ], 'Open ticket');
    if (v == null || !mounted) return;
    save(
      () => tickets.insert(
        0,
        Ticket(clients.firstWhere((c) => c.name == v['Client']), v['Issue']!, Priority.values.firstWhere((p) => p.name == v['Priority']!.toLowerCase())),
      ),
    );
    toast(context, 'Ticket opened');
  }

  @override
  Widget build(BuildContext context) {
    String cap(Priority p) => '${p.name[0].toUpperCase()}${p.name.substring(1)}';
    final open = tickets.where((t) => t.open).toList();
    final closedToday = tickets.where((t) => t.closed != null && sameDay(t.closed!, today)).length;
    final shown = tickets.where((t) => t.open == (view == 0) && (priority == 0 || t.priority == Priority.values[priority - 1])).toList();
    return page([
      Kv([('Active', '${open.length}'), ('Resolved today', '$closedToday'), ('Urgent / high', '${open.where((t) => t.priority != Priority.medium).length}')]),
      mainButton('New ticket', raise),
      Chips(labels: ['Active ${open.length}', 'Closed ${tickets.length - open.length}'], selected: view, onSelect: (i) => setState(() => view = i)),
      Chips(labels: ['All', for (final p in Priority.values) cap(p)], selected: priority, onSelect: (i) => setState(() => priority = i)),
      if (shown.isEmpty) empty('No tickets match these filters'),
      for (final t in shown)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(t.client.name, style: inter(14, c: C.mist)),
                  ),
                  Tag(t.priority == Priority.medium ? Icons.remove : Icons.priority_high, cap(t.priority), t.priority == Priority.urgent ? C.rose : C.accent2),
                ],
              ),
              const SizedBox(height: 4),
              Text(t.issue, style: inter(16, w: FontWeight.w500)),
              Text(t.open ? 'Opened ${when(t.opened)}' : 'Closed ${when(t.closed!)}', style: inter(14, c: C.mist)),
              actions([
                t.open ? small('Resolve', () => save(() => t.closed = DateTime.now()), filled: true) : small('Reopen', () => save(() => t.closed = null)),
              ]),
            ],
          ),
        ),
    ]);
  }
}

// ---------- Settings ----------
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> edit(BuildContext context) async {
    final v = await formSheet(context, 'Personal details', [
      F(
        'Full name',
        required: true,
        initial: me.name,
        check: (s) => memberNameProblem(s, except: me),
      ),
      F(
        'Phone number',
        initial: phone,
        hint: 'Optional, for emergency pod dispatch',
        check: (s) {
          final n = s.replaceAll(RegExp(r'\D'), '').length;
          return n < 10 || n > 15 ? 'Enter 10 to 15 digits' : null;
        },
      ),
    ], 'Save changes');
    if (v == null) return;
    save(() {
      me.name = v['Full name']!;
      phone = normalPhone(v['Phone number']!);
    });
    if (context.mounted) toast(context, 'Saved');
  }

  Future<void> editPod(BuildContext context) async {
    final v = await formSheet(context, 'Your pod', [
      F('Pod name', required: true, initial: pod.name),
      F('Daily standup', required: true, initial: pod.standup, hint: 'e.g. 10:00 AM'),
    ], 'Save');
    if (v == null) return;
    save(() {
      pod.name = v['Pod name']!;
      pod.standup = v['Daily standup']!;
    });
  }

  @override
  Widget build(BuildContext context) => page([
    Row(
      children: [
        initials(me.name, r: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(me.name, style: inter(22, w: FontWeight.w500)),
              Text('Team lead · ${pod.name}', style: inter(15, c: C.mist)),
            ],
          ),
        ),
      ],
    ),
    sec('Personal details'),
    Rows([tile('Phone', s: phone.isEmpty ? 'Not added' : phone), tile('Work email', s: email.isEmpty ? 'Set by the organisation admin' : email)]),
    Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text('Contact support to change your account email', style: inter(13, c: C.mist)),
    ),
    mainButton('Edit details', () => edit(context)),
    sec('Your pod'),
    Rows([
      tile(pod.name, s: '${plural(members.length, 'member')} · you are the reporting lead', lead: const Icon(Icons.groups_outlined)),
      tile('${pod.standup} daily standup', s: 'Pod sync', lead: const Icon(Icons.schedule)),
      for (final m in members.skip(1)) tile(m.name, s: m.role, lead: initials(m.name, r: 16)),
    ]),
    actions([small('Edit pod', () => editPod(context))]),
  ]);
}

// ---------- Chat ----------
// ponytail: messages live in memory on this phone only, like the admin app, until the chat API exists.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  int filter = 0;
  String q = '';
  @override
  Widget build(BuildContext context) {
    final shown = allChannels.where((c) => (filter == 0 || (filter == 1) == c.group) && matches(q, [c.name, c.about])).toList();
    return page([
      sub('Pods, groups and direct messages'),
      Chips(
        labels: ['All', 'Groups ${allChannels.where((c) => c.group).length}', 'Direct ${allChannels.where((c) => !c.group).length}'],
        selected: filter,
        onSelect: (i) => setState(() => filter = i),
      ),
      SearchBox('Search channels or people', (v) => setState(() => q = v)),
      if (shown.isEmpty)
        empty('No match')
      else
        Rows([
          for (final c in shown)
            tile(
              c.group ? '# ${c.name}' : c.name,
              s: c.messages.isEmpty ? c.about : c.messages.last.text,
              lead: CircleAvatar(
                radius: 20,
                backgroundColor: C.raised,
                child: Icon(c.group ? Icons.tag : Icons.person_outline, size: 18, color: C.mist2),
              ),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _Thread(c))),
            ),
        ]),
    ]);
  }
}

class _Thread extends StatefulWidget {
  const _Thread(this.channel);
  final Channel channel;
  @override
  State<_Thread> createState() => _ThreadState();
}

class _ThreadState extends State<_Thread> {
  final input = TextEditingController();

  void send() {
    final text = input.text.trim();
    if (text.isEmpty) return;
    save(() => widget.channel.messages.add(Msg(me.name, text)));
    input.clear();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;
    return Scaffold(
      appBar: AppBar(
        title: Text(ch.group ? '# ${ch.name}' : ch.name, style: inter(18, w: FontWeight.w500)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: changed,
              builder: (_, _) => ch.messages.isEmpty
                  ? Center(
                      child: Text('No messages yet', style: inter(15, c: C.mist)),
                    )
                  : ListView(
                      reverse: true,
                      padding: const EdgeInsets.all(20),
                      children: [
                        for (final m in ch.messages.reversed)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 300),
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: C.raised, borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.text, style: inter(16)),
                                  Text(when(m.at), style: inter(12, c: C.mist)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      style: inter(16),
                      onSubmitted: (_) => send(),
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send',
                    onPressed: send,
                    icon: Icon(Icons.send, color: C.accent),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
