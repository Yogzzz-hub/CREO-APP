import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_appearance.dart';
import '../../core/app_theme.dart';
import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';
import '../../core/headings.dart';
import 'workstation_account_repository.dart';
import 'workstation_data.dart';

String _message(Object error) => error is HttpError
    ? error.message
    : error is ArgumentError
    ? error.message.toString()
    : 'The server response could not be read. Please retry.';

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.creo.appSurface,
      border: Border.all(color: context.creo.appLine),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Heading(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.error = false});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: error ? context.creo.error : context.creo.accent,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: error ? context.creo.error : context.creo.appInk,
        ),
      ),
    ),
  );
}

class _Frame extends StatelessWidget {
  const _Frame({
    required this.title,
    required this.children,
    required this.refresh,
    this.loading = false,
  });
  final String title;
  final List<Widget> children;
  final Future<void> Function() refresh;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    final items = [
      if (loading)
        Semantics(
          liveRegion: true,
          label: 'Loading account information',
          child: MediaQuery.disableAnimationsOf(context)
              ? const Text('Loading…')
              : const LinearProgressIndicator(),
        ),
      if (loading) const SizedBox(height: 16),
      ...children,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Heading(title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
          if (CreoAppearanceScope.maybeOf(context) != null)
            const CreoThemeToggle(),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refresh,
          // The last panel stretches to the bottom edge on short pages.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: FillScroll(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                keyboardDismiss: true,
                fill: items.lastIndexWhere((w) => w is _Panel),
                children: items,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WorkstationSchedulePage extends StatefulWidget {
  const WorkstationSchedulePage({
    super.key,
    required this.session,
    required this.freelancer,
  });
  final AuthSession session;
  final bool freelancer;
  @override
  State<WorkstationSchedulePage> createState() => _ScheduleState();
}

class _ScheduleState extends State<WorkstationSchedulePage> {
  late final repo = WorkstationAccountRepository(
    widget.session,
    freelancer: widget.freelancer,
  );
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  String _start = '', _end = '', _category = 'Planned Holiday / Break';
  List<WorkspaceLeave>? _leaves;
  WorkstationData? _pod;
  String? _error, _notice, _podError;
  bool _loading = false, _busy = false;
  int _epoch = 0;
  final _categories = const [
    'Planned Holiday / Break',
    'Holiday / Vacation',
    'Personal Commitment',
    'Studio Maintenance',
    'Medical / Rest',
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _epoch++;
    _reason.dispose();
    super.dispose();
  }

  bool _current(int epoch) =>
      mounted &&
      epoch == _epoch &&
      widget.session.phase == SessionPhase.authenticated;

  Future<void> _load() async {
    if (_loading || _busy) return;
    final epoch = ++_epoch;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final leaves = await repo.leaves();
      if (!_current(epoch)) return;
      setState(() => _leaves = leaves);
    } catch (error) {
      if (_current(epoch)) {
        setState(() {
          _error = _message(error);
          _leaves = null;
        });
      }
    }
    if (!widget.freelancer && _current(epoch)) {
      try {
        final pod = await repo.pod();
        if (_current(epoch)) {
          setState(() {
            _pod = pod;
            _podError = null;
          });
        }
      } catch (error) {
        if (_current(epoch)) {
          setState(() {
            _pod = null;
            _podError = _message(error);
          });
        }
      }
    }
    if (_current(epoch)) setState(() => _loading = false);
  }

  Future<void> _date(bool first) async {
    final now = DateTime.now().toUtc();
    final today = DateTime(now.year, now.month, now.day);
    final min = !first && _start.isNotEmpty ? DateTime.parse(_start) : today;
    final selected = await showDatePicker(
      context: context,
      initialDate:
          (DateTime.tryParse(first ? _start : _end)?.isBefore(min) ?? true)
          ? min
          : DateTime.parse(first ? _start : _end),
      firstDate: min,
      lastDate: DateTime(today.year + 10, 12, 31),
    );
    if (selected == null || !mounted) return;
    final value =
        '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
    setState(() {
      if (first) {
        _start = value;
        if (_end.isNotEmpty && _end.compareTo(_start) < 0) _end = '';
      } else {
        _end = value;
      }
    });
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final validation = WorkstationAccountRepository.validateLeave(
      _start,
      _end,
      _reason.text,
      DateTime.now(),
    );
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    FocusScope.of(context).unfocus();
    final epoch = _epoch;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    var committed = false;
    try {
      await repo.requestLeave(_start, _end, _reason.text, category: _category);
      if (!_current(epoch)) return;
      committed = true;
      setState(() {
        _notice = widget.freelancer
            ? 'Unavailability sent to project leads.'
            : 'Leave request submitted for approval.';
        _reason.clear();
        if (widget.freelancer) {
          _start = '';
          _end = '';
        }
      });
    } catch (error) {
      if (_current(epoch)) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (committed && _current(epoch)) await _load();
  }

  Future<void> _cancel(WorkspaceLeave leave) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: Text('${leave.start} to ${leave.end}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _busy) return;
    final epoch = _epoch;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    var committed = false;
    try {
      await repo.cancelLeave(leave);
      committed = true;
      if (_current(epoch)) setState(() => _notice = 'Request cancelled.');
    } catch (error) {
      if (_current(epoch)) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (committed && _current(epoch)) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final leaves = _leaves ?? const <WorkspaceLeave>[];
    final pending = leaves.where((l) => l.status == 'pending').toList();
    final now = DateTime.now();
    final approved = leaves
        .where(
          (l) => l.status == 'approved' && !DateTime.parse(l.end).isBefore(now),
        )
        .toList();
    final assignments = _pod == null
        ? const <WorkstationTask>[]
        : [
                ..._pod!.backlog,
                ..._pod!.inProduction,
                ..._pod!.inQa,
                ..._pod!.completed,
              ]
              .where(
                (task) =>
                    task.assignedTo == widget.session.current?.user.id &&
                    !['completed', 'ready_to_publish'].contains(task.status),
              )
              .toList();
    return _Frame(
      title: widget.freelancer ? 'Time off & blackout' : 'Schedule & leave',
      loading: _loading,
      refresh: _load,
      children: [
        if (_notice != null) _Notice(_notice!),
        if (_error != null) ...[
          _Notice(_error!, error: true),
          OutlinedButton(
            onPressed: _loading ? null : _load,
            child: const Text('Retry'),
          ),
          const SizedBox(height: 16),
        ],
        if (widget.freelancer && _leaves != null) ...[
          _Panel(
            title: 'Availability overview',
            children: [
              Text(
                '${approved.length} scheduled · ${approved.fold<int>(0, (n, l) => n + l.days)} approved days',
              ),
              Text(
                '${pending.length} under review · ${pending.fold<int>(0, (n, l) => n + l.days)} requested days',
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        _Panel(
          title: widget.freelancer
              ? 'Schedule unavailability'
              : 'Request time off',
          children: [
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.freelancer) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      itemHeight: null,
                      decoration: const InputDecoration(
                        labelText: 'Blackout reason',
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _category = v!),
                    ),
                    const SizedBox(height: 16),
                  ],
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _date(true),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      'Start date: ${_start.isEmpty ? 'Choose date' : _start}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _date(false),
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      'End date: ${_end.isEmpty ? 'Choose date' : _end}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reason,
                    enabled: !_busy,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: widget.freelancer ? null : 2000,
                    decoration: const InputDecoration(
                      labelText: 'Reason and handover notes',
                    ),
                    validator: (value) => value?.trim().isEmpty != false
                        ? 'Enter a reason.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy || _loading ? null : _submit,
                    child: Text(_busy ? 'Submitting…' : 'Submit for approval'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'My requests',
          children: [
            if (_leaves != null && leaves.isEmpty)
              const Text('No leave requests yet.'),
            for (final leave in leaves)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${leave.start} → ${leave.end}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${leave.status.replaceAll('_', ' ')} · ${leave.days} days',
                    ),
                    const SizedBox(height: 8),
                    Text(leave.reason),
                    Text('Reviewer: ${leave.reviewer}'),
                    if (leave.canCancel)
                      OutlinedButton(
                        onPressed: _busy ? null : () => _cancel(leave),
                        child: const Text('Cancel request'),
                      ),
                    const Divider(),
                  ],
                ),
              ),
          ],
        ),
        if (!widget.freelancer) ...[
          const SizedBox(height: 16),
          _Panel(
            title: 'Upcoming assignments',
            children: [
              if (_podError != null) _Notice(_podError!, error: true),
              if (_pod != null && assignments.isEmpty)
                const Text('No upcoming assignments.'),
              if (_pod != null)
                for (final task in assignments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${task.client} · ${task.format.replaceAll('_', ' ')}',
                    ),
                    subtitle: Text(
                      '${task.status.replaceAll('_', ' ')}\nDue: ${task.due?.toLocal().toString().split(' ').first ?? 'Unscheduled'}',
                    ),
                  ),
            ],
          ),
        ],
      ],
    );
  }
}

class WorkstationSettingsPage extends StatefulWidget {
  const WorkstationSettingsPage({
    super.key,
    required this.session,
    required this.freelancer,
  });
  final AuthSession session;
  final bool freelancer;
  @override
  State<WorkstationSettingsPage> createState() => _SettingsState();
}

class _SettingsState extends State<WorkstationSettingsPage> {
  late final repo = WorkstationAccountRepository(
    widget.session,
    freelancer: widget.freelancer,
  );
  final _name = TextEditingController(), _phone = TextEditingController();
  final _form = GlobalKey<FormState>();
  WorkspaceProfile? _profile;
  WorkstationData? _pod;
  String? _error, _notice, _podError;
  bool _loading = false, _saving = false;
  int _epoch = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _epoch++;
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool _current(int epoch) =>
      mounted &&
      epoch == _epoch &&
      widget.session.phase == SessionPhase.authenticated;
  Future<void> _load() async {
    if (_loading || _saving) return;
    final epoch = ++_epoch;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await repo.profile();
      if (!_current(epoch)) return;
      setState(() {
        _profile = profile;
        _name.text = profile.name;
        _phone.text = profile.phone;
      });
    } catch (error) {
      if (_current(epoch)) {
        setState(() {
          _error = _message(error);
          _profile = null;
        });
      }
    }
    if (!widget.freelancer && _current(epoch)) {
      try {
        final pod = await repo.pod();
        if (_current(epoch)) {
          setState(() {
            _pod = pod;
            _podError = null;
          });
        }
      } catch (error) {
        if (_current(epoch)) {
          setState(() {
            _pod = null;
            _podError = _message(error);
          });
        }
      }
    }
    if (_current(epoch)) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final epoch = _epoch;
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      final updated = await repo.saveProfile(_name.text, _phone.text);
      if (_current(epoch)) {
        setState(() {
          _profile = updated;
          _name.text = updated.name;
          _phone.text = updated.phone;
          _notice = 'Personal details updated successfully.';
        });
      }
    } catch (error) {
      if (_current(epoch)) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _meeting() async {
    try {
      if (!await launchUrl(
        Uri.parse('https://meet.google.com'),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('Unavailable');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to open Google Meet on this device.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => _Frame(
    title: widget.freelancer ? 'Profile & settings' : 'Preferences',
    refresh: _load,
    loading: _loading,
    children: [
      if (_notice != null) _Notice(_notice!),
      if (_error != null) ...[
        _Notice(_error!, error: true),
        OutlinedButton(
          onPressed: _loading ? null : _load,
          child: const Text('Retry'),
        ),
        const SizedBox(height: 16),
      ],
      _Panel(
        title: 'Personal details',
        children: [
          if (_profile != null) ...[
            Text(_profile!.name, style: Theme.of(context).textTheme.titleLarge),
            SelectableText(_profile!.email),
            Text(_profile!.role.replaceAll('_', ' ')),
            const SizedBox(height: 20),
          ],
          Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    enabled: _profile != null && !_saving && !_loading,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    autofillHints: const [AutofillHints.name],
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: (v) => v?.trim().isEmpty != false
                        ? 'Name cannot be empty.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phone,
                    enabled: _profile != null && !_saving && !_loading,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      helperText: 'Optional',
                    ),
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Work email is managed by your organization. Contact support to change it.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _profile == null || _saving || _loading
                        ? null
                        : _save,
                    child: Text(_saving ? 'Saving changes…' : 'Save changes'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (!widget.freelancer)
        _Panel(
          title: 'Your assigned pod',
          children: [
            if (_podError != null) _Notice(_podError!, error: true),
            if (_pod != null) ...[
              Text(
                _pod!.podName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final member in _pod!.members)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(member.name),
                  subtitle: Text(member.role.replaceAll('_', ' ')),
                ),
              if (_pod!.members.isEmpty)
                const Text('No other specialists in this pod.'),
            ],
            const SizedBox(height: 16),
            const Text('Daily standup · Google Meet / Zoom'),
            const Text(
              'The web app’s browser-local custom meeting link is not available on this device.',
            ),
            OutlinedButton.icon(
              onPressed: _meeting,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Google Meet'),
            ),
          ],
        ),
      if (widget.freelancer) ...[
        _Panel(
          title: 'Account security',
          children: [
            const Text(
              'Reset your password or add a password to your Google account using a secure email verification code.',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _profile == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => WorkstationPasswordPage(
                          session: widget.session,
                          email: _profile!.email,
                        ),
                      ),
                    ),
              icon: const Icon(Icons.lock_outline),
              label: const Text('Reset or change password'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _Panel(
          title: 'Payout & workspace terms',
          children: [
            Text('Payout model: 100% milestone-based (INR)'),
            Text('Platform fee deduction: 0% (zero fee direct payout)'),
            Text('Deliverable submissions: direct to Executive Admin'),
          ],
        ),
      ],
    ],
  );
}

/// The source freelancer password modal, adapted into a keyboard-safe page.
/// Session adoption remains exclusively owned by AuthSession.
class WorkstationPasswordPage extends StatefulWidget {
  const WorkstationPasswordPage({
    super.key,
    required this.session,
    required this.email,
  });
  final AuthSession session;
  final String email;
  @override
  State<WorkstationPasswordPage> createState() => _PasswordState();
}

class _PasswordState extends State<WorkstationPasswordPage> {
  final _code = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  String _step = 'email', _token = '';
  String? _error;
  bool _busy = false, _visible = false;
  int _cooldown = 0;
  Timer? _timer;
  late final _userId = widget.session.current?.user.id;
  bool get _active =>
      mounted &&
      widget.session.phase == SessionPhase.authenticated &&
      widget.session.current?.user.id == _userId;
  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_busy || !_active) return;
    if (_step == 'code' && !RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      setState(() => _error = 'Enter the six-digit verification code.');
      return;
    }
    if (_step == 'password') {
      final candidate = _password.text.trim();
      if (candidate.length < 8 ||
          candidate.length > 128 ||
          !RegExp('[a-zA-Z]').hasMatch(candidate) ||
          !RegExp('[0-9]').hasMatch(candidate)) {
        setState(
          () =>
              _error = 'Use 8–128 characters, including a letter and a number.',
        );
        return;
      }
      if (_password.text != _confirm.text) {
        setState(() => _error = 'Passwords do not match.');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_step == 'email') {
        await widget.session.repository.forgotPassword(widget.email);
        if (!_active) return;
        setState(() {
          _step = 'code';
          _cooldown = 60;
        });
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted || _cooldown <= 1) {
            timer.cancel();
            if (mounted) setState(() => _cooldown = 0);
          } else {
            setState(() => _cooldown--);
          }
        });
      } else if (_step == 'code') {
        final response = await widget.session.request(
          'POST',
          '/api/v1/auth/verify-reset-otp',
          body: {'email': widget.email, 'code': _code.text.trim()},
        );
        if (!_active) return;
        if (response['reset_token'] is! String ||
            (response['reset_token'] as String).isEmpty) {
          throw const FormatException('Invalid reset token');
        }
        setState(() {
          _token = response['reset_token'];
          _step = 'password';
        });
      } else {
        final attempt = widget.session.beginAttempt();
        final result = await widget.session.repository.resetPassword(
          _token,
          _password.text,
        );
        if (!_active || !widget.session.isCurrent(attempt)) return;
        if (result.user.id != _userId) {
          throw const FormatException('Password response account changed');
        }
        if (await widget.session.adopt(result, attempt) && mounted) {
          setState(() => _step = 'done');
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Heading('Account security')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _step == 'done'
                        ? 'Password saved'
                        : 'Reset or set your password',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 16),
                  SelectableText(widget.email),
                  const SizedBox(height: 20),
                  if (_error != null) _Notice(_error!, error: true),
                  if (_step == 'email')
                    const Text(
                      'We will send a six-digit verification code to your registered email. Google sign-in keeps working.',
                    ),
                  if (_step == 'code') ...[
                    const Text(
                      'Enter the code from your email. It expires in 10 minutes. Check spam if needed.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _code,
                      enabled: !_busy,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Verification code',
                      ),
                      onSubmitted: (_) => _run(),
                    ),
                    TextButton(
                      onPressed: _busy || _cooldown > 0
                          ? null
                          : () {
                              setState(() => _step = 'email');
                              _run();
                            },
                      child: Text(
                        _cooldown > 0
                            ? 'Resend code in ${_cooldown}s'
                            : 'Resend code',
                      ),
                    ),
                  ],
                  if (_step == 'password') ...[
                    const Text(
                      'Choose a password with 8–128 characters, a letter and a number. Other signed-in devices will be signed out.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: !_visible,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        suffixIcon: IconButton(
                          tooltip: _visible ? 'Hide password' : 'Show password',
                          onPressed: () => setState(() => _visible = !_visible),
                          icon: Icon(
                            _visible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirm,
                      enabled: !_busy,
                      obscureText: !_visible,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                      ),
                      onSubmitted: (_) => _run(),
                    ),
                  ],
                  if (_step == 'done')
                    const _Notice(
                      'You can now sign in with your email and password.',
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : _step == 'done'
                        ? () => Navigator.pop(context)
                        : _run,
                    child: Text(
                      _busy
                          ? 'Please wait…'
                          : switch (_step) {
                              'email' => 'Send code',
                              'code' => 'Verify code',
                              'password' => 'Save password',
                              _ => 'Done',
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
