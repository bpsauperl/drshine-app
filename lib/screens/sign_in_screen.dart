import 'package:flutter/material.dart';
import 'package:shine_kit/shine_kit.dart';

import '../api/api_client.dart';
import '../auth/browser_sign_in.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Sign in with SmileID in the system sheet: the only way in. The app has no
/// email, password or code fields of its own.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _server = TextEditingController();
  bool _busy = false;
  bool _showServer = false;

  /// A calm line above the SmileID button: why the app is back on sign-in.
  String? _notice;
  String? _error;
  bool _primed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_primed) {
      final state = AppScope.read(context);
      _server.text = state.serverUrl;
      _notice = state.takeSignInNotice();
      _primed = true;
    }
  }

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  Future<void> _go(Future<void> Function() call) async {
    setState(() {
      _busy = true;
      _notice = null;
      _error = null;
    });
    String? failure;
    try {
      await call();
    } on ApiException catch (e) {
      failure = e.errorFor('ticket') ?? e.message;
    } on SignInException catch (e) {
      failure = e.message;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = failure;
        });
      }
    }
  }

  /// Takes the address in the Server field into use, if it changed.
  Future<void> _applyServer(AppState state) async {
    final typed = _server.text.trim();
    if (typed.isNotEmpty && typed != state.serverUrl) {
      await state.setServer(typed);
    }
  }

  Future<void> _signInWithSmileId({bool another = false}) async {
    final state = AppScope.read(context);
    if (state.browser == null) {
      setState(() {
        _notice = webPreviewSentence;
        _error = null;
      });
      return;
    }
    await _go(() async {
      await _applyServer(state);
      await state.signInWithSmileId(another: another);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = Palette.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Brand.gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Wordmark(size: 22),
                  ),
                  // The arch only where there is room (not on small screens or over the keyboard).
                  if (MediaQuery.sizeOf(context).height -
                          MediaQuery.viewInsetsOf(context).bottom >=
                      720)
                    const KitArchHero(height: 190)
                  else
                    const SizedBox(height: 28),
                  Text(
                    'For Shine clinics',
                    style: KitType.eyebrow(color: context.kit.accentText),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    header: true,
                    child: Text(
                      'Welcome back.',
                      style: KitType.display(44, color: context.kit.ink),
                    ),
                  ),
                  ..._smileIdStep(state, p),
                  const SizedBox(height: 20),
                  _serverSection(state, p),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The only way in: one button that opens SmileID in the system sheet.
  List<Widget> _smileIdStep(AppState state, Palette p) => [
    const SizedBox(height: 24),
    if (_notice != null) ...[Notice(_notice!), const SizedBox(height: 14)],
    if (_error != null) ...[
      Notice(_error!, danger: true, icon: Icons.error_outline),
      const SizedBox(height: 14),
    ] else if (state.smileIdMissing) ...[
      Notice(smileIdErrorSentence('not_ready')),
      const SizedBox(height: 14),
    ],
    KitButton(
      key: const Key('smileid'),
      label: 'Sign in with SmileID',
      trailingIcon: Icons.arrow_forward_rounded,
      busy: _busy,
      onPressed: _busy ? null : _signInWithSmileId,
    ),
    const SizedBox(height: 14),
    Text(
      'Face ID, Touch ID or a code by email. One account for every SmileLabs app.',
      textAlign: TextAlign.center,
      style: KitType.body(color: p.secondary),
    ),
    const SizedBox(height: 10),
    TextButton(
      key: const Key('smileid-another'),
      onPressed: _busy ? null : () => _signInWithSmileId(another: true),
      child: const Text('Use another SmileID'),
    ),
  ];

  /// The server address the SmileID button signs in to.
  Widget _serverSection(AppState state, Palette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          key: const Key('server-toggle'),
          onPressed: () => setState(() => _showServer = !_showServer),
          icon: Icon(
            _showServer ? Icons.expand_less : Icons.dns_outlined,
            size: 18,
          ),
          label: const Text('Server'),
          style: TextButton.styleFrom(foregroundColor: p.secondary),
        ),
        if (_showServer) ...[
          const SizedBox(height: 6),
          TextField(
            key: const Key('server'),
            controller: _server,
            enabled: !_busy,
            keyboardType: TextInputType.url,
            autocorrect: false,
            // Done on the keyboard asks the new server whether it has SmileID.
            onSubmitted: (_) => _applyServer(state),
            decoration: const InputDecoration(labelText: 'Server address'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    setState(() => _server.text = defaultServerUrl);
                    _applyServer(state);
                  },
            child: const Text('Use the default server'),
          ),
        ],
      ],
    );
  }
}
