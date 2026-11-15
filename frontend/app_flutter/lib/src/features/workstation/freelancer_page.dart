import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_appearance.dart';
import '../../core/app_theme.dart';
import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';
import 'freelancer_repository.dart';
import 'workstation_account_pages.dart';
import 'workstation_files.dart';
import 'workstation_notifications_page.dart';
import 'workstation_hub_pages.dart';
import 'workstation_meetings_page.dart';

class FreelancerPage extends StatefulWidget {
  const FreelancerPage({super.key, required this.session});
  final AuthSession session;
  @override
  State<FreelancerPage> createState() => _FreelancerPageState();
}

class _FreelancerPageState extends State<FreelancerPage> {
  int _unreadNotifications = 0;
  Future<void> _notifications() async {
    final generation = widget.session.beginReadGeneration;
    String? selected;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => WorkstationNotificationsPage(
          session: widget.session,
          onUnreadChanged: (count) {
            if (mounted && widget.session.isCurrent(generation)) {
              setState(() => _unreadNotifications = count);
            }
          },
          onNavigate: (path) {
            selected = path;
            Navigator.of(routeContext).pop();
          },
        ),
      ),
    );
    if (!mounted || !widget.session.isCurrent(generation) || selected == null) {
      return;
    }
    final uri = Uri.parse(selected!);
    final Widget? page = switch (uri.path) {
      '/freelancer/leave' => WorkstationSchedulePage(
        session: widget.session,
        freelancer: true,
      ),
      '/freelancer/settings' => WorkstationSettingsPage(
        session: widget.session,
        freelancer: true,
      ),
      '/slack' => WorkstationHubPage(
        session: widget.session,
        initialDm: uri.queryParameters['dm'],
      ),
      _ => null,
    };
    if (page == null) {
      await _load();
      return;
    }
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => page));
  }

  late FreelancerRepository _repository;
  List<FreelancerTask> _tasks = [];
  FreelancerTaskGroup _group = FreelancerTaskGroup.pending;
  String? _account;
  HttpError? _error;
  String? _notice;
  bool _loading = false;
  final Set<String> _busy = {};
  int _epoch = 0;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repository = FreelancerRepository(widget.session);
    _account = widget.session.current?.user.id;
    widget.session.addListener(_sessionChanged);
    _load();
  }

  void _sessionChanged() {
    if (widget.session.phase != SessionPhase.authenticated ||
        widget.session.current?.user.id != _account) {
      _epoch++;
      if (mounted) {
        setState(() {
          _tasks = [];
          _notice = null;
        });
      }
    }
  }

  bool get _current =>
      mounted &&
      widget.session.phase == SessionPhase.authenticated &&
      widget.session.current?.user.id == _account;

  Future<void> _load() async {
    if (_loading) return;
    final epoch = ++_epoch;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final next = await _repository.load();
      if (!_current || epoch != _epoch) return;
      setState(() => _tasks = next);
    } catch (error) {
      if (!_current || epoch != _epoch) return;
      setState(() {
        _error = _asError(error);
        if (_error!.status == 401 || _error!.status == 403) _tasks = [];
      });
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }

  HttpError _asError(Object error) => error is HttpError
      ? error
      : const HttpError(
          status: 0,
          code: 'WORKSPACE_UNAVAILABLE',
          message: 'Your work could not be loaded. Please retry.',
        );

  Future<void> _start(FreelancerTask task) async {
    if (!_busy.add(task.id)) return;
    setState(() {
      _notice = null;
      _error = null;
    });
    try {
      await _repository.start(task);
      if (!_current) return;
      setState(() => _notice = 'Work started. Updating your assignments…');
      await _load();
    } catch (error) {
      if (_current) setState(() => _error = _asError(error));
    } finally {
      _busy.remove(task.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _open(String value) async {
    final uri = widget.session.repository.resolveMediaUri(value);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This asset does not have a supported secure link.'),
          ),
        );
      }
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Unavailable');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open this asset. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _sheet(String title, Widget child) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 200),
            reverseDuration: Duration(milliseconds: 200),
          ),
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _history(FreelancerTask task) async {
    var future = _repository.history(task);
    await _sheet(
      'Delivery history',
      StatefulBuilder(
        builder: (context, updateHistory) => FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Loading delivery history',
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(_asError(snapshot.error!).message),
                  ),
                  TextButton(
                    onPressed: () =>
                        updateHistory(() => future = _repository.history(task)),
                    child: const Text('Retry history'),
                  ),
                ],
              );
            }
            final rows = snapshot.data ?? [];
            if (rows.isEmpty) {
              return const Text(
                'No history has been recorded for this assignment yet.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row['action_label'] ?? row['action'] ?? 'Update'} · v${row['version'] ?? '—'}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${row['actor_name'] ?? 'Team'} · ${_date(DateTime.tryParse('${row['created_at'] ?? ''}'))}',
                          ),
                          if (row['reason'] is String &&
                              (row['reason'] as String).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(row['reason'] as String),
                            ),
                          if (row['file_url'] is String)
                            TextButton.icon(
                              onPressed: () => _open(row['file_url'] as String),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('View version'),
                            ),
                          if (row['voice_note_url'] is String)
                            TextButton.icon(
                              onPressed: () =>
                                  _open(row['voice_note_url'] as String),
                              icon: const Icon(Icons.volume_up_outlined),
                              label: const Text('Listen to feedback'),
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }

  Future<void> _submit(FreelancerTask task) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      showDragHandle: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 200),
              reverseDuration: Duration(milliseconds: 200),
            ),
      builder: (_) => _FreelancerSubmission(
        task: task,
        repository: _repository,
        session: widget.session,
      ),
    );
    if (sent == true && _current) {
      setState(
        () => _notice =
            'Content submitted for review. Updating your assignments…',
      );
      await _load();
    }
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

  String _date(DateTime? date) => date == null
      ? 'Not provided'
      : '${date.toLocal().day.toString().padLeft(2, '0')}/${date.toLocal().month.toString().padLeft(2, '0')}/${date.toLocal().year}';
  String _groupLabel(FreelancerTaskGroup group) => switch (group) {
    FreelancerTaskGroup.pending => 'In progress',
    FreelancerTaskGroup.review => 'QA review',
    FreelancerTaskGroup.revision => 'Revisions',
    FreelancerTaskGroup.completed => 'Approved',
  };

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(18),
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: context.creo.appSurface,
      border: Border.all(color: context.creo.appLine),
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );

  Widget _task(FreelancerTask task) {
    final busy = _busy.contains(task.id);
    final latest = task.deliverables.isEmpty ? null : task.deliverables.last;
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            task.client,
            style: TextStyle(
              color: context.creo.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(task.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(_groupLabel(task.group))),
              if (task.format.isNotEmpty) Chip(label: Text(task.format)),
              if (task.duration != null) Chip(label: Text(task.duration!)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Due: ${_date(task.due)}'),
          if (task.assignedAt != null)
            Text('Assigned: ${_date(task.assignedAt)}'),
          const SizedBox(height: 8),
          Text(
            task.fee == null
                ? 'Milestone fee not provided'
                : 'Milestone fee: ₹${task.fee}',
          ),
          if (task.footage != null)
            TextButton.icon(
              onPressed: () => _open(task.footage!),
              icon: const Icon(Icons.folder_open),
              label: const Text('Open raw footage / source assets'),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Raw footage link pending from Admin / Team Lead.',
                style: TextStyle(color: context.creo.appMist),
              ),
            ),
          if (task.hook != null) _directive('Hook / concept', task.hook!),
          if (task.audio != null) _directive('Audio directions', task.audio!),
          if (task.description.isNotEmpty)
            _directive('Creative brief & scope', task.description),
          if (task.reference != null)
            TextButton.icon(
              onPressed: () => _open(task.reference!),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open creative reference'),
            ),
          if (latest != null) ...[
            const Divider(),
            Text(
              'Latest delivery · v${latest['version'] ?? '—'} · ${latest['status'] ?? 'Submitted'}',
            ),
            if (latest['file_url'] is String)
              TextButton.icon(
                onPressed: () => _open(latest['file_url'] as String),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('View submitted file'),
              ),
          ],
          const Divider(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _history(task),
                icon: const Icon(Icons.history),
                label: const Text('History'),
              ),
              if (task.canStart)
                FilledButton.icon(
                  onPressed: busy ? null : () => _start(task),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(busy ? 'Starting…' : 'Start working'),
                ),
              if (task.group != FreelancerTaskGroup.completed)
                FilledButton.icon(
                  onPressed: busy ? null : () => _submit(task),
                  icon: const Icon(Icons.upload_outlined),
                  label: Text(
                    task.group == FreelancerTaskGroup.revision
                        ? 'Submit revision'
                        : task.group == FreelancerTaskGroup.review
                        ? 'Re-upload'
                        : 'Submit content',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _directive(String label, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.creo.appMist,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(text),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final rows = _tasks
        .where(
          (task) =>
              task.group == _group &&
              (query.isEmpty ||
                  '${task.title} ${task.client} ${task.format}'
                      .toLowerCase()
                      .contains(query)),
        )
        .toList();
    final completed = _tasks.where(
      (task) => task.group == FreelancerTaskGroup.completed,
    );
    final knownFees = completed
        .where((task) => task.fee != null)
        .fold<num>(0, (sum, task) => sum + task.fee!);
    num feesFor(bool Function(FreelancerTask) include) => _tasks
        .where(include)
        .where((task) => task.fee != null)
        .fold<num>(0, (sum, task) => sum + task.fee!);
    final inReviewFees = feesFor(
      (task) => task.group == FreelancerTaskGroup.review,
    );
    final activeFees = feesFor(
      (task) =>
          task.group == FreelancerTaskGroup.pending ||
          task.group == FreelancerTaskGroup.revision,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Freelancer workspace'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: _notifications,
            icon: Badge(
              isLabelVisible: _unreadNotifications > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          if (CreoAppearanceScope.maybeOf(context) != null)
            const CreoThemeToggle(showTooltip: false),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  widget.session.current?.user.fullName ?? 'Freelancer',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.work_outline),
                title: const Text('Assigned work'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Leave requests'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => WorkstationSchedulePage(
                        session: widget.session,
                        freelancer: true,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Profile & settings'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => WorkstationSettingsPage(
                        session: widget.session,
                        freelancer: true,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: const Text('Workspace hub'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          WorkstationHubPage(session: widget.session),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: _signOut,
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Assigned workload',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your briefs, deliveries and review history in one place.',
                      ),
                      const SizedBox(height: 20),
                      _card(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_tasks.length} assignments',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text('Approved milestone total: ₹$knownFees'),
                            const SizedBox(height: 8),
                            Text('Awaiting QA review: ₹$inReviewFees'),
                            Text('Active work: ₹$activeFees'),
                            Text(
                              'Total milestone pipeline: ₹${knownFees + inReviewFees + activeFees}',
                            ),
                            const Text(
                              'Approval is not proof of payment. Missing milestone amounts are excluded.',
                            ),
                          ],
                        ),
                      ),
                      if (_notice != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(_notice!),
                          ),
                        ),
                      if (_error != null)
                        _card(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                liveRegion: true,
                                child: Text(_error!.message),
                              ),
                              if (_tasks.isNotEmpty)
                                const Text(
                                  'Previously loaded assignments are shown. Updates may be unavailable.',
                                ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: _loading ? null : _load,
                                  child: const Text('Retry'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Search assigned work',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _search.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: FreelancerTaskGroup.values
                            .map(
                              (group) => ChoiceChip(
                                label: Text(
                                  '${_groupLabel(group)} (${_tasks.where((task) => task.group == group).length})',
                                ),
                                selected: _group == group,
                                onSelected: (_) =>
                                    setState(() => _group = group),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text('${rows.length} matching assignments'),
                          ),
                          IconButton(
                            tooltip: 'Refresh assignments',
                            onPressed: _loading ? null : _load,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      if (_loading)
                        const LinearProgressIndicator(
                          semanticsLabel: 'Refreshing assigned work',
                        ),
                      const SizedBox(height: 12),
                      if (!_loading && rows.isEmpty)
                        _card(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                query.isEmpty
                                    ? 'No assignments in this stage'
                                    : 'No matching assignments',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Choose another stage, clear your search, or refresh your assigned work.',
                              ),
                            ],
                          ),
                        ),
                      ...rows.map(_task),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _epoch++;
    widget.session.removeListener(_sessionChanged);
    _search.dispose();
    super.dispose();
  }
}

class _FreelancerSubmission extends StatefulWidget {
  const _FreelancerSubmission({
    required this.task,
    required this.repository,
    required this.session,
  });
  final FreelancerTask task;
  final FreelancerRepository repository;
  final AuthSession session;
  @override
  State<_FreelancerSubmission> createState() => _FreelancerSubmissionState();
}

class _FreelancerSubmissionState extends State<_FreelancerSubmission> {
  final _link = TextEditingController(), _notes = TextEditingController();
  WorkstationFile? _file;
  bool _fileMode = true, _busy = false, _picking = false;
  String? _error;
  double? _progress;
  late final _account = widget.session.current?.user.id;
  bool get _current =>
      mounted &&
      widget.session.phase == SessionPhase.authenticated &&
      widget.session.current?.user.id == _account;

  Future<void> _pick() async {
    if (_picking || _busy) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final chosen = await WorkstationFileTransfer.pick();
      if (!_current) {
        if (chosen != null) await WorkstationFileTransfer.release(chosen);
        return;
      }
      if (chosen != null) {
        final old = _file;
        setState(() => _file = chosen);
        if (old != null) await WorkstationFileTransfer.release(old);
      }
    } catch (error) {
      if (_current) {
        setState(
          () => _error = error is HttpError
              ? error.message
              : 'Unable to select a file on this device. You can submit a cloud link instead.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _send() async {
    if (_busy) return;
    if (_fileMode && _file == null) {
      setState(() => _error = 'Choose a file to upload.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.repository.requireTask(widget.task);
      if (_fileMode) {
        await WorkstationFileTransfer(widget.session).upload(
          '/api/v1/admin/freelancer/tasks/${Uri.encodeComponent(widget.task.id)}/upload-content',
          _file!,
          notes: _notes.text.trim(),
          onProgress: (value) {
            if (_current) setState(() => _progress = value);
          },
        );
      } else {
        await widget.repository.submitLink(
          widget.task,
          _link.text,
          _notes.text,
        );
      }
      if (mounted && _current) {
        setState(() => _busy = false);
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (error is HttpError) {
        widget.repository.markUncertain(widget.task, error);
      }
      if (_current) {
        setState(
          () => _error = error is HttpError
              ? error.message
              : 'Submission failed. Your input is preserved.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _previewFile() async {
    final file = _file;
    if (file == null || _busy) return;
    try {
      await WorkstationFileTransfer.preview(file);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'This file could not be previewed on your device.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_picking,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Submit content',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(widget.task.title),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('File upload'),
                    selected: _fileMode,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _fileMode = true),
                  ),
                  ChoiceChip(
                    label: const Text('Cloud link'),
                    selected: !_fileMode,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _fileMode = false),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_fileMode) ...[
                OutlinedButton.icon(
                  onPressed: _busy || _picking ? null : _pick,
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    _picking
                        ? 'Opening files…'
                        : _file == null
                        ? 'Choose a media file'
                        : 'Choose another file',
                  ),
                ),
                if (_file != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '${_file!.name} · ${(_file!.size / (1024 * 1024)).toStringAsFixed(1)} MB',
                    ),
                  ),
                if (_file != null)
                  TextButton.icon(
                    onPressed: _busy ? null : _previewFile,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Preview selected file'),
                  ),
              ] else
                TextField(
                  controller: _link,
                  enabled: !_busy,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Asset / cloud storage URL',
                    hintText: 'https://…',
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _notes,
                enabled: !_busy,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Submission notes (optional)',
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(color: context.creo.error),
                    ),
                  ),
                ),
              if (_busy) ...[
                LinearProgressIndicator(
                  value: _fileMode ? _progress : null,
                  semanticsLabel: 'Submitting content',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sending your content. Do not resubmit while this request is pending.',
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: _busy || _picking ? null : _send,
                child: Text(_busy ? 'Submitting…' : 'Submit for review'),
              ),
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    final file = _file;
    if (file != null) WorkstationFileTransfer.release(file);
    _link.dispose();
    _notes.dispose();
    super.dispose();
  }
}
