import 'package:flutter/material.dart';
import 'package:shine_kit/shine_kit.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../auth/browser_sign_in.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// What the screen is waiting for, so the right button shows the spinner.
enum _Doing { smileId, password }

/// Sign in with SmileID in the system sheet. While the server still takes
/// drShine passwords, a link opens email and password, then the 6-digit
/// two-step code when the server asks.
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
  _Doing? _doing;
  bool _showServer = false;
  bool _hidePassword = true;

  /// Whether the password form is open; null until the user chooses.
  bool? _showPassword;

  /// A calm line above the SmileID button: why the app is back on sign-in.
  String? _notice;
  String? _smileIdError;
  String? _error;
  bool _primed = false;

  bool get _busy => _doing != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_primed) {
      final state = AppScope.read(context);
      _email.text = state.lastEmail ?? '';
      _server.text = state.serverUrl;
      _notice = state.takeSignInNotice();
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

  Future<void> _go(_Doing doing, Future<void> Function() call) async {
    setState(() {
      _doing = doing;
      _notice = null;
      _smileIdError = null;
      _error = null;
    });
    String? failure;
    try {
      await call();
    } on ApiException catch (e) {
      failure =
          e.errorFor('email') ??
          e.errorFor('code') ??
          e.errorFor('ticket') ??
          e.message;
    } on SignInException catch (e) {
      failure = e.message;
    } finally {
      if (mounted) {
        setState(() {
          _doing = null;
          if (doing == _Doing.smileId) {
            _smileIdError = failure;
          } else {
            _error = failure;
          }
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
        _smileIdError = null;
      });
      return;
    }
    await _go(_Doing.smileId, () async {
      await _applyServer(state);
      await state.signInWithSmileId(another: another);
    });
  }

  Future<void> _signIn() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    final state = AppScope.read(context);
    await _go(_Doing.password, () async {
      await _applyServer(state);
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
    await _go(_Doing.password, () => state.confirmTwoFactor(_code.text.trim()));
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
                    if (askingCode)
                      ..._codeStep(state, p)
                    else ...[
                      ..._smileIdStep(p),
                      ..._passwordStep(state, p),
                      const SizedBox(height: 20),
                      _serverSection(state, p),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The main way in: one button that opens SmileID in the system sheet.
  List<Widget> _smileIdStep(Palette p) => [
    const SizedBox(height: 24),
    if (_notice != null) ...[Notice(_notice!), const SizedBox(height: 14)],
    if (_smileIdError != null) ...[
      Notice(_smileIdError!, danger: true, icon: Icons.error_outline),
      const SizedBox(height: 14),
    ],
    KitButton(
      key: const Key('smileid'),
      label: 'Sign in with SmileID',
      trailingIcon: Icons.arrow_forward_rounded,
      busy: _doing == _Doing.smileId,
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

  /// Email and password, behind a link, only while the server takes passwords.
  List<Widget> _passwordStep(AppState state, Palette p) {
    if (!state.passwordAllowed) {
      return const [];
    }
    // A server without SmileID has only this way in, so it starts open.
    final open = _showPassword ?? !(state.signInOptions?.smileId ?? true);
    return [
      TextButton(
        key: const Key('password-toggle'),
        onPressed: _busy ? null : () => setState(() => _showPassword = !open),
        style: TextButton.styleFrom(foregroundColor: p.secondary),
        child: const Text('Use your drShine password'),
      ),
      if (open) ...[
        const SizedBox(height: 10),
        TextField(
          key: const Key('email'),
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
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
              tooltip: _hidePassword ? 'Show password' : 'Hide password',
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Notice(_error!, danger: true, icon: Icons.error_outline),
        ],
        const SizedBox(height: 20),
        // Secondary: Sign in with SmileID stays the screen's main button.
        KitButton.secondary(
          key: const Key('sign-in'),
          label: 'Sign in',
          trailingIcon: Icons.arrow_forward_rounded,
          busy: _doing == _Doing.password,
          onPressed: _busy ? null : _signIn,
        ),
      ],
    ];
  }

  /// The 6-digit two-step code after a password, as before.
  List<Widget> _codeStep(AppState state, Palette p) => [
    const SizedBox(height: 10),
    Text(
      'Enter the 6-digit code from your authenticator app, or a recovery code.',
      style: KitType.body(color: p.secondary),
    ),
    const SizedBox(height: 28),
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
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
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
      label: 'Confirm',
      trailingIcon: Icons.arrow_forward_rounded,
      busy: _busy,
      onPressed: _confirm,
    ),
    TextButton(
      onPressed: _busy ? null : state.cancelTwoFactor,
      child: const Text('Use another account'),
    ),
  ];

  /// The server address. It counts for the SmileID button and the password alike.
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
            // Done on the keyboard asks the new server what it takes.
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
