import 'dart:async';
import 'package:flutter/material.dart';

import 'data.dart';
import 'profile.dart';
import 'team.dart';
import 'admin_api_service.dart';
import 'ui.dart';
import '../../workstation/workstation_hub_pages.dart';

class InboxTab extends StatelessWidget {
  const InboxTab({super.key, this.initial = 0});
  final int initial;
  @override
  Widget build(BuildContext context) => TabPage(
    name: 'Inbox',
    initial: initial,
    tabs: ['Chat', 'Support ${openTickets.length}'],
    pages: [_Chat(), _Support()],
  );
}

/// "5 m", "3 h", "2 d"
String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  return d.inMinutes < 60
      ? '${d.inMinutes} m'
      : d.inHours < 24
      ? '${d.inHours} h'
      : '${d.inDays} d';
}

// Shared authenticated channel and direct-message implementation.
class _Chat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final session = currentAdminApi?.session;
    return session == null
        ? const Center(child: Text('Sign in to open workspace chat.'))
        : WorkstationHubPage(session: session);
  }
}

// ---------- Support ----------
S prioStatus(String p) => switch (p) {
  'Urgent' || 'High' => S.bad,
  'Medium' => S.wait,
  _ => S.ok,
};

String get avgFirstReply {
  final waits = [
    for (final t in tickets)
      if (t.replies.isNotEmpty)
        t.replies.first.at.difference(t.opened).inMinutes,
  ];
  return waits.isEmpty
      ? '—'
      : '${waits.reduce((a, b) => a + b) ~/ waits.length} m';
}

void openTicket(BuildContext context, Ticket t) {
  if (t.serverId != null && currentAdminApi != null) {
    unawaited(
      currentAdminApi!.fetchTicketMessages(t.serverId!, t).catchError((_) {}),
    );
  }
  openPage(
    context,
    'Ticket #${t.id}',
    (c) => [
      title(t.subject),
      sub('${t.client} · opened ${ago(t.opened)} ago'),
      const SizedBox(height: 8),
      Status(
        t.closed ? S.ok : prioStatus(t.priority),
        t.closed ? 'Closed' : t.priority,
      ),
      Rows([tile('Assigned to', s: t.agent.isEmpty ? 'Nobody yet' : t.agent)]),
      sec('Replies'),
      if (t.replies.isEmpty)
        empty('No replies yet')
      else
        Rows([
          for (final r in t.replies)
            tile(r.text, s: '${r.from} · ${ago(r.at)} ago'),
        ]),
      actions([
        if (!t.closed)
          small('Reply', () async {
            final v = await formSheet(c, 'Reply to ${t.client}', [
              const F('Message', required: true, lines: 4),
            ], 'Send reply');
            if (v != null && t.serverId != null) {
              try {
                await currentAdminApi?.replyTicket(t.serverId!, v['Message']!);
              } catch (_) {
                if (c.mounted)
                  toast(
                    c,
                    'Could not confirm the reply. Refresh this ticket before retrying.',
                  );
              }
            }
          }, filled: true),
        small(t.closed ? 'Reopen' : 'Close ticket', () async {
          if (t.serverId == null)
            return toast(c, 'This ticket has no server record to update.');
          try {
            await currentAdminApi?.updateTicketStatus(
              t.serverId!,
              t.closed ? 'open' : 'closed',
            );
          } catch (_) {
            if (c.mounted)
              toast(
                c,
                'Could not confirm the status change. Refresh the ticket before retrying.',
              );
          }
        }),
      ]),
    ],
  );
}

class _Support extends StatefulWidget {
  const _Support();
  @override
  State<_Support> createState() => _SupportState();
}

class _SupportState extends State<_Support> {
  int
  state = 0,
  prio = 0; // state: 0 active, 1 closed. prio: 0 all, then priorities[prio - 1]
  String q = '';

  Future<void> newTicket() async {
    toast(
      context,
      'The server has no admin endpoint to open a ticket for another client. Ask the client to open it in their portal.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final list =
        tickets
            .where((t) => t.closed == (state == 1))
            .where((t) => prio == 0 || t.priority == priorities[prio - 1])
            .where((t) => matches(q, [t.subject, t.client, '#${t.id}']))
            .toList()
          ..sort((a, b) => a.opened.compareTo(b.opened));
    return page([
      const SizedBox(height: 4),
      Kv([
        ('Open', '${openTickets.length}'),
        ('Solved today', '$solvedToday'),
        ('First reply', avgFirstReply),
      ]),
      SearchBox(
        'Search ticket number, client, subject',
        (v) => setState(() => q = v),
      ),
      Chips(
        labels: [
          'Active ${openTickets.length}',
          'Closed ${tickets.length - openTickets.length}',
        ],
        selected: state,
        onSelect: (i) => setState(() => state = i),
      ),
      Chips(
        labels: const ['All', ...priorities],
        selected: prio,
        onSelect: (i) => setState(() => prio = i),
      ),
      if (list.isEmpty)
        empty(state == 0 ? 'No open tickets' : 'No closed tickets')
      else
        Rows([
          for (final t in list)
            tile(
              t.subject,
              s: '#${t.id} · ${t.client} · ${t.agent.isEmpty ? 'not assigned' : t.agent} · ${ago(t.opened)}',
              trail: Status(prioStatus(t.priority), t.priority),
              onTap: () => openTicket(context, t),
            ),
        ]),
      mainButton('New ticket', newTicket),
    ]);
  }
}

class Settings extends StatelessWidget {
  const Settings({super.key, this.onSignOut});
  final VoidCallback? onSignOut;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Back', style: inter(16, w: FontWeight.w500)),
      ),
      body: _SettingsBody(onSignOut: onSignOut),
    );
  }
}

class _SettingsBody extends StatefulWidget {
  const _SettingsBody({this.onSignOut});
  final VoidCallback? onSignOut;
  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  @override
  Widget build(BuildContext context) {
    Widget icon(IconData i) => Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: C.raised,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(i, size: 20, color: C.mist2),
    );
    const chev = Icon(Icons.chevron_right);
    return ListenableBuilder(
      listenable: changed,
      builder: (context, _) => page([
        title('Settings'),
        sec('Account'),
        Rows([
          tile(
            'Profile',
            s: me.name,
            lead: icon(Icons.person_outline),
            trail: chev,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    Profile(pushed: true, onSignOut: widget.onSignOut),
              ),
            ),
          ),
          tile(
            'Roles and access',
            s: 'Role catalog and team accounts',
            lead: icon(Icons.shield_outlined),
            trail: chev,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _RolesAccess()),
            ),
          ),
          tile(
            'Notifications',
            s: 'Agency email and WhatsApp settings',
            lead: icon(Icons.notifications_outlined),
            trail: chev,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _NotificationSettings()),
            ),
          ),
          tile(
            'Payments',
            s: 'View agency provider availability',
            lead: icon(Icons.payments_outlined),
            trail: chev,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _PaymentSettings()),
            ),
          ),
        ]),
        sec('Reading and language'),
        Rows([
          tile(
            'Text size',
            s: 'Follows your phone setting',
            lead: icon(Icons.text_fields),
            trail: chev,
            onTap: () => showDialog<void>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Text size'),
                content: const Text(
                  'Creo follows your device text size. Change it in your phone settings under Display or Accessibility.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
          tile(
            'Language',
            s: 'English (only supported language)',
            lead: icon(Icons.language),
            trail: chev,
            onTap: () => toast(
              context,
              'English is currently the only supported language.',
            ),
          ),
        ]),
        if (widget.onSignOut != null) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: C.rose,
                side: BorderSide(color: C.rose.withOpacity(0.5)),
                minimumSize: const Size(48, 52),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onSignOut!();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out of Workspace'),
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              'Sign-in and log out arrive when the app is connected to the Creo server.',
              style: inter(14, c: C.mist),
            ),
          ),
      ]),
    );
  }
}

class _NotificationSettings extends StatefulWidget {
  const _NotificationSettings();
  @override
  State<_NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<_NotificationSettings> {
  bool saving = false;
  Future<void> setValue(String key, bool value) async {
    final api = currentAdminApi;
    if (api == null)
      return toast(
        context,
        'Connect to the Creo account to change this setting.',
      );
    setState(() => saving = true);
    try {
      await api.saveSettings({key: value});
    } catch (_) {
      if (mounted)
        toast(
          context,
          'Could not confirm the save. Refresh settings before retrying.',
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = currentAdminApi;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListenableBuilder(
        listenable: changed,
        builder: (context, _) {
          final value = api?.settings ?? const <String, dynamic>{};
          return page([
            title('Agency notifications'),
            sub('These switches control agency-wide delivery settings.'),
            if (api?.settingsLoaded != true) ...[
              empty('Agency settings have not loaded. Refresh to try again.'),
              mainButton('Refresh settings', () async {
                await api?.fetchSettings();
              }),
            ] else ...[
              SwitchListTile(
                title: const Text('Email notifications'),
                value: value['email_notifications'] == true,
                onChanged: saving
                    ? null
                    : (v) => setValue('email_notifications', v),
              ),
              SwitchListTile(
                title: const Text('WhatsApp notifications'),
                value: value['whatsapp_notifications'] == true,
                onChanged: saving
                    ? null
                    : (v) => setValue('whatsapp_notifications', v),
              ),
            ],
          ]);
        },
      ),
    );
  }
}

class _PaymentSettings extends StatelessWidget {
  const _PaymentSettings();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Payments')),
    body: ListenableBuilder(
      listenable: changed,
      builder: (context, _) {
        final value = currentAdminApi?.settings ?? const <String, dynamic>{};
        String status(String key) => value[key] == true
            ? 'Enabled on the agency account'
            : value[key] == false
            ? 'Disabled on the agency account'
            : 'Not available';
        return page([
          title('Payment providers'),
          sub(
            'This page reports agency configuration. Payment setup and transactions remain in the web admin.',
          ),
          tile(
            'Razorpay',
            s: status('razorpay_enabled'),
            lead: const Icon(Icons.payments_outlined),
          ),
          tile(
            'Stripe',
            s: status('stripe_enabled'),
            lead: const Icon(Icons.credit_card_outlined),
          ),
        ]);
      },
    ),
  );
}

class _RolesAccess extends StatelessWidget {
  const _RolesAccess();
  static const roleLabels = <String, String>{
    'admin': 'Admin',
    'super_admin': 'Super admin',
    'team_lead': 'Team lead',
    'editor': 'Editor',
    'designer': 'Designer',
    'sales': 'Sales',
    'bde': 'BDE',
    'bde_head': 'BDE head',
    'freelancer': 'Freelancer',
    'client': 'Client',
    'investor_relations': 'Investor relations',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Roles and access')),
    body: ListenableBuilder(
      listenable: changed,
      builder: (context, _) {
        final api = currentAdminApi;
        final members = [...?api?.team, ...?api?.sales, ...?api?.freelancers];
        return page([
          title('Role catalog'),
          sub(
            'Accounts are created with server-defined roles. Privileged admin roles cannot be granted from this mobile screen.',
          ),
          Rows([
            for (final e in roleLabels.entries)
              tile(e.value, s: e.key, lead: const Icon(Icons.badge_outlined)),
          ]),
          sec('Accounts'),
          if (members.isEmpty)
            empty(
              'No team accounts loaded yet. Pull to refresh the admin workspace.',
            )
          else
            Rows([
              for (final p in members)
                tile(
                  (p['full_name'] ?? p['name'] ?? p['email'] ?? 'Account')
                      .toString(),
                  s: '${roleLabels[p['role']?.toString()] ?? p['designation'] ?? p['specialty'] ?? p['role'] ?? 'Account'} · ${(p['account_status'] ?? p['status'] ?? (p['is_active'] == true ? 'Active' : 'Unknown')).toString()}',
                  lead: Initials(
                    (p['full_name'] ?? p['name'] ?? p['email'] ?? 'A')
                        .toString(),
                  ),
                ),
            ]),
          sec('Create account'),
          twoButtons(
            OutlinedButton(
              onPressed: () => invitePerson(context, Kind.staff),
              child: const Text('Team member'),
            ),
            FilledButton(
              onPressed: () => invitePerson(context, Kind.freelancer),
              child: const Text('Freelancer'),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => invitePerson(context, Kind.sales),
            child: const Text('Sales account'),
          ),
        ]);
      },
    ),
  );
}
