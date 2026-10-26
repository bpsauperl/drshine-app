import 'package:flutter/material.dart';
import 'package:shine_kit/shine_kit.dart';

import '../../api/api_client.dart';
import '../../state/order_builder.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../camera/blueprint.dart';
import '../camera/guided_camera_screen.dart';
import 'order_builder_screen.dart';

/// The 18 photo slots, grouped, with the required ones marked and the count.
class PhotosStep extends StatelessWidget {
  const PhotosStep({super.key, required this.builder, this.cameraEnabled});

  final OrderBuilder builder;
  final bool? cameraEnabled;

  void _open(BuildContext context, PhotoSlot slot) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => GuidedCameraScreen(
          builder: builder,
          startSlot: slot.slot,
          cameraEnabled: cameraEnabled,
        ),
      ),
    );
  }

  /// The first required photo still to take.
  static PhotoSlot? _nextSlot(OrderBuilder builder) {
    for (final group in builder.photoGroups) {
      for (final slot in group.value) {
        if (slot.required && !slot.isTaken) {
          return slot;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final done = builder.takenRequiredPhotos;
    final total = builder.requiredPhotos;
    final complete = total > 0 && done == total;

    return ListView(
      padding: const EdgeInsets.all(Brand.gutter),
      children: [
        StepHeading(
          title: complete ? 'All photos in.' : 'Add the photos.',
          subtitle: 'Tap a photo to take it. * required',
        ),
        KitTile(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Required photos',
                      style: KitType.eyebrow(color: context.kit.accentText),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$done',
                            style: KitType.number(
                              size: 32,
                              color: context.kit.ink,
                            ),
                          ),
                          TextSpan(
                            text: ' of $total taken',
                            style: KitType.label(color: context.kit.secondary)
                                .copyWith(fontSize: 15),
                          ),
                        ],
                      ),
                      key: const Key('photo-count'),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 54,
                height: 54,
                child: CircularProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  backgroundColor: p.accentSoft,
                  color: context.kit.accentText,
                ),
              ),
            ],
          ),
        ),
        if (!complete && _nextSlot(builder) != null) ...[
          const SizedBox(height: 12),
          KitButton(
            key: const Key('take-next'),
            label: 'Take the next: ${_nextSlot(builder)!.label}',
            icon: Icons.photo_camera_outlined,
            onPressed: () => _open(context, _nextSlot(builder)!),
          ),
        ],
        if (!cameraSupported && cameraEnabled != true) ...[
          const SizedBox(height: 14),
          const Notice(
            'Camera unavailable here. Take the photos with the drShine app on a phone.',
            icon: Icons.no_photography_outlined,
          ),
        ],
        for (final group in builder.photoGroups) ...[
          SectionLabel(
            group.key,
            trailing: group.value.any((s) => s.required)
                ? null
                : const Pill('Optional'),
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.78,
            children: [
              for (final slot in group.value)
                SlotTile(
                  builder: builder,
                  slot: slot,
                  onTap: () => _open(context, slot),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}

/// One photo slot: the photo, or its outline in indigo.
class SlotTile extends StatelessWidget {
  const SlotTile({
    super.key,
    required this.builder,
    required this.slot,
    required this.onTap,
  });

  final OrderBuilder builder;
  final PhotoSlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final file = slot.file;
    if (file != null) {
      builder.loadThumbnail(file);
    }
    final bytes = builder.photoBytes(slot);
    final uploading = builder.uploading.contains(slot.slot);
    final error = builder.slotErrors[slot.slot];

    return Semantics(
      button: true,
      label:
          '${slot.label}${slot.required ? ', required' : ''}${slot.isTaken ? ', taken' : ''}',
      child: Material(
        color: p.tile,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: slot.required && !slot.isTaken
              ? BorderSide(color: p.accent.withValues(alpha: 0.35), width: 1)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('slot-${slot.slot}'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (bytes != null)
                      Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    else
                      Container(
                        color: p.tile,
                        child: CustomPaint(
                          painter: BlueprintPainter(
                            blueprintFor(slot.slot, slot.guide),
                            color: p.accent,
                            opacity: 0.55,
                            strokeWidth: 1.2,
                            fill: 0.78,
                          ),
                        ),
                      ),
                    if (uploading)
                      Container(
                        color: Colors.black38,
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: error != null
                          ? const _Badge(
                              icon: Icons.priority_high_rounded,
                              color: Brand.danger,
                            )
                          : slot.isTaken && !uploading
                          ? _Badge(
                              icon: Icons.check_rounded,
                              color: p.accentFill,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: slot.label),
                      if (slot.required && !slot.isTaken)
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: p.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: error != null ? Brand.danger : p.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Icon(icon, size: 14, color: Colors.white),
    );
  }
}
