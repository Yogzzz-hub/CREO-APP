import 'package:flutter/material.dart';

import 'data.dart';
import 'inbox.dart';
import 'ui.dart';

/// The signed-in admin. Used as a bottom tab and opened from Settings ([pushed] adds a back bar).
class Profile extends StatelessWidget {
  const Profile({super.key, this.pushed = false});
  final bool pushed;

  @override
  Widget build(BuildContext context) {
    String or(String v) => v.isEmpty ? 'Not added' : v;
    Widget body() => page([
      if (pushed) title('Profile'),
      const SizedBox(height: 16),
      Center(
        child: Column(children: [
          CircleAvatar(radius: 44, backgroundColor: C.raised, child: Text(initials(me.name), style: inter(30, w: FontWeight.w600, c: C.mist2))),
          const SizedBox(height: 12),
          Text(me.name, style: inter(24, w: FontWeight.w600)),
          Text(me.role, style: inter(15, c: C.mist)),
        ]),
      ),
      sec('Details'),
      Rows([
        tile('Email', s: or(me.email), lead: const Icon(Icons.mail_outline)),
        tile('Phone', s: or(me.phone), lead: const Icon(Icons.phone_outlined)),
        tile('Agency', s: or(me.agency), lead: const Icon(Icons.storefront_outlined)),
      ]),
      Padding(
          padding: const EdgeInsets.only(top: 14),
          child: FilledButton(
              onPressed: () async {
                final v = await formSheet(context, 'Edit profile', [
                  F('Name', required: true, initial: me.name),
                  F('Role', initial: me.role),
                  F('Email', initial: me.email),
                  F('Phone', initial: me.phone),
                  F('Agency', initial: me.agency),
                ], 'Save');
                if (v != null) {
                  save(() => me
                    ..name = v['Name']!
                    ..role = v['Role']!
                    ..email = v['Email']!
                    ..phone = v['Phone']!
                    ..agency = v['Agency']!);
                }
              },
              child: const Text('Edit profile'))),
      if (!pushed) ...[
        sec('Account'),
        Rows([
          tile('Settings',
              lead: const Icon(Icons.settings_outlined),
              trail: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Settings()))),
        ]),
      ],
    ]);
    return pushed
        ? Scaffold(
            appBar: AppBar(title: Text('Back', style: inter(16, w: FontWeight.w500))),
            body: ListenableBuilder(listenable: changed, builder: (_, _) => body()))
        : body();
  }
}
