import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth_session.dart';
import '../../core/auth_repository.dart';
import 'onboarding_repository.dart';
import 'onboarding_terms.dart';
import 'questionnaire_fields.dart';
import 'questionnaire_options.dart';
import 'questionnaire_validation.dart';

class ClientOnboardingPage extends StatefulWidget {
  const ClientOnboardingPage({
    super.key,
    required this.session,
    this.onCompleted,
    this.onEmailVerified,
  });
  final AuthSession session;
  final VoidCallback? onCompleted;
  final VoidCallback? onEmailVerified;
  @override
  State<ClientOnboardingPage> createState() => _OnboardingState();
}

class _OnboardingState extends State<ClientOnboardingPage> {
  late final _repo = ClientOnboardingRepository(widget.session);
  Map<String, dynamic>? _status, _questionnaire, _brand;
  final Map<String, Map<String, dynamic>> _edits = {};
  String _section = 'a';
  int _formVersion = 0;
  String? _error, _notice;
  bool _busy = false, _accepted = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    final generation = widget.session.beginReadGeneration;
    setState(() => _busy = true);
    try {
      final status = await _repo.read('status');
      Map<String, dynamic>? questionnaire, brand;
      if (status['stage'] is! int) throw const FormatException('Missing stage');
      if ((status['stage'] as int) >= 3) {
        questionnaire = await _repo.read('questionnaire');
        try {
          brand = await _repo.read('brand-dna/status');
        } catch (_) {
          brand = {'status': 'unavailable'};
        }
      }
      if (!mounted || !widget.session.isCurrent(generation)) return;
      setState(() {
        _status = status;
        _questionnaire = questionnaire;
        _brand = brand;
        _error = null;
        final resume =
            status['resume_section'] ?? questionnaire?['last_active_section'];
        if (resume is String && questionnaireFields.containsKey(resume)) {
          _section = resume;
        }
      });
      if ((status['stage'] as int) >= 1) widget.onEmailVerified?.call();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) => error is HttpError
      ? error.message
      : 'Onboarding could not be loaded. Your draft is retained.';

  Future<void> _openWebPayment() async {
    try {
      final opened = await launchUrl(
        Uri.https('creo.yogalakshmibaskar20.workers.dev', '/onboarding', {
          'step': '3',
        }),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('Browser unavailable');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open checkout. Please try again.');
      }
    }
  }

  Future<void> _perform(Future<Object?> Function() action) async {
    if (_busy) return;
    final generation = widget.session.beginReadGeneration;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
      if (mounted && widget.session.isCurrent(generation)) {
        setState(() => _notice = 'Saved on the server.');
        setState(() => _busy = false);
        await _load();
      }
    } catch (error) {
      if (mounted && widget.session.isCurrent(generation)) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic> _original(String section) => Map<String, dynamic>.from(
    _questionnaire?['section_$section'] as Map? ?? {},
  );
  Widget _field(
    String key,
    Object shape,
    dynamic value,
    ValueChanged<dynamic> changed,
  ) {
    final label = key.replaceAll('_', ' ');
    final options = questionnaireOptions[key];
    if (options != null && shape == 'list') {
      final selected = value is List ? List<String>.from(value) : <String>[];
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            Wrap(
              spacing: 8,
              children: [
                for (final option in options.entries)
                  FilterChip(
                    label: Text(option.value),
                    selected: selected.contains(option.key),
                    onSelected: _busy
                        ? null
                        : (checked) {
                            checked
                                ? selected.add(option.key)
                                : selected.remove(option.key);
                            changed(selected);
                          },
                  ),
              ],
            ),
          ],
        ),
      );
    }
    if (options != null && shape == 'text') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<String>(
          key: ValueKey('$_section-$_formVersion-$key'),
          initialValue: value is String && options.containsKey(value)
              ? value
              : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final option in options.entries)
              DropdownMenuItem(value: option.key, child: Text(option.value)),
          ],
          onChanged: _busy ? null : changed,
        ),
      );
    }
    if (shape is Map) {
      final rows = value is List
          ? value.map((row) => Map<String, dynamic>.from(row as Map)).toList()
          : <Map<String, dynamic>>[];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          for (var index = 0; index < rows.length; index++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (final entry in shape.entries)
                      _field(
                        '${entry.key}',
                        entry.value,
                        rows[index][entry.key],
                        (next) {
                          rows[index][entry.key] = next;
                          changed(rows);
                        },
                      ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              _formVersion++;
                              rows.removeAt(index);
                              changed(rows);
                            },
                      child: Text('Remove $label'),
                    ),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () {
                    _formVersion++;
                    rows.add({});
                    changed(rows);
                  },
            icon: const Icon(Icons.add),
            label: Text('Add $label'),
          ),
        ],
      );
    }
    final list = shape == 'list';
    final number = shape == 'number';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: ValueKey('$_section-$_formVersion-$key'),
        initialValue: list
            ? (value is List ? value.join(', ') : '')
            : '${value ?? ''}',
        enabled: !_busy,
        maxLines: number ? 1 : null,
        keyboardType: number ? TextInputType.number : TextInputType.multiline,
        decoration: InputDecoration(
          labelText: label,
          helperText: list
              ? 'Separate entries with commas'
              : number
              ? 'Choose a value from 0 to 10'
              : null,
        ),
        onChanged: (text) {
          if (number) {
            final next = int.tryParse(text);
            if (next != null && next >= 0 && next <= 10) changed(next);
          } else {
            changed(
              list
                  ? text
                        .split(',')
                        .map((entry) => entry.trim())
                        .where((entry) => entry.isNotEmpty)
                        .toList()
                  : text,
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final next = status?['next_required_stage'];
    final answers = {..._original(_section), ...?_edits[_section]};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your Creo workspace'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => widget.session.logout(),
            icon: const Icon(Icons.logout),
          ),
          IconButton(
            tooltip: 'Refresh saved progress',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_notice != null) Text(_notice!),
            if (status != null) ...[
              Text(
                '${status['stage_name']}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                'Next: ${{'verify': 'Verify email', 'terms': 'Review agreement', 'payment': 'Confirm payment', 'questionnaire': 'Tell us about your brand', 'brand_dna': 'Prepare Brand DNA', 'pod': 'Allocate creative team', 'calendar': 'Prepare content calendar', 'complete': 'Complete setup', 'portal': 'Open workspace'}[next] ?? 'Refresh progress'}',
              ),
              const SizedBox(height: 20),
              if (next == 'verify')
                const Text(
                  'Verify your email using the verification message, then refresh saved progress.',
                ),
              if (next == 'terms') ...[
                SelectableText(onboardingTerms),
                CheckboxListTile(
                  value: _accepted,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _accepted = value == true),
                  title: const Text(
                    'I have read and agree to the Master Service Agreement v1.0',
                  ),
                ),
                FilledButton(
                  onPressed: _busy || !_accepted
                      ? null
                      : () => _perform(
                          () => _repo.write(
                            'terms',
                            body: {'terms_version': 'v1.0'},
                          ),
                        ),
                  child: const Text('Accept agreement'),
                ),
              ],
              if (next == 'payment') ...[
                const Text(
                  'Payment setup must be completed through the existing web checkout or verified offline payment process. Mobile Razorpay checkout is not available. Refresh after payment is confirmed.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _openWebPayment,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Continue payment on website'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sign in on the website to complete checkout. Return here and refresh saved progress after payment.',
                ),
              ],
              if (_questionnaire != null) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey(_section),
                  initialValue: _section,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Questionnaire section',
                  ),
                  items: [
                    for (final entry in questionnaireNames.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          '${entry.key.toUpperCase()}. ${entry.value}',
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _section = value!),
                ),
                const SizedBox(height: 20),
                if (_section == 'a')
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload brand logo'),
                    onPressed: _busy
                        ? null
                        : () => _perform(() async {
                            final url = await _repo.uploadLogo();
                            if (url != null && mounted) {
                              setState(
                                () => (_edits['a'] ??= {})['brand_logo_url'] =
                                    url,
                              );
                            }
                            return null;
                          }),
                  ),
                if (_section == 'a' &&
                    '${answers['brand_logo_url'] ?? ''}'.isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove brand logo'),
                    onPressed: _busy
                        ? null
                        : () => _perform(() async {
                            await _repo.removeLogo();
                            if (mounted) {
                              setState(() {
                                final original = _original('a')
                                  ..remove('brand_logo_url')
                                  ..remove('brand_logo_filename');
                                _questionnaire!['section_a'] = original;
                                _edits['a']?.remove('brand_logo_url');
                                _edits['a']?.remove('brand_logo_filename');
                                _formVersion++;
                              });
                            }
                            return null;
                          }),
                  ),
                for (final entry in questionnaireFields[_section]!.entries)
                  _field(
                    entry.key,
                    entry.value,
                    answers[entry.key],
                    (value) => setState(
                      () => (_edits[_section] ??= {})[entry.key] = value,
                    ),
                  ),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _perform(
                          () => _repo.save(
                            _section,
                            _original(_section),
                            _edits[_section] ?? {},
                          ),
                        ),
                  child: const Text('Save section'),
                ),
                const SizedBox(height: 20),
                Text('Brand DNA: ${_brand?['status'] ?? 'Not yet available'}'),
                if (_brand?['summary_line'] is String)
                  Text(_brand!['summary_line'] as String),
                if (_questionnaire?['core_completed'] == true)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _perform(() => _repo.write('brand')),
                    child: const Text('Generate Brand DNA'),
                  ),
                if (_questionnaire?['core_completed'] == true &&
                    {'brand_dna', 'pod', 'calendar', 'complete'}.contains(next))
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _perform(() async {
                            final problem = questionnaireProblem({
                              for (final section in 'abcdefg'.split(''))
                                section: {
                                  ..._original(section),
                                  ...?_edits[section],
                                },
                            });
                            if (problem != null) {
                              throw HttpError(
                                status: 400,
                                code: 'QUESTIONNAIRE_INCOMPLETE',
                                message: problem,
                              );
                            }
                            if (_edits.isNotEmpty) {
                              await _repo.write(
                                'questionnaire/sections',
                                body: {
                                  'sections': {
                                    for (final section in _edits.keys)
                                      section: {
                                        ..._original(section),
                                        ..._edits[section]!,
                                      },
                                  },
                                  'active_section': _section,
                                },
                              );
                            }
                            final result = await _repo.write('complete');
                            if (result['status'] != 'completed') {
                              throw const FormatException(
                                'Completion not confirmed',
                              );
                            }
                            final confirmed = await _repo.read('status');
                            if (confirmed['is_complete'] != true) {
                              throw const FormatException(
                                'Progress not complete',
                              );
                            }
                            if (mounted) {
                              setState(() => _status = confirmed);
                              widget.onCompleted?.call();
                            }
                            return null;
                          }),
                    child: const Text('Complete setup and allocate team'),
                  ),
              ],
              if (status['is_complete'] == true)
                FilledButton(
                  onPressed: widget.onCompleted,
                  child: const Text('Open workspace'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
