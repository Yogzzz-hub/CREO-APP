import 'package:flutter/material.dart';

import 'data.dart';
import 'admin_api_service.dart';
import 'save_csv.dart';
import 'ui.dart';
import 'sales_workspace.dart';

class MoneyTab extends StatelessWidget {
  const MoneyTab({super.key, this.initial = 0});
  final int initial;
  @override
  Widget build(BuildContext context) => TabPage(
    name: 'Money',
    initial: initial,
    tabs: const ['Revenue', 'Plans', 'Sales'],
    pages: [_Revenue(), _Plans(), _Sales()],
  );
}

Future<void> newInvoice(BuildContext context, {String client = ''}) async {
  toast(
    context,
    'Invoices are created by the billing service. This app shows confirmed transaction records only.',
  );
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
      for (final v in invoices)
        csvRow([
          v.number,
          v.client,
          v.scope,
          v.date.toIso8601String().substring(0, 10),
          v.amount,
          v.method,
        ]),
    ];
    try {
      final done = await saveCsv('creo-invoices.csv', rows.join('\n'));
      if (mounted) toast(context, '$done, ${invoices.length} invoices');
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'The CSV could not be saved. Choose another location and retry.',
        );
      }
    }
  }

  void openInvoice(Invoice v) => openPage(
    context,
    'Invoice ${v.number}',
    (c) => [
      title('Invoice ${v.number}'),
      sub(longDate(v.date)),
      Rows([
        tile('Client', s: v.client),
        tile('Covers', s: v.scope),
        tile('Payment method', s: v.method),
        tile(
          'Amount',
          trail: Text(inr(v.amount), style: inter(18, w: FontWeight.w500)),
        ),
      ]),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = invoicedByMonth(now);
    final top = months.map((m) => m.$2).reduce((a, b) => a > b ? a : b);
    String short(int n) => n >= 100000
        ? '${(n / 100000).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')}L'
        : '${n ~/ 1000}K';
    final list =
        invoices
            .where((v) => pick == 0 || v.method == payMethods[pick - 1])
            .where((v) => matches(q, [v.client, v.scope, (v.number)]))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final methodTotals = <String, int>{
      for (final method in payMethods)
        method: invoices
            .where((v) => v.method == method)
            .fold(0, (sum, v) => sum + v.amount),
    };
    return page([
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monthly revenue from plans', style: inter(14, c: C.mist)),
            Text(inr(mrr), style: inter(30, w: FontWeight.w500)),
            Text(
              paidClients.isEmpty
                  ? 'No paying clients yet'
                  : '${paidClients.length} paying clients · average ${inr(mrr ~/ paidClients.length)}',
              style: inter(14, c: C.mist),
            ),
            if (top > 0) ...[
              const SizedBox(height: 20),
              Text('Invoiced per month', style: inter(13, c: C.mist)),
              const SizedBox(height: 8),
              SizedBox(
                height: 136,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (i, (m, v)) in months.indexed) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          label: '$m ${inr(v)}',
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                v == 0 ? '' : short(v),
                                style: inter(
                                  11,
                                  w: i == 5 ? FontWeight.w500 : FontWeight.w400,
                                  c: i == 5 ? C.text : C.mist,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 90 * v / top,
                                decoration: BoxDecoration(
                                  color: i == 5 ? C.accent : C.raised,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(m, style: inter(12, c: C.mist)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      Rows([
        for (final method in payMethods)
          tile(method, trail: money(methodTotals[method] ?? 0)),
      ]),
      sec('Invoices'),
      SearchBox(
        'Search client or invoice number',
        (v) => setState(() => q = v),
      ),
      Chips(
        labels: ['All', ...payMethods],
        selected: pick,
        onSelect: (i) => setState(() => pick = i),
      ),
      if (list.isEmpty)
        empty('No confirmed paid transactions yet')
      else
        Rows([
          for (final v in list)
            tile(
              v.client,
              s: '#${v.number} · ${dm(v.date)} · ${v.method}',
              trail: money(v.amount),
              onTap: () => openInvoice(v),
            ),
        ]),
      twoButtons(
        OutlinedButton(
          onPressed: invoices.isEmpty ? null : exportCsv,
          child: const Text('Export CSV'),
        ),
        FilledButton(
          onPressed: () => newInvoice(context),
          child: const Text('New invoice'),
        ),
      ),
    ]);
  }
}

class _Plans extends StatelessWidget {
  const _Plans();

  Future<void> newProposal(BuildContext context) async {
    if (clients.isEmpty) {
      return toast(context, 'Add a client first (Team, Clients)');
    }
    final v = await formSheet(context, 'Custom proposal', [
      F('Client', options: clientNames, required: true),
      F(
        'Target plan',
        options: [for (final p in plans) p.name],
        required: true,
      ),
      const F('Proposed rate, ₹ a month', required: true, number: true),
      const F('Scope notes and commitments', lines: 3),
    ], 'Send proposal');
    if (v == null || !context.mounted) return;
    final c = clients.firstWhere((c) => c.name == v['Client']);
    final rate = toInt(
      v.entries.firstWhere((e) => e.key.startsWith('Proposed rate,')).value,
    );
    if (c.serverId == null) {
      return toast(
        context,
        'Refresh clients: this client has no server ID for a proposal.',
      );
    }
    try {
      await currentAdminApi!.createNegotiation({
        'client_id': c.serverId,
        'client_name': c.name,
        'client_email': c.email,
        'target_topic': v['Target plan'],
        'proposed_rate': rate,
        'proposed_offer':
            '${v['Target plan']} at $rate',
        'current_plan': c.plan,
        'target_plan': v['Target plan'],
        'notes': v['Scope notes and commitments'],
        'send_email': false,
      });
      if (context.mounted) toast(context, 'Proposal saved on the server.');
    } catch (_) {
      if (context.mounted) {
        toast(
          context,
          'Could not confirm proposal save. Refresh proposals before retrying.',
        );
      }
    }
  }

  Future<void> counter(BuildContext context, Negotiation n) async {
    final v = await formSheet(context, 'Counter offer', [
      F(
        'New rate, ₹ a month',
        required: true,
        number: true,
        initial: '${n.proposed}',
      ),
    ], 'Send counter');
    if (v == null || !context.mounted) return;
    if (n.serverId == null) {
      return toast(
        context,
        'Refresh proposals: this proposal has no server ID.',
      );
    }
    final rate = toInt(
      v.entries.firstWhere((e) => e.key.startsWith('New rate,')).value,
    );
    try {
      await currentAdminApi!.actionNegotiation(n.serverId!, {
        'action': 'counter',
        'counter_price': rate,
        'counter_note': '',
      });
    } catch (_) {
      if (context.mounted) {
        toast(
          context,
          'Could not confirm counteroffer. Refresh proposals before retrying.',
        );
      }
    }
  }

  Future<void> act(BuildContext context, Negotiation n, String action) async {
    if (n.serverId == null) {
      return toast(
        context,
        'Refresh proposals: this proposal has no server ID.',
      );
    }
    try {
      await currentAdminApi!.actionNegotiation(n.serverId!, {
        'action': action,
        if (action == 'accept') 'agreed_price': n.proposed,
      });
    } catch (_) {
      if (context.mounted) {
        toast(
          context,
          'Could not confirm proposal update. Refresh before retrying.',
        );
      }
    }
  }

  Future<void> editPlan(BuildContext context, Plan p) async {
    toast(
      context,
      'Plan editing needs a server plan ID and an admin update endpoint; neither is available in this API.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final waiting = waitingProposals;
    final past = negotiations.where((n) => n.status != 'Waiting').toList();
    return page([
      for (final (i, n) in waiting.indexed)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Status(S.wait, 'Proposal waiting'),
              const SizedBox(height: 8),
              Text(
                '${n.client}: ${n.fromPlan} to ${n.toPlan}',
                style: inter(16, w: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                '${inr(n.proposed)} a month${planNamed(n.toPlan) == null ? '' : ' instead of ${inr(planNamed(n.toPlan)!.price)}'}',
                style: inter(14, c: C.mist2),
              ),
              if (n.notes.isNotEmpty)
                Text(n.notes, style: inter(14, c: C.mist)),
              actions([
                small('Reject', () => act(context, n, 'decline')),
                small('Counter', () => counter(context, n)),
                small(
                  'Accept',
                  () => act(context, n, 'accept'),
                  filled: i == 0,
                ),
              ]),
            ],
          ),
        ),
      sec('Plans'),
      for (final p in plans)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(p.name, style: inter(16, w: FontWeight.w500)),
                  ),
                  Text(inr(p.price), style: inter(18, w: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${p.includes} · ${clientsOn(p.name)} client${clientsOn(p.name) == 1 ? '' : 's'}',
                style: inter(14, c: C.mist),
              ),
              actions([small('Edit plan', () => editPlan(context, p))]),
            ],
          ),
        ),
      if (past.isNotEmpty) ...[
        sec('Past proposals'),
        Rows([
          for (final n in past)
            tile(
              '${n.client}: ${n.toPlan}',
              s: '${inr(n.proposed)} · ${dm(n.date)}',
              trail: Text(n.status, style: inter(13, c: C.mist)),
            ),
        ]),
      ],
      mainButton('New custom proposal', () => newProposal(context)),
    ]);
  }
}

class _Sales extends StatelessWidget {
  @override
  Widget build(BuildContext context) => page([
    title('Sales workspace'),
    sub(
      'Open the connected sales workspace to manage leads, stages and follow-ups.',
    ),
    mainButton('Open sales workspace', () {
      final session = currentAdminApi?.session;
      if (session == null) {
        toast(context, 'Sign in to open sales.');
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AdminSalesWorkspace(session: session),
        ),
      );
    }),
  ]);
}
