import 'package:flutter/material.dart';
import '../../../core/auth_session.dart';
import '../../../core/auth_repository.dart';

class AdminSalesRepository {
  AdminSalesRepository(this.session) : generation = session.beginReadGeneration;
  final AuthSession session;
  final int generation;
  static final _journals = Expando<Map<int, Set<String>>>();
  Set<String> get pending =>
      (_journals[session] ??= {}).putIfAbsent(generation, () => {});
  List<Map<String, dynamic>> rows = [];
  void check() {
    if (!session.isCurrent(generation) ||
        session.phase != SessionPhase.authenticated ||
        !{'admin', 'super_admin'}.contains(session.current?.user.role)) {
      throw const HttpError(
        status: 403,
        code: 'FORBIDDEN',
        message: 'This admin session has ended.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> load() async {
    check();
    final response = await session.request('GET', '/api/v1/bde/leads');
    check();
    return rows = (response['items'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> write(
    String key,
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    check();
    if (!pending.add(key)) {
      throw const HttpError(
        status: 409,
        code: 'WRITE_UNCONFIRMED',
        message:
            'This request is pending or unconfirmed. Check its server state before retrying.',
      );
    }
    try {
      final result = await session.request(method, path, body: body);
      check();
      if (result['id'] is! String) {
        throw const FormatException('Unconfirmed response');
      }
      pending.remove(key);
    } catch (error) {
      if (error is HttpError && error.status >= 400 && error.status < 500) {
        pending.remove(key);
        rethrow;
      }
      throw const HttpError(
        status: 0,
        code: 'WRITE_UNCONFIRMED',
        message:
            'The server result is unconfirmed. Refresh and verify it before submitting again.',
      );
    }
  }

  Future<void> create(Map<String, dynamic> fields) => write(
    'create:${fields['email']}${fields['company_name']}',
    'POST',
    '/api/v1/bde/leads',
    fields,
  );
  Future<void> update(Map<String, dynamic> row, String status) async {
    check();
    if (!rows.any((item) => identical(item, row)) ||
        row['id'] is! String ||
        !stages.contains(status)) {
      throw const HttpError(
        status: 403,
        code: 'STALE_LEAD',
        message: 'Refresh and choose a current lead.',
      );
    }
    await write(
      'lead:${row['id']}',
      'PATCH',
      '/api/v1/bde/leads/${Uri.encodeComponent(row['id'])}',
      {'status': status},
    );
  }

  static const stages = [
    'new',
    'contacted',
    'meeting_scheduled',
    'proposal_sent',
    'negotiation',
    'converted',
    'lost',
  ];
}

class AdminSalesWorkspace extends StatefulWidget {
  const AdminSalesWorkspace({super.key, required this.session});
  final AuthSession session;
  @override
  State<AdminSalesWorkspace> createState() => _SalesWorkspaceState();
}

class _SalesWorkspaceState extends State<AdminSalesWorkspace> {
  late final repo = AdminSalesRepository(widget.session);
  late Future<List<Map<String, dynamic>>> future = repo.load();
  bool busy = false;
  String? error;
  String query = '';
  void reload() => setState(() => future = repo.load());
  Future<void> create() async {
    final name = TextEditingController(),
        company = TextEditingController(),
        email = TextEditingController(),
        phone = TextEditingController();
    final form = GlobalKey<FormState>();
    bool saving = false;
    String? failure;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, update) => AlertDialog(
          title: const Text('New lead'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    enabled: !saving,
                    decoration: const InputDecoration(
                      labelText: 'Contact name',
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Enter a contact name.'
                        : null,
                  ),
                  TextFormField(
                    controller: company,
                    enabled: !saving,
                    decoration: const InputDecoration(labelText: 'Company'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Enter a company.' : null,
                  ),
                  TextFormField(
                    controller: email,
                    enabled: !saving,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                    ),
                    validator: (v) =>
                        (v ?? '').isNotEmpty &&
                            !RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(v!.trim())
                        ? 'Enter a valid email.'
                        : null,
                  ),
                  TextFormField(
                    controller: phone,
                    enabled: !saving,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                    ),
                  ),
                  if (failure != null)
                    Semantics(liveRegion: true, child: Text(failure!)),
                  if (saving) const LinearProgressIndicator(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      update(() => saving = true);
                      try {
                        await repo.create({
                          'name': name.text.trim(),
                          'company_name': company.text.trim(),
                          'email': email.text.trim().isEmpty
                              ? null
                              : email.text.trim(),
                          'phone': phone.text.trim().isEmpty
                              ? null
                              : phone.text.trim(),
                          'estimated_deal_value': 0,
                          'priority': 'warm',
                          'status': 'new',
                        });
                        if (dialog.mounted) Navigator.pop(dialog);
                        if (mounted) reload();
                      } catch (e) {
                        if (dialog.mounted) {
                          update(
                            () => failure = e is HttpError
                                ? e.message
                                : 'The lead could not be confirmed.',
                          );
                        }
                      } finally {
                        if (dialog.mounted) update(() => saving = false);
                      }
                    },
              child: const Text('Create lead'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    company.dispose();
    email.dispose();
    phone.dispose();
  }

  Future<void> move(Map<String, dynamic> row, String status) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.update(row, status);
      if (mounted) reload();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is HttpError
              ? e.message
              : 'The update could not be confirmed.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Sales pipeline'),
      actions: [
        IconButton(
          tooltip: 'Refresh pipeline',
          onPressed: busy ? null : reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: busy ? null : create,
      icon: const Icon(Icons.add),
      label: const Text('New lead'),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null) Semantics(liveRegion: true, child: Text(error!)),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search leads',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v.toLowerCase()),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'The sales pipeline could not be loaded. Refresh to retry.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = snapshot.data!
                  .where(
                    (row) => '${row['name']} ${row['company_name']}'
                        .toLowerCase()
                        .contains(query),
                  )
                  .toList();
              if (rows.isEmpty) return const Text('No matching leads.');
              return Column(
                children: [
                  for (final row in rows)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${row['company_name'] ?? ''}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text('${row['name'] ?? ''}'),
                            if (row['email'] != null) Text('${row['email']}'),
                            if (row['phone'] != null) Text('${row['phone']}'),
                            Text('Priority: ${row['priority'] ?? ''}'),
                            Text(
                              'Estimated value: ${row['estimated_deal_value'] ?? 0}',
                            ),
                            DropdownButtonFormField<String>(
                              key: ValueKey('${row['id']}-${row['status']}'),
                              initialValue:
                                  AdminSalesRepository.stages.contains(
                                    row['status'],
                                  )
                                  ? row['status']
                                  : null,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Stage',
                              ),
                              items: [
                                for (final stage in AdminSalesRepository.stages)
                                  DropdownMenuItem(
                                    value: stage,
                                    child: Text(stage.replaceAll('_', ' ')),
                                  ),
                              ],
                              onChanged: busy
                                  ? null
                                  : (value) {
                                      if (value != null) move(row, value);
                                    },
                            ),
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
  );
}
