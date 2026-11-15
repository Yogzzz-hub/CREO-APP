import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_appearance.dart';
import '../splash/splash_screen.dart';
import '../../core/app_theme.dart';
import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';
import 'workstation_task_page.dart';
import 'workstation_account_pages.dart';
import 'workstation_hub_pages.dart';
import 'workstation_hub_repository.dart';
import 'workstation_notifications_page.dart';
import 'workstation_meetings_page.dart';
import 'workstation_data.dart';
import 'workstation_task_browser.dart';
import 'member_workspace_shell.dart';

/// Android-first adaptation of MemberOverviewPage / MemberMobileDashboard.
/// The loader owns transport/session semantics; this widget owns display only.
class WorkstationPage extends StatefulWidget {
  const WorkstationPage({
    super.key,
    required this.user,
    required this.load,
    this.onSignOut,
    this.preview = false,
    this.session,
  });
  final AuthUser user;
  final LoadWorkstation load;
  final Future<void> Function()? onSignOut;
  final bool preview;
  final AuthSession? session;

  @override
  State<WorkstationPage> createState() => _WorkstationPageState();
}

class _WorkstationPageState extends State<WorkstationPage>
    with SingleTickerProviderStateMixin {
  final _scaffold = GlobalKey<ScaffoldState>();
  final _deliverablesAnchor = GlobalKey();
  final _search = TextEditingController();
  final _reply = TextEditingController();
  bool _sendingReply = false;
  int? _sessionGeneration;
  int? _notificationUnread;
  WorkstationMeetingStore? _preferences;
  final _dismissedFeedback = <String>{};
  bool _feedbackSaving = false;
  bool _feedbackLoading = false;
  String? _feedbackError;
  final _pinned = <String>{};
  WorkstationTaskSort _sort = WorkstationTaskSort.due;
  String _stage = '';
  bool _dueOnly = false, _pinnedOnly = false;
  late WorkstationController _controller;
  late final AnimationController _entrance;
  bool _allPod = false, _archived = false, _team = false;
  bool _started = false, _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _sessionGeneration = widget.session?.beginReadGeneration;
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _createController();
  }

  void _createController() {
    _controller = WorkstationController(() => widget.load());
    if (hasWorkstationHome(widget.user)) unawaited(_controller.refresh());
  }

  @override
  void didUpdateWidget(WorkstationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.role != widget.user.role ||
        _sessionGeneration != widget.session?.beginReadGeneration) {
      _sessionGeneration = widget.session?.beginReadGeneration;
      _controller.dispose();
      _allPod = _archived = _team = false;
      _search.clear();
      _reply.clear();
      _sendingReply = false;
      _notificationUnread = null;
      _dismissedFeedback.clear();
      _feedbackError = null;
      _feedbackSaving = _feedbackLoading = false;
      if (_preferences != null) unawaited(_loadFeedback());
      _pinned.clear();
      _sort = WorkstationTaskSort.due;
      _stage = '';
      _dueOnly = _pinnedOnly = false;
      _createController();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.session != null && _preferences == null) {
      _preferences =
          WorkstationMeetingScope.maybeOf(context) ??
          WorkstationMeetingStore.shared;
      unawaited(_loadFeedback());
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else if (!_started) {
      _entrance.forward();
    }
    _started = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    _entrance.dispose();
    _search.dispose();
    _reply.dispose();
    super.dispose();
  }

  void _clearFilters() => setState(() {
    _search.clear();
    _stage = '';
    _dueOnly = _pinnedOnly = false;
  });

  String _feedbackKey(WorkstationTask task) =>
      '${task.id}:${task.version ?? 0}:${task.feedback ?? ''}';
  List<WorkstationTask> _feedback(WorkstationData data) => data.feedback
      .where((task) => !_dismissedFeedback.contains(_feedbackKey(task)))
      .toList();
  Future<void> _loadFeedback() async {
    if (_feedbackLoading) return;
    setState(() => _feedbackLoading = true);
    final id = widget.user.id, generation = widget.session?.beginReadGeneration;
    try {
      final saved = await _preferences!.loadFeedback(id);
      if (mounted &&
          widget.user.id == id &&
          widget.session?.beginReadGeneration == generation) {
        setState(() {
          _dismissedFeedback
            ..clear()
            ..addAll(saved);
          _feedbackError = null;
        });
      }
    } catch (_) {
      if (mounted &&
          widget.user.id == id &&
          widget.session?.beginReadGeneration == generation) {
        setState(
          () => _feedbackError =
              'Saved feedback preferences could not be read. Your review notes remain visible.',
        );
      }
    } finally {
      if (mounted &&
          widget.user.id == id &&
          widget.session?.beginReadGeneration == generation) {
        setState(() => _feedbackLoading = false);
      }
    }
  }

  Future<void> _setDismissed(Set<String> next) async {
    if (_feedbackSaving || _feedbackLoading || _preferences == null) return;
    final id = widget.user.id, generation = widget.session?.beginReadGeneration;
    bool current() =>
        mounted &&
        widget.user.id == id &&
        widget.session?.beginReadGeneration == generation &&
        widget.session?.phase == SessionPhase.authenticated;
    setState(() => _feedbackSaving = true);
    try {
      await _preferences!.saveFeedback(id, next, isCurrent: current);
      if (current()) {
        setState(() {
          _dismissedFeedback
            ..clear()
            ..addAll(next);
          _feedbackError = null;
        });
      }
    } catch (_) {
      if (current()) {
        setState(
          () => _feedbackError =
              'This feedback preference could not be saved. Please retry.',
        );
      }
    } finally {
      if (current()) setState(() => _feedbackSaving = false);
    }
  }

  Future<void> _quickReply() async {
    final session = widget.session;
    if (session == null) {
      _notAvailable('Messaging in the signed-out preview');
      return;
    }
    final text = _reply.text.trim();
    if (_sendingReply || text.isEmpty) return;
    final generation = session.beginReadGeneration;
    final accountId = widget.user.id;
    final repository = WorkstationHubRepository(session);
    setState(() => _sendingReply = true);
    try {
      final channels = await repository.channels();
      if (!mounted ||
          !session.isCurrent(generation) ||
          widget.user.id != accountId) {
        return;
      }
      if (channels.isEmpty) {
        await _destination('Workspace Hub');
        return;
      }
      FocusManager.instance.primaryFocus?.unfocus();
      final selected = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : const AnimationStyle(duration: Duration(milliseconds: 250)),
        builder: (context) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Send reply to…',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(text),
              const SizedBox(height: 16),
              for (final channel in channels)
                ListTile(
                  leading: const Icon(Icons.tag),
                  title: Text(
                    workspaceText(
                      channel['label'],
                      workspaceText(channel['name'], 'Conversation'),
                    ),
                  ),
                  onTap: () =>
                      Navigator.pop(context, workspaceText(channel['id'])),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
      if (selected == null || !mounted || !session.isCurrent(generation)) {
        return;
      }
      // Capture server history before sending so an uncertain write can only be
      // reconciled against a newly returned matching message.
      await repository.messages(selected, direct: false);
      await repository.send(selected, text, direct: false);
      if (!mounted ||
          !session.isCurrent(generation) ||
          widget.user.id != accountId) {
        return;
      }
      if (_reply.text.trim() == text) _reply.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reply sent.')));
    } catch (error) {
      if (mounted && session.isCurrent(generation)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is HttpError
                  ? error.message
                  : 'Reply could not be sent. Your draft was retained.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && session.isCurrent(generation)) {
        setState(() => _sendingReply = false);
      }
    }
  }

  void _jumpToDeliverables({bool dueOnly = false}) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _allPod = _archived = _pinnedOnly = false;
      _search.clear();
      _stage = '';
      _dueOnly = dueOnly;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _deliverablesAnchor.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: .02,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _togglePin(WorkstationTask task) {
    final wasPinned = _pinned.contains(task.id);
    final account = (widget.user.id, widget.user.role);
    void update(bool pinned) {
      if (!mounted || account != (widget.user.id, widget.user.role)) return;
      setState(() {
        if (pinned) {
          _pinned.add(task.id);
        } else {
          _pinned.remove(task.id);
        }
      });
    }

    update(!wasPinned);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            wasPinned ? 'Task unpinned.' : 'Task pinned for this visit.',
          ),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => update(wasPinned),
          ),
        ),
      );
  }

  String get _initials {
    final parts = widget.user.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p.characters.first).join().toUpperCase();
  }

  Future<void> _sheet(String title, Widget child) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .82,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
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
                      onPressed: () => Navigator.pop(sheetContext),
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
  }

  void _notAvailable(String title) => _sheet(
    title,
    Text(
      '$title is not available in the mobile app yet. Your account and work are unchanged.',
      style: Theme.of(context).textTheme.bodyLarge,
    ),
  );

  Future<void> _destination(
    String destination, {
    String? taskId,
    String? dm,
    String? channel,
  }) async {
    final session = widget.session;
    if (session == null) {
      _notAvailable('$destination (preview has no signed-in account)');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final tab = switch (destination) {
      'Tasks' => 1,
      'Workspace Hub' => 2,
      'Schedule and leave' => 3,
      'Account settings' => 4,
      _ => null,
    };
    final navigation = MemberNavigationScope.maybeOf(context);
    if (navigation != null &&
        tab != null &&
        taskId == null &&
        dm == null &&
        channel == null) {
      navigation.select(tab);
      return;
    }
    final page = switch (destination) {
      'Tasks' => WorkstationTaskPage(session: session, taskId: taskId),
      'Meetings' => WorkstationMeetingsPage(
        session: session,
        store: WorkstationMeetingScope.maybeOf(context),
      ),
      'Schedule and leave' => WorkstationSchedulePage(
        session: session,
        freelancer: false,
      ),
      'Account settings' => WorkstationSettingsPage(
        session: session,
        freelancer: false,
      ),
      'Workspace Hub' => WorkstationHubPage(
        session: session,
        initialDm: dm,
        initialChannel: channel,
      ),
      'Instagram Connect' => WorkstationPublishingPage(session: session),
      _ => null,
    };
    if (page == null) return;
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => page));
    if (mounted && widget.user.id == session.current?.user.id) {
      await _controller.refresh();
    }
  }

  void _account() => _sheet(
    'Your account',
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.user.fullName,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(widget.user.email),
        const SizedBox(height: 8),
        Text(widget.user.role.replaceAll('_', ' ')),
        const SizedBox(height: 20),
        const Text('Account settings are not available in the mobile app yet.'),
      ],
    ),
  );

  Future<void> _logout() async {
    if (_loggingOut || widget.onSignOut == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out on this device?'),
        content: const Text(
          'You will need to sign in again to open your workspace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay signed in'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await widget.onSignOut!();
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _openLink(String value) async {
    final uri = Uri.tryParse(value);
    final valid =
        uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
    var opened = false;
    try {
      if (valid) {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // The app stays usable if the OS has no suitable handler.
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This link could not be opened. Please try again.'),
        ),
      );
    }
  }

  void _meetings() => widget.session != null
      ? _destination('Meetings')
      : _sheet(
          'Join a meeting',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Open your meeting provider to join a call. No scheduled meeting time is available here yet.',
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _openLink('https://meet.google.com'),
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('Open Google Meet'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _openLink('https://zoom.us/join'),
                icon: const Icon(Icons.video_call_outlined),
                label: const Text('Open Zoom'),
              ),
            ],
          ),
        );

  Future<void> _liveNotifications() async {
    final session = widget.session!;
    final generation = session.beginReadGeneration;
    String? selected;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => WorkstationNotificationsPage(
          session: session,
          onUnreadChanged: (count) {
            if (mounted && session.isCurrent(generation)) {
              setState(() => _notificationUnread = count);
            }
          },
          onNavigate: (path) {
            selected = path;
            Navigator.of(routeContext).pop();
          },
        ),
      ),
    );
    if (!mounted || !session.isCurrent(generation) || selected == null) return;
    final uri = Uri.parse(selected!);
    switch (uri.path) {
      case '/workstation/tasks':
        await _destination('Tasks', taskId: uri.queryParameters['taskId']);
      case '/workstation/schedule':
        await _destination('Schedule and leave');
      case '/workstation/settings':
        await _destination('Account settings');
      case '/workstation/slack':
        await _destination(
          'Workspace Hub',
          dm: uri.queryParameters['dm'],
          channel: uri.queryParameters['channel'],
        );
      case '/admin/publishing':
        await _destination('Instagram Connect');
      case '/workstation':
        break;
    }
  }

  void _notifications(WorkstationData? data) => widget.session != null
      ? _liveNotifications()
      : _sheet(
          'Pod notifications',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: data == null
                ? [const Text('Load your workspace to check notifications.')]
                : data.notices.isEmpty
                ? [
                    const Text(
                      'No pod notifications returned for this workspace.',
                    ),
                  ]
                : [
                    for (final notice in data.notices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              notice.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(notice.message),
                          ],
                        ),
                      ),
                  ],
          ),
        );

  void _details(WorkstationTask task) => _sheet(
    'Deliverable details',
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(task.title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 12),
        Text(task.client),
        const SizedBox(height: 12),
        Text('${_status(task.status)} · ${task.format.replaceAll('_', ' ')}'),
        if (task.version != null) ...[
          const SizedBox(height: 12),
          Text('Version ${task.version}'),
        ],
        const SizedBox(height: 12),
        Text(_due(task.due)),
        if (task.feedback?.isNotEmpty ?? false) ...[
          const SizedBox(height: 24),
          const Text('Review feedback'),
          const SizedBox(height: 8),
          Text(task.feedback!),
        ],
        const SizedBox(height: 24),
        if (task.fileUrl != null &&
            Uri.tryParse(task.fileUrl!)?.scheme == 'https')
          FilledButton.icon(
            onPressed: () => _openLink(task.fileUrl!),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open uploaded preview'),
          )
        else
          const Text('No uploaded preview is available for this task.'),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: widget.session == null
              ? () => _notAvailable('Upload and handoff')
              : () {
                  Navigator.of(context).pop();
                  _destination('Tasks', taskId: task.id);
                },
          icon: const Icon(Icons.upload_outlined),
          label: const Text('Upload and handoff'),
        ),
      ],
    ),
  );

  void _queue(WorkstationData? data) {
    if (widget.session != null) {
      _destination('Tasks');
      return;
    }
    if (data == null) {
      _notAvailable('Task queue while workspace is unavailable');
      return;
    }
    final rows = [
      ...data.tasks(widget.user),
      ...data.backlog.where((task) => task.eligibleBacklog(widget.user)),
    ];
    _sheet(
      'Your task queue',
      WorkstationTaskBrowser(
        rows: rows,
        caption:
            'Your active work and eligible backlog. Claiming or moving tasks is not available on mobile yet.',
        tileBuilder: (task) => _taskTile(task, allowPin: false),
      ),
    );
  }

  static String _status(String status) => switch (status) {
    'in_production' => 'In progress',
    'internal_qa' => 'In QA',
    'backlog' || 'yet_to_do' => 'Backlog',
    'completed' => 'Completed',
    _ => status.replaceAll('_', ' '),
  };

  static String _due(DateTime? due) {
    if (due == null) return 'No due date';
    final local = due.toLocal();
    return 'Due ${local.day}/${local.month}/${local.year}';
  }

  Widget _card(
    Widget child, {
    Key? key,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    VoidCallback? onTap,
  }) => Material(
    key: key,
    color: context.creo.appSurface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: context.creo.appLine),
    ),
    child: onTap == null
        ? Padding(padding: padding, child: child)
        : Semantics(
            button: true,
            child: InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
          ),
  );

  Widget _caption(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      height: 1.4,
      fontWeight: FontWeight.w600,
      letterSpacing: .7,
      color: context.creo.appMist,
    ),
  );

  Widget _pill(String text, {bool accent = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: accent
          ? context.creo.accent.withValues(alpha: .12)
          : context.creo.appBase,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: accent ? context.creo.accent : context.creo.appMist,
      ),
    ),
  );

  Widget _taskTile(WorkstationTask task, {bool allowPin = true}) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Material(
      color: context.creo.appBase,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey('task-${task.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => _details(task),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 12),
                    child: Icon(
                      task.format == 'reel' || task.format == 'story'
                          ? Icons.movie_outlined
                          : Icons.layers_outlined,
                      color: context.creo.accent,
                      size: 22,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.client,
                          style: TextStyle(
                            color: context.creo.appMist,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (allowPin)
                    IconButton(
                      key: ValueKey('pin-${task.id}'),
                      isSelected: _pinned.contains(task.id),
                      tooltip: _pinned.contains(task.id)
                          ? 'Unpin task'
                          : 'Pin for this visit',
                      color: _pinned.contains(task.id)
                          ? context.creo.accent
                          : context.creo.appMist,
                      onPressed: () => _togglePin(task),
                      icon: AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 160),
                        child: Icon(
                          _pinned.contains(task.id)
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          key: ValueKey(_pinned.contains(task.id)),
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _pill(_status(task.status), accent: true),
                  Text(
                    _due(task.due),
                    style: TextStyle(fontSize: 12, color: context.creo.appMist),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _empty(
    String title,
    String description, {
    VoidCallback? action,
    String? label,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 14),
      Icon(Icons.task_alt_outlined, size: 34, color: context.creo.accent),
      const SizedBox(height: 16),
      Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Text(
        description,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: context.creo.appMist,
          height: 1.55,
          fontSize: 14,
        ),
      ),
      if (action != null && label != null) ...[
        const SizedBox(height: 20),
        FilledButton(
          onPressed: action,
          child: Text(label, textAlign: TextAlign.center),
        ),
      ],
      const SizedBox(height: 12),
    ],
  );

  Widget _metrics(WorkstationData data) {
    final mine = data.tasks(widget.user);
    final progress = data.inProduction
        .where((t) => t.assignedToUser(widget.user))
        .length;
    final qa = data.inQa.where((t) => t.assignedToUser(widget.user)).length;
    final active = _card(
      onTap: _jumpToDeliverables,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _caption('ACTIVE TASKS')),
              Icon(Icons.bolt_outlined, color: context.creo.accent, size: 20),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${mine.length}',
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(fontSize: 34),
          ),
          const SizedBox(height: 4),
          Text(
            '$progress in progress · $qa in QA',
            style: TextStyle(
              color: context.creo.appMist,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const Divider(height: 24),
          Text(
            'Due by today: ${data.dueByToday(widget.user, DateTime.now())}',
            style: TextStyle(
              color: context.creo.accent,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    final hours = _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _caption('WEEKLY HOURS')),
              Icon(
                Icons.schedule_outlined,
                color: context.creo.accent,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '—',
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(fontSize: 34),
          ),
          const SizedBox(height: 8),
          Text(
            'Hours unavailable',
            style: TextStyle(color: context.creo.appMist, fontSize: 14),
          ),
        ],
      ),
    );
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 340 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.5) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [active, const SizedBox(height: 12), hours],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: active),
                const SizedBox(width: 12),
                Expanded(child: hours),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _card(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.calendar_month_outlined, color: context.creo.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _caption('REMAINING PTO'),
                    const SizedBox(height: 6),
                    Text(
                      'Balance unavailable',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The dashboard API does not provide a leave balance.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: context.creo.appMist,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actions(WorkstationData data) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        key: const Key('workstation-refresh'),
        onPressed: _controller.loading ? null : _controller.refresh,
        icon: const Icon(Icons.refresh, size: 20),
        label: Text(_controller.loading ? 'Refreshing…' : 'Refresh'),
      ),
      FilledButton.icon(
        key: const Key('browse-tasks'),
        onPressed: () => _queue(data),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Browse tasks'),
      ),
      OutlinedButton.icon(
        onPressed: _meetings,
        icon: const Icon(Icons.videocam_outlined, size: 20),
        label: const Text('Join a meeting'),
      ),
      OutlinedButton.icon(
        onPressed: () => _destination('Workspace Hub'),
        icon: const Icon(Icons.tag, size: 20),
        label: const Text('Workspace Hub'),
      ),
      OutlinedButton.icon(
        onPressed: () => _destination('Schedule and leave'),
        icon: const Icon(Icons.event_outlined, size: 20),
        label: const Text('Schedule'),
      ),
    ],
  );

  Widget _deliverables(WorkstationData data) {
    final source = data.tasks(
      widget.user,
      allPod: _allPod,
      archived: _archived,
    );
    final filtered =
        _search.text.trim().isNotEmpty ||
        _pinnedOnly ||
        (!_archived && (_dueOnly || _stage.isNotEmpty));
    final rows = browseWorkstationTasks(
      source,
      query: _search.text,
      sort: _sort,
      stage: _archived ? '' : _stage,
      dueOnly: !_archived && _dueOnly,
      pinnedIds: _pinnedOnly ? _pinned : null,
    );
    final active = data.tasks(widget.user, allPod: _allPod).length;
    final archived = data
        .tasks(widget.user, allPod: _allPod, archived: true)
        .length;
    return _card(
      key: _deliverablesAnchor,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Assigned deliverables',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            '${data.podName} deliverables pipeline',
            style: TextStyle(color: context.creo.appMist, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                key: const Key('scope-mine'),
                label: const Text('My tasks'),
                selected: !_allPod,
                onSelected: (_) => setState(() => _allPod = false),
              ),
              ChoiceChip(
                key: const Key('scope-pod'),
                label: const Text('Pod tasks'),
                selected: _allPod,
                onSelected: (_) => setState(() => _allPod = true),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                key: const Key('tab-active'),
                label: Text('Active ($active)'),
                selected: !_archived,
                onSelected: (_) => setState(() => _archived = false),
              ),
              ChoiceChip(
                key: const Key('tab-archived'),
                label: Text('Archived ($archived)'),
                selected: _archived,
                onSelected: (_) => setState(() => _archived = true),
              ),
            ],
          ),
          const Divider(height: 28),
          WorkstationSearch(
            controller: _search,
            fieldKey: 'deliverables-search',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (!_archived) ...[
                FilterChip(
                  key: const Key('filter-due'),
                  label: const Text('Due by today'),
                  selected: _dueOnly,
                  onSelected: (value) => setState(() => _dueOnly = value),
                ),
                for (final stage in const [
                  ('in_production', 'In progress'),
                  ('internal_qa', 'In QA'),
                ])
                  FilterChip(
                    key: ValueKey('filter-${stage.$1}'),
                    label: Text(stage.$2),
                    selected: _stage == stage.$1,
                    onSelected: (value) =>
                        setState(() => _stage = value ? stage.$1 : ''),
                  ),
              ],
              FilterChip(
                key: const Key('filter-pinned'),
                label: const Text('Pinned'),
                avatar: const Icon(Icons.bookmark_border, size: 18),
                selected: _pinnedOnly,
                onSelected: (value) => setState(() => _pinnedOnly = value),
              ),
            ],
          ),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              WorkstationSortMenu(
                key: const Key('deliverables-sort'),
                value: _sort,
                onChanged: (value) => setState(() => _sort = value),
              ),
              if (filtered)
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear filters'),
                ),
            ],
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              '${rows.length} matching ${rows.length == 1 ? 'deliverable' : 'deliverables'}',
              style: TextStyle(color: context.creo.appMist, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            _empty(
              filtered
                  ? 'No matching deliverables'
                  : _archived
                  ? 'No archived deliverables'
                  : 'No active deliverables in production',
              filtered
                  ? 'Try another search or clear the filters to see more of this view.'
                  : _archived
                  ? 'Completed work will appear here when it is returned for this workspace.'
                  : 'Your selected view has no work in production or QA. Browse your task queue for eligible backlog.',
              action: filtered ? _clearFilters : () => _queue(data),
              label: filtered
                  ? 'Reset search and filters'
                  : 'Browse task queue',
            )
          else ...[
            for (final task in rows.take(4)) _taskTile(task),
            if (rows.length > 4) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _sheet(
                  'Matching deliverables',
                  WorkstationTaskBrowser(
                    rows: rows,
                    tileBuilder: (task) => _taskTile(task, allowPin: false),
                  ),
                ),
                child: Text('View all ${rows.length} deliverables'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _feedbackAndTeam(WorkstationData data) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ChoiceChip(
              key: const Key('panel-feedback'),
              label: Text('Lead feedback (${_feedback(data).length})'),
              selected: !_team,
              onSelected: (_) => setState(() => _team = false),
            ),
            ChoiceChip(
              key: const Key('panel-team'),
              label: const Text('Pod team sync'),
              selected: _team,
              onSelected: (_) => setState(() => _team = true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_team) ...[
          Text(data.podName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '${data.members.length} pod members',
            style: TextStyle(color: context.creo.appMist),
          ),
          const SizedBox(height: 16),
          if (data.members.isEmpty)
            const Text('No team members returned for this workspace.'),
          for (final member in data.members)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: context.creo.accent.withValues(alpha: .15),
                    foregroundColor: context.creo.accent,
                    child: const Icon(Icons.person_outline),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          member.craft,
                          style: TextStyle(
                            color: context.creo.appMist,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _meetings,
            icon: const Icon(Icons.videocam_outlined),
            label: const Text('Join a meeting'),
          ),
        ] else ...[
          if (_feedbackError != null) ...[
            Semantics(liveRegion: true, child: Text(_feedbackError!)),
            TextButton(
              onPressed: _loadFeedback,
              child: const Text('Retry saved feedback preferences'),
            ),
          ],
          if (_dismissedFeedback.isNotEmpty)
            TextButton(
              onPressed: _feedbackSaving ? null : () => _setDismissed({}),
              child: const Text('Show dismissed feedback'),
            ),
          if (_feedback(data).isEmpty)
            _empty(
              'No feedback or revision requests',
              'No review feedback was returned for the current tasks.',
            )
          else
            for (final task in _feedback(data).take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Material(
                  color: context.creo.appBase,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => _details(task),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            task.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            task.feedback!,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: context.creo.appInk,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            task.client,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.creo.appMist,
                            ),
                          ),
                          if (widget.session != null)
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      _destination('Workspace Hub'),
                                  child: const Text('Reply in workspace'),
                                ),
                                TextButton(
                                  onPressed:
                                      _feedbackSaving ||
                                          _feedbackLoading ||
                                          _feedbackError != null
                                      ? null
                                      : () => _setDismissed({
                                          ..._dismissedFeedback,
                                          _feedbackKey(task),
                                        }),
                                  child: const Text('Dismiss feedback'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          if (_feedback(data).length > 3)
            TextButton(
              onPressed: () => _sheet(
                'All review feedback',
                Column(
                  children: [
                    for (final task in _feedback(data)) _taskTile(task),
                  ],
                ),
              ),
              child: const Text('View all feedback'),
            ),
          const Divider(height: 28),
          Text('Quick reply', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            widget.session == null
                ? 'Sign in to send a message to your workspace.'
                : 'Choose one of your server-provided channels before sending.',
            style: TextStyle(
              color: context.creo.appMist,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.session != null) ...[
            TextField(
              controller: _reply,
              enabled: !_sendingReply,
              maxLength: 10000,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Reply to your pod'),
              textInputAction: TextInputAction.newline,
            ),
            FilledButton.icon(
              onPressed: _sendingReply ? null : _quickReply,
              icon: const Icon(Icons.send_outlined),
              label: Text(_sendingReply ? 'Sending…' : 'Choose channel & send'),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: () => _destination('Workspace Hub'),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Workspace Hub'),
          ),
        ],
      ],
    ),
  );

  Widget _drawer(WorkstationData? data) => Drawer(
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: CreoWordmark(fontSize: 30),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '${widget.user.fullName}\n${widget.user.role}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const Divider(),
          for (final entry in [
            (Icons.dashboard_outlined, 'Dashboard', () {}),
            (Icons.checklist_outlined, 'Tasks', () => _queue(data)),
            (
              Icons.photo_camera_outlined,
              'Instagram Connect',
              () => _destination('Instagram Connect'),
            ),
            (
              Icons.event_outlined,
              'Leave requests',
              () => _destination('Schedule and leave'),
            ),
            (
              Icons.chat_bubble_outline,
              'Workspace Hub',
              () => _destination('Workspace Hub'),
            ),
            (
              Icons.settings_outlined,
              'Account settings',
              () => widget.session == null
                  ? _account()
                  : _destination('Account settings'),
            ),
          ])
            ListTile(
              leading: Icon(entry.$1),
              title: Text(entry.$2),
              selected: entry.$2 == 'Dashboard',
              onTap: () {
                Navigator.of(context).pop();
                entry.$3();
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(
              widget.preview
                  ? 'Preview mode — no account signed in'
                  : 'Sign out on this device',
            ),
            enabled: widget.onSignOut != null && !_loggingOut,
            onTap: () {
              Navigator.of(context).pop();
              _logout();
            },
          ),
        ],
      ),
    ),
  );

  Widget _header(WorkstationData? data) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Row(
      children: [
        if (MemberNavigationScope.maybeOf(context) != null)
          PopupMenuButton<String>(
            key: const Key('workstation-menu'),
            tooltip: 'More workspace actions',
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              } else {
                _destination(value);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'Instagram Connect',
                child: Text('Instagram Connect'),
              ),
              PopupMenuItem(value: 'Meetings', child: Text('Meetings')),
              PopupMenuItem(
                value: 'logout',
                child: Text('Sign out on this device'),
              ),
            ],
          )
        else
          IconButton(
            key: const Key('workstation-menu'),
            tooltip: 'Open navigation',
            onPressed: () => _scaffold.currentState?.openDrawer(),
            icon: const Icon(Icons.menu),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: CreoWordmark(),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'MEMBER',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                    color: context.creo.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const CreoThemeToggle(),
        IconButton(
          tooltip: 'Pod notifications',
          onPressed: () => _notifications(data),
          icon: Badge(
            isLabelVisible: _notificationUnread == null
                ? data?.notices.isNotEmpty ?? false
                : _notificationUnread! > 0,
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
        IconButton(
          tooltip: 'Your account',
          onPressed: () {
            final navigation = MemberNavigationScope.maybeOf(context);
            if (navigation != null) {
              navigation.select(4);
            } else {
              _account();
            }
          },
          icon: CircleAvatar(
            radius: 17,
            backgroundColor: context.creo.accent,
            foregroundColor: context.creo.onAccent,
            child: Text(
              _initials.isEmpty ? 'M' : _initials,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _error(HttpError error, {bool stale = false}) => _card(
    Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            error.status == 403 ? Icons.lock_outline : Icons.cloud_off_outlined,
            color: context.creo.accent,
          ),
          const SizedBox(height: 12),
          Text(
            error.status == 403
                ? 'Workspace access unavailable'
                : stale
                ? 'Could not refresh your workspace'
                : 'Could not load your workspace',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error.message,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: context.creo.appMist,
            ),
          ),
          if (stale) ...[
            const SizedBox(height: 8),
            const Text('Showing the last loaded information.'),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _controller.loading ? null : _controller.refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!hasWorkstationHome(widget.user)) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('This account cannot open the member workstation.'),
            ),
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final data = _controller.data;
        return Scaffold(
          key: _scaffold,
          drawer: MemberNavigationScope.maybeOf(context) == null
              ? _drawer(data)
              : null,
          body: SafeArea(
            child: Column(
              children: [
                if (widget.preview)
                  MaterialBanner(
                    padding: const EdgeInsets.all(12),
                    content: const Text(
                      'UI PREVIEW · Sample data · Not signed in',
                      style: TextStyle(fontSize: 13),
                    ),
                    actions: const [SizedBox.shrink()],
                  ),
                _header(data),
                Divider(height: 1, color: context.creo.appLine),
                if (_controller.loading && data != null)
                  Semantics(
                    label: 'Refreshing workspace',
                    liveRegion: true,
                    child: MediaQuery.disableAnimationsOf(context)
                        ? const Text('Refreshing workspace…')
                        : const LinearProgressIndicator(minHeight: 2),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _controller.refresh,
                    child: SingleChildScrollView(
                      key: const PageStorageKey('workstation-scroll'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                            child: FadeTransition(
                              opacity: _entrance.drive(
                                CurveTween(curve: Curves.easeOutCubic),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Semantics(
                                    header: true,
                                    child: Text(
                                      'Your workspace',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineLarge,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    data?.podName ?? 'Member workstation',
                                    style: TextStyle(
                                      color: context.creo.appMist,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  if (data == null && _controller.loading)
                                    _card(
                                      Semantics(
                                        liveRegion: true,
                                        label: 'Loading workspace',
                                        child: Column(
                                          children: [
                                            if (MediaQuery.disableAnimationsOf(
                                              context,
                                            ))
                                              const Icon(Icons.hourglass_top)
                                            else
                                              const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            const SizedBox(height: 20),
                                            const Text(
                                              'Loading your workspace…',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (_controller.error != null) ...[
                                    _error(
                                      _controller.error!,
                                      stale: data != null,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  if (data != null) ...[
                                    _metrics(data),
                                    const SizedBox(height: 16),
                                    _actions(data),
                                    const SizedBox(height: 20),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        if (constraints.maxWidth >= 900 &&
                                            MediaQuery.textScalerOf(
                                                  context,
                                                ).scale(1) <=
                                                1.5) {
                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: _deliverables(data),
                                              ),
                                              const SizedBox(width: 20),
                                              Expanded(
                                                child: _feedbackAndTeam(data),
                                              ),
                                            ],
                                          );
                                        }
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            _deliverables(data),
                                            const SizedBox(height: 16),
                                            _feedbackAndTeam(data),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
