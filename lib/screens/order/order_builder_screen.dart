import 'package:flutter/material.dart';
import 'package:shine_kit/shine_kit.dart';

import '../../api/api_client.dart';
import '../../state/order_builder.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'done_screen.dart';
import 'photos_step.dart';
import 'plan_step.dart';
import 'rx_step.dart';
import 'scans_step.dart';
import 'submit_step.dart';

/// The Aligners order, step by step: Plan, Photos, Scans, RX, Submit.
class OrderBuilderScreen extends StatefulWidget {
  const OrderBuilderScreen({
    super.key,
    required this.orderId,
    this.initial,
    this.patientName,
    this.cameraEnabled,
  });

  final String orderId;
  final Order? initial;
  final String? patientName;

  /// Overrides the platform check for the in-app camera (tests).
  final bool? cameraEnabled;

  @override
  State<OrderBuilderScreen> createState() => _OrderBuilderScreenState();
}

class _OrderBuilderScreenState extends State<OrderBuilderScreen> {
  OrderBuilder? _builder;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _builder?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = AppScope.read(context);
    setState(() => _error = null);
    try {
      final order = widget.initial ?? await state.api.order(widget.orderId);
      if (!mounted) {
        return;
      }
      setState(
        () => _builder = OrderBuilder(
          api: state.api,
          order: order,
          userCanSend: state.user?.canSend ?? false,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    }
  }

  Future<void> _leave() async {
    final builder = _builder;
    if (builder != null && builder.rxDirty) {
      await builder.saveRx();
    }
  }

  @override
  Widget build(BuildContext context) {
    final builder = _builder;
    if (builder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Aligners order')),
        body: _error == null
            ? const Center(child: CircularProgressIndicator())
            : CenteredMessage(
                icon: Icons.cloud_off_outlined,
                title: "Couldn't open the order",
                text: _error,
                action: OutlinedButton(
                  onPressed: _load,
                  child: const Text('Try again'),
                ),
              ),
      );
    }

    return ListenableBuilder(
      listenable: builder,
      builder: (context, _) {
        final order = builder.order;
        return PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) {
              _leave();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Column(
                children: [
                  Text(
                    'Aligners${order.series != null ? ' · Series ${order.series}' : ''}',
                  ),
                  if ((widget.patientName ?? order.reference).isNotEmpty)
                    Text(
                      [
                        ?widget.patientName,
                        if (order.reference.isNotEmpty) order.reference,
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: Palette.of(context).secondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
            body: Column(
              children: [
                StepStrip(builder: builder),
                if (builder.busy)
                  const LinearProgressIndicator(minHeight: 2)
                else
                  const SizedBox(height: 2),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: KeyedSubtree(
                      key: ValueKey(builder.current),
                      child: _step(builder),
                    ),
                  ),
                ),
                if (builder.current != BuilderStep.submit)
                  _BottomBar(builder: builder),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _step(OrderBuilder builder) => switch (builder.current) {
    BuilderStep.plan => PlanStep(builder: builder),
    BuilderStep.photos => PhotosStep(
      builder: builder,
      cameraEnabled: widget.cameraEnabled,
    ),
    BuilderStep.scans => ScansStep(builder: builder),
    BuilderStep.rx => RxStep(builder: builder),
    BuilderStep.submit => SubmitStep(
      builder: builder,
      onSent: () => Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const DoneScreen()),
      ),
    ),
  };
}

/// The steps as a row of bars: filled when done, the current one stronger,
/// each with its name. Tap one to jump to it.
class StepStrip extends StatelessWidget {
  const StepStrip({super.key, required this.builder});

  final OrderBuilder builder;

  @override
  Widget build(BuildContext context) {
    final k = context.kit;
    final steps = builder.steps;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 12),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                button: true,
                selected: builder.current == steps[i],
                label:
                    '${steps[i].label}${builder.isComplete(steps[i]) ? ', done' : ''}',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: builder.busy ? null : () => builder.goTo(steps[i]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: builder.isComplete(steps[i])
                                ? k.accentText
                                : builder.current == steps[i]
                                ? k.accent.withValues(alpha: 0.55)
                                : k.hairline.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (builder.isComplete(steps[i])) ...[
                              Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: k.accentText,
                              ),
                              const SizedBox(width: 2),
                            ],
                            Flexible(
                              child: Text(
                                steps[i].label,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: builder.current == steps[i]
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: builder.current == steps[i]
                                      ? k.ink
                                      : k.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.builder});

  final OrderBuilder builder;

  @override
  Widget build(BuildContext context) {
    final previous = builder.previousStep;
    final next = builder.nextStep;
    return ColoredBox(
      color: context.kit.ground,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(Brand.gutter, 10, Brand.gutter, 16),
        child: Row(
          children: [
            if (previous != null) ...[
              SizedBox(
                width: 110,
                child: KitButton.secondary(
                  label: 'Back',
                  onPressed: builder.busy ? null : () => builder.goTo(previous),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: KitButton(
                key: const Key('next-step'),
                label: next == null ? 'Continue' : 'Continue to ${next.label}',
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: builder.busy || next == null
                    ? null
                    : () => builder.goTo(next),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A step's heading: a big title and a calm line.
class StepHeading extends StatelessWidget {
  const StepHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: PageTitle(title, subtitle: subtitle)),
          ?trailing,
        ],
      ),
    );
  }
}
