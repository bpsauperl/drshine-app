import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'new_patient_sheet.dart';
import 'patient_screen.dart';
import 'settings_screen.dart';

/// The patients you may see, newest first, with search and "New patient".
class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Patient>? _patients;
  String? _error;
  bool _loading = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final patients = await AppScope.read(context).api.patients(query: _search.text);
      if (mounted && request == _request) {
        setState(() => _patients = patients);
      }
    } on ApiException catch (e) {
      if (mounted && request == _request) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted && request == _request) {
        setState(() => _loading = false);
      }
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
    setState(() {});
  }

  Future<void> _newPatient() async {
    final patient = await showNewPatientSheet(context);
    if (patient != null && mounted) {
      await _open(patient);
    }
  }

  Future<void> _open(Patient patient) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PatientScreen(patientId: patient.id)));
    if (mounted) {
      unawaited(_load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final user = AppScope.of(context).user;
    final patients = _patients;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Wordmark(size: 24),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-patient'),
        onPressed: _newPatient,
        backgroundColor: p.accentFill,
        foregroundColor: Colors.white,
        elevation: 1,
        icon: const Icon(Icons.add),
        label: const Text('New patient', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 12),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PageTitle('Patients', subtitle: user?.clinic?.name),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _search,
                      onChanged: _onSearch,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search by name or ID',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear',
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _search.clear();
                                  _onSearch('');
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null && patients == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: CenteredMessage(
                  icon: Icons.cloud_off_outlined,
                  title: "Couldn't load patients",
                  text: _error,
                  action: OutlinedButton(onPressed: _load, child: const Text('Try again')),
                ),
              )
            else if (patients == null)
              const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
            else if (patients.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: CenteredMessage(
                  icon: Icons.people_outline,
                  title: _search.text.isEmpty ? 'No patients yet' : 'No one found',
                  text: _search.text.isEmpty ? 'Add your first patient to start an order.' : 'Try another name or ID.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Brand.gutter, 0, Brand.gutter, 100),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      if (_loading) const LinearProgressIndicator(minHeight: 2),
                      if (_error != null) ...[Notice(_error!, danger: true), const SizedBox(height: 10)],
                      Tile(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < patients.length; i++) ...[
                              if (i > 0) const Divider(indent: 72),
                              _PatientRow(patient: patients[i], onTap: () => _open(patients[i])),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient, required this.onTap});

  final Patient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            InitialsAvatar(patient.initials),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    [patient.code, if (patient.doctor != null) patient.doctor!.name].join(' · '),
                    style: TextStyle(color: p.secondary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (patient.statusLabel.isNotEmpty) Pill(patient.statusLabel),
            Icon(Icons.chevron_right, color: p.secondary),
          ],
        ),
      ),
    );
  }
}
