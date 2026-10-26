/// The JSON shapes of the drShine app API (contract v1, section A).
///
/// Every `fromJson` is forgiving: missing or null fields fall back to empty
/// values, so a newer backend that adds fields never breaks the app.
library;

typedef Json = Map<String, dynamic>;

String _str(Object? value) => value == null ? '' : '$value';
String? _strOrNull(Object? value) => value == null ? null : '$value';
bool _bool(Object? value) => value == true || value == 1 || value == '1';
int? _intOrNull(Object? value) => switch (value) {
      int v => v,
      num v => v.round(),
      String v => int.tryParse(v),
      _ => null,
    };
Json _map(Object? value) => value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};
List<Json> _list(Object? value) =>
    value is List ? value.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList() : <Json>[];
List<String> _strings(Object? value) => value is List ? value.map((v) => '$v').toList() : <String>[];
DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse('$value');

/// A small `{id, name}` reference (clinic, doctor).
class Ref {
  const Ref({required this.id, required this.name});

  final String id;
  final String name;

  static Ref? maybe(Object? json) {
    if (json is! Map) {
      return null;
    }
    final m = _map(json);
    return Ref(id: _str(m['id']), name: _str(m['name']));
  }
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.roleLabel,
    required this.canSend,
    this.clinic,
  });

  factory User.fromJson(Json json) => User(
        id: _str(json['id']),
        name: _str(json['name']),
        email: _str(json['email']),
        role: _str(json['role']),
        roleLabel: _str(json['role_label']),
        canSend: _bool(json['can_send']),
        clinic: Ref.maybe(json['clinic']),
      );

  final String id;
  final String name;
  final String email;
  final String role;
  final String roleLabel;

  /// True for treating doctors: only they send orders; assistants prepare.
  final bool canSend;
  final Ref? clinic;
}

/// What `POST /login` answers: a token and user, or a two-step challenge.
class LoginResult {
  const LoginResult({this.token, this.user, this.challenge});

  factory LoginResult.fromJson(Json json) => _bool(json['two_factor'])
      ? LoginResult(challenge: _str(json['challenge']))
      : LoginResult(token: _str(json['token']), user: User.fromJson(_map(json['user'])));

  final String? token;
  final User? user;
  final String? challenge;

  bool get needsTwoFactor => challenge != null;
}

class Patient {
  const Patient({
    required this.id,
    required this.code,
    required this.name,
    required this.firstName,
    required this.lastName,
    required this.status,
    required this.statusLabel,
    this.birthDate,
    this.doctor,
    this.clinic,
    this.isMinor = false,
  });

  factory Patient.fromJson(Json json) => Patient(
        id: _str(json['id']),
        code: _str(json['code']),
        name: _str(json['name']),
        firstName: _str(json['first_name']),
        lastName: _str(json['last_name']),
        birthDate: _strOrNull(json['birth_date']),
        status: _str(json['status']),
        statusLabel: _str(json['status_label']),
        doctor: Ref.maybe(json['doctor']),
        clinic: Ref.maybe(json['clinic']),
        isMinor: _bool(json['is_minor']),
      );

  final String id;
  final String code;
  final String name;
  final String firstName;
  final String lastName;
  final String? birthDate;
  final String status;
  final String statusLabel;
  final Ref? doctor;
  final Ref? clinic;
  final bool isMinor;

  String get initials {
    final letters = [firstName, lastName].where((p) => p.isNotEmpty).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty && name.isNotEmpty ? name[0].toUpperCase() : letters;
  }
}

/// The fields of `POST /patients`.
class NewPatient {
  const NewPatient({
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.country,
    this.birthDate,
    this.email,
    this.phone,
  });

  final String firstName;
  final String lastName;

  /// `female`, `male` or `other`.
  final String gender;
  final String country;

  /// ISO date, `2012-05-01`.
  final String? birthDate;
  final String? email;
  final String? phone;

  Json toJson() => {
        'first_name': firstName,
        'last_name': lastName,
        'gender': gender,
        'country': country,
        if (birthDate != null && birthDate!.isNotEmpty) 'birth_date': birthDate,
        if (email != null && email!.isNotEmpty) 'email': email,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
      };
}

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.reference,
    required this.type,
    required this.typeLabel,
    required this.status,
    required this.statusLabel,
    required this.journeyLabel,
    required this.draft,
    this.series,
    this.createdAt,
    this.submittedAt,
  });

  factory OrderSummary.fromJson(Json json) => OrderSummary(
        id: _str(json['id']),
        reference: _str(json['reference']),
        type: _str(json['type']),
        typeLabel: _str(json['type_label']),
        series: _intOrNull(json['series']),
        status: _str(json['status']),
        statusLabel: _str(json['status_label']),
        journeyLabel: _str(json['journey_label']),
        createdAt: _date(json['created_at']),
        submittedAt: _date(json['submitted_at']),
        draft: _bool(json['draft']),
      );

  final String id;
  final String reference;
  final String type;
  final String typeLabel;
  final int? series;
  final String status;
  final String statusLabel;
  final String journeyLabel;
  final DateTime? createdAt;
  final DateTime? submittedAt;
  final bool draft;

  bool get isAligners => type == 'aligner_series';
}

class PatientDetail {
  const PatientDetail({required this.patient, required this.orders});

  factory PatientDetail.fromJson(Json json) => PatientDetail(
        patient: Patient.fromJson(_map(json['patient'])),
        orders: _list(json['orders']).map(OrderSummary.fromJson).toList(),
      );

  final Patient patient;
  final List<OrderSummary> orders;
}

class OrderStep {
  const OrderStep({required this.key, required this.label, required this.complete, required this.status});

  factory OrderStep.fromJson(Json json) => OrderStep(
        key: _str(json['key']),
        label: _str(json['label']),
        complete: _bool(json['complete']),
        status: _str(json['status']),
      );

  final String key;
  final String label;
  final bool complete;
  final String status;
}

class PlanChoice {
  const PlanChoice({required this.asks, this.kind, this.audience});

  factory PlanChoice.fromJson(Json json) => PlanChoice(
        asks: _bool(json['asks']),
        kind: _strOrNull(json['kind']),
        audience: _strOrNull(json['audience']),
      );

  final bool asks;

  /// `complete` or `flexible`; null until chosen.
  final String? kind;

  /// `adult` or `growing` for Complete; null for Flexible.
  final String? audience;

  bool get isChosen => kind == 'flexible' || (kind == 'complete' && audience != null);
}

class OrderFile {
  const OrderFile({required this.id, required this.name, required this.url, this.slot});

  factory OrderFile.fromJson(Json json) => OrderFile(
        id: _str(json['id']),
        name: _str(json['name']),
        url: _str(json['url']),
        slot: _strOrNull(json['slot']),
      );

  static OrderFile? maybe(Object? json) => json is Map ? OrderFile.fromJson(_map(json)) : null;

  final String id;
  final String name;
  final String url;
  final String? slot;
}

class PhotoSlot {
  const PhotoSlot({
    required this.slot,
    required this.label,
    required this.group,
    required this.required,
    required this.guide,
    this.file,
  });

  factory PhotoSlot.fromJson(Json json) => PhotoSlot(
        slot: _str(json['slot']),
        label: _str(json['label']),
        group: _str(json['group']),
        required: _bool(json['required']),
        guide: _str(json['guide']),
        file: OrderFile.maybe(json['file']),
      );

  final String slot;
  final String label;
  final String group;
  final bool required;

  /// The key of the app's own outline drawing.
  final String guide;
  final OrderFile? file;

  bool get isTaken => file != null;
}

class ScanSlot {
  const ScanSlot({required this.slot, required this.label, this.file});

  factory ScanSlot.fromJson(Json json) =>
      ScanSlot(slot: _str(json['slot']), label: _str(json['label']), file: OrderFile.maybe(json['file']));

  final String slot;
  final String label;
  final OrderFile? file;
}

class Rx {
  const Rx({this.planningPartner, this.arches, this.concerns = const [], this.treatmentGoal, this.prescription});

  factory Rx.fromJson(Json json) => Rx(
        planningPartner: _strOrNull(json['planning_partner']),
        arches: _strOrNull(json['arches']),
        concerns: _strings(json['concerns']),
        treatmentGoal: _strOrNull(json['treatment_goal']),
        prescription: _strOrNull(json['prescription']),
      );

  final String? planningPartner;
  final String? arches;
  final List<String> concerns;
  final String? treatmentGoal;
  final String? prescription;

  Json toJson() => {
        'planning_partner': planningPartner,
        'arches': arches,
        'concerns': concerns,
        'treatment_goal': treatmentGoal,
        'prescription': prescription,
      };

  Rx copyWith({
    String? planningPartner,
    String? arches,
    List<String>? concerns,
    String? treatmentGoal,
    String? prescription,
  }) =>
      Rx(
        planningPartner: planningPartner ?? this.planningPartner,
        arches: arches ?? this.arches,
        concerns: concerns ?? this.concerns,
        treatmentGoal: treatmentGoal ?? this.treatmentGoal,
        prescription: prescription ?? this.prescription,
      );
}

class Option {
  const Option({required this.value, required this.label, this.description});

  factory Option.fromJson(Json json) => Option(
        value: _str(json['value']),
        label: _str(json['label']),
        description: _strOrNull(json['description']),
      );

  final String value;
  final String label;
  final String? description;
}

class OrderOptions {
  const OrderOptions({this.partners = const [], this.arches = const [], this.concerns = const []});

  factory OrderOptions.fromJson(Json json) => OrderOptions(
        partners: _list(json['partners']).map(Option.fromJson).toList(),
        arches: _list(json['arches']).map(Option.fromJson).toList(),
        concerns: _list(json['concerns']).map(Option.fromJson).toList(),
      );

  final List<Option> partners;
  final List<Option> arches;
  final List<Option> concerns;
}

class PriceLine {
  const PriceLine({required this.label, this.detail, this.amountCents});

  factory PriceLine.fromJson(Json json) => PriceLine(
        label: _str(json['label']),
        detail: _strOrNull(json['detail']),
        amountCents: _intOrNull(json['amount_cents']),
      );

  final String label;
  final String? detail;
  final int? amountCents;
}

class Attestation {
  const Attestation({required this.id, required this.title, required this.text});

  factory Attestation.fromJson(Json json) =>
      Attestation(id: _str(json['id']), title: _str(json['title']), text: _str(json['text']));

  final String id;
  final String title;
  final String text;
}

/// The full Aligners order: everything the case builder needs.
class Order {
  const Order({
    required this.id,
    required this.reference,
    required this.type,
    required this.status,
    required this.statusLabel,
    required this.draft,
    required this.canSend,
    required this.steps,
    required this.planChoice,
    required this.photos,
    required this.scans,
    required this.rx,
    required this.options,
    required this.missing,
    required this.ready,
    required this.priceLines,
    required this.attestations,
    this.series,
    this.totalCents,
    this.submittedAt,
  });

  factory Order.fromJson(Json json) {
    final missing = <String, List<String>>{};
    final rawMissing = json['missing'];
    if (rawMissing is Map) {
      rawMissing.forEach((key, value) => missing['$key'] = _strings(value));
    }
    return Order(
      id: _str(json['id']),
      reference: _str(json['reference']),
      type: _str(json['type']),
      series: _intOrNull(json['series']),
      status: _str(json['status']),
      statusLabel: _str(json['status_label']),
      draft: _bool(json['draft']),
      canSend: _bool(json['can_send']),
      steps: _list(json['steps']).map(OrderStep.fromJson).toList(),
      planChoice: PlanChoice.fromJson(_map(json['plan_choice'])),
      photos: _list(json['photos']).map(PhotoSlot.fromJson).toList(),
      scans: _list(json['scans']).map(ScanSlot.fromJson).toList(),
      rx: Rx.fromJson(_map(json['rx'])),
      options: OrderOptions.fromJson(_map(json['options'])),
      missing: missing,
      ready: _bool(json['ready']),
      priceLines: _list(json['price_lines']).map(PriceLine.fromJson).toList(),
      totalCents: _intOrNull(json['total_cents']),
      attestations: _list(json['attestations']).map(Attestation.fromJson).toList(),
      submittedAt: _date(json['submitted_at']),
    );
  }

  final String id;
  final String reference;
  final String type;
  final int? series;
  final String status;
  final String statusLabel;
  final bool draft;
  final bool canSend;
  final List<OrderStep> steps;
  final PlanChoice planChoice;
  final List<PhotoSlot> photos;
  final List<ScanSlot> scans;
  final Rx rx;
  final OrderOptions options;

  /// What is still missing, per step key (`photos`, `impressions`, `rx`…).
  final Map<String, List<String>> missing;
  final bool ready;
  final List<PriceLine> priceLines;
  final int? totalCents;
  final List<Attestation> attestations;
  final DateTime? submittedAt;

  OrderStep? step(String key) {
    for (final step in steps) {
      if (step.key == key) {
        return step;
      }
    }
    return null;
  }
}

/// One scan waiting in the clinic's Scan Hub inbox.
class HubScan {
  const HubScan({required this.id, required this.source, required this.jaws, this.patientName, this.takenAt, this.match});

  factory HubScan.fromJson(Json json) => HubScan(
        id: _str(json['id']),
        source: _str(json['source']),
        patientName: _strOrNull(json['patient_name']),
        takenAt: _date(json['taken_at']),
        jaws: _strings(json['jaws']),
        match: _strOrNull(json['match']),
      );

  final String id;
  final String source;
  final String? patientName;
  final DateTime? takenAt;
  final List<String> jaws;
  final String? match;
}

class ScanInbox {
  const ScanInbox({required this.connected, required this.scans, this.error});

  factory ScanInbox.fromJson(Json json) => ScanInbox(
        connected: _bool(json['connected']),
        scans: _list(json['scans']).map(HubScan.fromJson).toList(),
        error: _strOrNull(json['error']),
      );

  final bool connected;
  final List<HubScan> scans;
  final String? error;
}
