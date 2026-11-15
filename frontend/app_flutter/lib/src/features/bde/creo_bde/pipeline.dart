// Sales funnel and leads (/bde): stats, search, the four-lane queue and the table.
import 'package:flutter/material.dart';

import 'bde_shell.dart';
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
    final loading = currentBdeApi?.isLoading == true;
    final found = leads.where((l) => matches(q, [l.name, l.company, l.phone, l.email, l.requirements])).toList();
    final inThis = found.where((l) => lane.stages.contains(l.stage)).toList();

    // Live metrics from server if available
    final metrics = currentBdeApi?.liveMetrics;
    final livePipeline = metrics != null
        ? (metrics['pipeline_value'] as num?)?.toInt() ?? pipelineValue
        : pipelineValue;
    final liveConversion = metrics != null
        ? (metrics['conversion_rate'] != null ? '${(metrics['conversion_rate'] as num).toStringAsFixed(0)}%' : conversion)
        : conversion;
    final liveWon = metrics != null ? (metrics['won_count'] as num?)?.toInt() ?? wonCount : wonCount;
    final liveTotal = metrics != null ? (metrics['total_leads'] as num?)?.toInt() ?? leads.length : leads.length;

    return page([
      title('Sales funnel'),
      sub('${openLeads.length} open lead${openLeads.length == 1 ? '' : 's'} · ${shortDate(DateTime.now())}'),
      Kv([('Pipeline', inr(livePipeline)), ('Conversion', liveConversion), ('Won', '$liveWon of $liveTotal')]),
      // Loading shimmer placeholder while first fetch runs
      if (loading && leads.isEmpty)
        _LoadingShimmer()
      else ...[
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
          if (inThis.isEmpty)
            _EmptyLane(lane: lane, hasSearch: q.isNotEmpty, onAdd: () => newLead(context, lane: lane))
          else
            for (final l in inThis) LeadCard(l),
        ] else ...[
          if (found.isEmpty)
            _EmptyAll(hasLeads: leads.isNotEmpty, onAdd: () => newLead(context))
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
      ],
    ]);
  }
}

/// Shimmer skeleton shown while leads are loading for the first time.
class _LoadingShimmer extends StatefulWidget {
  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final alpha = (100 + (_ctrl.value * 80)).round();
        final fill = C.raised.withAlpha(alpha);
        Widget bar(double w, double h) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(width: w, height: h, decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(6))),
            );
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            bar(140, 14),
            const SizedBox(height: 8),
            for (var i = 0; i < 4; i++) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                height: 80,
                decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(14)),
              ),
            ],
            Center(child: Text('Loading your leads…', style: inter(14, c: C.mist))),
          ]),
        );
      },
    );
  }
}

/// Empty state for a specific lane with an illustration icon.
class _EmptyLane extends StatelessWidget {
  const _EmptyLane({required this.lane, required this.hasSearch, required this.onAdd});
  final Lane lane;
  final bool hasSearch;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (hasSearch) return empty('No match in ${lane.label}');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(children: [
        Icon(Icons.inbox_outlined, size: 48, color: C.mist),
        const SizedBox(height: 12),
        Text('No prospects in ${lane.label}', style: inter(16, w: FontWeight.w500, c: C.mist2)),
        const SizedBox(height: 4),
        Text('Tap Add to move a lead here or create a new one.', style: inter(14, c: C.mist), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        small('Add prospect', onAdd),
      ]),
    );
  }
}

/// Empty state for the full list (Table view).
class _EmptyAll extends StatelessWidget {
  const _EmptyAll({required this.hasLeads, required this.onAdd});
  final bool hasLeads;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (hasLeads) return empty('No match');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        Icon(Icons.people_outline, size: 56, color: C.mist),
        const SizedBox(height: 16),
        Text('No leads yet', style: inter(18, w: FontWeight.w500, c: C.mist2)),
        const SizedBox(height: 6),
        Text('Add your first prospect and start tracking\nfollow-ups and pipeline value.', style: inter(14, c: C.mist), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        mainButton('Add first prospect', onAdd),
      ]),
    );
  }
}
