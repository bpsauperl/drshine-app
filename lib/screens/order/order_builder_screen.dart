import 'package:flutter/material.dart';

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
  const OrderBuilderScreen({super.key, required this.orderId, this.initial, this.patientName, this.cameraEnabled});

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
      setState(() => _builder = OrderBuilder(api: state.api, order: order, userCanSend: state.user?.canSend ?? false));
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
                action: OutlinedButton(onPressed: _load, child: const Text('Try again')),
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
                  Text('Aligners order${order.series != null ? ' · series ${order.series}' : ''}'),
                  if ((widget.patientName ?? order.reference).isNotEmpty)
                    Text(
                      [?widget.patientName, if (order.reference.isNotEmpty) order.reference].join(' · '),
                      style: TextStyle(fontSize: 12, color: Palette.of(context).secondary, fontWeight: FontWeight.w400),
                    ),
                ],
              ),
            ),
            body: Column(
              children: [
                StepStrip(builder: builder),
                if (builder.busy) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: KeyedSubtree(key: ValueKey(builder.current), child: _step(builder)),
                  ),
                ),
                if (builder.current != BuilderStep.submit) _BottomBar(builder: builder),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _step(OrderBuilder builder) => switch (builder.current) {
        BuilderStep.plan => PlanStep(builder: builder),
        BuilderStep.photos => PhotosStep(builder: builder, cameraEnabled: widget.cameraEnabled),
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

/// The steps as a progress strip: done steps ticked, the current one in indigo.
class StepStrip extends StatelessWidget {
  const StepStrip({super.key, required this.builder});

  final OrderBuilder builder;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final steps = builder.steps;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: builder.isComplete(steps[i - 1]) ? p.accent : p.line,
                ),
              ),
            _StepDot(
              step: steps[i],
              number: i + 1,
              current: builder.current == steps[i],
              complete: builder.isComplete(steps[i]),
              onTap: builder.busy ? null : () => builder.goTo(steps[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.step, required this.number, required this.current, required this.complete, this.onTap});

  final BuilderStep step;
  final int number;
  final bool current;
  final bool complete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final fill = current ? p.accentFill : (complete ? p.accentSoft : p.tile);
    final fg = current ? Colors.white : (complete ? p.accent : p.secondary);
    return Semantics(
      button: true,
      selected: current,
      label: '${step.label}${complete ? ', done' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: Border.all(color: current || complete ? p.accent : p.line, width: 1.5),
                ),
                child: complete && !current
                    ? Icon(Icons.check_rounded, size: 18, color: fg)
                    : Text('$number', style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(height: 4),
              Text(
                step.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                  color: current ? p.ink : p.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.builder});

  final OrderBuilder builder;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final previous = builder.previousStep;
    final next = builder.nextStep;
    return Container(
      decoration: BoxDecoration(color: p.canvas, border: Border(top: BorderSide(color: p.line))),
      padding: const EdgeInsets.fromLTRB(Brand.gutter, 10, Brand.gutter, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (previous != null)
              SizedBox(
                width: 110,
                child: OutlinedButton(
                  onPressed: builder.busy ? null : () => builder.goTo(previous),
                  child: const Text('Back'),
                ),
              ),
            if (previous != null) const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('next-step'),
                onPressed: builder.busy || next == null ? null : () => builder.goTo(next),
                child: Text(next == null ? 'Continue' : 'Continue to ${next.label}'),
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
  const StepHeading({super.key, required this.title, this.subtitle, this.trailing});

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
