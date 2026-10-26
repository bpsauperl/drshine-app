import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../state/order_builder.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'order_builder_screen.dart';

/// Quick phrases for the prescription.
const List<String> rxQuickPhrases = [
  'IPR allowed where needed.',
  'Keep the midlines.',
  'Attachments allowed.',
];

/// The prescription: planning partner, arches, concerns, goal and RX.
class RxStep extends StatefulWidget {
  const RxStep({super.key, required this.builder});

  final OrderBuilder builder;

  @override
  State<RxStep> createState() => _RxStepState();
}

class _RxStepState extends State<RxStep> {
  late final TextEditingController _goal = TextEditingController(
    text: widget.builder.rxDraft.treatmentGoal ?? '',
  );
  late final TextEditingController _prescription = TextEditingController(
    text: widget.builder.rxDraft.prescription ?? '',
  );

  @override
  void initState() {
    super.initState();
    widget.builder.addListener(_sync);
  }

  @override
  void dispose() {
    widget.builder.removeListener(_sync);
    _goal.dispose();
    _prescription.dispose();
    super.dispose();
  }

  /// Quick phrases change the draft from outside the text field.
  void _sync() {
    final text = widget.builder.rxDraft.prescription ?? '';
    if (_prescription.text != text) {
      _prescription.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final builder = widget.builder;
    final rx = builder.rxDraft;
    final options = builder.order.options;
    final p = Palette.of(context);

    return ListView(
      padding: const EdgeInsets.all(Brand.gutter),
      children: [
        const StepHeading(
          title: 'The prescription.',
          subtitle: 'Who plans, which arches, and what you want.',
        ),
        const SectionLabel('Planning partner'),
        for (final partner in options.partners) ...[
          _PartnerCard(
            option: partner,
            selected: rx.planningPartner == partner.value,
            onTap: () =>
                builder.editRx(rx.copyWith(planningPartner: partner.value)),
          ),
          const SizedBox(height: 10),
        ],
        if (options.arches.isNotEmpty) ...[
          const SectionLabel('Arches'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              key: const Key('arches'),
              segments: [
                for (final a in options.arches)
                  ButtonSegment(value: a.value, label: Text(a.label)),
              ],
              selected: {if (rx.arches != null) rx.arches!},
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              onSelectionChanged: (s) {
                if (s.isNotEmpty) {
                  builder.editRx(rx.copyWith(arches: s.first));
                }
              },
            ),
          ),
        ],
        if (options.concerns.isNotEmpty) ...[
          const SectionLabel('Concerns'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in options.concerns)
                FilterChip(
                  label: Text(c.label),
                  selected: rx.concerns.contains(c.value),
                  onSelected: (_) => builder.toggleConcern(c.value),
                  selectedColor: p.accentSoft,
                  labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: rx.concerns.contains(c.value) ? p.accent : p.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
        const SectionLabel('Treatment goal'),
        TextField(
          controller: _goal,
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'What should the treatment achieve?',
          ),
          onChanged: (v) =>
              builder.editRx(builder.rxDraft.copyWith(treatmentGoal: v)),
        ),
        const SectionLabel('Prescription'),
        TextField(
          key: const Key('prescription'),
          controller: _prescription,
          minLines: 4,
          maxLines: 10,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Movements, limits, anything the planner should know.',
          ),
          onChanged: (v) =>
              builder.editRx(builder.rxDraft.copyWith(prescription: v)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final phrase in rxQuickPhrases)
              ActionChip(
                avatar: Icon(Icons.add, size: 16, color: p.accent),
                label: Text(phrase),
                onPressed: () => builder.addPhrase(phrase),
              ),
          ],
        ),
        if (builder.error != null) ...[
          const SizedBox(height: 14),
          Notice(builder.error!, danger: true),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: builder.rxDirty && !builder.busy ? builder.saveRx : null,
            icon: Icon(
              builder.rxDirty ? Icons.save_outlined : Icons.check,
              size: 18,
            ),
            label: Text(builder.rxDirty ? 'Save' : 'Saved'),
          ),
        ),
      ],
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final Option option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Semantics(
      selected: selected,
      child: Tile(
        onTap: onTap,
        border: selected ? p.accent : null,
        padding: const EdgeInsets.all(16),
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
                    option.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if ((option.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      option.description!,
                      style: TextStyle(color: p.secondary),
                    ),
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
