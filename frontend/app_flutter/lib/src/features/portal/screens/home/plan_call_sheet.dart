import 'package:flutter/material.dart';
import '../../../../core/auth_repository.dart';
import '../../../../core/auth_session.dart';
import '../../core/theme/app_colors.dart';

const _topics = [
  'Custom Pricing / Retainer Discount',
  'Custom Quotas (More Reels / Stories)',
  'Multi-Brand / Enterprise Volume Package',
  'Plan Consultation (Starter vs Accelerator vs Enterprise)',
];
const _times = [
  'Immediate / ASAP (Next 30 mins)',
  'Today Afternoon (2:00 PM - 5:00 PM)',
  'Today Evening (6:00 PM - 9:00 PM)',
  'Tomorrow Morning (10:00 AM - 1:00 PM)',
];

/// Opens the "Book a plan consultation call" sheet (POST /api/v1/portal/book-call).
Future<void> showPlanCallSheet(BuildContext context, AuthSession session) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PlanCallSheet(session: session),
  );
}

class _PlanCallSheet extends StatefulWidget {
  const _PlanCallSheet({required this.session});
  final AuthSession session;

  @override
  State<_PlanCallSheet> createState() => _PlanCallSheetState();
}

class _PlanCallSheetState extends State<_PlanCallSheet> {
  final _offer = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  String _topic = _topics.first;
  String _time = _times.first;
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _offer.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phone.text.trim();
    if (phone.isEmpty) {
      setState(
        () => _error =
            'Please provide a contact phone number so your agency team can reach you.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.request(
        'POST',
        '/api/v1/portal/book-call',
        body: {
          'target_topic': _topic,
          if (_offer.text.trim().isNotEmpty) 'proposed_offer': _offer.text.trim(),
          'phone_number': phone,
          'preferred_time': _time,
          if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        },
      );
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is HttpError
              ? error.message
              : 'Failed to submit call request.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mist = isDark ? CreoColors.mist : CreoColors.lightMist;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: _sent
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, size: 48, color: CreoColors.emerald),
                  const SizedBox(height: 12),
                  Text('Call request sent', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Your agency team has received the plan consultation request. '
                    'They will contact you at ${_phone.text.trim()} ($_time).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: mist),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Book a Plan Consultation Call',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Discuss custom video deliverables or negotiate a tailored plan with our executive team.',
                    style: TextStyle(fontSize: 12, color: mist),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: CreoColors.terracotta)),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _topic,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'What would you like to negotiate?',
                    ),
                    items: [
                      for (final t in _topics)
                        DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: _busy ? null : (v) => setState(() => _topic = v ?? _topic),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _offer,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Proposed scope / budget (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('plan-call-phone'),
                    controller: _phone,
                    enabled: !_busy,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Contact phone'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _time,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Preferred time'),
                    items: [
                      for (final t in _times)
                        DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: _busy ? null : (v) => setState(() => _time = v ?? _time),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notes,
                    enabled: !_busy,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(_busy ? 'Sending…' : 'Send call request'),
                  ),
                ],
              ),
      ),
    );
  }
}
