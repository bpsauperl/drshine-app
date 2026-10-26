import 'package:flutter/material.dart';
import 'package:shine_kit/shine_kit.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import 'order/order_builder_screen.dart';

/// One patient: the summary, the orders, and "New Aligners order".
class PatientScreen extends StatefulWidget {
  const PatientScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<PatientScreen> createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen> {
  PatientDetail? _detail;
  String? _error;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final detail = await AppScope.read(context).api.patient(widget.patientId);
      if (mounted) {
        setState(() => _detail = detail);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    }
  }

  Future<void> _newOrder() async {
    setState(() => _starting = true);
    try {
      final order = await AppScope.read(context).api
          .createAlignersOrder(widget.patientId);
      if (mounted) {
        await _openOrder(order.id, initial: order);
      }
    } on ApiException catch (e) {
      if (mounted) {
        showMessage(context, e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  Future<void> _openOrder(String id, {Order? initial}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderBuilderScreen(
          orderId: id,
          initial: initial,
          patientName: _detail?.patient.name,
        ),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final k = context.kit;
    if (detail == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error == null
            ? const Center(child: CircularProgressIndicator())
            : CenteredMessage(
                icon: Icons.cloud_off_outlined,
                title: "Couldn't open the patient",
                text: _error,
                action: SizedBox(
                  width: 200,
                  child: KitButton.secondary(
                    label: 'Try again',
                    onPressed: _load,
                  ),
                ),
              ),
      );
    }

    final patient = detail.patient;
    OrderSummary? draft;
    for (final order in detail.orders) {
      if (order.isAligners && order.draft) {
        draft = order;
        break;
      }
    }
    final openDraft = draft;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Brand.gutter,
              10,
              Brand.gutter,
              120,
            ),
            children: [
              Row(
                children: [
                  KitRoundButton(
                    icon: Icons.arrow_back_rounded,
                    label: 'Patients',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Expanded(child: Center(child: Wordmark(size: 17))),
                  const SizedBox(width: KitSize.touch),
                ],
              ),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                child: Text(
                  patient.name,
                  style: KitType.display(32, color: k.ink),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: k.accentText,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (patient.statusLabel.isNotEmpty) patient.statusLabel,
                        patient.code,
                      ].join(' · '),
                      style: KitType.label(color: k.secondary),
                    ),
                  ),
                ],
              ),
              KitArchHero(
                height: 190,
                semanticLabel:
                    '${patient.firstName.isEmpty ? 'The patient' : patient.firstName}\'s arch',
              ),
              _Facts(patient: patient),
              const SizedBox(height: 22),
              if (detail.orders.isEmpty)
                KitTile(
                  child: Text(
                    'No orders yet. Ready when you are.',
                    style: KitType.body(color: k.secondary),
                  ),
                )
              else
                KitListGroup(
                  title: 'Orders',
                  children: [
                    for (final order in detail.orders)
                      _OrderRow(
                        order: order,
                        onOpen: order.isAligners
                            ? () => _openOrder(order.id)
                            : null,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 16),
        child: openDraft == null
            ? KitButton(
                key: const Key('new-order'),
                label: 'New Aligners order',
                icon: Icons.add_rounded,
                busy: _starting,
                onPressed: _newOrder,
              )
            : KitButton(
                key: const Key('continue-order'),
                label: 'Continue series ${openDraft.series ?? ''}'.trim(),
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () => _openOrder(openDraft.id),
              ),
      ),
    );
  }
}

/// Born, doctor and clinic, side by side.
class _Facts extends StatelessWidget {
  const _Facts({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final k = context.kit;
    final facts = <(String, String)>[
      if ((patient.birthDate ?? '').isNotEmpty)
        (
          'Born',
          formatIsoDate(patient.birthDate) +
              (patient.isMinor ? ' · minor' : ''),
        ),
      if (patient.doctor != null) ('Doctor', patient.doctor!.name),
      if (patient.clinic != null) ('Clinic', patient.clinic!.name),
    ];
    if (facts.isEmpty) {
      return const SizedBox.shrink();
    }
    return KitTile(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in facts)
            Expanded(
              child: Semantics(
                label: '$label: $value',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: KitType.label(color: k.secondary)),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: k.ink,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, this.onOpen});

  final OrderSummary order;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final title = [
      order.typeLabel.isEmpty ? 'Order' : order.typeLabel,
      if (order.series != null) 'series ${order.series}',
    ].join(' · ');
    final when = order.submittedAt != null
        ? 'Sent ${formatDate(order.submittedAt)}'
        : (order.createdAt != null
              ? 'Started ${formatDate(order.createdAt)}'
              : '');
    return KitListRow(
      icon: order.isAligners
          ? Icons.layers_outlined
          : Icons.inventory_2_outlined,
      title: title,
      detail: [
        order.reference,
        if (order.journeyLabel.isNotEmpty) order.journeyLabel,
        if (when.isNotEmpty) when,
      ].join(' · '),
      state: order.draft ? 'Draft' : order.statusLabel,
      highlight: order.draft,
      onTap: onOpen,
    );
  }
}
