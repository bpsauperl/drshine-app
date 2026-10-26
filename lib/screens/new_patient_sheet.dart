import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// The countries drShine knows (the server checks the same list).
const List<String> patientCountries = [
  'Slovenia',
  'Croatia',
  'Austria',
  'Italy',
  'Serbia',
  'Bosnia and Herzegovina',
  'North Macedonia',
  'Montenegro',
  'Germany',
];

/// Opens the "New patient" form. Returns the created patient, or null.
Future<Patient?> showNewPatientSheet(BuildContext context) => showModalBottomSheet<Patient>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const NewPatientSheet(),
    );

class NewPatientSheet extends StatefulWidget {
  const NewPatientSheet({super.key});

  @override
  State<NewPatientSheet> createState() => _NewPatientSheetState();
}

class _NewPatientSheetState extends State<NewPatientSheet> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  DateTime? _birthDate;
  String _gender = 'female';
  String _country = patientCountries.first;
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _iso(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      setState(() => _error = const ApiException(422, 'Add the first and last name.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final patient = await AppScope.read(context).api.createPatient(NewPatient(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            birthDate: _iso(_birthDate),
            gender: _gender,
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            country: _country,
          ));
      if (mounted) {
        Navigator.of(context).pop(patient);
      }
    } on ApiException catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    InputDecoration field(String label, String key) =>
        InputDecoration(labelText: label, errorText: _error?.errorFor(key));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Brand.gutter, 0, Brand.gutter, Brand.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New patient', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 18),
            TextField(
              controller: _first,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: field('First name', 'first_name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _last,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: field('Last name', 'last_name'),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: field('Date of birth', 'birth_date').copyWith(suffixIcon: const Icon(Icons.event_outlined)),
                child: Text(
                  _birthDate == null ? 'Optional' : '${_birthDate!.day}. ${_birthDate!.month}. ${_birthDate!.year}',
                  style: TextStyle(color: _birthDate == null ? p.secondary : p.ink),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Gender', style: TextStyle(color: p.secondary)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'female', label: Text('Female')),
                ButtonSegment(value: 'male', label: Text('Male')),
                ButtonSegment(value: 'other', label: Text('Other')),
              ],
              selected: {_gender},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _gender = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: field('Email (optional)', 'email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: field('Phone (optional)', 'phone'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _country,
              decoration: field('Country', 'country'),
              borderRadius: BorderRadius.circular(14),
              items: [for (final c in patientCountries) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _country = v ?? _country),
            ),
            if (_error != null && _error!.errors.isEmpty) ...[
              const SizedBox(height: 14),
              Notice(_error!.message, danger: true, icon: Icons.error_outline),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : const Text('Add patient'),
            ),
          ],
        ),
      ),
    );
  }
}
