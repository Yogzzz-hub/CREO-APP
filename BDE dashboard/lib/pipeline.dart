// Sales funnel and leads (/bde): stats, search, the four-lane queue and the table.
import 'package:flutter/material.dart';

import 'data.dart';
import 'leads.dart';
import 'ui.dart';

class PipelineTab extends StatefulWidget {
  const PipelineTab({super.key});
  @override
  State<PipelineTab> createState() => _PipelineTabState();
}

class _PipelineTabState extends State<PipelineTab> {
  String q = '';
  bool table = false;
  Lane lane = Lane.contacted;

  @override
  Widget build(BuildContext context) {
    final found = leads.where((l) => matches(q, [l.name, l.company, l.phone, l.email, l.requirements])).toList();
    final inThis = found.where((l) => lane.stages.contains(l.stage)).toList();
    return page([
      title('Sales funnel'),
      sub('${openLeads.length} open lead${openLeads.length == 1 ? '' : 's'} · ${shortDate(DateTime.now())}'),
      Kv([('Pipeline', inr(pipelineValue)), ('Conversion', conversion), ('Won', '$wonCount of ${leads.length}')]),
      SearchBox('Search prospects', (v) => setState(() => q = v)),
      Chips(labels: const ['Queue', 'Table'], selected: table ? 1 : 0, onSelect: (i) => setState(() => table = i == 1)),
      if (!table) ...[
        Chips(
          labels: [for (final l in Lane.values) '${l.label} ${found.where((x) => l.stages.contains(x.stage)).length}'],
          selected: lane.index,
          wrap: true,
          onSelect: (i) => setState(() => lane = Lane.values[i]),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(children: [
            Expanded(
                child: Text('${lane.label} · ${inr(inThis.fold(0, (s, l) => s + l.value))}', style: inter(16, w: FontWeight.w500, c: C.mist2))),
            small('Add', () => newLead(context, lane: lane)),
          ]),
        ),
        if (inThis.isEmpty) empty(q.isEmpty ? 'No clients in ${lane.label}. Tap Add to create a lead.' : 'No match in ${lane.label}'),
        for (final l in inThis) LeadCard(l),
      ] else ...[
        if (found.isEmpty)
          empty(leads.isEmpty ? 'No leads yet. Add a prospect to start tracking follow-ups.' : 'No match')
        else
          Rows([
            for (final l in found)
              tile(l.company,
                  s: '${l.name} · ${l.stage.label}\n${l.next == null ? 'No follow-up' : when(l.next!.due)} · ${inr(l.value)}',
                  trail: tempTag(l.temp),
                  onTap: () => openLead(context, l)),
          ]),
        mainButton('Add prospect', () => newLead(context)),
      ],
    ]);
  }
}
