import 'package:flutter/material.dart';
import '../../core/auth_repository.dart';
import 'team_lead_repository.dart';

class TeamLeadCreateTaskPage extends StatefulWidget {
  const TeamLeadCreateTaskPage({
    super.key,
    required this.repository,
    required this.clients,
  });
  final TeamLeadRepository repository;
  final List<Map<String, dynamic>> clients;
  @override
  State<TeamLeadCreateTaskPage> createState() => _CreateState();
}

class _CreateState extends State<TeamLeadCreateTaskPage> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, String>{};
  String? _client, _due;
  String _format = 'reel';
  String? _error;
  bool _busy = false;
  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.createTask({
        ..._fields,
        'client_id': _client,
        'deliverable_type': _format,
        if (_due != null) 'due_date': _due,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is HttpError
              ? error.message
              : 'Task could not be confirmed.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('New pod task')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Create real work for a client assigned to your pod. The server checks plan limits and computes the SLA.',
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Client'),
                items: [
                  for (final row in widget.clients)
                    DropdownMenuItem(
                      value: row['id'] as String,
                      child: Text('${row['name'] ?? 'Client'}'),
                    ),
                ],
                onChanged: _busy ? null : (value) => _client = value,
                validator: (value) => value == null ? 'Choose a client.' : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _format,
                decoration: const InputDecoration(labelText: 'Format'),
                items: [
                  for (final value in [
                    'reel',
                    'story',
                    'shoot_day',
                    'static_post',
                    'carousel',
                  ])
                    DropdownMenuItem(
                      value: value,
                      child: Text(value.replaceAll('_', ' ')),
                    ),
                ],
                onChanged: _busy ? null : (value) => _format = value!,
              ),
              for (final name in [
                'title',
                'brief',
                'raw_footage_url',
                'format',
                'target_duration',
                'audio_notes',
                'reference_url',
                'hook',
              ])
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextFormField(
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: name.replaceAll('_', ' '),
                    ),
                    maxLength: name == 'title'
                        ? 200
                        : name == 'brief'
                        ? 2000
                        : null,
                    maxLines: ['brief', 'audio_notes'].contains(name) ? 3 : 1,
                    onChanged: (value) => _fields[name] = value.trim(),
                    validator: name == 'title'
                        ? (value) => value?.trim().isNotEmpty == true
                              ? null
                              : 'Enter a title.'
                        : null,
                  ),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(_due ?? 'Due date (optional)'),
                onPressed: _busy
                    ? null
                    : () async {
                        final now = DateTime.now();
                        final day = await showDatePicker(
                          context: context,
                          firstDate: DateTime(now.year, now.month, now.day),
                          lastDate: DateTime(now.year + 5),
                        );
                        if (day != null && mounted) {
                          setState(
                            () => _due = day.toIso8601String().substring(0, 10),
                          );
                        }
                      },
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              FilledButton(
                onPressed: _busy || widget.clients.isEmpty ? null : _save,
                child: Text(_busy ? 'Creating…' : 'Create task'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class TeamLeadSupportPage extends StatefulWidget {
  const TeamLeadSupportPage({super.key, required this.repository});
  final TeamLeadRepository repository;
  @override
  State<TeamLeadSupportPage> createState() => _SupportState();
}

class _SupportState extends State<TeamLeadSupportPage> {
  late Future<List<Map<String, dynamic>>> _load = widget.repository.tickets();
  String? _error;
  bool _busy = false;
  Future<void> _open(Map<String, dynamic> ticket) async {
    try {
      final messages = await widget.repository.messages(ticket);
      if (!mounted) return;
      var draft = '';
      var status = 'open';
      var send = false;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${ticket['subject'] ?? ticket['title']}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('${ticket['description'] ?? ''}'),
                  for (final row in messages)
                    ListTile(
                      title: Text('${row['sender_name'] ?? 'Team'}'),
                      subtitle: Text('${row['message'] ?? ''}'),
                    ),
                  TextField(
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Reply'),
                    onChanged: (value) => draft = value,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Status after reply',
                    ),
                    items: [
                      for (final value in [
                        'open',
                        'in_progress',
                        'resolved',
                        'closed',
                      ])
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.replaceAll('_', ' ')),
                        ),
                    ],
                    onChanged: (value) => status = value!,
                  ),
                  FilledButton(
                    onPressed: () {
                      if (draft.trim().isNotEmpty) {
                        send = true;
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Send reply'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (!mounted || !send) return;
      setState(() => _busy = true);
      await widget.repository.reply(ticket, draft, status);
      if (mounted) setState(() => _load = widget.repository.tickets());
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is HttpError
              ? error.message
              : 'Support could not be loaded.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pod support'),
      actions: [
        IconButton(
          tooltip: 'Refresh support',
          onPressed: _busy
              ? null
              : () => setState(() => _load = widget.repository.tickets()),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) Text(_error!),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _load,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  snapshot.error is HttpError
                      ? (snapshot.error as HttpError).message
                      : 'Support unavailable. Refresh to retry.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.isEmpty) {
                return const Text('No support tickets for this pod.');
              }
              return Column(
                children: [
                  for (final row in snapshot.data!)
                    Card(
                      child: ListTile(
                        title: Text('${row['subject'] ?? row['title']}'),
                        subtitle: Text('${row['client']} · ${row['status']}'),
                        onTap: _busy ? null : () => _open(row),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
