import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';
import '../workstation/workstation_data.dart';
import '../workstation/workstation_account_pages.dart';
import '../workstation/workstation_hub_pages.dart';
import '../workstation/workstation_meetings_page.dart';
import 'team_lead_repository.dart';
import 'team_lead_people_page.dart';
import 'team_lead_forms.dart';
import '../splash/splash_screen.dart';

class TeamLeadPage extends StatefulWidget {
  const TeamLeadPage({super.key, required this.session});
  final AuthSession session;
  @override
  State<TeamLeadPage> createState() => _TeamLeadPageState();
}

class _TeamLeadPageState extends State<TeamLeadPage> {
  late final _repo = TeamLeadRepository(widget.session);
  late final _sessionGeneration = widget.session.beginReadGeneration;
  WorkstationData? _data;
  String? _error;
  bool _loading = false, _writing = false;
  int _tab = 0, _epoch = 0;
  String _query = '';
  @override
  void initState() {
    super.initState();
    widget.session.addListener(_changed);
    _load();
  }

  void _changed() {
    if (widget.session.isCurrent(_sessionGeneration) &&
        widget.session.phase == SessionPhase.authenticated)
      return;
    _epoch++;
    if (mounted) {
      setState(() {
        _data = null;
        _error = null;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_changed);
    _epoch++;
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
      final value = await _repo.load();
      if (mounted && epoch == _epoch) setState(() => _data = value);
    } catch (error) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _data = null;
          _error = error is HttpError
              ? error.message
              : 'The pod could not be loaded. Please retry.';
        });
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }

  Future<void> _details(WorkstationTask task) async {
    var notes = '';
    String? action;
    Map<String, dynamic>? member;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('${task.client} · ${task.status.replaceAll('_', ' ')}'),
                  if (task.feedback?.isNotEmpty == true) Text(task.feedback!),
                  if (task.fileUrl?.isNotEmpty == true)
                    TextButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open submitted media'),
                      onPressed: () async {
                        final uri = widget.session.repository.resolveMediaUri(
                          task.fileUrl!,
                        );
                        if (uri != null) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                  if (_data?.inQa.contains(task) == true) ...[
                    TextField(
                      onChanged: (value) => notes = value,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Review notes',
                        helperText: 'Required when requesting changes',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        action = 'approve';
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('Approve for client review'),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        if (notes.trim().isEmpty) {
                          update(() {});
                          return;
                        }
                        action = 'reject';
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('Request changes'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Reassign within this pod',
                    ),
                    items: [
                      for (final row in _repo.members.where(
                        (row) =>
                            row['id'] is String &&
                            row['is_accepting_work'] != false &&
                            {
                              'editor',
                              'designer',
                              'team_lead',
                            }.contains(row['role']),
                      ))
                        DropdownMenuItem(
                          value: row,
                          child: Text(
                            '${row['full_name'] ?? row['email']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => update(() => member = value),
                  ),
                  OutlinedButton(
                    onPressed: member == null
                        ? null
                        : () {
                            action = 'assign';
                            Navigator.pop(sheetContext);
                          },
                    child: const Text('Confirm reassignment'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final comment = notes;
    if (!mounted || action == null || _writing) return;
    final generation = widget.session.beginReadGeneration;
    setState(() {
      _writing = true;
      _error = null;
    });
    try {
      if (action == 'assign') {
        await _repo.reassign(task, member!);
      } else {
        await _repo.review(
          task,
          approve: action == 'approve',
          comment: comment,
        );
      }
      if (mounted && widget.session.isCurrent(generation)) await _load();
    } catch (error) {
      if (mounted && widget.session.isCurrent(generation)) {
        setState(
          () => _error = error is HttpError
              ? error.message
              : 'The change could not be confirmed.',
        );
      }
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final tasks = data == null
        ? <WorkstationTask>[]
        : _tab == 1
        ? data.inQa
        : [
            ...data.backlog,
            ...data.inProduction,
            ...data.inQa,
            ...data.clientReview,
            ...data.readyToPublish,
            ...data.completed,
          ];
    final rows = tasks
        .where(
          (task) =>
              '${task.title} ${task.client} ${task.assigneeName} ${task.status}'
                  .toLowerCase()
                  .contains(_query.toLowerCase()),
        )
        .toList();
    // Android back on any tab but Home returns to Home instead of closing the app.
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _tab != 0) setState(() => _tab = 0);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              CreoWordmark(),
              SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Team lead',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh pod',
              onPressed: _loading || _writing ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Sign out',
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: SafeArea(
          child: _tab == 4
              ? ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _destination(
                      'Team leave requests',
                      Icons.fact_check_outlined,
                      TeamLeadPeoplePage(repository: _repo),
                    ),
                    _destination(
                      'Pod member settings',
                      Icons.group_outlined,
                      TeamLeadPeoplePage(repository: _repo, members: true),
                    ),
                    _destination(
                      'Pod support',
                      Icons.support_agent_outlined,
                      TeamLeadSupportPage(repository: _repo),
                    ),
                    _destination(
                      'My time off',
                      Icons.event_busy_outlined,
                      WorkstationSchedulePage(
                        session: widget.session,
                        freelancer: false,
                      ),
                    ),
                    _destination(
                      'Profile & settings',
                      Icons.person_outline,
                      WorkstationSettingsPage(
                        session: widget.session,
                        freelancer: false,
                      ),
                    ),
                    _destination(
                      'Team chat',
                      Icons.chat_bubble_outline,
                      WorkstationHubPage(session: widget.session),
                    ),
                    _destination(
                      'Publishing',
                      Icons.publish_outlined,
                      WorkstationPublishingPage(session: widget.session),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_loading || _writing) const LinearProgressIndicator(),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (data != null) ...[
                      Text(
                        data.podName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      if (_tab == 0) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              label: Text(
                                '${data.inQa.length} awaiting review',
                              ),
                            ),
                            Chip(
                              label: Text(
                                '${data.inProduction.length} in production',
                              ),
                            ),
                            Chip(label: Text('${data.clients.length} clients')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your pod',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        for (final member in data.members)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person_outline),
                            title: Text(member.name),
                            subtitle: Text(member.craft),
                          ),
                        for (final notice in data.notices)
                          Card(
                            child: ListTile(
                              title: Text(notice.title),
                              subtitle: Text(notice.message),
                            ),
                          ),
                      ] else if (_tab == 3) ...[
                        if (data.clients.isEmpty)
                          const Text('No clients are assigned to this pod.'),
                        for (final client in data.clients)
                          Card(
                            child: ExpansionTile(
                              title: Text('${client['name'] ?? 'Client'}'),
                              subtitle: Text(
                                '${client['brand_summary'] ?? client['email'] ?? ''}',
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: SelectableText(
                                    '${client['email'] ?? ''}\nInstagram: ${client['instagram'] ?? 'Not connected'}\nBrand DNA:\n${_brandDna(client['brand_dna'])}',
                                  ),
                                ),
                                for (final quota
                                    in (client['quota_usage'] as List? ??
                                        const []))
                                  ListTile(
                                    title: Text('${quota['kind']}'),
                                    subtitle: Text(
                                      '${quota['used']} used · ${quota['remaining']} remaining of ${quota['quota']}',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ] else ...[
                        TextField(
                          onChanged: (value) => setState(() => _query = value),
                          decoration: const InputDecoration(
                            labelText: 'Search tasks, clients or status',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('${rows.length} tasks'),
                        if (rows.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No matching work. Refresh or change your search.',
                            ),
                          ),
                        for (final task in rows)
                          Card(
                            child: ListTile(
                              title: Text(task.title),
                              subtitle: Text(
                                '${task.client}\n${task.status.replaceAll('_', ' ')} · ${task.assigneeName ?? 'Unassigned'}',
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _writing ? null : () => _details(task),
                            ),
                          ),
                      ],
                    ] else if (!_loading && _error == null)
                      const Text('No pod data is available.'),
                  ],
                ),
        ),
        floatingActionButton: _tab == 2 && data != null
            ? FloatingActionButton.extended(
                onPressed: _writing || _loading
                    ? null
                    : () async {
                        final created = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TeamLeadCreateTaskPage(
                              repository: _repo,
                              clients: data.clients,
                            ),
                          ),
                        );
                        if (created == true && mounted) await _load();
                      },
                icon: const Icon(Icons.add),
                label: const Text('New task'),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() {
            _tab = value;
            _query = '';
          }),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.fact_check_outlined),
              label: 'Review',
            ),
            NavigationDestination(
              icon: Icon(Icons.view_kanban_outlined),
              label: 'Tasks',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              label: 'Clients',
            ),
            NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final meetingStore = WorkstationMeetingScope.maybeOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out on this device?'),
        content: const Text(
          'Your saved session will be cleared on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await logoutWorkstationSession(widget.session, store: meetingStore);
    }
  }

  Widget _destination(String title, IconData icon, Widget page) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => page),
      ),
    ),
  );
}

// Brand DNA arrives as nested JSON; show one readable line per field.
String _brandDna(Object? value, [String indent = '']) {
  if (value == null || (value is Map && value.isEmpty))
    return '${indent}Not available';
  if (value is! Map) return '$indent$value';
  return [
    for (final e in value.entries)
      e.value is Map
          ? '$indent${e.key.toString().replaceAll('_', ' ')}:\n${_brandDna(e.value, '$indent  ')}'
          : '$indent${e.key.toString().replaceAll('_', ' ')}: ${e.value is List ? (e.value as List).join(', ') : e.value}',
  ].join('\n');
}
