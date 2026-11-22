import 'package:flutter/material.dart';
import '../../core/auth_repository.dart';
import 'team_lead_repository.dart';

class TeamLeadPeoplePage extends StatefulWidget {
  const TeamLeadPeoplePage({
    super.key,
    required this.repository,
    this.members = false,
  });
  final TeamLeadRepository repository;
  final bool members;
  @override
  State<TeamLeadPeoplePage> createState() => _PeopleState();
}

class _PeopleState extends State<TeamLeadPeoplePage> {
  late final _generation = widget.repository.session.beginReadGeneration;
  late Future<List<Map<String, dynamic>>> _rows = _load();
  bool _busy = false;
  String? _error;
  Future<List<Map<String, dynamic>>> _load() async {
    if (!widget.members) return widget.repository.leaves();
    await widget.repository.load();
    return widget.repository.members;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted && widget.repository.session.isCurrent(_generation)) {
        setState(() => _rows = _load());
      }
    } catch (error) {
      if (mounted && widget.repository.session.isCurrent(_generation)) {
        setState(
          () => _error = error is HttpError
              ? error.message
              : 'The change could not be confirmed.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> member) async {
    var capacity = '${member['daily_capacity'] ?? ''}';
    var skills = (member['skills'] as List? ?? []).join(', ');
    var accepting = member['is_accepting_work'] == true;
    var save = false;
    final form = GlobalKey<FormState>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${member['full_name'] ?? 'Pod member'}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextFormField(
                      initialValue: capacity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Daily capacity',
                      ),
                      onChanged: (value) => capacity = value,
                      validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
                          ? 'Enter a positive whole number.'
                          : null,
                    ),
                    TextFormField(
                      initialValue: skills,
                      decoration: const InputDecoration(
                        labelText: 'Skills',
                        helperText: 'Separate skills with commas',
                      ),
                      onChanged: (value) => skills = value,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Accepting new work'),
                      value: accepting,
                      onChanged: (value) => update(() => accepting = value),
                    ),
                    FilledButton(
                      onPressed: () {
                        if (form.currentState!.validate()) {
                          save = true;
                          Navigator.pop(sheet);
                        }
                      },
                      child: const Text('Save member settings'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted || !save) return;
    await _run(
      () => widget.repository.updateMember(
        member,
        capacity: int.parse(capacity),
        skills: skills
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
        accepting: accepting,
      ),
    );
  }

  Future<void> _decide(Map<String, dynamic> row, bool approve) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Approve leave?' : 'Reject leave?'),
        content: Text(
          '${row['user_name'] ?? row['employee_name'] ?? 'Pod member'}\n${row['start_date']} – ${row['end_date']}\n${row['reason'] ?? ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(() => widget.repository.decideLeave(row, approve: approve));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.repository.session,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(
          widget.members ? 'Pod member settings' : 'Team leave requests',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy
                ? null
                : () => setState(() {
                    _rows = _load();
                    _error = null;
                  }),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: !widget.repository.session.isCurrent(_generation)
            ? const Center(child: Text('This session has ended.'))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _rows,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(
                          snapshot.error is HttpError
                              ? (snapshot.error as HttpError).message
                              : 'Records could not be loaded. Refresh to retry.',
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.data!.isEmpty) {
                        return Text(
                          widget.members
                              ? 'No members in this pod.'
                              : 'No leave requests in this pod.',
                        );
                      }
                      return Column(
                        children: [
                          for (final row in snapshot.data!)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      '${row[widget.members ? 'full_name' : 'user_name'] ?? row['employee_name'] ?? 'Pod member'}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    if (widget.members) ...[
                                      Text(
                                        '${row['role'] ?? ''} · ${row['daily_capacity'] ?? 'Not set'} daily capacity',
                                      ),
                                      Text(
                                        (row['skills'] as List? ?? []).join(
                                          ', ',
                                        ),
                                      ),
                                      Text(
                                        row['is_accepting_work'] == true
                                            ? 'Accepting new work'
                                            : 'Not accepting new work',
                                      ),
                                      OutlinedButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _edit(row),
                                        child: const Text('Edit settings'),
                                      ),
                                    ] else ...[
                                      Text(
                                        '${row['start_date']} – ${row['end_date']}',
                                      ),
                                      Text('${row['reason'] ?? ''}'),
                                      Text('${row['status']}'),
                                      if (row['is_self'] == true)
                                        const Text(
                                          'Your request is reviewed by another approver.',
                                        ),
                                      if (row['is_self'] == false &&
                                          row['user_id'] !=
                                              widget
                                                  .repository
                                                  .session
                                                  .current
                                                  ?.user
                                                  .id &&
                                          row['status'] == 'pending')
                                        Wrap(
                                          spacing: 12,
                                          children: [
                                            if (row['can_approve'] == true)
                                              FilledButton(
                                                onPressed: _busy
                                                    ? null
                                                    : () => _decide(row, true),
                                                child: const Text('Approve'),
                                              ),
                                            if (row['can_reject'] == true)
                                              OutlinedButton(
                                                onPressed: _busy
                                                    ? null
                                                    : () => _decide(row, false),
                                                child: const Text('Reject'),
                                              ),
                                          ],
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
      ),
    ),
  );
}
