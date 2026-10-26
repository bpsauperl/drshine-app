import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../state/order_builder.dart';
import '../../theme.dart';
import '../../util/format.dart';
import '../../widgets/common.dart';
import 'order_builder_screen.dart';

/// The upper and lower scan slots, and the Scan Hub inbox with Import.
class ScansStep extends StatelessWidget {
  const ScansStep({super.key, required this.builder});

  final OrderBuilder builder;

  Future<void> _import(BuildContext context, HubScan scan) async {
    final ok = await builder.importScan(scan.id);
    if (context.mounted) {
      showMessage(
        context,
        ok
            ? 'Scan imported.'
            : (builder.error ?? "The scan couldn't be imported."),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final inbox = builder.scanInbox;
    final complete = builder.isComplete(BuilderStep.scans);

    return RefreshIndicator(
      onRefresh: builder.loadScans,
      child: ListView(
        padding: const EdgeInsets.all(Brand.gutter),
        children: [
          StepHeading(
            title: complete ? 'Scans are in.' : 'Add the scans.',
            subtitle: 'Import from your scanner through Scan Hub.',
          ),
          Tile(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < builder.order.scans.length; i++) ...[
                  if (i > 0) const Divider(indent: 56),
                  _ScanSlotRow(slot: builder.order.scans[i]),
                ],
              ],
            ),
          ),
          for (final text
              in builder
                  .missingFor(BuilderStep.scans)
                  .where((t) => t.contains('CBCT'))) ...[
            const SizedBox(height: 10),
            Notice(text),
          ],
          SectionLabel(
            'Scan Hub',
            trailing: IconButton(
              tooltip: 'Refresh',
              onPressed: builder.loadingScans ? null : builder.loadScans,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (builder.loadingScans && inbox == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (inbox == null)
            const SizedBox.shrink()
          else if (!inbox.connected)
            const Notice(
              'Scan Hub isn\'t connected for your clinic yet. Connect it on drshine web.',
              icon: Icons.link_off,
            )
          else if (inbox.error != null)
            Notice(inbox.error!, danger: true)
          else if (inbox.scans.isEmpty)
            Tile(
              child: Text(
                'No scans for this patient in Scan Hub yet.',
                style: TextStyle(color: p.secondary),
              ),
            )
          else
            for (final scan in inbox.scans) ...[
              _HubScanCard(
                scan: scan,
                importing: builder.importingScan == scan.id,
                onImport: builder.busy || !builder.order.draft
                    ? null
                    : () => _import(context, scan),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 16),
          Center(
            child: Text(
              'or upload .stl on drshine web',
              style: TextStyle(color: p.secondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanSlotRow extends StatelessWidget {
  const _ScanSlotRow({required this.slot});

  final ScanSlot slot;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final has = slot.file != null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        has ? Icons.check_circle : Icons.radio_button_unchecked,
        color: has ? p.accent : p.secondary,
      ),
      title: Text(
        slot.label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        has ? slot.file!.name : 'Not added yet',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _HubScanCard extends StatelessWidget {
  const _HubScanCard({
    required this.scan,
    required this.importing,
    this.onImport,
  });

  final HubScan scan;
  final bool importing;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final jaws = scan.jaws
        .map((j) => j == 'upper' ? 'Upper' : (j == 'lower' ? 'Lower' : j))
        .join(' + ');
    return Tile(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.view_in_ar_outlined, color: p.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan.source.isEmpty ? 'Scan' : scan.source,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (jaws.isNotEmpty) jaws,
                    if (scan.takenAt != null) formatDate(scan.takenAt),
                  ].join(' · '),
                  style: TextStyle(color: p.secondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: FilledButton(
              onPressed: importing ? null : onImport,
              style: FilledButton.styleFrom(minimumSize: const Size(96, 40)),
              child: importing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Import'),
            ),
          ),
        ],
      ),
    );
  }
}
