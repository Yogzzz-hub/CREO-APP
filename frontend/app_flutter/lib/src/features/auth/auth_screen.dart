// ─────────────────────────────────────────────────────────────────────────────
// AuthScreen – mobile sign-in, sign-up and email verification (OTP).
//
// One screen, three views: signin | signup | verify. Backend calls go through
// AuthRepository / AuthSession; this file only owns form state and layout.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../core/app_appearance.dart';
import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';
import '../splash/splash_screen.dart';

String? validateLoginEmail(String value) {
  final email = value.trim();
  if (email.isEmpty) return 'Enter your email address.';
  // HTML email input semantics; EmailStr on the server remains authoritative.
  if (!RegExp(
    r'''^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?)*$''',
  ).hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? validateLoginPassword(String value) {
  if (value.trim().isEmpty) return 'Enter your password.';
  if (value.runes.length > 128) return 'Use no more than 128 characters.';
  return null; // Existing passwords do not inherit signup strength restrictions.
}

class _ScreenCopy {
  final String title;
  final String Function(String email) lead;
  const _ScreenCopy({required this.title, required this.lead});
}

const _copy = {
  'signin': _ScreenCopy(title: 'Welcome back.', lead: _signinLead),
  'signup': _ScreenCopy(title: 'Create your account.', lead: _signupLead),
  'verify': _ScreenCopy(title: 'Check your inbox.', lead: _verifyLead),
};

String _signinLead(String _) =>
    'Sign in to review this week\'s batch and approve drafts.';
String _signupLead(String _) =>
    'Set up your brand and your first batch lands within 7 days.';
String _verifyLead(String email) =>
    'We sent a 6-digit code to ${email.isNotEmpty ? email : 'your email'}. Enter it to finish creating your account.';

// ── Error model ──────────────────────────────────────────────────────────────
const _accountMethodCodes = {'PASSWORD_NOT_SET', 'ACCOUNT_EXISTS'};

class _AuthNotice {
  final String message;
  final String? code;
  final String? email;
  final List<String> methods;
  const _AuthNotice({
    required this.message,
    this.code,
    this.email,
    this.methods = const [],
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthScreen widget
// ─────────────────────────────────────────────────────────────────────────────

class AuthScreen extends StatefulWidget {
  final String defaultView; // 'signin' | 'signup'
  final AuthRepository? repository;
  final AuthSession? session;
  final ValueChanged<DestinationIntent>? onDestination;
  final String? sessionMessage;
  const AuthScreen({
    super.key,
    this.defaultView = 'signin',
    this.repository,
    this.session,
    this.onDestination,
    this.sessionMessage,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late final AuthRepository _repo;
  late final AuthSession _session;
  final _signInKey = GlobalKey<FormState>();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _formScroll = ScrollController();
  int? _attempt;
  DestinationIntent? _destination;

  // ── Form state ────────────────────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  late String _mode; // 'signin' | 'signup'
  bool _loading = false;
  bool _slowServerWake = false;
  bool _showPassword = false;
  bool _termsAccepted = true;
  bool _registrationPending = false;
  _AuthNotice? _error;

  Timer? _wakeTimer;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? AuthRepository();
    _session =
        widget.session ??
        (widget.repository == null
            ? AuthSession.shared
            : AuthSession(store: _repo.store));
    _mode = widget.defaultView == 'signup' ? 'signup' : 'signin';
  }

  @override
  void dispose() {
    if (_attempt case final attempt?) _session.cancel(attempt);
    if (widget.repository == null) _repo.close();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _formScroll.dispose();
    _wakeTimer?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _fullNameCtrl.dispose();
    _brandCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // ── Mode switching ────────────────────────────────────────────────────
  void _switchMode(String next) {
    if (next == _mode || _loading || _destination != null) return;
    setState(() {
      _mode = next;
      _error = null;
    });
  }

  // ── Error helper ──────────────────────────────────────────────────────
  void _showError(Object err, String fallback, {String? forEmail}) {
    if (!mounted) return;
    if (err is HttpError) {
      final methods =
          (err.details['sign_in_methods'] as List?)
              ?.whereType<String>()
              .toList() ??
          [];
      setState(
        () => _error = _AuthNotice(
          message: err.message.isNotEmpty ? err.message : fallback,
          code: err.code,
          email: forEmail,
          methods: methods,
        ),
      );
    } else {
      setState(() => _error = _AuthNotice(message: fallback));
    }
  }

  // ── Wake-up timer ─────────────────────────────────────────────────────
  void _startWakeTimer() {
    _wakeTimer?.cancel();
    _wakeTimer = Timer(Duration(milliseconds: 3500), () {
      if (mounted) setState(() => _slowServerWake = true);
    });
  }

  void _cancelWakeTimer() {
    _wakeTimer?.cancel();
    if (mounted) setState(() => _slowServerWake = false);
  }

  void _cancelSignIn() {
    if (_attempt case final attempt?) _session.cancel(attempt);
    _attempt = null;
    _cancelWakeTimer();
    setState(() {
      _loading = false;
    });
  }

  Future<void> _signIn() async {
    if (_loading || _destination != null) return;
    if (!_signInKey.currentState!.validate()) {
      if (validateLoginEmail(_emailCtrl.text) != null) {
        _emailFocus.requestFocus();
      } else {
        _passwordFocus.requestFocus();
      }
      return;
    }
    final email = _emailCtrl.text.trim();
    final password =
        _passwordCtrl.text; // Preserve the original credential bytes.
    late int attempt;
    try {
      attempt = _session.beginAttempt();
    } catch (error) {
      _showError(error, 'The saved session needs attention before signing in.');
      return;
    }
    _attempt = attempt;
    setState(() {
      _loading = true;
      _error = null;
    });
    _startWakeTimer();
    try {
      final response = await _repo.loginWithPassword(email, password);
      if (!mounted || !_session.isCurrent(attempt)) return;
      if (!await _session.adopt(response, attempt)) return;
      if (!mounted || !_session.isCurrent(attempt)) return;
      final destination = DestinationIntent.forUser(response.user);
      _passwordCtrl.clear();
      FocusScope.of(context).unfocus();
      TextInput.finishAutofillContext();
      setState(() => _destination = destination);
      widget.onDestination?.call(destination);
    } catch (error) {
      if (!mounted || !_session.isCurrent(attempt)) return;
      _showError(
        error,
        'Sign-in could not be completed or saved. Please try again.',
        forEmail: email,
      );
      if (_formScroll.hasClients) {
        _formScroll.jumpTo(0);
      }
    } finally {
      if (mounted && _attempt == attempt) {
        _cancelWakeTimer();
        setState(() {
          _loading = false;
          _attempt = null;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // handleSubmit – sign-in or register intent
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _handleSubmit() async {
    if (_loading || _destination != null) return;
    if (_mode == 'signin') {
      await _signIn();
      return;
    }
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final fullName = _fullNameCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(
        () => _error = _AuthNotice(
          message: 'Please enter your email and password.',
        ),
      );
      return;
    }
    if (_mode == 'signup' && fullName.isEmpty) {
      setState(
        () => _error = _AuthNotice(message: 'Please enter your full name.'),
      );
      return;
    }
    if (_mode == 'signup' && !_termsAccepted) {
      setState(
        () => _error = _AuthNotice(
          message:
              'Please accept the Terms & Privacy Policy to create an account.',
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _slowServerWake = false;
    });
    _startWakeTimer();

    try {
      {
        final result = await _repo.registerIntent(email, password, fullName);
        if (result.status != 'sent' || !result.emailDelivered) {
          throw Exception(
            'We could not deliver the verification email. Please try again shortly.',
          );
        }
        if (mounted) setState(() => _registrationPending = true);
      }
    } catch (err) {
      if (mounted && _mode == 'signup') {
        setState(() => _registrationPending = false);
      }
      _showError(
        err,
        'Authentication failed. Please verify credentials.',
        forEmail: email,
      );
    } finally {
      _cancelWakeTimer();
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // handleVerify – OTP confirmation
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _handleVerify() async {
    if (_loading) return;
    final otp = _otpCtrl.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(
        () => _error = _AuthNotice(
          message:
              'Please enter the 6-digit verification code sent to your email.',
        ),
      );
      return;
    }

    final attempt = _session.beginAttempt();
    _attempt = attempt;
    setState(() {
      _loading = true;
      _error = null;
    });
    _startWakeTimer();

    try {
      final session = await _repo.verifyRegistration(
        _emailCtrl.text.trim(),
        otp,
        password: _passwordCtrl.text.trim().isNotEmpty
            ? _passwordCtrl.text.trim()
            : null,
        fullName: _fullNameCtrl.text.trim().isNotEmpty
            ? _fullNameCtrl.text.trim()
            : null,
      );
      if (!mounted || !_session.isCurrent(attempt)) return;
      if (await _session.adopt(session, attempt) &&
          mounted &&
          _session.isCurrent(attempt)) {
        _navigateByRole(session.user);
      }
    } catch (err) {
      _showError(err, 'The verification code is invalid or has expired.');
    } finally {
      _cancelWakeTimer();
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // handleResend
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _handleResend() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text.trim();
      final fullName = _fullNameCtrl.text.trim();

      RegistrationCodeResult result;
      if (password.isNotEmpty) {
        result = await _repo.registerIntent(email, password, fullName);
      } else {
        result = await _repo.resendRegistration(email);
      }
      if (result.status != 'sent' || !result.emailDelivered) {
        throw Exception(
          'We could not deliver the verification email. Please try again shortly.',
        );
      }
      _otpCtrl.clear();
    } catch (err) {
      _showError(err, 'Unable to resend the verification code.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Google OAuth
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _startGoogleSignIn() async {
    if (_loading || _destination != null) return;
    setState(() {
      _loading = true;
    });
    try {
      // Use the production callback URL that the React app registers with Google.
      const callbackUrl = 'https://creo.agency/auth/google/callback';
      final url = await _repo.getGoogleAuthUrl(callbackUrl);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // silently ignore – Google URL fetch failed
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Role-based navigation (matches ProtectedRoute.getRoleHome)
  // ─────────────────────────────────────────────────────────────────────
  void _navigateByRole(AuthUser user) {
    final intent = DestinationIntent.forUser(user);
    setState(() => _destination = intent);
    widget.onDestination?.call(intent);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Forgot-password bottom sheet
  // ─────────────────────────────────────────────────────────────────────
  void _openForgotPassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.creo.appSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ForgotPasswordSheet(
        initialEmail: _emailCtrl.text.trim(),
        repo: _repo,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screen = _registrationPending ? 'verify' : _mode;
    final copy = _copy[screen]!;
    final busy = _loading || _destination != null;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: context.creo.appBase,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _formScroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const CreoMark(height: 28),
                      const Spacer(),
                      if (CreoAppearanceScope.maybeOf(context) != null)
                        const CreoThemeToggle(),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Text(
                    copy.title,
                    style: text.headlineLarge?.copyWith(
                      color: context.creo.appInk,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    copy.lead(_emailCtrl.text.trim()),
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 32),

                  if (widget.sessionMessage != null &&
                      _error == null &&
                      !_loading)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(widget.sessionMessage!),
                      ),
                    ),
                  if (_error != null)
                    Semantics(
                      liveRegion: true,
                      child: _buildErrorBanner(_error!),
                    ),
                  if (_destination != null)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Text(
                          'Sign-in accepted. ${_destination!.blocker}',
                          key: const Key('destination-status'),
                        ),
                      ),
                    ),

                  if (_registrationPending)
                    _VerifyForm(
                      otpCtrl: _otpCtrl,
                      loading: _loading,
                      onSubmit: _handleVerify,
                      onResend: _handleResend,
                      onChangeDetails: () => setState(() {
                        _registrationPending = false;
                        _otpCtrl.clear();
                        _error = null;
                      }),
                    )
                  else if (_mode == 'signin')
                    _buildSignInForm(busy)
                  else
                    _buildSignUpForm(busy),

                  const SizedBox(height: 24),
                  _SubmitPill(
                    loading: _loading,
                    onPressed: busy
                        ? null
                        : (_registrationPending
                              ? _handleVerify
                              : _handleSubmit),
                    label: _submitLabel,
                  ),
                  if (_loading && _attempt != null && _mode == 'signin')
                    TextButton(
                      onPressed: _cancelSignIn,
                      child: const Text('Cancel sign-in'),
                    ),
                  if (_loading && _slowServerWake)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'The server was asleep after a quiet spell. Waking it up can take about 30 seconds.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(fontSize: 14),
                      ),
                    ),

                  if (!_registrationPending) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: Divider(color: context.creo.appLine)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or', style: text.bodyMedium),
                        ),
                        Expanded(child: Divider(color: context.creo.appLine)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _GooglePill(onPressed: busy ? null : _startGoogleSignIn),
                    const SizedBox(height: 32),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _mode == 'signin'
                              ? 'New to Creo?'
                              : 'Already have an account?',
                          style: text.bodyMedium,
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => _switchMode(
                                  _mode == 'signin' ? 'signup' : 'signin',
                                ),
                          child: Text(
                            _mode == 'signin' ? 'Create account' : 'Sign in',
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordToggle(bool busy) => IconButton(
    tooltip: _showPassword ? 'Hide password' : 'Show password',
    onPressed: busy
        ? null
        : () => setState(() => _showPassword = !_showPassword),
    icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
  );

  Widget _buildSignInForm(bool busy) {
    return AutofillGroup(
      child: Form(
        key: _signInKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AuthField(
              label: 'Email',
              child: TextFormField(
                key: const Key('login-email'),
                controller: _emailCtrl,
                focusNode: _emailFocus,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                validator: (v) => validateLoginEmail(v ?? ''),
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                decoration: const InputDecoration(
                  hintText: 'name@brand.com',
                  errorMaxLines: 4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _AuthField(
              label: 'Password',
              trailing: TextButton(
                onPressed: busy ? null : _openForgotPassword,
                child: const Text('Forgot password?'),
              ),
              child: TextFormField(
                key: const Key('login-password'),
                controller: _passwordCtrl,
                focusNode: _passwordFocus,
                enabled: !busy,
                obscureText: !_showPassword,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: (v) => validateLoginPassword(v ?? ''),
                onFieldSubmitted: (_) => _signIn(),
                decoration: InputDecoration(
                  hintText: 'Your password',
                  errorMaxLines: 4,
                  suffixIcon: _passwordToggle(busy),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpForm(bool busy) {
    Widget field(
      String label,
      TextEditingController ctrl,
      String hint, {
      TextInputType keyboard = TextInputType.text,
      Iterable<String>? autofill,
      bool password = false,
      String? note,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: _AuthField(
        label: label,
        trailing: note == null
            ? null
            : Text(note, style: Theme.of(context).textTheme.bodySmall),
        child: TextField(
          controller: ctrl,
          enabled: !busy,
          keyboardType: keyboard,
          autofillHints: autofill,
          obscureText: password && !_showPassword,
          autocorrect: !password,
          enableSuggestions: !password,
          textInputAction: password
              ? TextInputAction.done
              : TextInputAction.next,
          onSubmitted: password ? (_) => _handleSubmit() : null,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: password ? _passwordToggle(busy) : null,
          ),
        ),
      ),
    );

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field(
            'Full name',
            _fullNameCtrl,
            'Your full name',
            autofill: const [AutofillHints.name],
          ),
          field(
            'Brand name',
            _brandCtrl,
            'Your brand',
            note: 'Optional',
            autofill: const [AutofillHints.organizationName],
          ),
          field(
            'Email',
            _emailCtrl,
            'name@brand.com',
            keyboard: TextInputType.emailAddress,
            autofill: const [AutofillHints.email],
          ),
          field(
            'Password',
            _passwordCtrl,
            'Choose a password',
            password: true,
            note: '8+ characters',
            autofill: const [AutofillHints.newPassword],
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _termsAccepted,
            onChanged: busy
                ? null
                : (v) => setState(() => _termsAccepted = v ?? false),
            title: Text(
              'I accept the Terms and Privacy Policy',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit label ──────────────────────────────────────────────────────
  String get _submitLabel {
    if (_registrationPending) {
      return _loading ? 'Verifying...' : 'Verify and continue';
    }
    if (_mode == 'signin') {
      if (_loading) {
        return _slowServerWake ? 'Waking up the server...' : 'Signing in...';
      }
      return 'Sign in';
    } else {
      if (_loading) {
        return _slowServerWake
            ? 'Waking up the server...'
            : 'Creating your account...';
      }
      return 'Create account';
    }
  }

  // ── Error banner ──────────────────────────────────────────────────────
  Widget _buildErrorBanner(_AuthNotice notice) {
    final isMethodConflict =
        notice.code != null && _accountMethodCodes.contains(notice.code);
    if (isMethodConflict) {
      return _AccountMethodNotice(
        notice: notice,
        onGoogle: _startGoogleSignIn,
        onForgot: _openForgotPassword,
        onSwitchToSignIn: () => _switchMode('signin'),
        loading: _loading,
      );
    }
    return _ErrorBanner(
      message: notice.message,
      showResetLink: notice.code == 'INVALID_CREDENTIALS',
      onReset: _openForgotPassword,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AuthField extends StatelessWidget {
  final String label;
  final Widget? trailing;
  final Widget child;
  const _AuthField({required this.label, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              ?trailing,
            ],
          ),
        ),
        child,
      ],
    );
  }
}

// ── Verify (OTP) form ────────────────────────────────────────────────────────
class _VerifyForm extends StatelessWidget {
  final TextEditingController otpCtrl;
  final bool loading;
  final VoidCallback onSubmit, onResend, onChangeDetails;
  const _VerifyForm({
    required this.otpCtrl,
    required this.loading,
    required this.onSubmit,
    required this.onResend,
    required this.onChangeDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AuthField(
          label: 'Verification code',
          child: TextField(
            controller: otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: context.creo.appInk,
              letterSpacing: 12,
            ),
            decoration: InputDecoration(hintText: '000000', counterText: ''),
          ),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: loading ? null : onChangeDetails,
              child: Text(
                'Change details',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.creo.appMist.withValues(
                    alpha: loading ? 0.5 : 1,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: loading ? null : onResend,
              child: Text(
                'Resend code',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: loading
                      ? context.creo.accent.withValues(alpha: 0.5)
                      : context.creo.accent,
                  decoration: TextDecoration.underline,
                  decorationColor: context.creo.accent.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Primary submit button ────────────────────────────────────────────────────
class _SubmitPill extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  const _SubmitPill({
    required this.label,
    required this.loading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.creo.onAccent;
    return ElevatedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading) ...[
            SizedBox(
              width: 18,
              height: 18,
              child: MediaQuery.disableAnimationsOf(context)
                  ? Icon(Icons.hourglass_top, size: 18, color: color)
                  : CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

// ── Google outline pill ──────────────────────────────────────────────────────
class _GooglePill extends StatelessWidget {
  final VoidCallback? onPressed;
  const _GooglePill({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _GoogleIcon(),
          SizedBox(width: 10),
          Flexible(
            child: Text('Continue with Google', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Simplified: draw a styled 'G' icon placeholder
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = Color(0xFF4285F4);
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: 'G',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Error banner ─────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  final bool showResetLink;
  final VoidCallback onReset;
  const _ErrorBanner({
    required this.message,
    required this.showResetLink,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: context.creo.errorBg,
        border: Border.all(color: context.creo.errorBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: context.creo.appInk,
              height: 1.5,
            ),
          ),
          if (showResetLink)
            TextButton(onPressed: onReset, child: Text('Reset your password')),
        ],
      ),
    );
  }
}

// ── Account-method conflict notice ───────────────────────────────────────────
class _AccountMethodNotice extends StatelessWidget {
  final _AuthNotice notice;
  final VoidCallback onGoogle;
  final VoidCallback onForgot;
  final VoidCallback onSwitchToSignIn;
  final bool loading;
  const _AccountMethodNotice({
    required this.notice,
    required this.onGoogle,
    required this.onForgot,
    required this.onSwitchToSignIn,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final methods = notice.methods;
    final hasGoogle = methods.contains('google');
    final hasPassword = methods.contains('password');
    final who = (notice.email?.isNotEmpty == true)
        ? notice.email!
        : 'This email';

    final title = notice.code == 'ACCOUNT_EXISTS'
        ? 'You already have a Creo account'
        : hasGoogle
        ? 'This account uses Google sign-in'
        : 'No password set yet';

    final body = notice.code == 'ACCOUNT_EXISTS'
        ? (hasPassword
              ? '$who is already registered. Sign in instead${hasGoogle ? ', or continue with Google' : ''}.'
              : '$who is already registered${hasGoogle ? ' with Google' : ''}. ${hasGoogle ? 'Continue with Google, or set' : 'Set'} a password.')
        : (hasGoogle
              ? '$who was created with Google. Continue with Google, or set a password.'
              : '$who doesn\'t have a password yet. Verify your email to set one.');

    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: context.creo.accent, width: 2),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.creo.accent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  hasGoogle && !hasPassword
                      ? Icons.login
                      : Icons.vpn_key_rounded,
                  size: 18,
                  color: context.creo.onAccent,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.creo.appInk,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        color: context.creo.appMist,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (hasGoogle)
                OutlinedButton(
                  onPressed: loading ? null : onGoogle,
                  child: Text('Continue with Google'),
                ),
              if (notice.code == 'ACCOUNT_EXISTS' && hasPassword)
                OutlinedButton(
                  onPressed: loading ? null : onSwitchToSignIn,
                  child: Text('Sign in instead'),
                ),
              if (!hasPassword)
                OutlinedButton(
                  onPressed: loading ? null : onForgot,
                  child: Text('Set a password'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Forgot-password bottom sheet ─────────────────────────────────────────────
class _ForgotPasswordSheet extends StatefulWidget {
  final String initialEmail;
  final AuthRepository repo;
  const _ForgotPasswordSheet({required this.initialEmail, required this.repo});
  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final TextEditingController _emailCtrl;
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repo.forgotPassword(email);
      setState(() => _sent = true);
    } catch (err) {
      setState(
        () => _error = err is HttpError
            ? err.message
            : 'Unable to send reset email.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        28,
        28,
        28,
        28 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reset your password',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.creo.appInk,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: context.creo.appMist),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 20),
          if (_sent)
            Text(
              "We've sent a password reset link to your email.",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                color: context.creo.appInk,
                height: 1.5,
              ),
            )
          else ...[
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: context.creo.error, fontSize: 15),
              ),
              SizedBox(height: 10),
            ],
            _AuthField(
              label: 'Work email',
              child: TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: context.creo.appInk,
                ),
                decoration: InputDecoration(hintText: 'name@brand.com'),
              ),
            ),
            SizedBox(height: 24),
            _SubmitPill(
              label: _loading ? 'Sending...' : 'Send reset link',
              loading: _loading,
              onPressed: _loading ? null : _submit,
            ),
          ],
        ],
      ),
    );
  }
}
