import 'package:flutter/material.dart';

import '../../state/order_builder.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'order_builder_screen.dart';

/// Complete (Adult or Growing patient) or Flexible.
class PlanStep extends StatefulWidget {
  const PlanStep({super.key, required this.builder});

  final OrderBuilder builder;

  @override
  State<PlanStep> createState() => _PlanStepState();
}

class _PlanStepState extends State<PlanStep> {
  late String? _kind = widget.builder.order.planChoice.kind;
  late String? _audience = widget.builder.order.planChoice.audience;

  bool get _changed =>
      _kind != widget.builder.order.planChoice.kind ||
      (_kind == 'complete' &&
          _audience != widget.builder.order.planChoice.audience);

  bool get _valid =>
      _kind == 'flexible' || (_kind == 'complete' && _audience != null);

  /// A pick is saved straight away, so "Continue" never leaves it behind.
  Future<void> _pick({required String kind, String? audience}) async {
    setState(() {
      _kind = kind;
      _audience = kind == 'flexible' ? null : audience ?? _audience;
    });
    if (_valid && _changed) {
      await widget.builder.choosePlan(kind: _kind!, audience: _audience);
    }
  }

  @override
  Widget build(BuildContext context) {
    final builder = widget.builder;
    return ListView(
      padding: const EdgeInsets.all(Brand.gutter),
      children: [
        const StepHeading(
          title: 'Choose a plan.',
          subtitle:
              'Once for the treatment. Flexible can move to Complete any time.',
        ),
        _Choice(
          key: const Key('plan-complete'),
          title: 'Complete',
          text: 'One package for the whole treatment. Retainers, whitening trays and retention wires included.',
          selected: _kind == 'complete',
          onTap: () => _pick(kind: 'complete'),
        ),
        if (_kind == 'complete')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 0, 0),
            child: Column(
              children: [
                _Choice(
                  title: 'Adult',
                  text: 'All permanent teeth. The finished plan sets the package.',
                  selected: _audience == 'adult',
                  compact: true,
                  onTap: () => _pick(kind: 'complete', audience: 'adult'),
                ),
                const SizedBox(height: 10),
                _Choice(
                  title: 'Growing patient',
                  text: 'Mixed dentition. Shine Grow: unlimited aligners and series for 18 months.',
                  selected: _audience == 'growing',
                  compact: true,
                  onTap: () => _pick(kind: 'complete', audience: 'growing'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        _Choice(
          key: const Key('plan-flexible'),
          title: 'Flexible',
          text: 'Pay per unit: one treatment plan, then aligners as you go. No expiry.',
          selected: _kind == 'flexible',
          onTap: () => _pick(kind: 'flexible'),
        ),
        if (builder.error != null) ...[
          const SizedBox(height: 14),
          Notice(builder.error!, danger: true),
        ],
        if (_kind == 'complete' && _audience == null) ...[
          const SizedBox(height: 14),
          const Notice('Choose adult or growing patient.'),
        ],
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.title,
    required this.text,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String title;
  final String text;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Semantics(
      selected: selected,
      child: Tile(
        onTap: onTap,
        border: selected ? p.accent : null,
        padding: EdgeInsets.all(compact ? 14 : 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? p.accent : p.secondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 15 : 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(text, style: TextStyle(color: p.secondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
