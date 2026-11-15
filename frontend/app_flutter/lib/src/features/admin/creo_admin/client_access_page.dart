import 'package:flutter/material.dart';
import '../../../core/auth_repository.dart';
import 'admin_api_service.dart';

class ClientAccessPage extends StatefulWidget {
  const ClientAccessPage({
    super.key,
    required this.api,
    required this.clientId,
    required this.email,
  });
  final AdminApiService api;
  final String clientId, email;
  @override
  State<ClientAccessPage> createState() => _ClientAccessState();
}

class _ClientAccessState extends State<ClientAccessPage> {
  final _form = GlobalKey<FormState>();
  final _notes = TextEditingController();
  Map<String, dynamic>? _client;
  List<Map<String, dynamic>> _plans = [];
  String? _plan, _method, _error, _notice;
  bool _loading = true, _busy = false, _confirmed = false;
  String message(Object error) => error is HttpError
      ? error.message
      : error.toString().replaceFirst('Bad state: ', '');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (client, plans) = await widget.api.clientAccess(widget.clientId);
      if (!mounted) return;
      setState(() {
        _client = client;
        _plans = plans;
        if (!plans.any((row) => row['id'].toString() == _plan)) _plan = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _activate() async {
    if (_busy || _loading || _confirmed || !_form.currentState!.validate())
      return;
    final plan = _plans.firstWhere((row) => row['id'].toString() == _plan);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm client activation'),
        content: SingleChildScrollView(
          child: Text(
            'Activate ${widget.email} on ${plan['display_name'] ?? plan['name']}? '
            'The backend creates a 30-day manual subscription, records the plan amount of ₹${plan['monthly_price']}, '
            'and sends a payment-approved email. '
            '${_method == 'test_access' ? 'The notes will explicitly say test access and no payment received. ' : ''}'
            'The client must still complete brand onboarding before entering the portal.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm activation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final notes = _method == 'test_access'
          ? 'TEST ACCESS - NO PAYMENT RECEIVED. ${_notes.text.trim()}'
          : _notes.text.trim();
      await widget.api.activateClient(widget.clientId, _plan!, _method!, notes);
      if (!mounted) return;
      setState(() {
        _confirmed = true;
        _notice =
            'Activation confirmed by the server. Ask the client to refresh saved progress or sign in again, then complete brand onboarding.';
      });
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscription = _client?['subscription'];
    final active =
        subscription is Map &&
        {'active', 'trialing'}.contains(subscription['status']);
    final complete = _client?['onboarding_completed_at'] != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client activation'),
        actions: [
          IconButton(
            tooltip: 'Refresh client status',
            onPressed: _busy || _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.email,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _busy || _loading ? null : _load,
                  child: const Text('Retry status refresh'),
                ),
              ],
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Semantics(liveRegion: true, child: Text(_notice!)),
                ),
              if (_client != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    active ? 'Subscription active' : 'Subscription pending',
                  ),
                  subtitle: Text(
                    active
                        ? '${subscription['plan_display_name'] ?? subscription['plan_name'] ?? 'Assigned plan'}'
                        : 'Choose a plan and activation method below.',
                  ),
                ),
                Text(
                  complete
                      ? 'Onboarding is recorded as complete. The client app rechecks access with the backend after sign-in or refresh.'
                      : 'Remaining steps include the brand questionnaire, Brand DNA, team allocation, content calendar and final setup. Activation alone does not open the portal.',
                ),
                const SizedBox(height: 24),
                if (!active && !_confirmed) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey(_plan),
                    initialValue: _plan,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Server plan'),
                    items: [
                      for (final row in _plans)
                        DropdownMenuItem(
                          value: row['id'].toString(),
                          child: Text(
                            '${row['display_name'] ?? row['name']} · ₹${row['monthly_price']}',
                          ),
                        ),
                    ],
                    onChanged: _busy || _loading
                        ? null
                        : (value) => setState(() => _plan = value),
                    validator: (value) =>
                        value == null ? 'Choose a plan.' : null,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: _method,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Activation method',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'upi',
                        child: Text('Verified offline UPI payment'),
                      ),
                      DropdownMenuItem(
                        value: 'bank_transfer',
                        child: Text('Verified bank transfer'),
                      ),
                      DropdownMenuItem(
                        value: 'cash',
                        child: Text('Verified cash payment'),
                      ),
                      DropdownMenuItem(
                        value: 'test_access',
                        child: Text('Test access — no payment received'),
                      ),
                    ],
                    onChanged: _busy || _loading
                        ? null
                        : (value) => setState(() => _method = value),
                    validator: (value) =>
                        value == null ? 'Choose an activation method.' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _notes,
                    enabled: !_busy && !_loading,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Admin notes or payment reference',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Add a payment reference or test-access reason.'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'This action records the selected plan amount and sends the backend’s payment-approved email, including for test access.',
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy || _loading || _plans.isEmpty
                        ? null
                        : _activate,
                    child: Text(_busy ? 'Activating…' : 'Review activation'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
