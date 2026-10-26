import 'package:flutter/foundation.dart';

import '../api/api_client.dart';

/// The steps of the app's case builder, in order.
enum BuilderStep {
  plan('Plan'),
  photos('Photos'),
  scans('Scans'),
  rx('RX'),
  submit('Submit');

  const BuilderStep(this.label);

  final String label;

  /// The API step keys this app step covers (`scans` = impressions + CBCT).
  List<String> get apiKeys => switch (this) {
    BuilderStep.scans => const ['impressions', 'cbct'],
    _ => [name],
  };
}

/// One missing item, with the step it belongs to.
class MissingItem {
  const MissingItem(this.step, this.text);

  final BuilderStep step;
  final String text;
}

/// The Aligners order being built on the phone: which steps show, which are
/// complete, what is missing, the attestation ticks, and the calls that
/// change the order. The server stays the source of truth: every change
/// answers with the full order, which replaces ours.
class OrderBuilder extends ChangeNotifier {
  OrderBuilder({
    required this.api,
    required Order order,
    required this.userCanSend,
  }) : _order = order,
       rxDraft = order.rx {
    current = firstOpenStep;
  }

  final ApiClient api;

  /// `user.can_send`: only treating doctors send; assistants prepare.
  final bool userCanSend;

  Order _order;
  Order get order => _order;

  late BuilderStep current;

  /// The RX as edited on the phone, saved when leaving the RX step.
  Rx rxDraft;
  bool rxDirty = false;

  final Set<String> ticked = {};
  final Set<String> uploading = {};

  /// Photos just taken on this phone, shown until the server copy loads.
  final Map<String, Uint8List> localPhotos = {};

  /// Thumbnails loaded from the server, by file id.
  final Map<String, Uint8List> thumbnails = {};
  final Set<String> _loadingThumbnails = {};

  /// Upload errors per slot.
  final Map<String, String> slotErrors = {};

  bool busy = false;
  String? error;
  ScanInbox? scanInbox;
  bool loadingScans = false;
  String? importingScan;
  bool sent = false;

  /// `422` on submit: what the server says is still missing.
  Map<String, List<String>>? submitMissing;

  // ---------------------------------------------------------------- steps

  List<BuilderStep> get steps => [
    if (order.planChoice.asks) BuilderStep.plan,
    BuilderStep.photos,
    BuilderStep.scans,
    BuilderStep.rx,
    BuilderStep.submit,
  ];

  int get currentIndex => steps.indexOf(current);

  BuilderStep get firstOpenStep => steps.firstWhere(
    (step) => step != BuilderStep.submit && !isComplete(step),
    orElse: () => BuilderStep.submit,
  );

  bool isComplete(BuilderStep step) {
    if (step == BuilderStep.submit) {
      return order.submittedAt != null ||
          (order.step('submit')?.complete ?? false);
    }
    final known = step.apiKeys.map(order.step).whereType<OrderStep>().toList();
    if (known.isNotEmpty) {
      return known.every((s) => s.complete);
    }
    return switch (step) {
      BuilderStep.plan => order.planChoice.isChosen,
      BuilderStep.photos => takenRequiredPhotos == requiredPhotos,
      BuilderStep.scans => order.scans.every((scan) => scan.file != null),
      BuilderStep.rx =>
        (order.rx.planningPartner ?? '').isNotEmpty &&
            (order.rx.arches ?? '').isNotEmpty,
      BuilderStep.submit => false,
    };
  }

  /// The server's one-line status for a step ("10 of 12 photos").
  String statusOf(BuilderStep step) {
    if (step == BuilderStep.photos) {
      return photoCountLabel;
    }
    return order.step(step.apiKeys.first)?.status ?? '';
  }

  // --------------------------------------------------------------- photos

  int get requiredPhotos => order.photos.where((p) => p.required).length;

  int get takenRequiredPhotos =>
      order.photos.where((p) => p.required && p.isTaken).length;

  /// "11 of 12".
  String get photoCountLabel => '$takenRequiredPhotos of $requiredPhotos';

  /// The photo slots grouped as the API groups them, in the API's order.
  List<MapEntry<String, List<PhotoSlot>>> get photoGroups {
    final groups = <String, List<PhotoSlot>>{};
    for (final photo in order.photos) {
      groups.putIfAbsent(photo.group, () => []).add(photo);
    }
    return groups.entries.toList();
  }

  int slotIndex(String slot) => order.photos.indexWhere((p) => p.slot == slot);

  // -------------------------------------------------------------- missing

  /// Everything still missing before the order can be sent, step by step.
  List<MissingItem> get missing {
    final source = submitMissing ?? order.missing;
    return [
      for (final step in steps)
        if (step != BuilderStep.submit)
          for (final key in step.apiKeys)
            ...?source[key]?.map((text) => MissingItem(step, text)),
    ];
  }

  List<String> missingFor(BuilderStep step) => [
    for (final key in step.apiKeys) ...?order.missing[key],
  ];

  // --------------------------------------------------------- attestations

  bool isTicked(String id) => ticked.contains(id);

  void toggleAttestation(String id) {
    if (!ticked.remove(id)) {
      ticked.add(id);
    }
    notifyListeners();
  }

  bool get allAttested =>
      order.attestations.every((card) => ticked.contains(card.id));

  /// Only the treating doctor may send.
  bool get canSend => userCanSend && order.canSend;

  bool get canSubmit =>
      canSend &&
      order.ready &&
      allAttested &&
      missing.isEmpty &&
      !busy &&
      order.draft;

  // ------------------------------------------------------------ navigation

  Future<void> goTo(BuilderStep step) async {
    if (current == BuilderStep.rx && step != BuilderStep.rx && rxDirty) {
      await saveRx();
    }
    current = step;
    error = null;
    notifyListeners();
    if (step == BuilderStep.scans && scanInbox == null) {
      await loadScans();
    }
  }

  BuilderStep? get nextStep =>
      currentIndex + 1 < steps.length ? steps[currentIndex + 1] : null;

  BuilderStep? get previousStep =>
      currentIndex > 0 ? steps[currentIndex - 1] : null;

  // --------------------------------------------------------------- calls

  void _apply(Order fresh) {
    _order = fresh;
    submitMissing = null;
    if (!rxDirty) {
      rxDraft = fresh.rx;
    }
    ticked.removeWhere(
      (id) => !fresh.attestations.any((card) => card.id == id),
    );
    if (!steps.contains(current)) {
      current = steps.first;
    }
  }

  Future<T?> _run<T>(Future<T> Function() call) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      return await call();
    } on ApiException catch (e) {
      error = e.message;
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await _run(() async => _apply(await api.order(order.id)));
  }

  Future<bool> choosePlan({required String kind, String? audience}) async {
    final fresh = await _run(
      () => api.choosePlan(
        order.id,
        kind: kind,
        audience: kind == 'complete' ? audience : null,
      ),
    );
    if (fresh != null) {
      _apply(fresh);
      notifyListeners();
    }
    return fresh != null;
  }

  /// Uploads a photo into [slot] (replacing what was there) and reloads the order.
  Future<bool> uploadPhoto(
    String slot,
    Uint8List bytes, {
    String filename = 'photo.jpg',
  }) async {
    uploading.add(slot);
    localPhotos[slot] = bytes;
    slotErrors.remove(slot);
    notifyListeners();
    try {
      final file = await api.uploadFile(
        order.id,
        kind: 'photo',
        slot: slot,
        bytes: bytes,
        filename: filename,
      );
      thumbnails[file.id] = bytes;
      _apply(await api.order(order.id));
      return true;
    } on ApiException catch (e) {
      localPhotos.remove(slot);
      slotErrors[slot] = e.message;
      return false;
    } finally {
      uploading.remove(slot);
      notifyListeners();
    }
  }

  /// The picture to show for a slot: just taken, or loaded from the server.
  Uint8List? photoBytes(PhotoSlot photo) {
    final file = photo.file;
    if (file != null && thumbnails[file.id] != null) {
      return thumbnails[file.id];
    }
    return localPhotos[photo.slot];
  }

  Future<void> loadThumbnail(OrderFile file) async {
    if (thumbnails.containsKey(file.id) || !_loadingThumbnails.add(file.id)) {
      return;
    }
    try {
      final bytes = await api.fileBytes(order.id, file.id);
      if (bytes.isNotEmpty) {
        thumbnails[file.id] = bytes;
        notifyListeners();
      }
    } on ApiException {
      // The slot still shows as taken, without a thumbnail.
    } finally {
      _loadingThumbnails.remove(file.id);
    }
  }

  void editRx(Rx rx) {
    rxDraft = rx;
    rxDirty = true;
    notifyListeners();
  }

  /// Adds a quick phrase to the prescription, once.
  void addPhrase(String phrase) {
    final current = (rxDraft.prescription ?? '').trimRight();
    if (current.contains(phrase)) {
      return;
    }
    editRx(
      rxDraft.copyWith(
        prescription: current.isEmpty ? phrase : '$current\n$phrase',
      ),
    );
  }

  void toggleConcern(String value) {
    final concerns = [...rxDraft.concerns];
    if (!concerns.remove(value)) {
      concerns.add(value);
    }
    editRx(rxDraft.copyWith(concerns: concerns));
  }

  Future<bool> saveRx() async {
    final fresh = await _run(() => api.saveRx(order.id, rxDraft));
    if (fresh != null) {
      rxDirty = false;
      _apply(fresh);
      notifyListeners();
    }
    return fresh != null;
  }

  Future<void> loadScans() async {
    loadingScans = true;
    notifyListeners();
    try {
      scanInbox = await api.scans(order.id);
    } on ApiException catch (e) {
      scanInbox = ScanInbox(connected: true, scans: const [], error: e.message);
    } finally {
      loadingScans = false;
      notifyListeners();
    }
  }

  Future<bool> importScan(String scanId) async {
    importingScan = scanId;
    final fresh = await _run(() => api.importScan(order.id, scanId));
    importingScan = null;
    if (fresh != null) {
      _apply(fresh);
      notifyListeners();
      await loadScans();
    }
    return fresh != null;
  }

  /// Sends the order for planning. True when it went through.
  Future<bool> submit() async {
    if (!canSubmit) {
      return false;
    }
    busy = true;
    error = null;
    submitMissing = null;
    notifyListeners();
    try {
      _apply(
        await api.submit(
          order.id,
          order.attestations.map((c) => c.id).where(ticked.contains).toList(),
        ),
      );
      sent = true;
      return true;
    } on ApiException catch (e) {
      error = e.message;
      if (e.missing.isNotEmpty) {
        submitMissing = e.missing;
      }
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
