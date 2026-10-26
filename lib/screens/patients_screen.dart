import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shine_kit/shine_kit.dart';

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
      final patients = await AppScope.read(context).api
          .patients(query: _search.text);
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PatientScreen(patientId: patient.id),
      ),
    );
    if (mounted) {
      unawaited(_load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kit;
    final user = AppScope.of(context).user;
    final patients = _patients;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Brand.gutter,
                  10,
                  Brand.gutter,
                  14,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Wordmark(size: 20),
                          const Spacer(),
                          KitRoundButton(
                            icon: Icons.settings_outlined,
                            label: 'Settings',
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const SettingsScreen(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          KitRoundButton(
                            key: const Key('new-patient'),
                            icon: Icons.add_rounded,
                            label: 'New patient',
                            onPressed: _newPatient,
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      if (user?.clinic?.name != null) ...[
                        Text(
                          user!.clinic!.name,
                          style: KitType.eyebrow(color: k.accentText),
                        ),
                        const SizedBox(height: 6),
                      ],
                      const PageTitle('Patients'),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _search,
                        onChanged: _onSearch,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Name or ID',
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear',
                                  icon: const Icon(Icons.close_rounded),
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
                    action: SizedBox(
                      width: 200,
                      child: KitButton.secondary(
                        label: 'Try again',
                        onPressed: _load,
                      ),
                    ),
                  ),
                )
              else if (patients == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (patients.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: CenteredMessage(
                    icon: Icons.people_outline,
                    title: _search.text.isEmpty
                        ? 'No patients yet'
                        : 'No one found',
                    text: _search.text.isEmpty
                        ? 'Add your first patient to start an order.'
                        : 'Try another name or ID.',
                    action: _search.text.isEmpty
                        ? SizedBox(
                            width: 220,
                            child: KitButton(
                              label: 'New patient',
                              icon: Icons.add_rounded,
                              onPressed: _newPatient,
                            ),
                          )
                        : null,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    Brand.gutter,
                    0,
                    Brand.gutter,
                    40,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_loading)
                          const LinearProgressIndicator(minHeight: 2),
                        if (_error != null) ...[
                          Notice(_error!, danger: true),
                          const SizedBox(height: 10),
                        ],
                        KitListGroup(
                          title: _search.text.isEmpty ? 'Recent' : 'Found',
                          children: [
                            for (final patient in patients)
                              _PatientRow(
                                patient: patient,
                                onTap: () => _open(patient),
                              ),
                          ],
                        ),
                      ],
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

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient, required this.onTap});

  final Patient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KitListRow(
      leading: InitialsAvatar(patient.initials, size: 38),
      title: patient.name,
      detail: [
        patient.code,
        if (patient.doctor != null) patient.doctor!.name,
      ].join(' · '),
      state: patient.statusLabel.isEmpty ? null : patient.statusLabel,
      onTap: onTap,
    );
  }
}
