import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shine_kit/shine_kit.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// The device name the server shows in the user's sessions.
String deviceName() {
  if (kIsWeb) {
    return 'drShine web preview';
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'drShine on iPhone',
    TargetPlatform.android => 'drShine on Android',
    _ => 'drShine app',
  };
}

/// Email and password, then the 6-digit two-step code when the server asks.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _server = TextEditingController();
  bool _busy = false;
  bool _showServer = false;
  bool _hidePassword = true;
  String? _error;
  bool _primed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_primed) {
      final state = AppScope.read(context);
      _email.text = state.lastEmail ?? '';
      _server.text = state.serverUrl;
      _primed = true;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _go(Future<void> Function() call) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await call();
    } on ApiException catch (e) {
      _error = e.errorFor('email') ?? e.errorFor('code') ?? e.message;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _signIn() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    final state = AppScope.read(context);
    await _go(() async {
      if (_server.text.trim().isNotEmpty &&
          _server.text.trim() != state.serverUrl) {
        await state.setServer(_server.text);
      }
      final needsCode = await state.signIn(
        email: _email.text,
        password: _password.text,
        device: deviceName(),
      );
      if (needsCode) {
        _password.clear();
        _code.clear();
      }
    });
  }

  Future<void> _confirm() async {
    if (_code.text.trim().length < 6) {
      setState(
        () => _error = 'Enter the 6-digit code from your authenticator app.',
      );
      return;
    }
    final state = AppScope.read(context);
    await _go(() => state.confirmTwoFactor(_code.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = Palette.of(context);
    final askingCode = state.twoFactorChallenge != null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Brand.gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
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
                        askingCode ? 'One more step.' : 'Welcome back.',
                        style: KitType.display(44, color: context.kit.ink),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      askingCode
                          ? 'Enter the 6-digit code from your authenticator app, or a recovery code.'
                          : 'Sign in with your drShine account.',
                      style: KitType.body(color: p.secondary),
                    ),
                    const SizedBox(height: 28),
                    if (!askingCode) ...[
                      TextField(
                        key: const Key('email'),
                        controller: _email,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('password'),
                        controller: _password,
                        enabled: !_busy,
                        obscureText: _hidePassword,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _signIn(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Show password'
                                : 'Hide password',
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _hidePassword = !_hidePassword),
                          ),
                        ),
                      ),
                    ] else
                      TextField(
                        key: const Key('code'),
                        controller: _code,
                        enabled: !_busy,
                        autofocus: true,
                        keyboardType: TextInputType.visiblePassword,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          letterSpacing: 8,
                          fontWeight: FontWeight.w600,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9-]'),
                          ),
                          LengthLimitingTextInputFormatter(21),
                        ],
                        onSubmitted: (_) => _confirm(),
                        decoration: const InputDecoration(hintText: '000000'),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Notice(_error!, danger: true, icon: Icons.error_outline),
                    ],
                    const SizedBox(height: 20),
                    KitButton(
                      key: const Key('sign-in'),
                      label: askingCode ? 'Confirm' : 'Sign in',
                      trailingIcon: Icons.arrow_forward_rounded,
                      busy: _busy,
                      onPressed: askingCode ? _confirm : _signIn,
                    ),
                    if (askingCode)
                      TextButton(
                        onPressed: _busy ? null : state.cancelTwoFactor,
                        child: const Text('Use another account'),
                      ),
                    const SizedBox(height: 28),
                    if (!askingCode) _serverSection(p),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _serverSection(Palette p) {
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
            decoration: const InputDecoration(labelText: 'Server address'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() => _server.text = defaultServerUrl),
            child: const Text('Use the default server'),
          ),
        ],
      ],
    );
  }
}
