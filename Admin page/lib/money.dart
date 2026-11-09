import 'package:flutter/material.dart';

import 'data.dart';
import 'save_csv.dart' if (dart.library.js_interop) 'save_csv_web.dart';
import 'ui.dart';

class MoneyTab extends StatelessWidget {
  const MoneyTab({super.key, this.initial = 0});
  final int initial;
  @override
  Widget build(BuildContext context) =>
      TabPage(name: 'Money', initial: initial, tabs: const ['Revenue', 'Plans', 'Sales'], pages: [_Revenue(), _Plans(), _Sales()]);
}

Future<void> newInvoice(BuildContext context, {String client = ''}) async {
  if (clients.isEmpty) return toast(context, 'Add a client first (Team, Clients)');
  final v = await formSheet(context, 'Create invoice', [
    F('Client', options: clientNames, required: true, initial: client),
    const F('What it covers', required: true, hint: 'e.g. Growth plan, November'),
    const F('Amount in ₹', required: true, number: true),
    const F('Payment method', options: payMethods, required: true, initial: 'Card, Razorpay'),
    F('Date', date: true, required: true, initial: today.toIso8601String().substring(0, 10)),
  ], 'Create invoice');
  if (v == null) return;
  save(() => invoices.add(Invoice(v['Client']!, v['What it covers']!, toInt(v['Amount in ₹']), v['Payment method']!, parseDate(v['Date'])!)));
  if (context.mounted) toast(context, 'Invoice created');
}

class _Revenue extends StatefulWidget {
  const _Revenue();
  @override
  State<_Revenue> createState() => _RevenueState();
}

class _RevenueState extends State<_Revenue> {
  int pick = 0; // 0 all, 1 card, 2 upi
  String q = '';

  Future<void> exportCsv() async {
    final rows = [
      csvRow(const ['Invoice', 'Client', 'Covers', 'Date', 'Amount', 'Method']),
      for (final v in invoices) csvRow([v.number, v.client, v.scope, v.date.toIso8601String().substring(0, 10), v.amount, v.method]),
    ];
    final done = await saveCsv('creo-invoices.csv', rows.join('\n'));
    if (mounted) toast(context, '$done, ${invoices.length} invoices');
  }

  void openInvoice(Invoice v) => openPage(context, 'Invoice ${v.number}', (c) => [
        title('Invoice ${v.number}'),
        sub(longDate(v.date)),
        Rows([
          tile('Client', s: v.client),
          tile('Covers', s: v.scope),
          tile('Payment method', s: v.method),
          tile('Amount', trail: Text(inr(v.amount), style: inter(18, w: FontWeight.w500))),
        ]),
      ]);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = invoicedByMonth(now);
    final top = months.map((m) => m.$2).reduce((a, b) => a > b ? a : b);
    String short(int n) => n >= 100000 ? '${(n / 100000).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')}L' : '${n ~/ 1000}K';
    final list = invoices
        .where((v) => pick == 0 || v.method == payMethods[pick - 1])
        .where((v) => matches(q, [v.client, v.scope, '${v.number}']))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return page([
      Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Monthly revenue from plans', style: inter(14, c: C.mist)),
        Text(inr(mrr), style: inter(30, w: FontWeight.w500)),
        Text(paidClients.isEmpty ? 'No paying clients yet' : '${paidClients.length} paying clients · average ${inr(mrr ~/ paidClients.length)}',
            style: inter(14, c: C.mist)),
        if (top > 0) ...[
          const SizedBox(height: 20),
          Text('Invoiced per month', style: inter(13, c: C.mist)),
          const SizedBox(height: 8),
          SizedBox(
            height: 136,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final (i, (m, v)) in months.indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                    child: Semantics(
                  label: '$m ${inr(v)}',
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(v == 0 ? '' : short(v), style: inter(11, w: i == 5 ? FontWeight.w500 : FontWeight.w400, c: i == 5 ? C.text : C.mist)),
                    const SizedBox(height: 4),
                    Container(
                      height: 90 * v / top,
                      decoration: BoxDecoration(color: i == 5 ? C.accent : C.raised, borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
                    ),
                    const SizedBox(height: 8),
                    Text(m, style: inter(12, c: C.mist)),
                  ]),
                )),
              ],
            ]),
          ),
        ],
      ])),
      Rows([
        tile('Card, Razorpay', trail: money(cardTotal)),
        tile('UPI or bank transfer', trail: money(upiTotal)),
      ]),
      sec('Invoices'),
      SearchBox('Search client or invoice number', (v) => setState(() => q = v)),
      Chips(labels: ['All', ...payMethods], selected: pick, onSelect: (i) => setState(() => pick = i)),
      if (list.isEmpty)
        empty('No invoices yet')
      else
        Rows([for (final v in list) tile(v.client, s: '#${v.number} · ${dm(v.date)} · ${v.method}', trail: money(v.amount), onTap: () => openInvoice(v))]),
      twoButtons(
        OutlinedButton(onPressed: invoices.isEmpty ? null : exportCsv, child: const Text('Export CSV')),
        FilledButton(onPressed: () => newInvoice(context), child: const Text('New invoice')),
      ),
    ]);
  }
}

class _Plans extends StatelessWidget {
  const _Plans();

  Future<void> newProposal(BuildContext context) async {
    if (clients.isEmpty) return toast(context, 'Add a client first (Team, Clients)');
    final v = await formSheet(context, 'Custom proposal', [
      F('Client', options: clientNames, required: true),
      F('Target plan', options: [for (final p in plans) p.name], required: true),
      const F('Proposed rate, ₹ a month', required: true, number: true),
      const F('Scope notes and commitments', lines: 3),
    ], 'Send proposal');
    if (v == null) return;
    final c = clients.firstWhere((c) => c.name == v['Client']);
    save(() => negotiations.add(Negotiation(c.name, c.plan ?? 'No plan', v['Target plan']!, toInt(v['Proposed rate, ₹ a month']), v['Scope notes and commitments']!)));
    if (context.mounted) toast(context, 'Proposal saved');
  }

  Future<void> counter(BuildContext context, Negotiation n) async {
    final v = await formSheet(context, 'Counter offer', [F('New rate, ₹ a month', required: true, number: true, initial: '${n.proposed}')], 'Send counter');
    if (v != null) {
      save(() {
        n.proposed = toInt(v['New rate, ₹ a month']);
        n.status = 'Countered';
      });
    }
  }

  void accept(BuildContext context, Negotiation n) {
    save(() {
      n.status = 'Accepted';
      final c = clients.where((c) => c.name == n.client).firstOrNull;
      c?.plan = n.toPlan;
      c?.customFee = n.proposed;
    });
    toast(context, '${n.client} moved to ${n.toPlan} at ${inr(n.proposed)}');
  }

  Future<void> editPlan(BuildContext context, Plan p) async {
    final v = await formSheet(context, 'Edit ${p.name}', [
      F('Price, ₹ a month', required: true, number: true, initial: '${p.price}'),
      F('Posts a month', required: true, number: true, initial: '${p.posts}'),
      F('Reels a month', required: true, number: true, initial: '${p.reels}'),
      F('Stories a month', required: true, number: true, initial: '${p.stories}'),
      F('Turnaround', required: true, initial: p.turnaround),
      F('Extras', initial: p.extras),
    ], 'Save plan');
    if (v == null) return;
    save(() {
      p
        ..price = toInt(v['Price, ₹ a month'])
        ..posts = toInt(v['Posts a month'])
        ..reels = toInt(v['Reels a month'])
        ..stories = toInt(v['Stories a month'])
        ..turnaround = v['Turnaround']!
        ..extras = v['Extras']!;
    });
  }

  @override
  Widget build(BuildContext context) {
    final waiting = waitingProposals;
    final past = negotiations.where((n) => n.status != 'Waiting').toList();
    return page([
      for (final (i, n) in waiting.indexed)
        Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Status(S.wait, 'Proposal waiting'),
          const SizedBox(height: 8),
          Text('${n.client}: ${n.fromPlan} to ${n.toPlan}', style: inter(16, w: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('${inr(n.proposed)} a month${planNamed(n.toPlan) == null ? '' : ' instead of ${inr(planNamed(n.toPlan)!.price)}'}', style: inter(14, c: C.mist2)),
          if (n.notes.isNotEmpty) Text(n.notes, style: inter(14, c: C.mist)),
          actions([
            small('Reject', () => save(() => n.status = 'Rejected')),
            small('Counter', () => counter(context, n)),
            small('Accept', () => accept(context, n), filled: i == 0),
          ]),
        ])),
      sec('Plans'),
      for (final p in plans)
        Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(p.name, style: inter(16, w: FontWeight.w500))),
            Text(inr(p.price), style: inter(18, w: FontWeight.w500)),
          ]),
          const SizedBox(height: 4),
          Text('${p.includes} · ${clientsOn(p.name)} client${clientsOn(p.name) == 1 ? '' : 's'}', style: inter(14, c: C.mist)),
          actions([small('Edit plan', () => editPlan(context, p))]),
        ])),
      if (past.isNotEmpty) ...[
        sec('Past proposals'),
        Rows([for (final n in past) tile('${n.client}: ${n.toPlan}', s: '${inr(n.proposed)} · ${dm(n.date)}', trail: Text(n.status, style: inter(13, c: C.mist)))]),
      ],
      mainButton('New custom proposal', () => newProposal(context)),
    ]);
  }
}

class _Sales extends StatefulWidget {
  const _Sales();
  @override
  State<_Sales> createState() => _SalesState();
}

class _SalesState extends State<_Sales> {
  int pick = 0; // 0 all, then leadStages[pick - 1]
  String q = '';

  Future<void> newLead() async {
    final reps = [for (final p in peopleOf(Kind.sales)) p.name];
    if (reps.isEmpty) return toast(context, 'Add a salesperson first (Team, Sales team)');
    final v = await formSheet(context, 'Add a lead', [
      const F('Company', required: true),
      F('Salesperson', options: reps, required: true),
      const F('Priority', options: priorities, initial: 'Medium'),
      const F('Estimated value, ₹ a month', number: true),
    ], 'Add lead');
    if (v == null) return;
    save(() => leads.add(Lead(v['Company']!, v['Salesperson']!, v['Priority']!, toInt(v['Estimated value, ₹ a month']))));
  }

  void openLead(Lead l) => openPage(context, l.company, (c) => [
        title(l.company),
        sub('${l.rep} · ${l.priority} priority'),
        Kv([('Stage', l.stage), ('Value', inr(l.value)), ('Touchpoints', '${l.touchpoints}')]),
        Panel(child: Text('Last contacted ${longDate(l.last)}', style: inter(15, c: C.mist2))),
        actions([
          small('Log a call or meeting', () => save(() {
                l.touchpoints++;
                l.last = DateTime.now();
              }), filled: true),
        ]),
        sec('Move to stage'),
        actions([for (final s in leadStages) if (s != l.stage) small(s, () => save(() => l.stage = s))]),
      ]);

  @override
  Widget build(BuildContext context) {
    final list = leads.where((l) => pick == 0 || l.stage == leadStages[pick - 1]).where((l) => matches(q, [l.company, l.rep])).toList()
      ..sort((a, b) => priorities.indexOf(a.priority).compareTo(priorities.indexOf(b.priority)));
    return page([
      const SizedBox(height: 4),
      Kv([('Leads', '${leads.length}'), ('Pipeline', inr(pipelineValue)), ('Win rate', winRate)]),
      SearchBox('Search company or salesperson', (v) => setState(() => q = v)),
      Chips(labels: ['All ${leads.length}', for (final s in leadStages) '$s ${leads.where((l) => l.stage == s).length}'], selected: pick, onSelect: (i) => setState(() => pick = i)),
      if (list.isEmpty)
        empty('No leads here yet')
      else
        Rows([
          for (final l in list)
            tile(l.company, s: '${l.rep} · ${l.priority} · ${inr(l.value)}', trail: Text(l.stage, style: inter(13, c: C.mist)), onTap: () => openLead(l)),
        ]),
      mainButton('Add a lead', newLead),
    ]);
  }
}
