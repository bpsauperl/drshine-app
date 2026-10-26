import 'package:flutter/material.dart';

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
      final order = await AppScope.read(context).api.createAlignersOrder(widget.patientId);
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
        builder: (_) => OrderBuilderScreen(orderId: id, initial: initial, patientName: _detail?.patient.name),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final p = Palette.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(detail?.patient.code ?? '')),
      body: detail == null
          ? (_error == null
              ? const Center(child: CircularProgressIndicator())
              : CenteredMessage(
                  icon: Icons.cloud_off_outlined,
                  title: "Couldn't open the patient",
                  text: _error,
                  action: OutlinedButton(onPressed: _load, child: const Text('Try again')),
                ))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 40),
                children: [
                  _Summary(patient: detail.patient),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('new-order'),
                    onPressed: _starting ? null : _newOrder,
                    icon: _starting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add),
                    label: const Text('New Aligners order'),
                  ),
                  SectionLabel('Orders', trailing: Text('${detail.orders.length}', style: TextStyle(color: p.secondary))),
                  if (detail.orders.isEmpty)
                    Tile(
                      child: Text('No orders yet. Ready when you are.', style: TextStyle(color: p.secondary)),
                    )
                  else
                    for (final order in detail.orders) ...[
                      _OrderCard(
                        order: order,
                        onOpen: order.isAligners ? () => _openOrder(order.id) : null,
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final facts = <(String, String)>[
      ('ID', patient.code),
      if ((patient.birthDate ?? '').isNotEmpty)
        ('Born', formatIsoDate(patient.birthDate) + (patient.isMinor ? ' · minor' : '')),
      if (patient.doctor != null) ('Doctor', patient.doctor!.name),
      if (patient.clinic != null) ('Clinic', patient.clinic!.name),
    ];
    return Tile(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(patient.initials, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.name, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    if (patient.statusLabel.isNotEmpty) Pill(patient.statusLabel, strong: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final (label, value) in facts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 70, child: Text(label, style: TextStyle(color: p.secondary))),
                  Expanded(child: Text(value)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, this.onOpen});

  final OrderSummary order;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final title = [
      order.typeLabel.isEmpty ? 'Order' : order.typeLabel,
      if (order.series != null) 'series ${order.series}',
    ].join(' · ');
    final when = order.submittedAt != null
        ? 'Sent ${formatDate(order.submittedAt)}'
        : (order.createdAt != null ? 'Started ${formatDate(order.createdAt)}' : '');

    return Tile(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              Pill(order.draft ? 'Draft' : order.statusLabel, strong: order.draft),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [order.reference, if (order.journeyLabel.isNotEmpty) order.journeyLabel, if (when.isNotEmpty) when].join(' · '),
            style: TextStyle(color: p.secondary, fontSize: 13),
          ),
          if (order.draft && onOpen != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.play_arrow_rounded, color: p.accent, size: 20),
                const SizedBox(width: 4),
                Text('Continue the draft', style: TextStyle(color: p.accent, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
