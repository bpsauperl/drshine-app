import 'package:flutter/material.dart';
import 'package:shine_kit/shine_kit.dart';

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
              const KitArchHero(
                height: 200,
                semanticLabel: 'The aligner, on its way to planning',
              ),
              const SizedBox(height: 8),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: p.accentFill,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Sent for planning.',
                style: KitType.display(40, color: context.kit.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'The plan comes back in Stella.',
                style: KitType.body(color: p.secondary),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              KitButton(
                label: 'Back to the patient',
                onPressed: () => Navigator.of(context).pop(),
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
