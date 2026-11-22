import 'package:flutter/material.dart';

import 'data.dart';
import 'inbox.dart';
import 'ui.dart';
import 'admin_api_service.dart';

/// The signed-in admin. Used as a bottom tab and opened from Settings ([pushed] adds a back bar).
class Profile extends StatelessWidget {
  const Profile({super.key, this.pushed = false, this.onSignOut});
  final bool pushed;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    String or(String v) => v.isEmpty ? 'Not added' : v;
    Widget body() => page([
      if (pushed) title('Profile'),
      const SizedBox(height: 16),
      Center(
        child: Column(
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: C.raised,
              child: Text(
                initials(me.name),
                style: inter(30, w: FontWeight.w500, c: C.mist2),
              ),
            ),
            const SizedBox(height: 12),
            Text(me.name, style: inter(24, w: FontWeight.w500)),
            Text(me.role, style: inter(15, c: C.mist)),
          ],
        ),
      ),
      sec('Details'),
      Rows([
        tile('Email', s: or(me.email), lead: const Icon(Icons.mail_outline)),
        tile('Phone', s: or(me.phone), lead: const Icon(Icons.phone_outlined)),
        tile(
          'Agency',
          s: or(me.agency),
          lead: const Icon(Icons.storefront_outlined),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: FilledButton(
          onPressed: () async {
            final v = await formSheet(context, 'Edit profile', [
              F('Name', required: true, initial: me.name),
              F('Phone', initial: me.phone),
            ], 'Save');
            if (v != null && context.mounted) {
              final api = currentAdminApi;
              if (api == null) {
                return toast(
                  context,
                  'Connect to the Creo account to update your profile.',
                );
              }
              try {
                await api.updateProfile(
                  name: v['Name']!.trim(),
                  phone: v['Phone']!.trim(),
                );
                if (context.mounted) toast(context, 'Profile saved.');
              } catch (_) {
                if (context.mounted) {
                  toast(
                    context,
                    'Could not confirm the profile save. Reopen the profile and check before retrying.',
                  );
                }
              }
            }
          },
          child: const Text('Edit profile'),
        ),
      ),
      if (!pushed) ...[
        sec('Account'),
        Rows([
          tile(
            'Settings',
            lead: const Icon(Icons.settings_outlined),
            trail: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => Settings(onSignOut: onSignOut)),
            ),
          ),
          if (onSignOut != null)
            tile(
              'Sign out of Workspace',
              lead: Icon(Icons.logout, color: C.rose),
              trail: const Icon(Icons.chevron_right),
              onTap: onSignOut,
            ),
        ]),
      ],
    ]);
    return pushed
        ? Scaffold(
            appBar: AppBar(
              title: Text('Back', style: inter(16, w: FontWeight.w500)),
            ),
            body: ListenableBuilder(
              listenable: changed,
              builder: (_, _) => body(),
            ),
          )
        : body();
  }
}
