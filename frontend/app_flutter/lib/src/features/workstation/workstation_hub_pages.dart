import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';
import 'workstation_files.dart';
import 'workstation_hub_repository.dart';

String _failure(Object error) => error is HttpError
    ? error.message
    : error is FormatException
    ? error.message
    : 'Unable to load this workspace. Please retry.';

/// Bounded foreground polling replaces the web page's background polling and
/// WebSocket invalidation; it never invents messages or queues offline writes.
abstract class _LiveState<T extends StatefulWidget> extends State<T>
    with WidgetsBindingObserver {
  AuthSession get session;
  late final repository = WorkstationHubRepository(session);
  Timer? _timer;
  bool foreground = true, loading = false, saving = false;
  String? error;
  int epoch = 0;
  late final String? accountId;
  late final int accountGeneration;
  bool get active =>
      session.phase == SessionPhase.authenticated &&
      session.current?.user.id == accountId &&
      session.isCurrent(accountGeneration) &&
      session.current?.user.mustResetPassword != true;
  Future<void> reload();
  @override
  void initState() {
    super.initState();
    accountId = session.current?.user.id;
    accountGeneration = session.beginReadGeneration;
    WidgetsBinding.instance.addObserver(this);
    session.addListener(_sessionChanged);
    unawaited(reload());
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (foreground &&
          active &&
          !loading &&
          !saving &&
          (ModalRoute.of(context)?.isCurrent ?? true)) {
        unawaited(reload());
      }
    });
  }

  void _sessionChanged() {
    if (!active) {
      epoch++;
      if (mounted) {
        setState(() {
          error = 'Your session has ended. Sign in again to continue.';
          loading = false;
          saving = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground && active && !loading && !saving) unawaited(reload());
  }

  @override
  void dispose() {
    epoch++;
    _timer?.cancel();
    session.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> act(Future<void> Function() action, String success) async {
    if (saving || session.phase != SessionPhase.authenticated) return;
    final run = epoch;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await action();
      if (!mounted || run != epoch) return;
      if (success.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
      await reload();
    } catch (err) {
      if (mounted && run == epoch) setState(() => error = _failure(err));
    } finally {
      if (mounted && run == epoch) setState(() => saving = false);
    }
  }

  Widget frame(
    String title,
    List<Widget> children, {
    Widget? bottom,
    ScrollController? scrollController,
  }) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: loading || saving ? null : reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(20),
              children: [
                if (active && (loading || saving))
                  Semantics(
                    liveRegion: true,
                    label: saving ? 'Saving' : 'Refreshing',
                    child: MediaQuery.disableAnimationsOf(context)
                        ? Text(saving ? 'Saving…' : 'Refreshing…')
                        : const LinearProgressIndicator(),
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
                          TextButton(
                            onPressed: loading || saving ? null : reload,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (active)
                  ...children
                else
                  const Text('Sign in again to view this workspace.'),
              ],
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: active ? bottom : null,
  );
  Widget card(Widget child) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: context.creo.appLine),
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class WorkstationHubPage extends StatefulWidget {
  const WorkstationHubPage({
    super.key,
    required this.session,
    this.initialDm,
    this.initialChannel,
  });
  final AuthSession session;
  final String? initialDm, initialChannel;
  @override
  State<WorkstationHubPage> createState() => _HubState();
}

class _HubState extends _LiveState<WorkstationHubPage> {
  @override
  AuthSession get session => widget.session;
  List<WorkspaceRecord> channels = [], contacts = [];
  String query = '', filter = 'All';
  bool _targetOpened = false;
  @override
  Future<void> reload() async {
    if (loading) return;
    final run = epoch;
    setState(() => loading = true);
    try {
      final next = await Future.wait([
        repository.channels(),
        repository.contacts(),
      ]);
      if (!mounted || run != epoch) return;
      setState(() {
        channels = next[0];
        contacts = next[1];
        error = null;
      });
      if (!_targetOpened &&
          (widget.initialDm != null || widget.initialChannel != null)) {
        _targetOpened = true;
        final direct = widget.initialDm != null;
        final id = widget.initialDm ?? widget.initialChannel;
        final matches = (direct ? contacts : channels).where(
          (row) => row['id'] == id,
        );
        if (matches.isNotEmpty) {
          final row = matches.first;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && active) _openConversation(row, direct);
          });
        } else {
          error = 'This conversation is not available for your account.';
        }
      }
    } catch (err) {
      if (mounted && run == epoch) {
        setState(() {
          error = _failure(err);
          channels = [];
          contacts = [];
        });
      }
    } finally {
      if (mounted && run == epoch) setState(() => loading = false);
    }
  }

  bool matches(WorkspaceRecord row) =>
      '${row['label'] ?? row['name']} ${row['desc'] ?? row['email'] ?? ''}'
          .toLowerCase()
          .contains(query.toLowerCase());
  @override
  Widget build(BuildContext context) => frame('Workspace Hub', [
    Text(
      session.current?.user.role == 'freelancer'
          ? 'Direct conversations with your workspace administrators.'
          : 'Your pod, channels and direct conversations.',
      style: Theme.of(context).textTheme.bodyLarge,
    ),
    const SizedBox(height: 16),
    TextField(
      decoration: const InputDecoration(
        labelText: 'Search conversations',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (value) => setState(() => query = value),
    ),
    const SizedBox(height: 12),
    Wrap(
      spacing: 8,
      children: [
        for (final item in [
          'All',
          if (session.current?.user.role != 'freelancer') 'Channels',
          'Direct',
        ])
          ChoiceChip(
            label: Text(item),
            selected: filter == item,
            onSelected: (_) => setState(() => filter = item),
          ),
      ],
    ),
    const SizedBox(height: 16),
    if (!loading && channels.isEmpty && contacts.isEmpty && error == null)
      const Text('No conversations are available for this account yet.'),
    if ({'admin', 'super_admin', 'team_lead'}.contains(repository.role))
      OutlinedButton.icon(
        onPressed: loading
            ? null
            : () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        _GroupForm(repository: repository, contacts: contacts),
                  ),
                );
                if (mounted && result == true) unawaited(reload());
              },
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Create group'),
      ),
    if (query.isNotEmpty && !channels.any(matches) && !contacts.any(matches))
      const Text('No conversations match your search.'),
    if (filter != 'Direct' && channels.where(matches).isNotEmpty)
      _sectionHeading(context, 'CHANNELS', channels.where(matches).length),
    if (filter != 'Direct')
      for (final row in channels.where(matches)) _conversation(row, false),
    if (filter != 'Channels' && contacts.where(matches).isNotEmpty)
      _sectionHeading(
        context,
        'DIRECT MESSAGES',
        contacts.where(matches).length,
      ),
    if (filter != 'Channels')
      for (final row in contacts.where(matches)) _conversation(row, true),
  ]);
  Widget _conversation(WorkspaceRecord row, bool direct) {
    final title = workspaceText(row[direct ? 'name' : 'label'], 'Conversation');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: context.creo.appSurface,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minVerticalPadding: 14,
          leading: CircleAvatar(
            backgroundColor: context.creo.accent.withValues(alpha: .14),
            foregroundColor: context.creo.accent,
            child: direct
                ? Text(
                    title.isEmpty ? '?' : title.substring(0, 1).toUpperCase(),
                  )
                : const Icon(Icons.tag_rounded),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            workspaceText(
              row[direct ? 'role' : 'desc'],
              direct ? 'Direct message' : 'Team channel',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: context.creo.appMist,
          ),
          onTap: () => _openConversation(row, direct),
        ),
      ),
    );
  }

  Future<void> _openConversation(WorkspaceRecord row, bool direct) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _ConversationPage(
            session: session,
            repository: repository,
            id: workspaceText(row['id']),
            direct: direct,
            title: workspaceText(
              row[direct ? 'name' : 'label'],
              'Conversation',
            ),
          ),
        ),
      );
}

class _GroupForm extends StatefulWidget {
  const _GroupForm({required this.repository, required this.contacts});
  final WorkstationHubRepository repository;
  final List<WorkspaceRecord> contacts;
  @override
  State<_GroupForm> createState() => _GroupFormState();
}

class _GroupFormState extends State<_GroupForm> {
  final name = TextEditingController(), description = TextEditingController();
  final members = <String>{};
  bool pod = false, busy = false;
  String? error;
  String query = '';
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.createGroup(
        name.text,
        description.text,
        members.toList(),
        pod: pod,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (err) {
      if (mounted) setState(() => error = _failure(err));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create group')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (error != null)
            Semantics(
              liveRegion: true,
              child: Text(error!, style: TextStyle(color: context.creo.error)),
            ),
          TextField(
            controller: name,
            enabled: !busy,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Group name'),
          ),
          TextField(
            controller: description,
            enabled: !busy,
            maxLength: 255,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pod channel'),
            value: pod,
            onChanged: busy ? null : (value) => setState(() => pod = value),
          ),
          TextField(
            enabled: !busy,
            decoration: const InputDecoration(labelText: 'Search members'),
            onChanged: (value) => setState(() => query = value.toLowerCase()),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(
                        () => members.addAll(
                          widget.contacts.map(
                            (row) => workspaceText(row['id']),
                          ),
                        ),
                      ),
                child: const Text('Select all'),
              ),
              TextButton(
                onPressed: busy ? null : () => setState(members.clear),
                child: const Text('Clear selected'),
              ),
            ],
          ),
          for (final row in widget.contacts.where(
            (row) =>
                '${row['name']} ${row['email']}'.toLowerCase().contains(query),
          ))
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(workspaceText(row['name'], 'Workspace member')),
              subtitle: Text(workspaceText(row['role'])),
              value: members.contains(row['id']),
              onChanged: busy
                  ? null
                  : (checked) => setState(() {
                      if (checked == true) {
                        members.add(workspaceText(row['id']));
                      } else {
                        members.remove(row['id']);
                      }
                    }),
            ),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Text(busy ? 'Creating…' : 'Create group'),
          ),
        ],
      ),
    ),
  );
}

class _ConversationPage extends StatefulWidget {
  const _ConversationPage({
    required this.session,
    required this.repository,
    required this.id,
    required this.direct,
    required this.title,
  });
  final AuthSession session;
  final WorkstationHubRepository repository;
  final String id, title;
  final bool direct;
  @override
  State<_ConversationPage> createState() => _ConversationState();
}

class _ConversationState extends _LiveState<_ConversationPage> {
  @override
  AuthSession get session => widget.session;
  final message = TextEditingController();
  final conversationScroll = ScrollController();
  int newMessages = 0;
  List<WorkspaceRecord> messages = [];
  final Map<String, String> reactions = {};
  WorkstationFile? attachment;
  WorkspaceRecord uploaded = {};
  double? uploadProgress;
  @override
  Future<void> reload() async {
    if (loading) return;
    final following =
        !conversationScroll.hasClients ||
        conversationScroll.position.maxScrollExtent -
                conversationScroll.offset <
            100;
    final previousIds = messages.map((row) => row['id']).toSet();
    final run = epoch;
    setState(() => loading = true);
    try {
      final next = await widget.repository.messages(
        widget.id,
        direct: widget.direct,
      );
      if (!mounted || run != epoch) return;
      final confirmed = widget.repository.takeConfirmedMessage(
        widget.id,
        direct: widget.direct,
      );
      final sameDraft =
          confirmed != null &&
          (message.text.trim() == confirmed['message'] ||
              (message.text.trim().isEmpty &&
                  attachment?.name == confirmed['message'])) &&
          uploaded['attachment_url'] == confirmed['attachment_url'];
      final oldFile = sameDraft ? attachment : null;
      setState(() {
        messages = next;
        if (!following) {
          newMessages += next
              .where((row) => !previousIds.contains(row['id']))
              .length;
        }
        error = null;
        if (sameDraft) {
          message.clear();
          attachment = null;
          uploaded = {};
          uploadProgress = null;
        }
      });
      if (following)
        WidgetsBinding.instance.addPostFrameCallback((_) => jumpToLatest());
      if (oldFile != null) await WorkstationFileTransfer.release(oldFile);
    } catch (err) {
      if (mounted && run == epoch) {
        setState(() {
          error = _failure(err);
          if (err is HttpError && err.status == 403) messages = [];
        });
      }
    } finally {
      if (mounted && run == epoch) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    message.dispose();
    conversationScroll.dispose();
    if (attachment != null) {
      unawaited(WorkstationFileTransfer.release(attachment!));
    }
    super.dispose();
  }

  void jumpToLatest() {
    if (!mounted || !conversationScroll.hasClients) return;
    if (newMessages > 0) setState(() => newMessages = 0);
    conversationScroll.jumpTo(conversationScroll.position.maxScrollExtent);
  }

  Future<void> chooseFile() async {
    try {
      final file = await WorkstationFileTransfer.pick(mediaOnly: false);
      if (!mounted) {
        if (file != null) await WorkstationFileTransfer.release(file);
        return;
      }
      if (file == null) return;
      if (file.size > 50 * 1024 * 1024) {
        await WorkstationFileTransfer.release(file);
        if (mounted) {
          setState(() => error = 'Attachments must be no larger than 50 MB.');
        }
        return;
      }
      final old = attachment;
      setState(() {
        attachment = file;
        uploaded = {};
      });
      if (old != null) await WorkstationFileTransfer.release(old);
    } catch (err) {
      if (mounted) setState(() => error = _failure(err));
    }
  }

  Future<void> send() async {
    if (saving ||
        loading ||
        (message.text.trim().isEmpty && attachment == null)) {
      return;
    }
    final draft = message.text;
    await act(() async {
      if (attachment != null && uploaded.isEmpty) {
        uploaded = await WorkstationFileTransfer(session).upload(
          '/api/v1/chat/upload',
          attachment!,
          mediaOnly: false,
          onProgress: (value) {
            if (mounted) setState(() => uploadProgress = value);
          },
        );
      }
      await widget.repository.send(
        widget.id,
        draft,
        direct: widget.direct,
        attachment: uploaded,
      );
      if (!mounted) return;
      message.clear();
      final old = attachment;
      setState(() {
        attachment = null;
        uploaded = {};
        uploadProgress = null;
      });
      if (old != null) await WorkstationFileTransfer.release(old);
    }, '');
  }

  Future<void> actions(WorkspaceRecord row) async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy message'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            for (final emoji in ['👍', '❤️', '✅'])
              ListTile(
                title: Text('React $emoji · this view only'),
                onTap: () => Navigator.pop(context, emoji),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selection == null) return;
    if (selection == 'copy') {
      await Clipboard.setData(
        ClipboardData(text: workspaceText(row['message'])),
      );
    } else {
      setState(() => reactions[workspaceText(row['id'])] = selection);
    }
  }

  Widget _messageTile(WorkspaceRecord row, int index) {
    final sender = workspaceText(row['sender_name'], 'Workspace member');
    final own = row['sender_id'] == session.current?.user.id;
    final date = DateTime.tryParse(workspaceText(row['created_at']))?.toLocal();
    final previous = index > 0 ? messages[index - 1] : null;
    final previousDate = DateTime.tryParse(
      workspaceText(previous?['created_at']),
    )?.toLocal();
    final sameDay =
        date != null &&
        previousDate != null &&
        date.year == previousDate.year &&
        date.month == previousDate.month &&
        date.day == previousDate.day;
    final grouped =
        sameDay &&
        previous?['sender_id'] == row['sender_id'] &&
        date.difference(previousDate).inMinutes.abs() < 5;
    final time = date == null
        ? ''
        : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (date != null && !sameDay)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              children: [
                Expanded(child: Divider(color: context.creo.appLine)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                Expanded(child: Divider(color: context.creo.appLine)),
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.only(top: grouped ? 2 : 14, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                child: grouped
                    ? null
                    : CircleAvatar(
                        radius: 18,
                        backgroundColor: context.creo.accent.withValues(
                          alpha: own ? .24 : .12,
                        ),
                        foregroundColor: context.creo.accent,
                        child: Text(
                          sender.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!grouped)
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            sender,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: own
                                  ? context.creo.accent
                                  : context.creo.appInk,
                            ),
                          ),
                          if (own)
                            Text(
                              'you',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          Text(
                            time,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    const SizedBox(height: 3),
                    SelectableText(
                      workspaceText(row['message']),
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                    if (row['attachment_url'] is String)
                      OutlinedButton.icon(
                        onPressed: () => _openAttachment(row),
                        icon: const Icon(Icons.insert_drive_file_outlined),
                        label: Text(
                          workspaceText(
                            row['attachment_name'],
                            'Open attachment',
                          ),
                        ),
                      ),
                    if (reactions.containsKey(row['id']))
                      Text(reactions[row['id']]!),
                  ],
                ),
              ),
              SizedBox(
                width: 40,
                child: IconButton(
                  tooltip: 'Message actions',
                  icon: Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: context.creo.appMist,
                  ),
                  onPressed: () => actions(row),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openAttachment(WorkspaceRecord row) async {
    final uri = session.repository.resolveMediaUri(
      row['attachment_url'] as String,
    );
    if (uri == null) {
      setState(() => error = 'This attachment link is unavailable.');
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        setState(() => error = 'Unable to open the attachment.');
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to open the attachment.');
    }
  }

  @override
  Widget build(BuildContext context) => frame(
    widget.direct ? widget.title : '# ${widget.title}',
    [
      if (messages.isEmpty && !loading && error == null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(
                widget.direct ? Icons.forum_outlined : Icons.tag_rounded,
                size: 40,
                color: context.creo.accent,
              ),
              const SizedBox(height: 16),
              Text(
                'Start the conversation',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Send a message or share a file with your team.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      for (var index = 0; index < messages.length; index++)
        _messageTile(messages[index], index),
      if (messages.length >= 200)
        const Text(
          'Showing the history returned by the server (up to 200 messages).',
        ),
    ],
    scrollController: conversationScroll,
    bottom: SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          8 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (newMessages > 0)
              TextButton.icon(
                onPressed: jumpToLatest,
                icon: const Icon(Icons.arrow_downward),
                label: Text('$newMessages new messages · Jump to latest'),
              ),
            if (attachment != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(attachment!.name),
                subtitle: Text(
                  uploadProgress == null
                      ? 'Ready to attach'
                      : 'Uploading ${(uploadProgress! * 100).round()}%',
                ),
                trailing: IconButton(
                  tooltip: 'Remove attachment',
                  onPressed: saving
                      ? null
                      : () async {
                          final old = attachment!;
                          setState(() {
                            attachment = null;
                            uploaded = {};
                          });
                          await WorkstationFileTransfer.release(old);
                        },
                  icon: const Icon(Icons.close),
                ),
              ),
            TextField(
              controller: message,
              enabled: !saving,
              minLines: 1,
              maxLines: 4,
              maxLength: 10000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Message',
                counterText: '',
                filled: true,
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                IconButton(
                  tooltip: 'Attach file',
                  onPressed: saving ? null : chooseFile,
                  icon: const Icon(Icons.attach_file),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Insert emoji',
                  enabled: !saving,
                  popUpAnimationStyle: MediaQuery.disableAnimationsOf(context)
                      ? AnimationStyle.noAnimation
                      : null,
                  onSelected: (value) {
                    message.text += value;
                    message.selection = TextSelection.collapsed(
                      offset: message.text.length,
                    );
                  },
                  itemBuilder: (_) => [
                    for (final value in ['👍', '❤️', '✅', '🎉'])
                      PopupMenuItem(value: value, child: Text(value)),
                  ],
                  icon: const Icon(Icons.emoji_emotions_outlined),
                ),
                FilledButton.icon(
                  onPressed: saving || loading ? null : send,
                  icon: const Icon(Icons.send),
                  label: Text(saving ? 'Sending…' : 'Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

const _statuses = [
  'pending_approval',
  'needs_schedule',
  'scheduled',
  'processing',
  'published',
  'failed',
  'paused',
  'uncertain',
  'canceled',
];
String _label(String value) => value.replaceAll('_', ' ');

class WorkstationPublishingPage extends StatefulWidget {
  const WorkstationPublishingPage({super.key, required this.session});
  final AuthSession session;
  @override
  State<WorkstationPublishingPage> createState() => _PublishingState();
}

class _PublishingState extends _LiveState<WorkstationPublishingPage> {
  @override
  AuthSession get session => widget.session;
  List<WorkspaceRecord> jobs = [];
  List<WorkspaceRecord> clients = [];
  bool clientsLoaded = false;
  String? clientError;
  String? planningSummary;
  String status = '', client = '';
  int offset = 0;
  @override
  Future<void> reload() async {
    if (loading) return;
    final run = epoch;
    setState(() => loading = true);
    try {
      final next = await repository.jobs(
        offset: offset,
        status: status,
        clientId: client,
      );
      if (!clientsLoaded) {
        try {
          final roster = await repository.publishingClients();
          if (!mounted || run != epoch) return;
          clients = roster;
          clientError = null;
        } catch (err) {
          clientError = 'Client filter unavailable: ${_failure(err)}';
        }
        clientsLoaded = true;
      }
      if (!mounted || run != epoch) return;
      setState(() {
        jobs = next;
        error = null;
      });
    } catch (err) {
      if (mounted && run == epoch) {
        setState(() {
          error = _failure(err);
          if (err is HttpError && err.status == 403) jobs = [];
        });
      }
    } finally {
      if (mounted && run == epoch) setState(() => loading = false);
    }
  }

  void change(VoidCallback update) {
    if (loading || saving) return;
    setState(update);
    unawaited(reload());
  }

  @override
  Widget build(BuildContext context) => frame('Instagram publishing', [
    const Text(
      'Only client-approved media and captions can publish. Editorial dates and publishing times are separate.',
    ),
    const SizedBox(height: 16),
    DropdownButtonFormField<String>(
      value: status,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Publishing status'),
      items: [
        const DropdownMenuItem(value: '', child: Text('All statuses')),
        for (final value in _statuses)
          DropdownMenuItem(value: value, child: Text(_label(value))),
      ],
      onChanged: loading || saving
          ? null
          : (value) => change(() {
              status = value ?? '';
              offset = 0;
            }),
    ),
    const SizedBox(height: 16),
    if (clientError != null)
      TextButton(
        onPressed: loading
            ? null
            : () {
                clientsLoaded = false;
                unawaited(reload());
              },
        child: Text('$clientError Retry filter'),
      ),
    if (clients.isNotEmpty) ...[
      DropdownButtonFormField<String>(
        value: client,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Client'),
        items: [
          const DropdownMenuItem(value: '', child: Text('All clients')),
          for (final row in clients)
            DropdownMenuItem(
              value: workspaceText(row['client_id']),
              child: Text(
                workspaceText(
                  row['company_name'],
                  workspaceText(
                    row['full_name'],
                    workspaceText(row['email'], 'Client'),
                  ),
                ),
              ),
            ),
        ],
        onChanged: loading || saving
            ? null
            : (value) => change(() {
                client = value ?? '';
                offset = 0;
              }),
      ),
      const SizedBox(height: 16),
    ],
    if ({'admin', 'super_admin', 'team_lead'}.contains(repository.role))
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: OutlinedButton.icon(
          onPressed: saving || loading
              ? null
              : () => act(
                  () async {
                    setState(() => planningSummary = null);
                    final summary = await repository.planCalendar();
                    if (mounted) {
                      setState(
                        () => planningSummary =
                            '${summary['planned']} calendar posts planned. ${summary['skipped']} skipped. Review captions before client approval.',
                      );
                    }
                  },
                  'Calendar planning finished. Review captions before client approval.',
                ),
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('Plan posts from calendars'),
        ),
      ),
    if (jobs.isEmpty && !loading && error == null)
      const Text('No publishing jobs match this view.'),
    if (planningSummary != null)
      Semantics(liveRegion: true, child: Text(planningSummary!)),
    for (final job in jobs)
      card(
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(workspaceText(job['title'], 'Instagram post')),
          subtitle: Text(
            '${workspaceText(job['client_name'])}\n${_label(workspaceText(job['status']))}\n${workspaceText(job['scheduled_at'], 'No publishing time')}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _PublishingDetail(
                session: session,
                id: workspaceText(job['deliverable_id']),
              ),
            ),
          ),
        ),
      ),
    Wrap(
      spacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
          onPressed: offset == 0 || loading || saving
              ? null
              : () => change(() => offset -= 100),
          child: const Text('Previous'),
        ),
        Text('Page ${offset ~/ 100 + 1}'),
        OutlinedButton(
          onPressed: jobs.length < 100 || loading || saving
              ? null
              : () => change(() => offset += 100),
          child: const Text('Next'),
        ),
      ],
    ),
  ]);
}

class _PublishingDetail extends StatefulWidget {
  const _PublishingDetail({required this.session, required this.id});
  final AuthSession session;
  final String id;
  @override
  State<_PublishingDetail> createState() => _PublishingDetailState();
}

class _PublishingDetailState extends _LiveState<_PublishingDetail> {
  @override
  AuthSession get session => widget.session;
  WorkspaceRecord? detail;
  List<WorkspaceRecord>? history;
  bool historyOpen = false, historyLoading = false;
  @override
  Future<void> reload() async {
    if (loading) return;
    final run = epoch;
    setState(() => loading = true);
    try {
      final next = await repository.publishingDetails(widget.id);
      if (!mounted || run != epoch) return;
      setState(() {
        detail = next;
        error = null;
      });
    } catch (err) {
      if (mounted && run == epoch) {
        setState(() {
          error = _failure(err);
          if (err is HttpError && err.status == 403) detail = null;
        });
      }
    } finally {
      if (mounted && run == epoch) setState(() => loading = false);
    }
  }

  Future<void> loadHistory() async {
    if (historyLoading) return;
    setState(() {
      historyOpen = !historyOpen;
    });
    if (!historyOpen) return;
    setState(() => historyLoading = true);
    try {
      final rows = await repository.publishingHistory(widget.id);
      if (mounted) setState(() => history = rows);
    } catch (err) {
      if (mounted) setState(() => error = _failure(err));
    } finally {
      if (mounted) setState(() => historyLoading = false);
    }
  }

  Future<void> action(String value) async {
    if (saving || loading) return;
    if ({'cancel', 'pause', 'publish_now'}.contains(value)) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            value == 'publish_now'
                ? 'Post to Instagram now?'
                : '${_label(value)} publication?',
          ),
          content: Text(
            value == 'publish_now'
                ? 'This posts the approved version immediately. It cannot be undone from Creo.'
                : 'The approved deliverable remains available in Creo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (!mounted || accepted != true) return;
    }
    await act(() async {
      await repository.publishingAction(widget.id, value);
    }, 'Publishing request accepted. Check the updated status.');
  }

  @override
  Widget build(BuildContext context) {
    final data = detail;
    final job = data?['job'] is WorkspaceRecord
        ? data!['job'] as WorkspaceRecord
        : <String, dynamic>{};
    final status = workspaceText(job['status']);
    final frozen = {'processing', 'uncertain', 'published'}.contains(status);
    final admin = {'admin', 'super_admin'}.contains(repository.role);
    final lead = admin || repository.role == 'team_lead';
    final manage = data?['can_manage'] == true;
    final calendar = data?['calendar_publish_at'] ?? job['calendar_publish_at'];
    Widget button(String text, String value) => OutlinedButton(
      onPressed: saving || loading ? null : () => action(value),
      child: Text(text),
    );
    return frame('Publishing details', [
      if (data != null) ...[
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _label(
                  status.isEmpty
                      ? workspaceText(data['approval_status'])
                      : status,
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                '${workspaceText(data['account'], 'No Instagram account')} · ${workspaceText(data['connection_status'], 'disconnected')}',
              ),
              const SizedBox(height: 12),
              Text(
                'Publishing: ${workspaceText(job['scheduled_at'], 'Not scheduled')}\nTimezone: ${workspaceText(job['timezone'], workspaceText(data['timezone'], 'Asia/Kolkata'))}\nCalendar slot: ${calendar ?? 'Not booked'}',
              ),
              const SizedBox(height: 12),
              SelectableText(workspaceText(job['caption'], 'No caption')),
              Text(
                '${workspaceText(job['media_type'])} · Version ${job['version'] ?? '—'}',
              ),
              if (data['publishing_enabled'] == false)
                const Text(
                  'Automatic publishing is unavailable. An administrator must check the configuration.',
                ),
              if (job['last_error'] != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    workspaceText(job['last_error']),
                    style: TextStyle(color: context.creo.error),
                  ),
                ),
              if (job['permalink'] is String)
                TextButton(
                  onPressed: () async {
                    final uri = session.repository.resolveMediaUri(
                      job['permalink'] as String,
                    );
                    if (uri != null) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: const Text('View published content'),
                ),
            ],
          ),
        ),
        if (manage)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!frozen)
                OutlinedButton(
                  onPressed: saving || loading ? null : edit,
                  child: const Text('Custom time & caption'),
                ),
              if (!frozen && calendar != null)
                job.isEmpty
                    ? OutlinedButton(
                        onPressed: saving || loading
                            ? null
                            : () => act(
                                () async {
                                  await repository.schedule(
                                    widget.id,
                                    caption: workspaceText(job['caption']),
                                    mediaType: workspaceText(
                                      job['media_type'],
                                      data['file_type']?.toString().startsWith(
                                                'video/',
                                              ) ==
                                              true
                                          ? 'REELS'
                                          : 'IMAGE',
                                    ),
                                  );
                                },
                                'Auto-post armed for the content calendar slot.',
                              ),
                        child: const Text('Arm from calendar'),
                      )
                    : button('Use calendar time', 'use_calendar'),
              if (lead &&
                  job['approved'] == true &&
                  data['connection_status'] == 'connected' &&
                  !frozen &&
                  status != 'canceled')
                button('Post now', 'publish_now'),
              if (status == 'paused') button('Resume schedule', 'resume'),
              if (lead &&
                  {'scheduled', 'processing'}.contains(status) &&
                  job['stage'] != 'submitting')
                button('Pause', 'pause'),
              if (admin && status == 'failed') button('Retry job', 'retry'),
              if (admin && status == 'uncertain')
                button('Check provider result', 'reconcile'),
              if (job.isNotEmpty && !frozen && status != 'canceled')
                button('Cancel auto-post', 'cancel'),
            ],
          ),
        TextButton.icon(
          onPressed: historyLoading ? null : loadHistory,
          icon: const Icon(Icons.history),
          label: Text(
            historyOpen ? 'Hide publishing history' : 'Publishing history',
          ),
        ),
        if (historyOpen) ...[
          if (historyLoading) const Text('Loading history…'),
          if (history?.isEmpty == true)
            const Text('No publishing history yet.'),
          for (final item in history ?? <WorkspaceRecord>[])
            card(
              Text(
                '${_label(workspaceText(item['action']))}\n${workspaceText(item['at'])}',
              ),
            ),
        ],
      ],
    ]);
  }

  Future<void> edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ScheduleForm(
          session: session,
          repository: repository,
          id: widget.id,
          detail: detail!,
        ),
      ),
    );
    if (mounted && changed == true) unawaited(reload());
  }
}

class _ScheduleForm extends StatefulWidget {
  const _ScheduleForm({
    required this.session,
    required this.repository,
    required this.id,
    required this.detail,
  });
  final AuthSession session;
  final WorkstationHubRepository repository;
  final String id;
  final WorkspaceRecord detail;
  @override
  State<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<_ScheduleForm> {
  final form = GlobalKey<FormState>();
  late final caption = TextEditingController(
    text: workspaceText((widget.detail['job'] as Map?)?['caption']),
  );
  late final zone = TextEditingController(
    text: workspaceText(
      (widget.detail['job'] as Map?)?['timezone'],
      workspaceText(widget.detail['timezone'], 'Asia/Kolkata'),
    ),
  );
  final time = TextEditingController();
  late String media = workspaceText(
    (widget.detail['job'] as Map?)?['media_type'],
    widget.detail['file_type']?.toString().startsWith('video/') == true
        ? 'REELS'
        : 'IMAGE',
  );
  int? fold;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    caption.dispose();
    zone.dispose();
    time.dispose();
    super.dispose();
  }

  Future<void> save({bool calendar = false}) async {
    if (busy || (!calendar && !form.currentState!.validate())) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.schedule(
        widget.id,
        localTime: calendar ? null : time.text.trim(),
        timezone: zone.text,
        caption: caption.text,
        mediaType: media,
        fold: fold,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (err) {
      if (mounted) setState(() => error = _failure(err));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pickLocalTime() async {
    final existing = DateTime.tryParse(time.text) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: existing,
      firstDate: DateTime(1970),
      lastDate: DateTime(9999, 12, 31),
    );
    if (!mounted || date == null) return;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(existing),
    );
    if (!mounted || selected == null) return;
    String two(int value) => value.toString().padLeft(2, '0');
    time.text =
        '${date.year}-${two(date.month)}-${two(date.day)}T${two(selected.hour)}:${two(selected.minute)}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Publishing schedule')),
    body: SafeArea(
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const Text(
              'Changes to media or caption require client approval again. Use the named IANA timezone; the server resolves daylight-saving ambiguity.',
            ),
            const SizedBox(height: 20),
            if (error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  style: TextStyle(color: context.creo.error),
                ),
              ),
            TextFormField(
              controller: time,
              enabled: !busy,
              decoration: InputDecoration(
                labelText: 'Local date & time',
                hintText: '2030-11-09T14:30',
                suffixIcon: IconButton(
                  tooltip: 'Choose local date and time',
                  onPressed: busy ? null : pickLocalTime,
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ),
              validator: (value) =>
                  DateTime.tryParse(value?.trim() ?? '') == null
                  ? 'Enter local date and time, for example 2030-11-09T14:30.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: zone,
              enabled: !busy,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Timezone (IANA)'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a timezone.'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: media,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Format'),
              items: [
                for (final value in ['IMAGE', 'REELS', 'STORIES'])
                  DropdownMenuItem(value: value, child: Text(value)),
              ],
              onChanged: busy
                  ? null
                  : (value) => setState(() {
                      media = value!;
                      if (media == 'STORIES') caption.clear();
                    }),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: fold ?? -1,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Repeated daylight-saving time',
              ),
              items: const [
                DropdownMenuItem(value: -1, child: Text('Ask if ambiguous')),
                DropdownMenuItem(value: 0, child: Text('First occurrence')),
                DropdownMenuItem(value: 1, child: Text('Second occurrence')),
              ],
              onChanged: busy
                  ? null
                  : (value) =>
                        setState(() => fold = value == -1 ? null : value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: caption,
              enabled: !busy && media != 'STORIES',
              maxLength: 2200,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Caption'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Validating and saving…' : 'Save custom time'),
            ),
            if (widget.detail['calendar_publish_at'] != null)
              OutlinedButton(
                onPressed: busy ? null : () => save(calendar: true),
                child: const Text('Use calendar time'),
              ),
          ],
        ),
      ),
    ),
  );
}

Widget _sectionHeading(BuildContext context, String title, int count) =>
    Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: context.creo.appMist,
            ),
          ),
          Text(
            '$count',
            style: TextStyle(fontSize: 11, color: context.creo.appMist),
          ),
        ],
      ),
    );
