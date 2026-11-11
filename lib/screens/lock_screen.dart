import 'package:flutter/material.dart';
import 'package:shine_kit/shine_kit.dart';

import '../state/app_lock.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Covers the app until the phone's own unlock passes: Face ID, Touch ID, the
/// fingerprint or the passcode. Sign out is the other way on.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.lock});

  final AppLock lock;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    await widget.lock.state.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final lock = widget.lock;
    final p = Palette.of(context);
    final busy = lock.asking || _signingOut;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Brand.gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Wordmark(size: 22),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Locked',
                    style: KitType.eyebrow(color: context.kit.accentText),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    header: true,
                    child: Text(
                      'drShine is locked.',
                      style: KitType.display(36, color: context.kit.ink),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Unlock with Face ID, your fingerprint or this phone's passcode to see your patients.",
                    style: KitType.body(color: p.secondary),
                  ),
                  const SizedBox(height: 28),
                  KitButton(
                    key: const Key('unlock'),
                    label: 'Unlock',
                    icon: Icons.lock_open_rounded,
                    busy: lock.asking,
                    onPressed: busy ? null : lock.unlock,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    key: const Key('lock-sign-out'),
                    onPressed: busy ? null : _signOut,
                    style: TextButton.styleFrom(foregroundColor: p.secondary),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
