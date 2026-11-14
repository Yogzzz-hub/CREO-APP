import 'package:flutter/material.dart';

import 'data.dart';
import 'profile.dart';
import 'ui.dart';

class InboxTab extends StatelessWidget {
  const InboxTab({super.key, this.initial = 0});
  final int initial;
  @override
  Widget build(BuildContext context) =>
      TabPage(name: 'Inbox', initial: initial, tabs: ['Chat', 'Support ${openTickets.length}'], pages: [_Chat(), _Support()]);
}

/// "5 m", "3 h", "2 d"
String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  return d.inMinutes < 60 ? '${d.inMinutes} m' : d.inHours < 24 ? '${d.inHours} h' : '${d.inDays} d';
}

// ---------- Chat ----------
// ponytail: messages live in memory on this phone only; no attachments or reactions until the chat API exists.
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
  Widget build(BuildContext context) {
    final ch = widget.channel;
    return Scaffold(
      appBar: AppBar(title: Text(ch.group ? '# ${ch.name}' : ch.name, style: inter(18, w: FontWeight.w600))),
      body: Column(children: [
        Expanded(
          child: ListenableBuilder(
            listenable: changed,
            builder: (_, _) => ch.messages.isEmpty
                ? Center(child: Text('No messages yet. Say hello.', style: inter(15, c: C.mist)))
                : ListView(reverse: true, padding: const EdgeInsets.all(20), children: [
                    for (final m in ch.messages.reversed)
                      Align(
                        alignment: m.from == me.name ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 300),
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(color: m.from == me.name ? C.raised : C.surface, borderRadius: BorderRadius.circular(16)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (m.from != me.name) Text(m.from, style: inter(13, w: FontWeight.w600, c: C.accent2)),
                            Text(m.text, style: inter(16)),
                            Text(ago(m.at), style: inter(12, c: C.mist)),
                          ]),
                        ),
                      ),
                  ]),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: input,
                      style: inter(16),
                      onSubmitted: (_) => send(),
                      decoration: const InputDecoration(
                          hintText: 'Type a message', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(999)), borderSide: BorderSide.none)))),
              IconButton(tooltip: 'Send', onPressed: send, icon: Icon(Icons.send, color: C.accent)),
            ]),
          ),
        ),
      ]),
    );
  }
}

void openThread(BuildContext context, Channel c) => Navigator.push(context, MaterialPageRoute(builder: (_) => _Thread(c)));

class _Chat extends StatefulWidget {
  const _Chat();
  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  String q = '';

  Future<void> newGroup() async {
    final v = await formSheet(context, 'New group', [const F('Group name', required: true, hint: 'e.g. pod-alpha-team')], 'Create group');
    if (v == null) return;
    final c = Channel(v['Group name']!.replaceAll(' ', '-').toLowerCase());
    if (nameTaken([for (final g in channels.where((g) => g.group)) g.name], c.name)) {
      if (mounted) toast(context, 'A group named ${c.name} already exists');
      return;
    }
    save(() => channels.add(c));
    if (mounted) openThread(context, c);
  }

  Future<void> newMessage() async {
    final names = [for (final p in people) p.name];
    if (names.isEmpty) return toast(context, 'Add team members first (Team)');
    final v = await formSheet(context, 'New message', [F('To', options: names, required: true)], 'Open chat');
    if (v == null) return;
    var c = channels.where((c) => !c.group && c.name == v['To']).firstOrNull;
    if (c == null) {
      c = Channel(v['To']!, group: false);
      save(() => channels.add(c!));
    }
    if (mounted) openThread(context, c);
  }

  @override
  Widget build(BuildContext context) {
    final list = channels.where((c) => matches(q, [c.name])).toList();
    Widget row(Channel c) => tile(c.name,
        s: c.messages.isEmpty ? 'No messages yet' : '${c.messages.last.from}: ${c.messages.last.text}',
        lead: c.group
            ? Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: C.raised, borderRadius: BorderRadius.circular(12)),
                child: Text('#', style: inter(18, w: FontWeight.w600, c: C.mist2)))
            : Initials(c.name),
        trail: c.messages.isEmpty ? null : Text(ago(c.messages.last.at), style: inter(12, c: C.mist)),
        onTap: () => openThread(context, c));
    final groups = list.where((c) => c.group).toList(), dms = list.where((c) => !c.group).toList();
    return page([
      SearchBox('Search chats', (v) => setState(() => q = v)),
      sec('Groups'),
      if (groups.isEmpty) empty('No groups yet.') else Rows([for (final c in groups) row(c)]),
      sec('Direct messages'),
      if (dms.isEmpty) empty('No messages yet.') else Rows([for (final c in dms) row(c)]),
      twoButtons(
        OutlinedButton(onPressed: newGroup, child: const Text('New group')),
        FilledButton(onPressed: newMessage, child: const Text('New message')),
      ),
    ]);
  }
}

// ---------- Support ----------
S prioStatus(String p) => switch (p) { 'Urgent' || 'High' => S.bad, 'Medium' => S.wait, _ => S.ok };

String get avgFirstReply {
  final waits = [for (final t in tickets) if (t.replies.isNotEmpty) t.replies.first.at.difference(t.opened).inMinutes];
  return waits.isEmpty ? '—' : '${waits.reduce((a, b) => a + b) ~/ waits.length} m';
}

void openTicket(BuildContext context, Ticket t) => openPage(context, 'Ticket #${t.id}', (c) => [
      title(t.subject),
      sub('${t.client} · opened ${ago(t.opened)} ago'),
      const SizedBox(height: 8),
      Status(t.closed ? S.ok : prioStatus(t.priority), t.closed ? 'Closed' : t.priority),
      Rows([tile('Assigned to', s: t.agent.isEmpty ? 'Nobody yet' : t.agent)]),
      sec('Replies'),
      if (t.replies.isEmpty) empty('No replies yet.') else Rows([for (final r in t.replies) tile(r.text, s: '${r.from} · ${ago(r.at)} ago')]),
      actions([
        if (!t.closed)
          small('Reply', () async {
            final v = await formSheet(c, 'Reply to ${t.client}', [const F('Message', required: true, lines: 4)], 'Send reply');
            if (v != null) save(() => t.replies.add(Msg(me.name, v['Message']!)));
          }, filled: true),
        small('Assign', () async {
          final v = await formSheet(c, 'Assign ticket', [F('Agent', options: [me.name, ...staffNames], required: true, initial: t.agent)], 'Assign');
          if (v != null) save(() => t.agent = v['Agent']!);
        }),
        small(t.closed ? 'Reopen' : 'Close ticket', () => save(() => t.closedAt = t.closed ? null : DateTime.now())),
      ]),
    ]);

class _Support extends StatefulWidget {
  const _Support();
  @override
  State<_Support> createState() => _SupportState();
}

class _SupportState extends State<_Support> {
  int state = 0, prio = 0; // state: 0 active, 1 closed. prio: 0 all, then priorities[prio - 1]
  String q = '';

  Future<void> newTicket() async {
    if (clients.isEmpty) return toast(context, 'Add a client first (Team, Clients)');
    final v = await formSheet(context, 'New ticket', [
      F('Client', options: clientNames, required: true),
      const F('Subject', required: true),
      const F('Priority', options: priorities, initial: 'Medium'),
      F('Assign to', options: [me.name, ...staffNames]),
    ], 'Open ticket');
    if (v == null) return;
    save(() => tickets.add(Ticket(v['Client']!, v['Subject']!, v['Priority']!, v['Assign to']!)));
  }

  @override
  Widget build(BuildContext context) {
    final list = tickets
        .where((t) => t.closed == (state == 1))
        .where((t) => prio == 0 || t.priority == priorities[prio - 1])
        .where((t) => matches(q, [t.subject, t.client, '#${t.id}']))
        .toList()
      ..sort((a, b) => a.opened.compareTo(b.opened));
    return page([
      const SizedBox(height: 4),
      Kv([('Open', '${openTickets.length}'), ('Solved today', '$solvedToday'), ('First reply', avgFirstReply)]),
      SearchBox('Search ticket number, client, subject', (v) => setState(() => q = v)),
      Chips(labels: ['Active ${openTickets.length}', 'Closed ${tickets.length - openTickets.length}'], selected: state, onSelect: (i) => setState(() => state = i)),
      Chips(labels: const ['All', ...priorities], selected: prio, onSelect: (i) => setState(() => prio = i)),
      if (list.isEmpty)
        empty(state == 0 ? 'No open tickets.' : 'No closed tickets.')
      else
        Rows([
          for (final t in list)
            tile(t.subject,
                s: '#${t.id} · ${t.client} · ${t.agent.isEmpty ? 'not assigned' : t.agent} · ${ago(t.opened)}',
                trail: Status(prioStatus(t.priority), t.priority),
                onTap: () => openTicket(context, t)),
        ]),
      mainButton('New ticket', newTicket),
    ]);
  }
}

class Settings extends StatelessWidget {
  const Settings({super.key});
  @override
  Widget build(BuildContext context) {
    Widget icon(IconData i) => Container(
        width: 36, height: 36, decoration: BoxDecoration(color: C.raised, borderRadius: BorderRadius.circular(10)), child: Icon(i, size: 20, color: C.mist2));
    const chev = Icon(Icons.chevron_right);
    return Scaffold(
      appBar: AppBar(title: Text('Back', style: inter(16, w: FontWeight.w500))),
      body: page([
        title('Settings'),
        sec('Account'),
        Rows([
          tile('Profile', s: me.name, lead: icon(Icons.person_outline), trail: chev,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Profile(pushed: true)))),
          tile('Roles and access', s: 'Admin, pod leads, sales, freelancers', lead: icon(Icons.shield_outlined), trail: chev, onTap: () => toast(context, 'Not built yet')),
          tile('Notifications', s: 'Drafts, leave, failed posts, tickets', lead: icon(Icons.notifications_outlined), trail: chev, onTap: () => toast(context, 'Not built yet')),
          tile('Payments', s: 'Not connected yet', lead: icon(Icons.payments_outlined), trail: chev, onTap: () => toast(context, 'Not built yet')),
        ]),
        sec('Reading and language'),
        Rows([
          tile('Text size', s: 'Follows your phone setting', lead: icon(Icons.text_fields), trail: chev, onTap: () => toast(context, 'Not built yet')),
          tile('Language', s: 'English', lead: icon(Icons.language), trail: chev, onTap: () => toast(context, 'Not built yet')),
        ]),
        Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text('Sign-in and log out arrive when the app is connected to the Creo server.', style: inter(14, c: C.mist))),
      ]),
    );
  }
}
