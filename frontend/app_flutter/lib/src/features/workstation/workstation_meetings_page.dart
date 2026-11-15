import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../core/auth_session.dart';

/// Begin invalidation synchronously before waiting for either secure-store task.
/// The shared preference queue prevents a pending save from outliving cleanup.
Future<void> logoutWorkstationSession(
  AuthSession session, {
  WorkstationMeetingStore? store,
}) async {
  final accountId = session.current?.user.id;
  await session.logout(
    clearAccountData: accountId == null
        ? null
        : () => (store ?? WorkstationMeetingStore.shared).clear(accountId),
  );
}

/// Explicit dependency injection for account preferences. Development fixtures
/// and widget tests can use an in-memory store without changing release logic.
class WorkstationMeetingScope extends InheritedWidget {
  const WorkstationMeetingScope({
    super.key,
    required this.store,
    required super.child,
  });
  final WorkstationMeetingStore store;
  static WorkstationMeetingStore? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<WorkstationMeetingScope>()
      ?.store;
  @override
  bool updateShouldNotify(WorkstationMeetingScope oldWidget) =>
      oldWidget.store != store;
}

class WorkstationMeetingConfig {
  const WorkstationMeetingConfig({
    this.code = '',
    this.meetUrl = 'https://meet.google.com',
    this.zoomUrl = 'https://zoom.us/join',
  });
  final String code, meetUrl, zoomUrl;

  static Uri? safeLink(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  }

  factory WorkstationMeetingConfig.normalized(
    String code,
    String meetUrl,
    String zoomUrl,
  ) {
    final trimmedCode = code.trim();
    final meet = meetUrl.trim().isNotEmpty
        ? meetUrl.trim()
        : trimmedCode.isEmpty
        ? 'https://meet.google.com'
        : Uri.https('meet.google.com', trimmedCode).toString();
    final zoom = zoomUrl.trim().isEmpty
        ? 'https://zoom.us/join'
        : zoomUrl.trim();
    if (safeLink(meet) == null || safeLink(zoom) == null) {
      throw const FormatException(
        'Enter valid HTTPS meeting links without account credentials.',
      );
    }
    return WorkstationMeetingConfig(
      code: trimmedCode,
      meetUrl: meet,
      zoomUrl: zoom,
    );
  }

  factory WorkstationMeetingConfig.fromJson(Map<String, dynamic> json) {
    if (json['code'] is! String ||
        json['meet_url'] is! String ||
        json['zoom_url'] is! String) {
      throw const FormatException('Meeting preferences could not be read.');
    }
    // The source explicitly discards its old synthetic standup URL/code.
    return WorkstationMeetingConfig.normalized(
      json['code'] == 'creo-standup-sync' ? '' : json['code'],
      (json['meet_url'] as String).contains('creo-standup-sync')
          ? ''
          : json['meet_url'],
      json['zoom_url'],
    );
  }

  Map<String, String> toJson() => {
    'code': code,
    'meet_url': meetUrl,
    'zoom_url': zoomUrl,
  };
}

typedef ReadMeetingPreference = Future<String?> Function(String key);
typedef WriteMeetingPreference =
    Future<void> Function(String key, String? value);

/// Account-scoped encrypted meeting/review preferences. A shared queue orders saves and logout
/// cleanup across page instances; no account data is included in widget fixtures.
class WorkstationMeetingStore {
  WorkstationMeetingStore({
    ReadMeetingPreference? read,
    WriteMeetingPreference? write,
  }) : _read = read ?? ((key) => _storage.read(key: key)),
       _write =
           write ??
           ((key, value) => value == null
               ? _storage.delete(key: key)
               : _storage.write(key: key, value: value));
  static const _storage = FlutterSecureStorage();
  static final shared = WorkstationMeetingStore();
  static final _queues = <String, Future<void>>{};
  final ReadMeetingPreference _read;
  final WriteMeetingPreference _write;
  static String keyFor(String accountId) =>
      'creo_meetings_v1_${Uri.encodeComponent(accountId)}';

  Future<T> _ordered<T>(String accountId, Future<T> Function() operation) {
    final previous = _queues[accountId] ?? Future<void>.value();
    final pending = previous.then((_) => operation());
    final tail = pending.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _queues[accountId] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_queues[accountId], tail)) _queues.remove(accountId);
      }),
    );
    return pending;
  }

  Future<WorkstationMeetingConfig> load(String accountId) =>
      _ordered(accountId, () async {
        final record = await _read(keyFor(accountId));
        return record == null
            ? const WorkstationMeetingConfig()
            : WorkstationMeetingConfig.fromJson(
                jsonDecode(record) as Map<String, dynamic>,
              );
      });

  Future<void> save(
    String accountId,
    WorkstationMeetingConfig config, {
    bool Function()? isCurrent,
  }) => _ordered(accountId, () async {
    if (isCurrent?.call() == false) {
      throw StateError(
        'This meeting configuration belongs to an ended session.',
      );
    }
    await _write(keyFor(accountId), jsonEncode(config.toJson()));
    if (isCurrent?.call() == false) {
      await _write(keyFor(accountId), null);
      throw StateError(
        'This meeting configuration belongs to an ended session.',
      );
    }
  });

  Future<void> clear(String accountId) => _ordered(accountId, () async {
    Object? failure;
    for (final key in [keyFor(accountId), _feedbackKey(accountId)]) {
      try {
        await _write(key, null);
      } catch (error) {
        failure = error;
      }
    }
    if (failure != null) throw failure;
  });
  String _feedbackKey(String accountId) =>
      'creo_review_feedback_v1_${Uri.encodeComponent(accountId)}';
  Future<Set<String>> loadFeedback(String accountId) =>
      _ordered(accountId, () async {
        final record = await _read(_feedbackKey(accountId));
        if (record == null) return <String>{};
        final decoded = jsonDecode(record);
        if (decoded is! List || decoded.any((value) => value is! String)) {
          throw const FormatException(
            'Saved feedback preferences could not be read.',
          );
        }
        return decoded.cast<String>().toSet();
      });
  Future<void> saveFeedback(
    String accountId,
    Set<String> dismissed, {
    required bool Function() isCurrent,
  }) => _ordered(accountId, () async {
    if (!isCurrent()) return;
    await _write(_feedbackKey(accountId), jsonEncode(dismissed.toList()));
    if (!isCurrent()) await _write(_feedbackKey(accountId), null);
  });
  static Future<void> clearForAccount(String accountId) =>
      shared.clear(accountId);
}

class WorkstationMeetingsPage extends StatefulWidget {
  const WorkstationMeetingsPage({
    super.key,
    required this.session,
    this.store,
    this.openLink,
  });
  final AuthSession session;
  final WorkstationMeetingStore? store;
  final Future<bool> Function(Uri)? openLink;
  @override
  State<WorkstationMeetingsPage> createState() => _MeetingState();
}

class _MeetingState extends State<WorkstationMeetingsPage> {
  late final _store = widget.store ?? WorkstationMeetingStore.shared;
  late final _account = widget.session.current?.user.id;
  final _code = TextEditingController(),
      _meet = TextEditingController(),
      _zoom = TextEditingController();
  WorkstationMeetingConfig _config = const WorkstationMeetingConfig();
  bool _loading = false, _saving = false, _editing = false, _copied = false;
  String _platform = 'meet';
  String? _error, _notice;
  Timer? _copyTimer;

  bool get _active =>
      mounted &&
      widget.session.phase == SessionPhase.authenticated &&
      widget.session.current?.user.id == _account &&
      widget.session.current?.user.mustResetPassword != true &&
      ['editor', 'designer'].contains(widget.session.current?.user.role);
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    _code.dispose();
    _meet.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _fill() {
    _code.text = _config.code;
    _meet.text = _config.meetUrl;
    _zoom.text = _config.zoomUrl;
  }

  Future<void> _load() async {
    if (_loading) return;
    if (!_active || _account == null) {
      setState(() => _error = 'An editor or designer session is required.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await _store.load(_account);
      if (!_active) return;
      setState(() {
        _config = value;
        _fill();
      });
    } catch (_) {
      if (_active) {
        setState(
          () => _error =
              'Meeting settings could not be read. Retry or reset the saved settings.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save({bool reset = false}) async {
    if (_saving || !_active || _account == null) return;
    WorkstationMeetingConfig next;
    try {
      next = reset
          ? const WorkstationMeetingConfig()
          : WorkstationMeetingConfig.normalized(
              _code.text,
              _meet.text,
              _zoom.text,
            );
    } on FormatException catch (error) {
      setState(() => _error = error.message);
      return;
    }
    final generation = widget.session.beginReadGeneration;
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      await _store.save(
        _account,
        next,
        isCurrent: () =>
            widget.session.phase == SessionPhase.authenticated &&
            widget.session.current?.user.id == _account &&
            widget.session.isCurrent(generation),
      );
      if (!_active) return;
      setState(() {
        _config = next;
        _fill();
        _editing = false;
        _notice = reset
            ? 'Meeting settings restored to defaults.'
            : 'Meeting configuration updated successfully.';
      });
    } catch (_) {
      if (_active) {
        setState(
          () => _error =
              'Meeting settings could not be saved. Your changes are still here; please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copy() async {
    if (!_active || _config.code.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: _config.code));
      if (!_active) return;
      _copyTimer?.cancel();
      setState(() {
        _copied = true;
        _notice = 'Meet code copied to clipboard.';
      });
      _copyTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copied = false);
      });
    } catch (_) {
      if (_active) {
        setState(
          () => _error =
              'Unable to copy the meet code. Select the code to copy it manually.',
        );
      }
    }
  }

  Future<void> _open() async {
    if (!_active) return;
    final uri = WorkstationMeetingConfig.safeLink(
      _platform == 'meet' ? _config.meetUrl : _config.zoomUrl,
    );
    if (uri == null) {
      setState(() => _error = 'Enter a valid HTTPS meeting link.');
      return;
    }
    try {
      final opened =
          await (widget.openLink?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!_active) return;
      setState(() {
        _error = opened ? null : 'No application could open this meeting link.';
        _notice = opened
            ? 'Opened ${_platform == 'meet' ? 'Google Meet' : 'Zoom'}.'
            : null;
      });
    } catch (_) {
      if (_active) {
        setState(
          () => _error = 'Unable to open the meeting link. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pod standup')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Meet with your pod',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Join through Google Meet or Zoom. These links are saved securely for your account on this device.',
                ),
                const SizedBox(height: 20),
                if (_loading)
                  Semantics(
                    liveRegion: true,
                    label: 'Loading saved meeting settings',
                    child: MediaQuery.disableAnimationsOf(context)
                        ? const Text('Loading…')
                        : const LinearProgressIndicator(),
                  ),
                if (_error != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(color: context.creo.error),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _load,
                    child: const Text('Retry reading settings'),
                  ),
                  TextButton(
                    onPressed: _saving ? null : () => _save(reset: true),
                    child: const Text('Reset saved settings'),
                  ),
                ],
                if (_notice != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_notice!),
                    ),
                  ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Google Meet'),
                      selected: _platform == 'meet',
                      onSelected: (_) => setState(() => _platform = 'meet'),
                    ),
                    ChoiceChip(
                      label: const Text('Zoom'),
                      selected: _platform == 'zoom',
                      onSelected: (_) => setState(() => _platform = 'zoom'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (!_editing)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.creo.appSurface,
                      border: Border.all(color: context.creo.appLine),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _platform == 'meet'
                              ? 'Google Meet direct redirect'
                              : 'Zoom join portal',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        SelectableText(
                          _platform == 'meet'
                              ? _config.meetUrl
                              : _config.zoomUrl,
                        ),
                        if (_platform == 'meet' && _config.code.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text('Meet code'),
                          SelectableText(_config.code),
                          OutlinedButton.icon(
                            onPressed: _loading ? null : _copy,
                            icon: Icon(
                              _copied ? Icons.check : Icons.copy_outlined,
                            ),
                            label: Text(_copied ? 'Copied' : 'Copy meet code'),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loading || !_active ? null : _open,
                          icon: const Icon(Icons.open_in_new),
                          label: Text(
                            _platform == 'meet'
                                ? 'Redirect to Google Meet'
                                : 'Redirect to Zoom',
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_editing) ...[
                  TextField(
                    controller: _code,
                    enabled: !_saving,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Google Meet code',
                    ),
                    onChanged: (value) {
                      if (value.trim().isNotEmpty) {
                        _meet.text = Uri.https(
                          'meet.google.com',
                          value.trim(),
                        ).toString();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _meet,
                    enabled: !_saving,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Google Meet URL',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _zoom,
                    enabled: !_saving,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'Zoom URL'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Save meeting settings'),
                  ),
                  OutlinedButton(
                    onPressed: _saving ? null : () => _save(reset: true),
                    child: const Text('Reset defaults'),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _loading || _saving || !_active
                      ? null
                      : () => setState(() {
                          _editing = !_editing;
                          _fill();
                          _notice = null;
                          _error = null;
                        }),
                  child: Text(
                    _editing
                        ? 'Close settings'
                        : 'Configure meeting link / code',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Opening a provider does not confirm that a meeting is active or scheduled. Your browser’s existing saved links are not transferred automatically.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
