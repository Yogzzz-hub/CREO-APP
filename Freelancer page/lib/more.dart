// The other pages in a freelancer's menu: Workspace Hub (/slack), Time Off & Blackout (/freelancer/leave)
// and Profile & Settings (/freelancer/settings).
import 'package:flutter/material.dart';

import 'data.dart';
import 'ui.dart';

// ---------- Chat ----------
// ponytail: messages live in memory on this phone only, like the admin app, until the chat API exists.
class ChatTab extends StatefulWidget {
  const ChatTab({super.key});
  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  int filter = 0;
  String q = '';
  @override
  Widget build(BuildContext context) {
    final shown = channels.where((c) => (filter == 0 || (filter == 1) == c.group) && matches(q, [c.name, c.about])).toList();
    return page([
      title('Chat'),
      sub('Workspace hub'),
      Chips(labels: [
        'All',
        'Groups ${channels.where((c) => c.group).length}',
        'Direct ${channels.where((c) => !c.group).length}',
      ], selected: filter, onSelect: (i) => setState(() => filter = i)),
      SearchBox('Search channels or people', (v) => setState(() => q = v)),
      if (shown.isEmpty)
        empty('No match')
      else
        Rows([
          for (final c in shown)
            tile(c.group ? '# ${c.name}' : c.name,
                s: c.messages.isEmpty ? c.about : c.messages.last.text,
                lead: CircleAvatar(
                    radius: 20, backgroundColor: C.raised, child: Icon(c.group ? Icons.tag : Icons.person_outline, size: 18, color: C.mist2)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _Thread(c)))),
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
      appBar: AppBar(title: Text(ch.group ? '# ${ch.name}' : ch.name, style: inter(18, w: FontWeight.w500))),
      body: Column(children: [
        Expanded(
          child: ListenableBuilder(
            listenable: changed,
            builder: (_, _) => ch.messages.isEmpty
                ? Center(child: Text('No messages yet', style: inter(15, c: C.mist)))
                : ListView(reverse: true, padding: const EdgeInsets.all(20), children: [
                    for (final m in ch.messages.reversed)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 300),
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: C.raised, borderRadius: BorderRadius.circular(16)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m.text, style: inter(16)),
                            Text(when(m.at), style: inter(12, c: C.mist)),
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
                          hintText: 'Type a message', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide.none)))),
              IconButton(tooltip: 'Send', onPressed: send, icon: Icon(Icons.send, color: C.accent)),
            ]),
          ),
        ),
      ]),
    );
  }
}


// ---------- Time off ----------
class TimeOffTab extends StatelessWidget {
  const TimeOffTab({super.key});

  Future<void> request(BuildContext context) async {
    final v = await formSheet(context, 'Block out dates', [
      const F('Reason', options: blackoutReasons, required: true, initial: 'Holiday / Vacation'),
      const F('Start date', date: true, required: true),
      const F('End date', date: true, required: true),
      const F('Notes for project leads', lines: 3, hint: 'e.g. all active drafts delivered before I leave'),
    ], 'Send to team lead');
    if (v == null || !context.mounted) return;
    final start = DateTime.parse(v['Start date']!), end = DateTime.parse(v['End date']!);
    if (start.isBefore(today)) return toast(context, 'Time off cannot start in the past');
    if (end.isBefore(start)) return toast(context, 'The end date is before the start date');
    final b = Blackout(v['Reason']!, start, end, v['Notes for project leads']!);
    save(() => blackouts.insert(0, b));
    toast(context, 'Sent to your team lead: ${b.days} day${b.days == 1 ? '' : 's'}');
  }

  @override
  Widget build(BuildContext context) {
    final away = upcomingBlackouts.any((b) => !b.start.isAfter(today));
    return page([
      title('Time off'),
      sub(away ? 'You are marked away today' : 'You are available for projects'),
      Kv([('Blocked ahead', '${daysOf(upcomingBlackouts)} days'), ('In review', '${daysOf(pendingBlackouts)} days')]),
      mainButton('Block out dates', () => request(context)),
      sec('Your dates'),
      if (blackouts.isEmpty) empty('No dates blocked out'),
      for (final b in blackouts)
        Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(b.days == 1 ? dm(b.start) : '${dm(b.start)} to ${dm(b.end)}', style: inter(16, w: FontWeight.w500))),
            stateTag(b.status),
          ]),
          const SizedBox(height: 4),
          Text('${b.reason} · ${b.days} day${b.days == 1 ? '' : 's'} · reviewer: team lead', style: inter(14, c: C.mist)),
          if (b.notes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(b.notes, style: inter(15, c: C.mist2))),
          if (b.status == 'Pending')
            actions([
              small('Withdraw', () async {
                if (await confirm(context, 'Withdraw these dates?', 'Withdraw')) save(() => blackouts.remove(b));
              }),
            ]),
        ])),
    ]);
  }
}

// ---------- Profile ----------
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> edit(BuildContext context) async {
    final v = await formSheet(context, 'Edit profile', [
      F('Full name', required: true, initial: me.name),
      F('Contact phone', initial: me.phone, hint: '10-digit mobile', check: (s) {
        final n = s.replaceAll(RegExp(r'\D'), '').length;
        return n < 10 || n > 15 ? 'Enter 10 to 15 digits' : null;
      }),
    ], 'Save');
    if (v == null) return;
    save(() {
      me.name = v['Full name']!;
      me.phone = normalPhone(v['Contact phone']!);
    });
    if (context.mounted) toast(context, 'Profile saved');
  }

  // ponytail: no backend, so no email goes out and any 6-digit code is accepted. Wire to the site's OTP endpoint.
  Future<void> password(BuildContext context) async {
    toast(context, 'A 6-digit code was sent to your registered email');
    final v = await formSheet(context, 'Change password', [
      F('Code from the email', required: true, secret: true, check: (s) => RegExp(r'^\d{6}$').hasMatch(s) ? null : 'Enter the 6 digits'),
      F('New password', required: true, secret: true, check: (s) => s.length < 8 ? 'Use at least 8 characters' : null),
      const F('Repeat new password', required: true, secret: true),
    ], 'Change password');
    if (v == null || !context.mounted) return;
    if (v['New password'] != v['Repeat new password']) return toast(context, 'The two passwords do not match');
    toast(context, 'Password changed');
  }

  @override
  Widget build(BuildContext context) => page([
        title(me.name),
        sub('Freelancer · contractor'),
        Rows([
          tile('Email', s: me.email.isEmpty ? 'Set by the platform admin' : me.email),
          tile('Phone', s: me.phone.isEmpty ? 'Not added' : me.phone),
        ]),
        Padding(padding: const EdgeInsets.only(top: 8), child: Text('Ask executive support to change your email', style: inter(13, c: C.mist))),
        mainButton('Edit profile', () => edit(context)),
        sec('Password'),
        Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Reset your password or set one for direct sign-in. A one-time code goes to your email first.', style: inter(15, c: C.mist2)),
          actions([small('Change password', () => password(context))]),
        ])),
        sec('Payout terms'),
        Rows([
          tile('Payout model', s: 'Paid per approved task, in rupees'),
          tile('Platform fee', s: 'None. You get the full payout'),
          tile('Submissions go to', s: 'The executive admin'),
        ]),
      ]);
}
