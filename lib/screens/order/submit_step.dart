import 'package:flutter/material.dart';
import 'package:shine_kit/shine_kit.dart';

import '../../state/order_builder.dart';
import '../../theme.dart';
import '../../util/format.dart';
import '../../widgets/common.dart';
import 'order_builder_screen.dart';

/// The summary, what's missing, the attestations, and "Send for planning".
class SubmitStep extends StatelessWidget {
  const SubmitStep({super.key, required this.builder, required this.onSent});

  final OrderBuilder builder;
  final VoidCallback onSent;

  Future<void> _send() async {
    if (await builder.submit()) {
      onSent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final order = builder.order;
    final missing = builder.missing;
    final sent = !order.draft || order.submittedAt != null;

    return ListView(
      padding: const EdgeInsets.all(Brand.gutter),
      children: [
        StepHeading(
          title: sent
              ? 'Sent for planning.'
              : (missing.isEmpty ? 'Ready when you are.' : 'Almost there.'),
          subtitle: sent
              ? 'The plan comes back in Stella.'
              : 'Check the summary, confirm, and send.',
        ),
        if (order.totalCents != null) ...[
          Text(
            sent ? 'Ordered' : 'Due now',
            style: KitType.eyebrow(color: context.kit.accentText),
          ),
          const SizedBox(height: 4),
          Text(
            formatEuros(order.totalCents),
            key: const Key('total'),
            style: KitType.display(76, color: context.kit.ink),
          ),
          const SizedBox(height: 14),
        ],
        if (order.priceLines.isNotEmpty)
          Tile(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              children: [
                for (final line in order.priceLines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if ((line.detail ?? '').isNotEmpty)
                                Text(
                                  line.detail!,
                                  style: TextStyle(
                                    color: p.secondary,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          formatEuros(line.amountCents),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (missing.isNotEmpty && !sent) ...[
          const SectionLabel('Still needed'),
          Tile(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final (step, text) in _byStep(missing))
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.radio_button_unchecked,
                      size: 20,
                      color: p.accent,
                    ),
                    title: Text(text),
                    trailing: Text(
                      step.label,
                      style: TextStyle(color: p.secondary),
                    ),
                    onTap: () => builder.goTo(step),
                  ),
              ],
            ),
          ),
        ],
        if (order.attestations.isNotEmpty && !sent) ...[
          const SectionLabel('Please confirm'),
          for (final card in order.attestations) ...[
            _AttestationCard(
              key: Key('attest-${card.id}'),
              title: card.title,
              text: card.text,
              ticked: builder.isTicked(card.id),
              onTap: () => builder.toggleAttestation(card.id),
            ),
            const SizedBox(height: 10),
          ],
        ],
        if (builder.error != null) ...[
          const SizedBox(height: 6),
          Notice(builder.error!, danger: true),
        ],
        const SizedBox(height: 14),
        if (!sent) ...[
          if (!builder.canSend) ...[
            const Notice(
              "Only a dentist can send. It's ready for them in drShine.",
              icon: Icons.lock_outline,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Saved with the order: who confirmed, when, and the terms version.',
            textAlign: TextAlign.center,
            style: KitType.label(color: p.secondary).copyWith(fontSize: 12),
          ),
          const SizedBox(height: 10),
          KitSlideToConfirm(
            key: const Key('send'),
            label: 'Slide to send for planning',
            enabled: builder.canSubmit,
            busy: builder.busy,
            onConfirmed: _send,
          ),
          if (builder.canSend && missing.isEmpty && !builder.allAttested)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Tick every card to send.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.secondary),
              ),
            ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

/// One line per step: the item itself, or "12 photos missing" when there are many.
List<(BuilderStep, String)> _byStep(List<MissingItem> missing) {
  final steps = <BuilderStep, List<String>>{};
  for (final item in missing) {
    steps.putIfAbsent(item.step, () => []).add(item.text);
  }
  return [
    for (final MapEntry(key: step, value: texts) in steps.entries)
      (
        step,
        texts.length == 1
            ? texts.single
            : '${texts.length} ${switch (step) {
                BuilderStep.photos => 'photos',
                BuilderStep.scans => 'scans',
                _ => 'items',
              }} missing',
      ),
  ];
}

class _AttestationCard extends StatelessWidget {
  const _AttestationCard({
    super.key,
    required this.title,
    required this.text,
    required this.ticked,
    required this.onTap,
  });

  final String title;
  final String text;
  final bool ticked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Semantics(
      checked: ticked,
      child: Tile(
        onTap: onTap,
        border: null,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: ticked ? p.accentFill : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: ticked ? p.accentFill : p.line,
                  width: 1.6,
                ),
              ),
              child: ticked
                  ? const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (text.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(text, style: TextStyle(color: p.secondary)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
