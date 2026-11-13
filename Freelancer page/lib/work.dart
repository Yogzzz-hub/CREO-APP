// Assigned Workload (/freelancer/tasks): earnings, the four status filters, task cards,
// the task page with its brief and history, and the upload sheet.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data.dart';
import 'ui.dart';

/// Opens only web links. Task links are typed by team leads, so a tel:, intent:, file: or broken link is refused
/// instead of handed to the phone (Uri.parse would also throw on a malformed one).
Future<void> openLink(BuildContext context, String url) async {
  if (!validUrl(url)) return toast(context, 'This link is not a web address');
  final ok = await launchUrl(Uri.parse(url.trim()), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) toast(context, 'Could not open the link');
}

class WorkTab extends StatefulWidget {
  const WorkTab({super.key, this.initial = 0});
  final int initial;
  @override
  State<WorkTab> createState() => _WorkTabState();
}

class _WorkTabState extends State<WorkTab> {
  late int filter = widget.initial;

  @override
  Widget build(BuildContext context) {
    final bucket = buckets[filter];
    final shown = tasksIn(bucket);
    return page([
      title('Work'),
      sub('Tasks from your team leads'),
      const _Earnings(),
      Chips(
          wrap: true,
          labels: [for (final b in buckets) '${b.label} ${countIn(b)}'],
          selected: filter,
          onSelect: (i) => setState(() => filter = i)),
      if (tasks.isEmpty)
        empty('No tasks yet. Team leads send each task with a brief, a due date and its payout.')
      else if (shown.isEmpty)
        empty('Nothing in ${bucket.label.toLowerCase()}')
      else
        for (final t in shown) _TaskCard(t),
    ]);
  }
}

/// Paid so far against everything assigned, with a thin bar between the two.
class _Earnings extends StatelessWidget {
  const _Earnings();
  @override
  Widget build(BuildContext context) {
    final approved = countIn(Status.done);
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Earned', style: inter(14, c: C.mist)),
        const SizedBox(height: 4),
        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
          Text(inr(earned), style: inter(32, w: FontWeight.w500)),
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('of ${inr(expected)} expected', style: inter(15, c: C.mist))),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
              value: expected == 0 ? 0 : earned / expected, minHeight: 6, color: C.accent, backgroundColor: C.raised, semanticsLabel: 'Share of payout earned'),
        ),
        const SizedBox(height: 8),
        Text('$approved approved · ${tasks.length} task${tasks.length == 1 ? '' : 's'} · paid on sign-off', style: inter(13, c: C.mist)),
      ]),
    );
  }
}

/// "₹4,500 · 16:9 4K Video · 45 s · due 5 Nov", with the due date in red when late.
Widget meta(Task t) => Text.rich(
    TextSpan(style: inter(14, c: C.mist), children: [
      TextSpan(text: inr(t.fee), style: inter(14, w: FontWeight.w500, c: C.mist2)),
      TextSpan(text: ' · ${t.format}'),
      if (t.length.isNotEmpty) TextSpan(text: ' · ${t.length}'),
      if (t.due != null) TextSpan(text: ' · due ${dm(t.due!)}', style: t.late ? inter(14, w: FontWeight.w500, c: C.rose) : null),
    ]));

/// The one next step for a task, or nothing once it is paid.
List<Widget> nextStep(BuildContext context, Task t) => switch (t.status) {
      Status.assigned => [
          small('Start working', filled: true, () {
            startWork(t);
            toast(context, 'Started. Upload your work when it is ready');
          })
        ],
      Status.working => [small('Upload and submit', filled: true, () => upload(context, t))],
      Status.revision => [small('Submit revision', filled: true, () => upload(context, t))],
      Status.review => [small('Re-upload', () => upload(context, t))],
      Status.done => [],
    };

class _TaskCard extends StatelessWidget {
  const _TaskCard(this.t);
  final Task t;
  @override
  Widget build(BuildContext context) => Panel(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => openTask(context, t),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(t.client, style: inter(13, c: C.mist))), statusTag(t.status)]),
              const SizedBox(height: 4),
              Text(t.title, style: inter(18, w: FontWeight.w500)),
              const SizedBox(height: 4),
              meta(t),
              if (t.status == Status.review) ...[
                const SizedBox(height: 8),
                Text('v${t.submissions.length} waiting for QA sign-off', style: inter(14, c: C.mist2)),
              ],
              if (nextStep(context, t).isNotEmpty) actions(nextStep(context, t)),
            ]),
          ),
        ),
      );
}

void openTask(BuildContext context, Task t) => openPage(context, 'Task', (c) => [
      Text(t.client, style: inter(14, c: C.mist)),
      title(t.title),
      Padding(padding: const EdgeInsets.only(top: 8), child: statusTag(t.status)),
      Kv([('Payout', inr(t.fee)), ('Due', t.due == null ? 'Not set' : dm(t.due!)), ('Length', t.length.isEmpty ? 'Any' : t.length)]),
      sub(t.format),
      if (nextStep(c, t).isNotEmpty) actions(nextStep(c, t)),
      sec('Source footage'),
      if (t.sourceUrl.isEmpty)
        empty('Source link pending from the admin or team lead')
      else
        Rows([tile('Open source footage', s: 'Download the files to edit', trail: Icon(Icons.open_in_new, size: 18, color: C.mist), onTap: () => openLink(c, t.sourceUrl))]),
      if (t.hook.isNotEmpty) ...[sec('Hook'), Panel(child: Text('"${t.hook}"', style: inter(16)))],
      if (t.audio.isNotEmpty) ...[sec('Sound direction'), Panel(child: Text(t.audio, style: inter(16)))],
      if (t.referenceUrl.isNotEmpty)
        Rows([tile('Open reference video', trail: Icon(Icons.open_in_new, size: 18, color: C.mist), onTap: () => openLink(c, t.referenceUrl))]),
      if (t.brief.isNotEmpty) ...[sec('Brief and scope'), Panel(child: Text(t.brief, style: inter(16, c: C.mist2)))],
      sec('Submissions'),
      if (t.submissions.isEmpty)
        empty('Nothing submitted yet')
      else
        Rows([
          for (final s in t.submissions.reversed)
            tile('v${s.version} · ${s.name}',
                s: [if (s.bytes != null) mb(s.bytes!), when(s.at), if (s.notes.isNotEmpty) s.notes].join(' · '),
                trail: s.url.isEmpty ? null : Icon(Icons.open_in_new, size: 18, color: C.mist),
                onTap: s.url.isEmpty ? null : () => openLink(c, s.url)),
        ]),
      sec('History'),
      if (t.history.isEmpty)
        empty('No history yet. Entries appear as team leads and clients review this task.')
      else
        Rows([
          for (final e in t.history.reversed) tile(e.label, s: [e.by, when(e.at), if (e.note.isNotEmpty) e.note].join(' · ')),
        ]),
    ]);

Future<void> upload(BuildContext context, Task t) async {
  final sent = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => UploadSheet(t));
  if (sent == true && context.mounted) toast(context, 'v${t.submissions.length} sent to the admin for review');
}

/// Send the finished work as a file from the phone or as a cloud link (Drive, Frame.io, Dropbox).
// ponytail: no backend, so a picked file is recorded by name and size only; it is not uploaded anywhere.
class UploadSheet extends StatefulWidget {
  const UploadSheet(this.task, {super.key});
  final Task task;
  @override
  State<UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<UploadSheet> {
  final key = GlobalKey<FormState>();
  final link = TextEditingController(), notes = TextEditingController();
  bool byLink = false;
  String? fileName, error;
  int? fileBytes;

  @override
  void dispose() {
    link.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> choose() async {
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: uploadTypes);
    if (f == null) return;
    final size = f.lengthSync() ?? await f.length();
    setState(() {
      // The picker's type filter is only a hint on web (the browser lets you pick "All files"), so check again here.
      if (!uploadTypes.contains(f.extension?.toLowerCase())) {
        error = '${f.name} is not an MP4, MOV, PNG, JPG, PDF, ZIP or PSD file';
        return;
      }
      if (size != null && size > maxUploadBytes) {
        error = '${f.name} is ${mb(size)}. Files must be 500 MB or less';
        return;
      }
      fileName = f.name;
      fileBytes = size;
      error = null;
    });
  }

  void send() {
    if (!key.currentState!.validate()) return;
    if (!byLink && fileName == null) return setState(() => error = 'Choose a file to upload');
    final url = link.text.trim();
    submit(widget.task,
        name: byLink ? (Uri.parse(url).host) : fileName!, url: byLink ? url : '', bytes: byLink ? null : fileBytes, notes: notes.text.trim());
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: key,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(widget.task.status == Status.revision ? 'Submit revision' : 'Upload work', style: inter(22, w: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(widget.task.title, style: inter(15, c: C.mist)),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('File'), icon: Icon(Icons.upload_file)),
                  ButtonSegment(value: true, label: Text('Cloud link'), icon: Icon(Icons.link)),
                ],
                selected: {byLink},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() {
                  byLink = s.first;
                  error = null;
                }),
              ),
              const SizedBox(height: 16),
              if (byLink)
                TextFormField(
                  controller: link,
                  keyboardType: TextInputType.url,
                  style: inter(16),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Paste the link to your file'
                      : validUrl(v!)
                          ? null
                          : 'Enter a full link starting with https://',
                  decoration: const InputDecoration(labelText: 'Cloud link *', hintText: 'https://drive.google.com/file/d/...'),
                )
              else
                OutlinedButton.icon(
                  onPressed: choose,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56), alignment: Alignment.centerLeft),
                  icon: Icon(fileName == null ? Icons.folder_open : Icons.check_circle_outline, color: fileName == null ? C.mist : C.peri),
                  label: Text(fileName == null ? 'Choose a file' : '$fileName${fileBytes == null ? '' : ' · ${mb(fileBytes!)}'}',
                      overflow: TextOverflow.ellipsis, style: inter(15, c: C.text)),
                ),
              if (!byLink)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('MP4, MOV, PNG, JPG, PDF, ZIP or PSD, up to 500 MB', style: inter(13, c: C.mist))),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: inter(14, c: C.rose))),
              const SizedBox(height: 12),
              TextFormField(
                controller: notes,
                minLines: 3,
                maxLines: 3,
                style: inter(16),
                decoration: const InputDecoration(labelText: 'Notes for the reviewer', hintText: 'e.g. 4K ProRes master, graded to the brief'),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: send, child: const Text('Submit for review')),
            ]),
          ),
        ),
      );
}
