// The other pages in a BDE's menu: Plans catalog (/admin/plans), Workspace Hub (/slack) and Leave (/bde/leave).
import 'package:flutter/material.dart';

import 'data.dart';
import 'ui.dart';

// ---------- Plans ----------
class PlansTab extends StatelessWidget {
  const PlansTab({super.key});

  Future<void> propose(BuildContext context) async {
    final names = [for (final p in plans) p.name];
    final v = await formSheet(context, 'Custom retainer proposal', [
      const F('Client brand name', required: true, hint: 'e.g. Apex Media'),
      F('Recipient email', required: true, hint: 'client@brand.com', check: (s) => validEmail(s) ? null : 'Enter an email like name@brand.in'),
      F('Current plan', options: ['None', ...names], initial: 'None'),
      const F('Target plan and custom scope', required: true, hint: 'e.g. Scale with 2 pods'),
      const F('Standard rate (₹ a month)', number: true),
      const F('Proposed rate (₹ a month)', number: true, required: true),
      const F('Scope notes and commitments', lines: 3, hint: 'e.g. 12-month contract with 2 dedicated pods'),
    ], 'Send to admin');
    if (v == null) return;
    save(() => negotiations.insert(
        0,
        Negotiation(v['Client brand name']!, v['Recipient email']!, v['Current plan']!, v['Target plan and custom scope']!,
            toInt(v['Standard rate (₹ a month)']), toInt(v['Proposed rate (₹ a month)']), v['Scope notes and commitments']!)));
    if (context.mounted) toast(context, 'Proposal sent to the admin for review');
  }

  @override
  Widget build(BuildContext context) => page([
        title('Plans'),
        sub('Retainer tiers, quotas and turnaround'),
        for (final p in plans)
          Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Expanded(child: Text(p.name, style: inter(18, w: FontWeight.w500))),
              Text(inr(p.price), style: inter(18, w: FontWeight.w500)),
              Text(' a month', style: inter(14, c: C.mist)),
            ]),
            const SizedBox(height: 8),
            for (final i in p.includes)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [Icon(Icons.check, size: 16, color: C.mist), const SizedBox(width: 8), Expanded(child: Text(i, style: inter(14, c: C.mist2)))]),
              ),
          ])),
        sec('Your plan negotiations'),
        sub('Only clients you contacted. Other requests go to the admin.'),
        mainButton('Initiate custom proposal', () => propose(context)),
        if (negotiations.isEmpty)
          empty('No proposals for your clients yet')
        else
          Rows([
            for (final n in negotiations)
              tile(n.client,
                  s: '${n.fromPlan} to ${n.toPlan}\n${inr(n.proposed)} a month${n.standard > 0 ? ' · standard ${inr(n.standard)}' : ''} · ${dm(n.date)}',
                  trail: stateTag(n.status)),
          ]),
      ]);
}

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

// ---------- Leave ----------
class LeaveTab extends StatelessWidget {
  const LeaveTab({super.key});

  Future<void> request(BuildContext context) async {
    final v = await formSheet(context, 'Leave request', [
      const F('Category', options: leaveKinds, required: true, initial: 'Casual leave'),
      const F('Start date', date: true, required: true),
      const F('End date', date: true, required: true),
      const F('Handover notes and pipeline cover', required: true, lines: 4, hint: 'Live negotiations, who covers them, client touchpoints'),
    ], 'Send request');
    if (v == null || !context.mounted) return;
    final start = DateTime.parse(v['Start date']!), end = DateTime.parse(v['End date']!);
    if (start.isBefore(today)) return toast(context, 'Leave cannot start in the past');
    if (end.isBefore(start)) return toast(context, 'The end date is before the start date');
    final notes = v['Handover notes and pipeline cover']!;
    if (notes.length > 1500) return toast(context, 'Keep handover notes under 1,500 characters');
    final l = LeaveRequest(v['Category']!, start, end, notes);
    save(() => leaves.insert(0, l));
    toast(context, 'Sent to the agency admin: ${l.days} day${l.days == 1 ? '' : 's'}');
  }

  @override
  Widget build(BuildContext context) => page([
        title('Leave'),
        sub('$allowance paid days a year · requests go to the agency admin'),
        Kv([('Taken', '${daysWith('Approved')}'), ('In review', '${daysWith('Pending')}'), ('Left', '$daysLeft')]),
        mainButton('Request leave', () => request(context)),
        sec('Your requests'),
        if (leaves.isEmpty) empty('No leave requests yet'),
        for (final l in leaves)
          Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(l.days == 1 ? dm(l.start) : '${dm(l.start)} to ${dm(l.end)}', style: inter(16, w: FontWeight.w500))),
              stateTag(l.status),
            ]),
            const SizedBox(height: 4),
            Text('${l.kind} · ${l.days} day${l.days == 1 ? '' : 's'} · reviewer: agency admin', style: inter(14, c: C.mist)),
            const SizedBox(height: 8),
            Text(l.notes, style: inter(15, c: C.mist2)),
            if (l.status == 'Pending')
              actions([
                small('Withdraw', () async {
                  if (await confirm(context, 'Withdraw this leave request?', 'Withdraw')) save(() => leaves.remove(l));
                }),
              ]),
          ])),
      ]);
}
