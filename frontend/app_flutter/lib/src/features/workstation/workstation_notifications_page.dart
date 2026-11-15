import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';
import 'workstation_notifications_repository.dart';

class WorkstationNotificationsPage extends StatefulWidget {
  const WorkstationNotificationsPage({
    super.key,
    required this.session,
    this.onNavigate,
    this.onUnreadChanged,
  });
  final AuthSession session;
  final void Function(String path)? onNavigate;
  final ValueChanged<int>? onUnreadChanged;
  @override
  State<WorkstationNotificationsPage> createState() => _NotificationsState();
}

class _NotificationsState extends State<WorkstationNotificationsPage>
    with WidgetsBindingObserver {
  late final WorkstationNotificationsRepository repository;
  late final int generation;
  late final String? account;
  WorkstationNotifications? data;
  Timer? timer;
  bool loading = false, writing = false, foreground = true;
  String? error, feedback;
  bool get active =>
      widget.session.phase == SessionPhase.authenticated &&
      widget.session.isCurrent(generation) &&
      widget.session.current?.user.id == account &&
      widget.session.current?.user.mustResetPassword != true &&
      const {
        'editor',
        'designer',
        'freelancer',
      }.contains(widget.session.current?.user.role);
  @override
  void initState() {
    super.initState();
    generation = widget.session.beginReadGeneration;
    account = widget.session.current?.user.id;
    repository = WorkstationNotificationsRepository(widget.session);
    widget.session.addListener(sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh());
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (active &&
          foreground &&
          !loading &&
          !writing &&
          (ModalRoute.of(context)?.isCurrent ?? true)) {
        unawaited(refresh(silent: true));
      }
    });
  }

  void sessionChanged() {
    if (!active && mounted) {
      setState(() {
        data = null;
        loading = false;
        writing = false;
        error = null;
        feedback = null;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground && active && !loading && !writing) {
      unawaited(refresh(silent: data != null));
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    widget.session.removeListener(sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String describe(Object problem) => problem is HttpError
      ? problem.message
      : problem is FormatException
      ? problem.message
      : 'Unable to load notifications. Please retry.';
  Future<void> refresh({bool silent = false}) async {
    if (loading || writing) return;
    if (!silent) {
      setState(() => loading = true);
    } else {
      loading = true;
    }
    try {
      final next = await repository.load();
      if (!mounted || !active) return;
      setState(() {
        data = next;
        error = null;
      });
      widget.onUnreadChanged?.call(next.unreadCount);
    } catch (problem) {
      if (!mounted || !active) return;
      setState(() {
        error = describe(problem);
        if (problem is HttpError && problem.status == 403) data = null;
      });
    } finally {
      if (mounted && active) setState(() => loading = false);
    }
  }

  Future<bool> mutate(
    Future<WorkstationNotifications> Function() action,
  ) async {
    if (!active || writing || loading || repository.mutationBlocked) {
      return false;
    }
    setState(() {
      writing = true;
      error = null;
      feedback = null;
    });
    try {
      final next = await action();
      if (!mounted || !active) return false;
      setState(() {
        data = next;
        feedback = 'Notifications refreshed from the server.';
      });
      widget.onUnreadChanged?.call(next.unreadCount);
      return true;
    } catch (problem) {
      if (mounted && active) setState(() => error = describe(problem));
      return false;
    } finally {
      if (mounted && active) setState(() => writing = false);
    }
  }

  Future<void> clearAll() async {
    if (writing || loading || repository.mutationBlocked) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text(
          'This deletes all notifications for your account, including older notifications not shown here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep notifications'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (!mounted || !active || confirmed != true) return;
    await mutate(repository.clearAll);
  }

  Future<void> open(WorkstationNotification item) async {
    if (writing || loading || !active) return;
    final target = notificationWorkspacePath(
      item.link,
      widget.session.current!.user.role,
    );
    if (target == null || widget.onNavigate == null) {
      setState(
        () => feedback =
            'This related destination is not available in the mobile workspace.',
      );
      return;
    }
    // React navigates even when marking read fails. Keep that behavior without
    // falsely claiming that the server marked the notification as read.
    if (!item.isRead && !repository.mutationBlocked) {
      await mutate(() => repository.markRead(item.id));
    }
    if (mounted && active) widget.onNavigate!(target);
  }

  String timestamp(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = active
        ? data?.items ?? const <WorkstationNotification>[]
        : const <WorkstationNotification>[];
    final disabled =
        loading || writing || repository.mutationBlocked || !active;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Refresh notifications',
            onPressed: loading || writing || !active ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  if (!active)
                    const Text('Sign in again to view your notifications.')
                  else ...[
                    Text(
                      data == null
                          ? 'Your notifications'
                          : '${data!.unreadCount} unread',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data == null && loading
                          ? 'Checking your latest notifications…'
                          : 'The latest notifications for your account. Unread count includes older items.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed:
                              disabled || data == null || data!.unreadCount == 0
                              ? null
                              : () => mutate(repository.markAllRead),
                          icon: const Icon(Icons.done_all),
                          label: const Text('Mark all read'),
                        ),
                        OutlinedButton.icon(
                          onPressed: disabled || rows.isEmpty ? null : clearAll,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Clear all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (loading || writing)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Semantics(
                          label: writing
                              ? 'Updating notifications'
                              : 'Loading notifications',
                          liveRegion: true,
                          child: MediaQuery.disableAnimationsOf(context)
                              ? Text(writing ? 'Updating…' : 'Loading…')
                              : const LinearProgressIndicator(),
                        ),
                      ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                error!,
                                style: TextStyle(color: context.creo.error),
                              ),
                              if (data != null)
                                const Text(
                                  'Previously loaded notifications are retained; their status may have changed.',
                                ),
                              TextButton(
                                onPressed: loading || writing ? null : refresh,
                                child: const Text('Retry refresh'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (repository.mutationUnconfirmed)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'An action has an unconfirmed outcome. Refresh to check the server state. No action will be retried automatically.',
                        ),
                      ),
                    if (feedback != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(feedback!),
                        ),
                      ),
                    if (data != null && rows.isEmpty && !loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Icon(Icons.notifications_none, size: 40),
                            SizedBox(height: 12),
                            Text('You’re all caught up.'),
                          ],
                        ),
                      ),
                    for (final item in rows)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: item.isRead
                                ? context.creo.appLine
                                : context.creo.accent,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  item.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(item.message),
                              const SizedBox(height: 8),
                              Text(
                                '${item.isRead ? 'Read' : 'Unread'}${item.createdAt == null ? '' : ' · ${timestamp(item.createdAt!)}'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  if (!item.isRead)
                                    TextButton.icon(
                                      onPressed: disabled
                                          ? null
                                          : () => mutate(
                                              () =>
                                                  repository.markRead(item.id),
                                            ),
                                      icon: const Icon(Icons.done),
                                      label: const Text('Mark read'),
                                    ),
                                  TextButton.icon(
                                    onPressed: disabled
                                        ? null
                                        : () => mutate(
                                            () => repository.delete(item.id),
                                          ),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Delete'),
                                  ),
                                  if (item.link != null &&
                                      item.link!.isNotEmpty)
                                    TextButton.icon(
                                      onPressed: loading || writing
                                          ? null
                                          : () => open(item),
                                      icon: const Icon(Icons.open_in_new),
                                      label: const Text('Open related page'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (rows.length >= 20)
                      const Text(
                        'Showing the latest 20 notifications. Older notifications are not included in this list.',
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
