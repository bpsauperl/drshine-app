import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api_client.dart';
import '../../state/order_builder.dart';
import 'blueprint.dart';

/// Whether this platform has the in-app camera (the web preview does not).
bool get cameraSupported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

/// The guided camera: a full-screen preview with the slot's faded outline,
/// a short instruction, shutter, flash, front/back switch, and a
/// "Use photo / Retake" review. "Use photo" uploads in the background and
/// moves on to the next slot, so all slots can be shot in a row.
class GuidedCameraScreen extends StatefulWidget {
  const GuidedCameraScreen({super.key, required this.builder, required this.startSlot, this.cameraEnabled});

  final OrderBuilder builder;
  final String startSlot;

  /// Overrides [cameraSupported] (tests).
  final bool? cameraEnabled;

  @override
  State<GuidedCameraScreen> createState() => _GuidedCameraScreenState();
}

class _GuidedCameraScreenState extends State<GuidedCameraScreen> with WidgetsBindingObserver {
  late int _index;
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  bool _useFront = false;
  FlashMode _flash = FlashMode.off;
  String? _cameraError;
  bool _capturing = false;
  Uint8List? _review;

  bool get _enabled => widget.cameraEnabled ?? cameraSupported;

  List<PhotoSlot> get _slots => widget.builder.order.photos;
  PhotoSlot get _slot => _slots[_index];
  Blueprint get _blueprint => blueprintFor(_slot.slot, _slot.guide);

  @override
  void initState() {
    super.initState();
    _index = widget.builder.slotIndex(widget.startSlot).clamp(0, _slots.length - 1);
    WidgetsBinding.instance.addObserver(this);
    if (_enabled) {
      unawaited(_startCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (!_enabled) {
      return;
    }
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller = null;
      unawaited(controller?.dispose());
      if (mounted) {
        setState(() {});
      }
    } else if (state == AppLifecycleState.resumed && controller == null) {
      unawaited(_startCamera());
    }
  }

  Future<void> _startCamera() async {
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) {
        setState(() => _cameraError = 'No camera found on this device.');
        return;
      }
      final wanted = _useFront ? CameraLensDirection.front : CameraLensDirection.back;
      final description = _cameras.firstWhere((c) => c.lensDirection == wanted, orElse: () => _cameras.first);
      final old = _controller;
      _controller = null;
      await old?.dispose();
      final controller = CameraController(
        description,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await controller.setFlashMode(_flash).catchError((Object _) {});
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _cameraError = null;
      });
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _cameraError = e.code == 'CameraAccessDenied' || e.code == 'CameraAccessDeniedWithoutPrompt'
            ? 'drShine needs the camera. Allow it in Settings, then come back.'
            : "The camera didn't start. Close and try again.");
      }
    }
  }

  Future<void> _switchCamera() async {
    setState(() => _useFront = !_useFront);
    await _startCamera();
  }

  Future<void> _cycleFlash() async {
    final next = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    setState(() => _flash = next);
    try {
      await _controller?.setFlashMode(next);
    } on CameraException {
      // The front camera often has no flash; the setting is kept for later.
    }
  }

  Future<void> _shoot() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() => _review = bytes);
      }
    } on CameraException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("That didn't work. Try again.")));
      }
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
    }
  }

  void _usePhoto() {
    final bytes = _review;
    if (bytes == null) {
      return;
    }
    unawaited(widget.builder.uploadPhoto(_slot.slot, bytes, filename: '${_slot.slot}.jpg'));
    setState(() => _review = null);
    if (_index + 1 < _slots.length) {
      _go(_index + 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _go(int index) {
    if (index < 0 || index >= _slots.length) {
      return;
    }
    setState(() {
      _index = index;
      _review = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final slot = _slot;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_review != null)
              Image.memory(_review!, fit: BoxFit.cover, gaplessPlayback: true)
            else ...[
              _preview(),
              BlueprintOverlay(blueprint: _blueprint),
            ],
            SafeArea(
              child: Column(
                children: [
                  _topBar(slot),
                  const SizedBox(height: 8),
                  _instruction(_review != null ? 'Sharp and well lit? Use it, or retake.' : instructionFor(slot.slot, _blueprint)),
                  const Spacer(),
                  if (_review != null) _reviewBar() else _shutterBar(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    final controller = _controller;
    if (!_enabled) {
      return const _Placeholder(
        icon: Icons.no_photography_outlined,
        title: 'Camera unavailable here',
        text: 'Take the photos with the drShine app on a phone.',
      );
    }
    if (_cameraError != null) {
      return _Placeholder(icon: Icons.videocam_off_outlined, title: 'Camera unavailable', text: _cameraError!);
    }
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    // Fill the screen, cropping the preview's longer side.
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = constraints.biggest.aspectRatio;
        final preview = 1 / controller.value.aspectRatio;
        final scale = screen > preview ? screen / preview : preview / screen;
        return ClipRect(
          child: Transform.scale(scale: scale, child: Center(child: CameraPreview(controller))),
        );
      },
    );
  }

  Widget _topBar(PhotoSlot slot) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _RoundButton(icon: Icons.close, tooltip: 'Close', onTap: () => Navigator.of(context).pop()),
          Expanded(
            child: Column(
              children: [
                Text(
                  slot.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_index + 1} of ${_slots.length}${slot.required ? '' : ' · optional'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          _RoundButton(
            icon: switch (_flash) {
              FlashMode.auto => Icons.flash_auto,
              FlashMode.always => Icons.flash_on,
              _ => Icons.flash_off,
            },
            tooltip: 'Flash',
            onTap: _review == null && _controller != null ? _cycleFlash : null,
          ),
        ],
      ),
    );
  }

  Widget _instruction(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(20)),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15)),
    );
  }

  Widget _shutterBar() {
    final ready = _controller?.value.isInitialized ?? false;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundButton(icon: Icons.chevron_left, tooltip: 'Previous photo', onTap: _index > 0 ? () => _go(_index - 1) : null),
        Semantics(
          button: true,
          label: 'Take photo',
          child: GestureDetector(
            key: const Key('shutter'),
            onTap: ready && !_capturing ? _shoot : null,
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
              padding: const EdgeInsets.all(5),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ready ? (_capturing ? Colors.white54 : Colors.white) : Colors.white24,
                ),
              ),
            ),
          ),
        ),
        _RoundButton(
          icon: Icons.chevron_right,
          tooltip: 'Next photo',
          onTap: _index + 1 < _slots.length ? () => _go(_index + 1) : null,
        ),
        _RoundButton(
          icon: Icons.cameraswitch_outlined,
          tooltip: _useFront ? 'Back camera' : 'Front camera',
          onTap: _enabled && _cameras.length > 1 ? _switchCamera : null,
        ),
      ],
    );
  }

  Widget _reviewBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _review = null),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Retake'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              key: const Key('use-photo'),
              onPressed: _usePhoto,
              child: const Text('Use photo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      iconSize: 26,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white24,
        disabledBackgroundColor: Colors.black12,
        fixedSize: const Size(48, 48),
      ),
      icon: Icon(icon),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, 0.62),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 30),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
