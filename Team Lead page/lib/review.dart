// Lead QA review (/lead/deliverables on the site): the queue, the checklist, and the two decisions.
import 'package:flutter/material.dart';

import 'data.dart';
import 'home.dart';
import 'ui.dart';

class ReviewTab extends StatefulWidget {
  const ReviewTab({super.key});
  @override
  State<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<ReviewTab> {
  int filter = 0;

  @override
  Widget build(BuildContext context) {
    final lists = [
      inStage(Stage.review),
      inStage(Stage.dispatched),
      // Sent back at least once and not yet resubmitted.
      inStage(Stage.progress).where((t) => t.version > 0).toList(),
    ];
    final shown = lists[filter];
    return page([
      title('Review'),
      sub('${pod.name} · lead QA'),
      Chips(
        labels: ['Pending QA ${lists[0].length}', 'With client ${lists[1].length}', 'In revision ${lists[2].length}'],
        selected: filter,
        onSelect: (i) => setState(() => filter = i),
      ),
      if (shown.isEmpty)
        empty(const ['Nothing waiting for QA', 'Nothing sent to clients yet', 'No work in revision'][filter])
      else
        Rows([
          for (final t in shown)
            tile(
              t.title,
              s: '${t.client.name} · ${t.format.label} · v${t.version} · ${t.who.name}',
              trail: stageTag(t.stage),
              onTap: () => openReview(context, t),
            ),
        ]),
    ]);
  }
}

void openReview(BuildContext context, Task t) => openPage(
  context,
  'Review',
  (c) => [
    Text('${t.client.name} · ${t.format.label} · v${t.version}', style: inter(14, c: C.mist)),
    title(t.title),
    sub('Creative: ${t.who.name}'),
    Padding(padding: const EdgeInsets.only(top: 8), child: stageTag(t.stage)),
    if (t.brief.isNotEmpty) ...[
      sec('Brief'),
      Panel(
        child: Text(t.brief, style: inter(15, c: C.mist2)),
      ),
    ],
    if (t.stage == Stage.review) ...[
      sec('Lead QA checklist'),
      Panel(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (final (i, item) in checklist.indexed)
              CheckboxListTile(
                value: t.checks[i],
                onChanged: (v) => save(() => t.checks[i] = v ?? false),
                title: Text(item, style: inter(15)),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: C.accent,
                checkColor: C.onAccent,
              ),
          ],
        ),
      ),
      twoButtons(
        OutlinedButton(onPressed: () => revisionForm(c, t), child: const Text('Request revision')),
        FilledButton(
          onPressed: () {
            if (!approve(t)) return toast(c, 'Tick every checklist item first');
            toast(c, 'Approved and sent to ${t.client.name}');
          },
          child: const Text('Approve & send'),
        ),
      ),
    ],
    sec('History'),
    if (t.history.isEmpty) empty('No history yet'),
    if (t.history.isNotEmpty) Rows([for (final e in t.history.reversed) tile(e.label, s: '${e.by} · ${when(e.at)}${e.note.isEmpty ? '' : '\n${e.note}'}')]),
  ],
);
