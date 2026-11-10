// Everything about one lead: its card, its page and the forms that change it. Used by Pipeline and CRM.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data.dart';
import 'ui.dart';

/// Labels for the stage picker when adding a lead, as on the site's Add prospect form.
const _newStages = {'Contacted': Stage.contacted, 'Interested': Stage.meeting, 'In negotiation': Stage.negotiation, 'Won': Stage.won, 'Lost': Stage.lost};

String? _email(String v) => validEmail(v) ? null : 'Enter an email like name@brand.in';
String? _phone(String v) => normalPhone(v).length < 11 ? 'Enter 10 digits, or + and the country code' : null;
String? _score(String v) => (int.tryParse(v) ?? -1) < 0 || int.parse(v) > 100 ? 'Enter 0 to 100' : null;

/// The dashboard's Add prospect and the CRM's New lead, as one form.
Future<void> newLead(BuildContext context, {Lane lane = Lane.contacted}) async {
  final v = await formSheet(context, 'New lead', [
    const F('Contact name', required: true, hint: 'e.g. Rahul Sharma'),
    const F('Company / brand', required: true, hint: 'e.g. Acme Retail'),
    const F('Phone / WhatsApp', hint: '10 digits, or + and the country code', check: _phone),
    const F('Email', hint: 'contact@acme.com', check: _email),
    F('Stage', options: _newStages.keys.toList(), required: true, initial: _newStages.entries.firstWhere((e) => e.value == lane.stage).key),
    const F('Priority', options: ['Hot', 'Warm', 'Cold'], required: true, initial: 'Warm'),
    const F('Estimated value (₹)', number: true),
    const F('Industry'),
    const F('Location'),
    const F('Source', initial: 'Inbound website'),
    const F('Requirements', lines: 3, hint: 'e.g. 15 Instagram reels a month and a brand refresh'),
    const F('First action', initial: 'Initial qualification call'),
    const F('First follow-up', date: true, time: true),
  ], 'Create lead');
  if (v == null) return;
  final due = parseDate(v['First follow-up']);
  save(() {
    final l = Lead(
      name: v['Contact name']!,
      company: v['Company / brand']!,
      phone: normalPhone(v['Phone / WhatsApp']!),
      email: v['Email']!,
      stage: _newStages[v['Stage']]!,
      temp: Temp.values.firstWhere((t) => t.label == v['Priority']),
      value: toInt(v['Estimated value (₹)']),
      industry: v['Industry']!,
      location: v['Location']!,
      source: v['Source']!.isEmpty ? 'Manual' : v['Source']!,
      requirements: v['Requirements']!,
    );
    leads.add(l);
    if (due != null) followUps.add(FollowUp(l, v['First action']!.isEmpty ? 'Initial qualification call' : v['First action']!, 'Call', due));
  });
  if (context.mounted) toast(context, 'Lead added');
}

Future<void> logActivity(BuildContext context, Lead l) async {
  final v = await formSheet(context, 'Log a conversation', [
    const F('Type', options: ['Call', 'WhatsApp', 'Meeting', 'Note', 'Email'], required: true, initial: 'Call'),
    const F('What was discussed', required: true, lines: 3, hint: 'e.g. Talked about a quarterly campaign; call back in 3 days'),
    const F('Outcome or next step', hint: 'e.g. Send the pricing deck'),
    const F('Next follow-up', date: true, time: true),
  ], 'Save');
  if (v == null) return;
  save(() {
    l.activities.add(Activity(v['Type']!, v['What was discussed']!, v['Outcome or next step']!));
    if (parseDate(v['Next follow-up']) case final d?) setFollowUp(l, d);
  });
}

Future<void> nextAction(BuildContext context, Lead? lead) async {
  if (leads.isEmpty) return toast(context, 'Add a lead first');
  final v = await formSheet(context, 'Next action', [
    if (lead == null) F('Lead', options: [for (final l in leads) l.company], required: true),
    const F('Next action', required: true, hint: 'e.g. Send the proposal'),
    const F('Type', options: actionKinds, required: true, initial: 'Call'),
    const F('Due', date: true, time: true, required: true),
  ], 'Schedule');
  if (v == null) return;
  final l = lead ?? leads.firstWhere((x) => x.company == v['Lead']);
  save(() => followUps.add(FollowUp(l, v['Next action']!, v['Type']!, DateTime.parse(v['Due']!))));
}

Future<void> resolveFollowUp(BuildContext context, FollowUp f) async {
  final v = await formSheet(context, 'Resolve: ${f.title}', [
    const F('Resolution', options: ['Complete', 'Snooze'], required: true, initial: 'Complete'),
    const F('Outcome or reason', required: true, lines: 3),
    const F('Next action', hint: 'Needed when this is the lead\'s last one'),
    const F('Next due date', date: true, time: true, hint: 'The new date when snoozing'),
  ], 'Save');
  if (v == null) return;
  String? error;
  save(() => error = resolve(f,
      complete: v['Resolution'] == 'Complete', reason: v['Outcome or reason']!, nextTitle: v['Next action']!, due: parseDate(v['Next due date'])));
  if (context.mounted) toast(context, error ?? 'Saved');
}

Future<void> moveStage(BuildContext context, Lead l) async {
  final v = await formSheet(context, 'Move ${l.company}', [
    F('Stage', options: [for (final s in Stage.values) s.label], required: true, initial: l.stage.label),
    const F('Reason or outcome', lines: 2, hint: 'Needed for Lost, Nurture and Disqualified'),
    F('Booked value (₹), when won', number: true, initial: '${l.value}'),
  ], 'Move');
  if (v == null) return;
  final s = stageNamed(v['Stage']!);
  if ([Stage.lost, Stage.nurture, Stage.disqualified].contains(s) && v['Reason or outcome']!.isEmpty) {
    if (context.mounted) toast(context, 'Add a reason for ${s.label}');
    return;
  }
  save(() => setStage(l, s, reason: v['Reason or outcome']!, booked: toInt(v['Booked value (₹), when won'])));
}

Future<void> qualifyLead(BuildContext context, Lead l) async {
  final v = await formSheet(context, 'Qualification', [
    for (final f in factors) F('$f (0-100)', number: true, check: _score),
    const F('Override temperature', options: ['Hot', 'Warm', 'Cold']),
    const F('Evidence and reason', required: true, lines: 3, hint: 'Leave unknown scores blank; the lead stays Unknown until all five are in'),
  ], 'Save');
  if (v == null) return;
  final o = v['Override temperature']!;
  save(() => qualify(l, [for (final f in factors) int.tryParse(v['$f (0-100)']!)], o.isEmpty ? null : Temp.values.firstWhere((t) => t.label == o),
      v['Evidence and reason']!));
}

Future<void> consent(BuildContext context, Lead l) async {
  final v = await formSheet(context, 'WhatsApp permission', [
    F('Permission', options: const ['Unknown', 'Opted in', 'Opted out'], required: true, initial: l.consent),
    const F('Purpose', required: true, hint: 'e.g. Proposal follow-ups'),
    const F('Source and evidence', required: true, lines: 3, hint: 'A public number is not permission. Record what the client said.'),
  ], 'Save');
  if (v == null) return;
  save(() => setConsent(l, v['Permission']!, v['Purpose']!, v['Source and evidence']!));
}

/// Opens WhatsApp with the site's greeting. Nothing is sent until the BDE presses send there.
void whatsApp(Lead l) => launchUrl(
    Uri.https('wa.me', '/${l.phone.replaceAll(RegExp(r'\D'), '')}', {
      'text': 'Hello ${l.name}, this is Creo Creative Studio reaching out about your enquiry for ${l.company}. '
          'How can we help with your content and design?',
    }),
    mode: LaunchMode.externalApplication);

void plus3Days(BuildContext context, Lead l) {
  final d = plus3();
  save(() {
    setFollowUp(l, d);
    l.activities.add(Activity('Call', 'Follow-up moved to ${when(d)}'));
  });
  toast(context, 'Next follow-up ${when(d)}');
}

/// Next follow-up in words and colour: rose when late, amber today.
Widget followUpLine(Lead l) {
  final n = l.next;
  final c = n == null ? C.mist : n.overdue ? C.rose : n.dueToday ? C.accent2 : C.mist2;
  return Row(children: [
    Icon(Icons.event_outlined, size: 16, color: c),
    const SizedBox(width: 8),
    Expanded(child: Text(n == null ? 'No follow-up set' : '${n.overdue ? 'Late · ' : ''}${when(n.due)} · ${n.title}', style: inter(14, c: c), maxLines: 1, overflow: TextOverflow.ellipsis)),
  ]);
}

class LeadCard extends StatelessWidget {
  const LeadCard(this.l, {super.key});
  final Lead l;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Material(
          color: C.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openLead(context, l),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(l.company, style: inter(16, w: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  tempTag(l.temp),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: Text('${l.name} · ${l.stage.label}', style: inter(14, c: C.mist), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text(inr(l.value), style: inter(14, w: FontWeight.w500)),
                ]),
                if (l.requirements.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(l.requirements, style: inter(14, c: C.mist2), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 12),
                followUpLine(l),
                actions([
                  if (l.phone.isNotEmpty) small('WhatsApp', () => whatsApp(l)),
                  small('+3 days', () => plus3Days(context, l)),
                  small('Log', () => logActivity(context, l)),
                  small('Move', () => moveStage(context, l)),
                ]),
              ]),
            ),
          ),
        ),
      );
}

/// The lead workspace: contact, qualification, follow-ups and the activity timeline.
void openLead(BuildContext context, Lead l) => openPage(context, 'Lead', (c) {
      if (!leads.contains(l)) return [empty('This lead was deleted')];
      return [
        title(l.company),
        sub('${l.name}${l.industry.isEmpty ? '' : ' · ${l.industry}'}${l.location.isEmpty ? '' : ' · ${l.location}'}'),
        Kv([('Stage', l.stage.label), ('Value', inr(l.value)), ('Temperature', l.temp.label)]),
        if (l.score != null)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Qualification ${l.score}/100 · ${l.evidence}% evidence', style: inter(14, c: C.mist))),
        actions([
          if (l.phone.isNotEmpty) small('WhatsApp', () => whatsApp(l), filled: true),
          if (l.phone.isNotEmpty) small('Call', () => launchUrl(Uri(scheme: 'tel', path: l.phone))),
          small('+3 days', () => plus3Days(c, l)),
          small('Log', () => logActivity(c, l)),
          small('Next action', () => nextAction(c, l)),
          small('Move stage', () => moveStage(c, l)),
          small('Qualify', () => qualifyLead(c, l)),
          small('WhatsApp permission', () => consent(c, l)),
        ]),
        sec('Contact'),
        Rows([
          tile('Phone', s: l.phone.isEmpty ? 'None' : l.phone),
          tile('Email', s: l.email.isEmpty ? 'None' : l.email),
          tile('WhatsApp permission', s: l.consent),
          tile('Source', s: l.source),
        ]),
        sec('Requirements'),
        Panel(child: Text(l.requirements.isEmpty ? 'No requirements yet' : l.requirements, style: inter(15, c: l.requirements.isEmpty ? C.mist : C.text))),
        sec('Follow-ups'),
        if (l.pending.isEmpty)
          empty('No follow-up set. Add a next action so this lead keeps moving.')
        else
          Rows([
            for (final f in l.pending)
              tile(f.title, s: '${f.kind} · ${when(f.due)}${f.overdue ? ' · late' : ''}', trail: small('Resolve', () => resolveFollowUp(c, f))),
          ]),
        sec('Activity'),
        if (l.activities.isEmpty)
          empty('Nothing logged yet')
        else
          Rows([
            for (final a in l.activities.reversed)
              tile(a.summary, s: '${a.type} · ${when(a.at)}${a.outcome.isEmpty ? '' : '\n${a.outcome}'}'),
          ]),
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: OutlinedButton(
            onPressed: () async {
              if (!await confirm(c, 'Delete ${l.company}? Its follow-ups, proposals, referrals and drafts go too.', 'Delete')) return;
              save(() => deleteLead(l));
              if (c.mounted) Navigator.pop(c);
            },
            style: OutlinedButton.styleFrom(foregroundColor: C.rose),
            child: const Text('Delete lead'),
          ),
        ),
      ];
    });
