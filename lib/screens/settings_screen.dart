import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// The signed-in user, the clinic, the server, and sign out.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    await state.signOut();
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;
    final p = Palette.of(context);

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(color: p.secondary)),
          ),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(Brand.gutter),
        children: [
          if (user != null)
            Tile(
              child: Row(
                children: [
                  InitialsAvatar(
                    user.name
                        .trim()
                        .split(RegExp(r'\s+'))
                        .where((s) => s.isNotEmpty)
                        .take(2)
                        .map((s) => s[0])
                        .join()
                        .toUpperCase(),
                    size: 52,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(user.email, style: TextStyle(color: p.secondary)),
                        const SizedBox(height: 6),
                        Pill(
                          user.roleLabel.isEmpty ? user.role : user.roleLabel,
                          strong: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SectionLabel('Clinic'),
          Tile(
            child: Column(
              children: [
                row('Clinic', user?.clinic?.name ?? '—'),
                row(
                  'Sending',
                  (user?.canSend ?? false)
                      ? 'You can send orders'
                      : 'You prepare, a dentist sends',
                ),
              ],
            ),
          ),
          const SectionLabel('Server'),
          Tile(
            onTap: () => launchUrl(
              Uri.parse(state.serverUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    state.serverUrl,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Icon(Icons.open_in_new, size: 18, color: p.secondary),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'Change the server on the sign-in screen.',
              style: TextStyle(color: p.secondary, fontSize: 13),
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            key: const Key('sign-out'),
            onPressed: () => _signOut(context),
            style: OutlinedButton.styleFrom(foregroundColor: Brand.danger),
            child: const Text('Sign out'),
          ),
          const SizedBox(height: 24),
          const Center(child: Wordmark(size: 20)),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(color: p.secondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
