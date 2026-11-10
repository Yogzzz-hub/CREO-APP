// Revenue CRM (/bde/crm/*), the sections a BDE can open. Head-only actions (approve, verify,
// record invoices, targets, handoffs, settings) are left out; their sections show what will appear.
import 'package:flutter/material.dart';

import 'data.dart';
import 'leads.dart';
import 'ui.dart';

class CrmTab extends StatelessWidget {
  const CrmTab({super.key, this.initial = 0});
  final int initial;
  @override
  Widget build(BuildContext context) => TabPage(
        name: 'CRM',
        initial: initial,
        tabs: const ['Action center', 'Leads', 'Pipeline', 'Follow-ups', 'Proposals', 'Referrals', 'Messages', 'AI workspace', 'Reports', 'Handoffs'],
        // Not const, so each section rebuilds when the data changes.
        pages: [_Today(), _Leads(), _Pipeline(), _FollowUps(), _Proposals(), _Referrals(), _Messages(), _Ai(), _Reports(), _Handoffs()],
      );
}

class _Today extends StatelessWidget {
  const _Today();
  @override
  Widget build(BuildContext context) {
    final next = pendingFollowUps.take(5).toList();
    return page([
      sub('Personal performance · ${monthName(DateTime.now())} ${DateTime.now().year}'),
      Kv([('Active', '${openLeads.length}'), ('Open pipeline', inr(pipelineValue))]),
      Kv([('Booked this month', inr(bookedThisMonth)), ('Collected', inr(0))]),
      Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('$newThisMonth new this month · $winsThisMonth won this month', style: inter(14, c: C.mist))),
      sec('Your next moves'),
      Kv([('Due today', '$dueTodayCount'), ('Overdue', '$overdueCount'), ('In review', '$toReviewCount')]),
      if (next.isEmpty)
        empty('Your follow-up queue is clear. Add a next action from a lead.')
      else
        Rows([
          for (final f in next)
            tile(f.title,
                s: '${f.lead.company} · ${when(f.due)}${f.overdue ? ' · late' : ''}',
                trail: small('Resolve', () => resolveFollowUp(context, f)),
                onTap: () => openLead(context, f.lead)),
        ]),
      sec('Quality and outcomes'),
      Rows([
        tile('Follow-ups on time', trail: Text(onTimeRate, style: inter(15))),
        tile('Referrals sourced', trail: Text('${referrals.length}', style: inter(15))),
        tile('Booked value target', trail: Text('Set by your head', style: inter(15, c: C.mist))),
      ]),
      sec('Needs a next step'),
      if (needsNextStep.isEmpty)
        empty('Every active lead has a pending next action')
      else
        Rows([
          for (final l in needsNextStep)
            tile(l.company, s: 'No next action', trail: Icon(Icons.chevron_right, color: C.mist), onTap: () => openLead(context, l)),
        ]),
    ]);
  }
}

class _Leads extends StatefulWidget {
  const _Leads();
  @override
  State<_Leads> createState() => _LeadsState();
}

class _LeadsState extends State<_Leads> {
  String q = '';
  Stage? stage;
  Temp? temp;

  Widget filter<T>(String label, T? value, List<T> all, String Function(T) name, ValueChanged<T?> set) => Expanded(
        child: DropdownButtonFormField<T?>(
          initialValue: value,
          isExpanded: true,
          dropdownColor: C.raised,
          style: inter(15),
          decoration: InputDecoration(labelText: label),
          items: [DropdownMenuItem(value: null, child: Text('All')), for (final v in all) DropdownMenuItem(value: v, child: Text(name(v)))],
          onChanged: (v) => setState(() => set(v)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final found = leads
        .where((l) => matches(q, [l.name, l.company, l.email, l.phone]) && (stage == null || l.stage == stage) && (temp == null || l.temp == temp))
        .take(100)
        .toList();
    return page([
      SearchBox('Person, company, email or phone', (v) => setState(() => q = v)),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(children: [
          filter('Stage', stage, Stage.values, (s) => s.label, (v) => stage = v),
          const SizedBox(width: 12),
          filter('Temperature', temp, Temp.values, (t) => t.label, (v) => temp = v),
        ]),
      ),
      twoButtons(FilledButton(onPressed: () => newLead(context), child: const Text('New lead')),
          OutlinedButton(onPressed: () => importCsv(context), child: const Text('Import CSV'))),
      if (found.isEmpty)
        empty(leads.isEmpty ? 'Your next opportunity starts here. Add a lead or import a CSV.' : 'No lead matches these filters')
      else
        for (final l in found) LeadCard(l),
    ]);
  }
}

class _Pipeline extends StatelessWidget {
  const _Pipeline();
  @override
  Widget build(BuildContext context) {
    final stages = Stage.values.where((s) => s != Stage.nurture && s != Stage.disqualified);
    if (leads.isEmpty) return page([empty('Your next opportunity starts here. Add a lead from Leads.')]);
    return page([
      for (final s in stages) ...[
        sec('${s.label} · ${leads.where((l) => l.stage == s).length}'),
        for (final l in leads.where((l) => l.stage == s)) LeadCard(l),
      ],
    ]);
  }
}

class _FollowUps extends StatelessWidget {
  const _FollowUps();
  @override
  Widget build(BuildContext context) {
    final all = [...pendingFollowUps, ...followUps.where((f) => f.done).toList().reversed];
    return page([
      sub('Sorted by due time. Resolve each one with an outcome and the next step.'),
      mainButton('Next action', () => nextAction(context, null)),
      if (all.isEmpty)
        empty('No follow-ups yet. Create a lead or schedule a next action.')
      else
        Rows([
          for (final f in all)
            tile(f.title,
                s: '${f.lead.company} · ${f.kind} · ${when(f.due)}',
                lead: stateTag(f.done ? 'Done' : f.overdue ? 'Overdue' : 'Pending'),
                trail: f.done ? null : small('Resolve', () => resolveFollowUp(context, f)),
                onTap: () => openLead(context, f.lead)),
        ]),
    ]);
  }
}

class _Proposals extends StatelessWidget {
  const _Proposals();
  @override
  Widget build(BuildContext context) => page([
        sub('Priced, versioned and checked by your BDE head before a client sees it.'),
        mainButton('Create proposal', () => leads.isEmpty ? toast(context, 'Add a lead first') : buildProposal(context, null)),
        if (proposals.isEmpty) empty('No proposals yet. Build one from a lead.'),
        for (final p in proposals)
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${p.number} · v${p.version}', style: inter(14, c: C.accent2))),
                stateTag(p.status),
              ]),
              const SizedBox(height: 4),
              Text(p.title, style: inter(16, w: FontWeight.w500)),
              Text('${p.lead.company} · valid until ${dm(p.validUntil)}', style: inter(14, c: C.mist)),
              const SizedBox(height: 8),
              for (final MapEntry(key: b, value: t) in p.totals.entries) Text('${b.label}: ${inr(t.total)}', style: inter(14, c: C.mist2)),
              actions([
                small('Preview', () => previewProposal(context, p)),
                if (p.status != 'Superseded') small('Revise', () => buildProposal(context, p)),
              ]),
            ]),
          ),
      ]);
}

class _Referrals extends StatelessWidget {
  const _Referrals();

  Future<void> add(BuildContext context) async {
    if (leads.isEmpty) return toast(context, 'Add the referred lead first');
    final v = await formSheet(context, 'Register a referral', [
      F('Referred lead', options: [for (final l in leads) l.company], required: true),
      const F('Introduced by', required: true),
      const F('Source or campaign', initial: 'Referral'),
      const F('Context', lines: 3),
    ], 'Register');
    if (v == null) return;
    save(() => referrals.add(Referral(leads.firstWhere((l) => l.company == v['Referred lead']), v['Introduced by']!, v['Source or campaign']!, v['Context']!)));
  }

  @override
  Widget build(BuildContext context) => page([
        sub('You keep the credit for a referral even if the lead changes hands.'),
        mainButton('Register referral', () => add(context)),
        if (referrals.isEmpty)
          empty('No referrals yet. Link a referred lead and record who introduced them.')
        else
          Rows([
            for (final r in referrals) tile(r.lead.company, s: 'From ${r.referrer} · ${dm(r.at)}', trail: stateTag(r.status)),
          ]),
      ]);
}

class _Messages extends StatelessWidget {
  const _Messages();

  Future<void> add(BuildContext context) async {
    if (leads.isEmpty) return toast(context, 'Add a lead first');
    final v = await formSheet(context, 'Message draft', [
      F('Lead', options: [for (final l in leads) l.company], required: true),
      const F('Message', required: true, lines: 5),
    ], 'Save draft');
    if (v == null) return;
    save(() => drafts.insert(0, MessageDraft(leads.firstWhere((l) => l.company == v['Lead']), v['Message']!)));
    if (context.mounted) toast(context, 'Draft saved. Nothing was sent.');
  }

  @override
  Widget build(BuildContext context) => page([
        _provider('WhatsApp', 'Not connected', 'Your agency admin connects the official WhatsApp provider. Until then drafts stay inside Creo.'),
        mainButton('Draft message', () => add(context)),
        if (drafts.isEmpty) empty('No messages yet. Save a draft for a lead.'),
        for (final d in drafts)
          Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(d.lead.company, style: inter(16, w: FontWeight.w500))), stateTag(d.status)]),
            const SizedBox(height: 8),
            Text(d.body, style: inter(15, c: C.mist2)),
            const SizedBox(height: 4),
            Text(when(d.at), style: inter(13, c: C.mist)),
          ])),
      ]);
}

Widget _provider(String name, String state, String about) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(name, style: inter(16, w: FontWeight.w500))), Tag(Icons.link_off, state, C.mist)]),
      const SizedBox(height: 8),
      Text(about, style: inter(14, c: C.mist)),
    ]));

class _Ai extends StatelessWidget {
  const _Ai();
  @override
  Widget build(BuildContext context) => page([
        _provider('Licensed lead finder', 'Not connected',
            'Search an agency-approved provider by industry and location, check the source, then review each import. Your admin connects the provider.'),
        _provider('AI assistant', 'Not connected',
            'Drafts a summary, reply, proposal or next action for a lead, with the CRM evidence it used. You review and edit before using it.'),
      ]);
}

class _Reports extends StatelessWidget {
  const _Reports();
  @override
  Widget build(BuildContext context) => page([
        Kv([('Booked this month', inr(bookedThisMonth)), ('Collected', inr(0)), ('Invoiced', inr(0))]),
        sec('Invoices and receipts'),
        empty('Your BDE head records invoices and receipts after a deal is won. Accepting a proposal never marks it paid.'),
      ]);
}

class _Handoffs extends StatelessWidget {
  const _Handoffs();
  @override
  Widget build(BuildContext context) =>
      page([empty('No delivery handoffs yet. When a proposal is accepted, your BDE head hands the exact scope to delivery and it shows here.')]);
}

// ---------- CSV import ----------
Future<void> importCsv(BuildContext context) async {
  final v = await formSheet(context, 'Import CSV', [
    const F('CSV', required: true, lines: 6, hint: 'name,company_name,email,phone\nRahul Sharma,Acme Retail,rahul@acme.in,9876543210'),
    const F('First follow-up for these leads', date: true, time: true, required: true),
  ], 'Preview');
  if (v == null || !context.mounted) return;
  final rows = previewCsv(v['CSV']!);
  final ready = rows.every((r) => r.status == 'Ready') && rows.isNotEmpty;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (c) => ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
      Text('${rows.length} row${rows.length == 1 ? '' : 's'}', style: inter(22, w: FontWeight.w500)),
      sub(ready ? 'All rows are ready. Nothing is saved until you confirm.' : 'Fix the rows below and paste again.'),
      Rows([for (final r in rows) tile('Row ${r.row} · ${r.company.isEmpty ? '—' : r.company}', s: r.name, trail: stateTag(r.status == 'Ready' ? 'Done' : r.status))]),
      if (ready) mainButton('Confirm import', () => Navigator.pop(c, true)),
    ]),
  );
  if (ok != true) return;
  save(() => importRows(rows, DateTime.parse(v['First follow-up for these leads']!)));
  if (context.mounted) toast(context, '${rows.length} leads imported. WhatsApp permission stays unknown.');
}

// ---------- Proposal builder and preview ----------
void buildProposal(BuildContext context, Proposal? original) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => _Builder(original)));

class _Builder extends StatefulWidget {
  const _Builder(this.original);
  final Proposal? original;
  @override
  State<_Builder> createState() => _BuilderState();
}

class _BuilderState extends State<_Builder> {
  final form = GlobalKey<FormState>();
  late Lead? lead = widget.original?.lead;
  late String title = widget.original?.title ?? '', summary = widget.original?.summary ?? '';
  late String scope = widget.original?.scope ?? '', terms = widget.original?.terms ?? '';
  late double tax = widget.original?.taxPct ?? 0;
  late DateTime valid = today.add(const Duration(days: 14));
  late final lines = widget.original?.lines.map((l) => l.copy()).toList() ?? [Line()];

  Widget field(String label, String initial, ValueChanged<String> set, {int lines = 1, bool required = false, bool number = false}) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextFormField(
          initialValue: initial,
          minLines: lines,
          maxLines: lines,
          style: inter(16),
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
          decoration: InputDecoration(labelText: required ? '$label *' : label),
          validator: (v) => required && (v ?? '').trim().isEmpty
              ? '$label is needed'
              : number && double.tryParse(v ?? '') == null
                  ? 'Numbers only'
                  : null,
          onChanged: (v) => setState(() => set(v.trim())),
        ),
      );

  Widget lineCard(int i, Line l) => Panel(
          key: ObjectKey(l),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Service ${i + 1}', style: inter(14, w: FontWeight.w500, c: C.accent2))),
          if (lines.length > 1) TextButton(onPressed: () => setState(() => lines.removeAt(i)), child: Text('Remove', style: inter(14, c: C.rose))),
        ]),
        field('Service', l.title, (v) => l.title = v, required: true),
        field('Scope and deliverables', l.scope, (v) => l.scope = v, lines: 2),
        Row(children: [
          Expanded(child: field('Quantity', '${l.qty}', (v) => l.qty = double.tryParse(v) ?? 0, number: true)),
          const SizedBox(width: 12),
          Expanded(child: field('Unit price (₹)', '${l.price}', (v) => l.price = double.tryParse(v)?.round() ?? 0, number: true)),
        ]),
        Row(children: [
          Expanded(child: field('Discount %', '${l.discount}', (v) => l.discount = double.tryParse(v) ?? 0, number: true)),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: DropdownButtonFormField<Billing>(
                initialValue: l.billing,
                isExpanded: true,
                dropdownColor: C.raised,
                style: inter(16),
                decoration: const InputDecoration(labelText: 'Billing'),
                items: [for (final b in Billing.values) DropdownMenuItem(value: b, child: Text(b.label))],
                onChanged: (b) => setState(() => l.billing = b!),
              ),
            ),
          ),
        ]),
      ]));

  void submit() {
    if (!form.currentState!.validate()) return;
    if (lines.any((l) => l.discount < 0 || l.discount > 100 || l.qty <= 0 || l.price < 0)) return toast(context, 'Check quantities, prices and discounts');
    save(() => saveProposal(widget.original, lead!, title, valid, tax, lines, summary: summary, scope: scope, terms: terms));
    Navigator.pop(context);
    toast(context, 'Proposal saved. Your BDE head reviews it before it can be shared.');
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.original;
    return Scaffold(
      appBar: AppBar(title: Text(o == null ? 'New proposal' : 'Revise ${o.number}', style: inter(18, w: FontWeight.w500))),
      body: Form(
        key: form,
        child: page([
          if (o != null) Panel(child: Text('Saving makes version ${o.version + 1}. Version ${o.version} keeps its prices.', style: inter(14, c: C.mist2))),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DropdownButtonFormField<Lead>(
              initialValue: lead,
              isExpanded: true,
              dropdownColor: C.raised,
              style: inter(16),
              decoration: const InputDecoration(labelText: 'Client *'),
              items: [for (final l in leads) DropdownMenuItem(value: l, child: Text(l.company))],
              validator: (v) => v == null ? 'Client is needed' : null,
              onChanged: o == null ? (l) => setState(() => lead = l) : null,
            ),
          ),
          field('Proposal title', title, (v) => title = v, required: true),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                final d = await showDatePicker(context: context, firstDate: today, lastDate: DateTime(2030), initialDate: valid);
                if (d != null) setState(() => valid = d);
              },
              child: InputDecorator(
                  decoration: InputDecoration(labelText: 'Valid until', suffixIcon: Icon(Icons.event, color: C.mist)), child: Text(dm(valid), style: inter(16))),
            ),
          ),
          field('Tax %', '$tax', (v) => tax = double.tryParse(v) ?? 0, number: true),
          field('Executive summary', summary, (v) => summary = v, lines: 3),
          field('Scope, deliverables and timeline', scope, (v) => scope = v, lines: 3),
          sec('Service and price lines'),
          for (final (i, l) in lines.indexed) lineCard(i, l),
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton(onPressed: () => setState(() => lines.add(Line())), child: const Text('Add line'))),
          field('Payment terms and acceptance', terms, (v) => terms = v, lines: 3),
          sec('Totals'),
          _totals(totalsOf(lines, tax)),
          mainButton('Save proposal', submit),
        ]),
      ),
    );
  }
}

Widget _totals(Map<Billing, Totals> totals) => Panel(
    child: totals.isEmpty
        ? Text('No lines yet', style: inter(15, c: C.mist))
        : Column(children: [
            for (final (i, MapEntry(key: b, value: t)) in totals.entries.indexed) ...[
              if (i > 0) const Divider(height: 24),
              for (final (k, v) in [('${b.label} subtotal', t.subtotal), ('Discount', -t.discount), ('Tax', t.tax)])
                Row(children: [Expanded(child: Text(k, style: inter(14, c: C.mist))), Text(inr(v), style: inter(14, c: C.mist2))]),
              const SizedBox(height: 4),
              Row(children: [Expanded(child: Text('${b.label} total', style: inter(16, w: FontWeight.w500))), Text(inr(t.total), style: inter(16, w: FontWeight.w500))]),
            ],
          ]));

/// The proposal as the client will read it.
void previewProposal(BuildContext context, Proposal p) => openPage(context, '${p.number} · v${p.version}', (_) => [
      Text('Creo', style: inter(22, w: FontWeight.w500)),
      Text('${p.number} · version ${p.version} · valid until ${dm(p.validUntil)}', style: inter(14, c: C.mist)),
      const SizedBox(height: 16),
      title(p.title),
      sub('Prepared for ${p.lead.company} · ${p.lead.name}'),
      for (final (h, body) in [('Executive summary', p.summary), ('Scope and timeline', p.scope)])
        if (body.isNotEmpty) ...[sec(h), Panel(child: Text(body, style: inter(15)))],
      for (final MapEntry(key: b, value: _) in p.totals.entries) ...[
        sec('${b.label} charges'),
        Rows([
          for (final l in p.lines.where((l) => l.billing == b))
            tile(l.title,
                s: '${l.scope.isEmpty ? '' : '${l.scope}\n'}${l.qty} × ${inr(l.price)}${l.discount > 0 ? ' · ${l.discount}% off' : ''}',
                trail: Text(inr(l.gross - l.off), style: inter(15))),
        ]),
      ],
      sec('Totals'),
      _totals(p.totals),
      sec('Terms and acceptance'),
      Panel(child: Text(p.terms.isEmpty ? 'Terms to be agreed with the agency.' : p.terms, style: inter(15))),
      Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text('Confidential proposal. Prices apply to this version only.', style: inter(13, c: C.mist))),
    ]);
