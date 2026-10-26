import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/common.dart';

/// After "Send for planning".
class DoneScreen extends StatelessWidget {
  const DoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Brand.gutter),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(color: p.accentSoft, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, size: 48, color: p.accent),
              ),
              const SizedBox(height: 24),
              Text('Sent for planning.', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'The plan comes back in Stella.',
                style: TextStyle(color: p.secondary, fontSize: 17),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to the patient'),
              ),
              const SizedBox(height: 8),
              const Wordmark(size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
