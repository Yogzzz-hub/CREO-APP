import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';
import '../../core/headings.dart';
import 'workstation_data.dart';
import 'workstation_files.dart';
import 'workstation_task_repository.dart';
import 'workstation_motion.dart';

class WorkstationTaskPage extends StatefulWidget {
  const WorkstationTaskPage({super.key, required this.session, this.taskId});
  final AuthSession session;
  final String? taskId;
  @override
  State<WorkstationTaskPage> createState() => _WorkstationTaskPageState();
}

class _WorkstationTaskPageState extends State<WorkstationTaskPage> {
  late final StaffTaskRepository _repo = StaffTaskRepository(widget.session);
  final _search = TextEditingController();
  WorkstationData? _data;
  String _column = 'Assigned', _client = 'All clients', _urgency = 'All';
  String? _error;
  bool _loading = false;
  String? _busyTask;
  int _epoch = 0;
  bool _targetOpened = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _epoch++;
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    final epoch = ++_epoch;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final next = await _repo.load();
      if (!mounted || epoch != _epoch) return;
      setState(() => _data = next);
      if (!_targetOpened && widget.taskId != null) {
        _targetOpened = true;
        final matches = staffBoardEntries(
          next,
          _repo.user,
        ).where((row) => row.task.id == widget.taskId);
        if (matches.isNotEmpty) {
          _column = matches.first.column;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _detail(matches.first);
          });
        }
      }
    } catch (error) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _error = _message(error);
          if (error is HttpError && [401, 403].contains(error.status)) {
            _data = null;
          }
        });
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }

  String _message(Object error) => error is HttpError
      ? error.message
      : 'Unable to complete the request. Please try again.';
  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _start(StaffTaskEntry row) async {
    if (_busyTask != null) return;
    setState(() => _busyTask = row.task.id);
    try {
      await _repo.start(row.task);
      if (!mounted) return;
      _notice('Task moved to In Production.');
      setState(() => _column = 'Production');
      await _load();
    } catch (error) {
      if (mounted) {
        _notice('${_message(error)} Refresh the board before retrying.');
      }
    } finally {
      if (mounted) setState(() => _busyTask = null);
    }
  }

  Future<void> _link(String value) async {
    final uri = widget.session.repository.resolveMediaUri(value);
    if (uri == null) {
      _notice('This file link cannot be opened safely.');
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _notice('No application could open this link.');
      }
    } catch (_) {
      _notice('The link could not be opened.');
    }
  }

  Future<void> _detail(StaffTaskEntry row) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final task = row.task, raw = row.task.source;
    final blueprint = raw['blueprint'] is Map
        ? raw['blueprint'] as Map
        : const {};
    final media = raw['deliverable'] is Map
        ? raw['deliverable'] as Map
        : const {};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(duration: Duration(milliseconds: 250)),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        minChildSize: .4,
        maxChildSize: .95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Close task details',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text('${task.client} · ${task.format.replaceAll('_', ' ')}'),
            const SizedBox(height: 16),
            Text('${row.column} · ${task.status.replaceAll('_', ' ')}'),
            if (task.due != null)
              Text('Due ${task.due!.toLocal().toString().split('.').first}'),
            for (final key in [
              'instructions',
              'title',
              'hook',
              'target_duration',
              'audio_notes',
            ])
              if ((blueprint[key] ?? raw[key] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SelectableText(
                    '${key.replaceAll('_', ' ')}\n${blueprint[key] ?? raw[key]}',
                  ),
                ),
            if (task.feedback?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text('Changes requested\n${task.feedback}'),
                ),
              ),
            for (final entry in {
              'Raw footage':
                  raw['raw_footage_url'] ??
                  blueprint['raw_footage_url'] ??
                  blueprint['drive_url'],
              'Brief': raw['brief_url'] ?? blueprint['brief_url'],
              'Reference': raw['reference_url'] ?? blueprint['reference_url'],
              'Latest delivery': task.fileUrl,
              'Voice feedback': media['voice_note_url'],
            }.entries)
              if (entry.value is String && (entry.value as String).isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.key),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _link(entry.value as String),
                ),
            if (task.version != null) Text('Delivery version ${task.version}'),
            if (row.column == 'Assigned')
              FilledButton(
                onPressed: _busyTask != null
                    ? null
                    : () {
                        Navigator.pop(context);
                        _start(row);
                      },
                child: const Text('Start work'),
              ),
            if (row.column == 'Production')
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _upload(row);
                },
                child: const Text('Upload & send to QA'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _upload(StaffTaskEntry row) async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _StaffUploadPage(repo: _repo, task: row.task),
      ),
    );
    if (sent == true && mounted) {
      setState(() => _column = 'QA');
      await _load();
    }
  }

  Future<void> _create() async {
    if (_data == null) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _StaffCreatePage(repo: _repo, clients: _data!.clients),
      ),
    );
    if (created == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.current?.user;
    final entries = _data == null || user == null
        ? <StaffTaskEntry>[]
        : staffBoardEntries(_data!, user);
    final query = _search.text.toLowerCase();
    final rows = entries
        .where(
          (row) =>
              row.column == _column &&
              (_client == 'All clients' || row.task.client == _client) &&
              (_urgency == 'All' ||
                  (_urgency == 'High'
                      ? row.highPriority
                      : !row.highPriority)) &&
              '${row.task.title} ${row.task.client} ${row.task.format.replaceAll('_', ' ')}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    final clients = {'All clients', ...entries.map((row) => row.task.client)};
    return Scaffold(
      appBar: AppBar(
        title: const Heading('My tasks'),
        actions: [
          IconButton(
            tooltip: 'Refresh task board',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: WorkstationPressFeedback(
        enabled: !_loading && _data != null,
        child: FloatingActionButton.extended(
          onPressed: _loading || _data == null ? null : _create,
          icon: const Icon(Icons.add),
          label: const Text('New task'),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: FillScroll(
            keyboardDismiss: true,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              Heading(
                'Make your next delivery count.',
                icon: Icons.checklist_outlined,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _data?.podName ?? 'Your assigned work',
                style: TextStyle(color: context.creo.appMist),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Search tasks, clients or formats',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Clear task search',
                    onPressed: () {
                      _search.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  DropdownButton<String>(
                    value: clients.contains(_client) ? _client : 'All clients',
                    items: clients
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(c, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _client = value!),
                  ),
                  DropdownButton<String>(
                    value: _urgency,
                    items: ['All', 'High', 'Normal']
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text('Priority: $c'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _urgency = value!),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final column in [
                    'Assigned',
                    'Production',
                    'QA',
                    'Review',
                  ])
                    ChoiceChip(
                      label: Text(
                        '$column (${entries.where((r) => r.column == column).length})',
                      ),
                      selected: _column == column,
                      onSelected: (_) => setState(() => _column = column),
                    ),
                ],
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(
                    semanticsLabel: 'Loading task board',
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(color: context.creo.error),
                        ),
                      ),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                ),
              // One list container that reaches the bottom edge.
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: context.creo.appLine),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_data != null && rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 32,
                          horizontal: 8,
                        ),
                        child: Text(
                          'No tasks match this view. Try another stage or clear your filters.',
                        ),
                      ),
                    for (final row in rows)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                row.task.client,
                                style: TextStyle(color: context.creo.accent),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                row.task.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                '${row.task.format.replaceAll('_', ' ')} · ${row.task.status.replaceAll('_', ' ')}',
                              ),
                              if (row.task.due != null)
                                Text(
                                  'Due ${row.task.due!.toLocal().toString().split(' ').first}',
                                ),
                              if (row.highPriority) const Text('High priority'),
                              if (row.task.feedback?.isNotEmpty ?? false)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    'Changes requested: ${row.task.feedback}',
                                  ),
                                ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: () => _detail(row),
                                    child: const Text('View details'),
                                  ),
                                  if (row.column == 'Assigned')
                                    FilledButton(
                                      onPressed: _busyTask == null
                                          ? () => _start(row)
                                          : null,
                                      child: Text(
                                        _busyTask == row.task.id
                                            ? 'Starting…'
                                            : 'Start work',
                                      ),
                                    ),
                                  if (row.column == 'Production')
                                    FilledButton(
                                      onPressed: () => _upload(row),
                                      child: const Text('Upload & send to QA'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffUploadPage extends StatefulWidget {
  const _StaffUploadPage({required this.repo, required this.task});
  final StaffTaskRepository repo;
  final WorkstationTask task;
  @override
  State<_StaffUploadPage> createState() => _StaffUploadPageState();
}

class _StaffUploadPageState extends State<_StaffUploadPage> {
  final _notes = TextEditingController();
  final _checks = <String>{};
  WorkstationFile? _file;
  bool _busy = false, _picking = false, _uncertain = false;
  double? _progress;
  String? _error;
  @override
  void dispose() {
    _notes.dispose();
    final file = _file;
    if (file != null) unawaited(WorkstationFileTransfer.release(file));
    super.dispose();
  }

  Future<void> _pick() async {
    if (_picking || _busy) return;
    setState(() => _picking = true);
    try {
      final file = await WorkstationFileTransfer.pick();
      if (!mounted) {
        if (file != null) await WorkstationFileTransfer.release(file);
        return;
      }
      if (file == null) return;
      final error = WorkstationFileTransfer.validate(file);
      if (error != null) {
        await WorkstationFileTransfer.release(file);
        if (mounted) setState(() => _error = error);
        return;
      }
      final old = _file;
      setState(() {
        _file = file;
        _error = null;
      });
      if (old != null) await WorkstationFileTransfer.release(old);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is HttpError
              ? error.message
              : 'Unable to select this file.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _send() async {
    if (_busy || _file == null || _uncertain) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await widget.repo.upload(
        widget.task,
        _file!,
        _notes.text,
        _checks,
        (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uploaded v${response['version'] ?? ''} and sent for QA.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _uncertain =
              error is HttpError &&
              ['TIMEOUT', 'NETWORK_ERROR'].contains(error.code);
          _error =
              '${error is HttpError ? error.message : 'Upload failed.'}${_uncertain ? ' Return to the board and refresh before submitting again; the server may have received the upload.' : ''}';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Heading('Upload & send to QA')),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            Text(
              widget.task.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              '${widget.task.client} · ${widget.task.format.replaceAll('_', ' ')}',
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _busy || _picking ? null : _pick,
              icon: const Icon(Icons.attach_file),
              label: Text(
                _picking
                    ? 'Opening files…'
                    : _file?.name ?? 'Choose delivery file',
              ),
            ),
            const Text('MP4/MOV up to 500 MB · PNG/JPG/WEBP/GIF up to 10 MB'),
            const SizedBox(height: 8),
            Text(switch (widget.task.format) {
              'reel' => '9:16 vertical video · 1080×1920 · MP4/MOV',
              'story' => '9:16 vertical · 1080×1920 · video or image',
              'static_post' => '4:5 portrait or 1:1 · 1080×1350 · PNG/JPG',
              'carousel' => '4:5 portrait · 1080×1350 · cover slide PNG/JPG',
              _ => 'Check the assigned brief for delivery specifications.',
            }),
            if (_file != null)
              TextButton.icon(
                icon: const Icon(Icons.preview_outlined),
                label: const Text('Preview selected file'),
                onPressed: _busy
                    ? null
                    : () async {
                        try {
                          await WorkstationFileTransfer.preview(_file!);
                        } catch (error) {
                          if (mounted) {
                            setState(
                              () => _error = error is HttpError
                                  ? error.message
                                  : 'Preview is unavailable.',
                            );
                          }
                        }
                      },
              ),
            const SizedBox(height: 20),
            TextField(
              controller: _notes,
              maxLines: 4,
              maxLength: 1700,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Delivery notes'),
            ),
            const SizedBox(height: 16),
            Text(
              'Self-check · ${_checks.length}/${staffSelfChecks.length}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Checks are included in your notes; unfinished checks do not prevent submission.',
            ),
            for (final check in staffSelfChecks.entries)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(check.value),
                value: _checks.contains(check.key),
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        if (value!) {
                          _checks.add(check.key);
                        } else {
                          _checks.remove(check.key);
                        }
                      }),
              ),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: context.creo.error),
                ),
              ),
            if (_busy) ...[
              LinearProgressIndicator(
                value: _progress,
                semanticsLabel: 'Sending delivery bytes',
              ),
              Text(
                _progress == 1
                    ? 'Transfer sent. Waiting for server confirmation…'
                    : 'Uploading ${((_progress ?? 0) * 100).round()}%',
              ),
            ],
            const SizedBox(height: 20),
            WorkstationPressFeedback(
              enabled: !_busy && _file != null && !_uncertain,
              scale: .95,
              child: FilledButton(
                onPressed: _busy || _file == null || _uncertain ? null : _send,
                child: Text(_busy ? 'Sending…' : 'Submit version for QA'),
              ),
            ),
            if (_uncertain)
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Return and refresh board'),
              ),
          ],
        ),
      ),
    ),
  );
}

class _StaffCreatePage extends StatefulWidget {
  const _StaffCreatePage({required this.repo, required this.clients});
  final StaffTaskRepository repo;
  final List<Map<String, dynamic>> clients;
  @override
  State<_StaffCreatePage> createState() => _StaffCreatePageState();
}

class _StaffCreatePageState extends State<_StaffCreatePage> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final key in [
      'title',
      'brief',
      'raw_footage_url',
      'target_duration',
      'audio_notes',
      'hook',
      'reference_url',
    ])
      key: TextEditingController(),
  };
  String? _client, _format, _due, _createdId, _error;
  bool _start = false, _busy = false, _uncertain = false;
  @override
  void initState() {
    super.initState();
    _client = widget.clients.firstOrNull?['id'] as String?;
    _format = staffTaskFormats[widget.repo.user.role]!.first;
    _fields['target_duration']!.text = '30-60s';
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy ||
        _uncertain ||
        !_form.currentState!.validate() ||
        _client == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await widget.repo.create({
        'client_id': _client,
        'deliverable_type': _format,
        'due_date': _due,
        for (final field in _fields.entries)
          if (field.value.text.trim().isNotEmpty || field.key == 'title')
            field.key: field.value.text.trim(),
      });
      if (created['id'] is! String || (created['id'] as String).isEmpty) {
        _uncertain = true;
        throw const HttpError(
          status: 0,
          code: 'INVALID_WRITE_RESPONSE',
          message:
              'The server accepted the request but did not return a task identifier. Refresh the board before creating another task.',
        );
      }
      _createdId = created['id'] as String;
      if (_start) {
        await widget.repo.session.request(
          'POST',
          '/api/v1/deliverables/tasks/${Uri.encodeComponent(_createdId!)}/start',
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _uncertain =
              _uncertain ||
              _createdId != null ||
              error is HttpError &&
                  ['TIMEOUT', 'NETWORK_ERROR'].contains(error.code);
          _error = _createdId != null
              ? 'Task was created, but starting it failed. Return to the board and start the existing task. Do not create it again.'
              : '${error is HttpError ? error.message : 'Task could not be created.'}${_uncertain ? ' Refresh the board before creating another task; completion is uncertain.' : ''}';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Heading('New task')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Create work for a client assigned to your pod.'),
              const SizedBox(height: 16),
              if (widget.clients.isEmpty)
                const Text('No client is assigned to your pod yet.'),
              DropdownButtonFormField<String>(
                initialValue: _client,
                itemHeight: null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Client'),
                items: widget.clients
                    .map(
                      (client) => DropdownMenuItem(
                        value: client['id'] as String,
                        child: Text(client['name'] as String? ?? 'Client'),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _client = value),
              ),
              DropdownButtonFormField<String>(
                initialValue: _format,
                itemHeight: null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Format'),
                items: staffTaskFormats[widget.repo.user.role]!
                    .map(
                      (format) => DropdownMenuItem(
                        value: format,
                        child: Text(format.replaceAll('_', ' ')),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _format = value),
              ),
              for (final field in _fields.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextFormField(
                    controller: field.value,
                    enabled: !_busy && !_uncertain,
                    maxLength: field.key == 'title'
                        ? 200
                        : field.key == 'brief'
                        ? 2000
                        : null,
                    maxLines: ['brief', 'audio_notes'].contains(field.key)
                        ? 3
                        : 1,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: field.key.replaceAll('_', ' '),
                    ),
                    validator: field.key == 'title'
                        ? (value) => value?.trim().isNotEmpty == true
                              ? null
                              : 'Enter a task title.'
                        : null,
                  ),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(_due ?? 'Due date (optional)'),
                onPressed: _busy
                    ? null
                    : () async {
                        final now = DateTime.now();
                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(now.year + 10),
                          initialDate: now,
                        );
                        if (date != null && mounted) {
                          setState(
                            () =>
                                _due = date.toIso8601String().substring(0, 10),
                          );
                        }
                      },
              ),
              if (_due != null)
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _due = null),
                  child: const Text('Clear due date'),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start immediately after creating'),
                value: _start,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _start = value),
              ),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(color: context.creo.error),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy || _client == null || _uncertain
                    ? null
                    : _save,
                child: Text(_busy ? 'Creating…' : 'Create task'),
              ),
              if (_uncertain)
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Return and refresh board'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
