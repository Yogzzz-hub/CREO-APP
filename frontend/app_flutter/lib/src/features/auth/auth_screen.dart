// ─────────────────────────────────────────────────────────────────────────────
// AuthScreen – Flutter port of frontend/src/pages/auth/AuthPage.tsx
//
// Screens:   signin | signup | verify (OTP)
// Features:
//   • Animated mode-toggle pill (Sign in / Create account)
//   • Underline-style form fields (matches AuthField / FIELD_INPUT)
//   • Password visibility toggle
//   • Remember-me / Accept-terms checkbox
//   • Account-method conflict notice (PASSWORD_NOT_SET / ACCOUNT_EXISTS)
//   • Generic error banner (INVALID_CREDENTIALS → shows "Reset password")
//   • SubmitPill button with spinner + "Waking up server" message after 3.5 s
//   • "Continue with Google" outlined pill
//   • Forgot-password bottom-sheet modal
//   • WhatsApp help link
//   • Brand panel (amber gradient, headline, bullet list)
//   • Fade-in / slide-up animations (respects MediaQuery.disableAnimations)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/app_appearance.dart';
import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';

// ── String constants (mirrors COPY in AuthPage.tsx) ─────────────────────────
const _kWhatsAppUrl = 'https://wa.me/919941999415';

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
  final String eyebrow;
  final String title;
  final String Function(String email) lead;
  final List<String> points;
  const _ScreenCopy({
    required this.eyebrow,
    required this.title,
    required this.lead,
    required this.points,
  });
}

const _copy = {
  'signin': _ScreenCopy(
    eyebrow: 'Client portal',
    title: 'Welcome back.',
    lead: _signinLead,
    points: [
      'Every batch lands in one portal',
      'Approve in one click, or decline with a note',
      'SLA-timed delivery; late batch credited',
    ],
  ),
  'signup': _ScreenCopy(
    eyebrow: 'New account',
    title: 'Start shipping every week.',
    lead: _signupLead,
    points: [
      'A dedicated lead, editor and designer',
      'Brand DNA onboarding on day one',
      'Month-to-month, cancel anytime',
    ],
  ),
  'verify': _ScreenCopy(
    eyebrow: 'One last step',
    title: 'Check your inbox.',
    lead: _verifyLead,
    points: [],
  ),
};

String _signinLead(String _) =>
    'Sign in to review this week\'s batch, approve drafts and keep your pod moving.';
String _signupLead(String _) =>
    'Create your account, add your Brand DNA, and your first batch lands within 7 days.';
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

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
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
  bool _rememberMe = true;
  bool _termsAccepted = true;
  bool _registrationPending = false;
  _AuthNotice? _error;

  Timer? _wakeTimer;

  // ── Animations ────────────────────────────────────────────────────────
  late AnimationController _headlineCtrl;
  late Animation<Offset> _headlineSlide;
  late Animation<double> _headlineFade;

  late AnimationController _leadCtrl;
  late Animation<Offset> _leadSlide;
  late Animation<double> _leadFade;

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

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
    _rememberMe = _mode == 'signin';

    _headlineCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
    _headlineSlide = Tween<Offset>(begin: Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _headlineCtrl, curve: Curves.easeOutExpo),
        );
    _headlineFade = CurvedAnimation(
      parent: _headlineCtrl,
      curve: Curves.easeOut,
    );

    _leadCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
    _leadSlide = Tween<Offset>(
      begin: Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _leadCtrl, curve: Curves.easeOutExpo));
    _leadFade = CurvedAnimation(parent: _leadCtrl, curve: Curves.easeOut);

    _playAnimations(delay: Duration(milliseconds: 100));
  }

  void _playAnimations({Duration delay = Duration.zero}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_reduceMotion) return;
      Future.delayed(delay, () {
        if (!mounted) return;
        _headlineCtrl.forward(from: 0);
        Future.delayed(Duration(milliseconds: 50), () {
          if (mounted && !_reduceMotion) _leadCtrl.forward(from: 0);
        });
      });
    });
  }

  @override
  void dispose() {
    if (_attempt case final attempt?) _session.cancel(attempt);
    if (widget.repository == null) _repo.close();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _formScroll.dispose();
    _wakeTimer?.cancel();
    _headlineCtrl.dispose();
    _leadCtrl.dispose();
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
      _rememberMe = next == 'signin';
      _error = null;
    });
    _playAnimations(delay: Duration(milliseconds: 50));
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
    final email = _emailCtrl.text.trim();

    return Scaffold(
      backgroundColor: context.creo.appBase,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final isWide =
                constraints.maxWidth > 800 &&
                constraints.maxHeight > 620 &&
                MediaQuery.textScalerOf(context).scale(1) < 1.5;
            if (isWide) {
              return Row(
                children: [
                  SizedBox(
                    width: constraints.maxWidth * 0.42,
                    child: _buildBrandPanel(copy, email, screen),
                  ),
                  Expanded(child: _buildFormPanel(copy, screen)),
                ],
              );
            }
            // Mobile: stack brand strip then form
            return SingleChildScrollView(
              controller: _formScroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                children: [
                  _buildBrandStrip(copy, email),
                  _buildFormPanel(copy, screen, embedded: true),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Brand panel (desktop left column) ────────────────────────────────
  Widget _buildBrandPanel(_ScreenCopy copy, String email, String screen) {
    return Container(
      color: CreoColors.accent,
      padding: EdgeInsets.fromLTRB(40, 36, 40, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wordmark
          _Wordmark(),
          SizedBox(height: 48),
          Spacer(),
          // Eyebrow
          Text(
            copy.eyebrow.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: CreoColors.onAccent.withValues(alpha: 0.7),
              letterSpacing: 2.5,
            ),
          ),
          SizedBox(height: 16),
          // Animated headline
          _reduceMotion
              ? Text(
                  copy.title,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: CreoColors.onAccent,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                  ),
                )
              : SlideTransition(
                  position: _headlineSlide,
                  child: FadeTransition(
                    opacity: _headlineFade,
                    child: Text(
                      copy.title,
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(
                            color: CreoColors.onAccent,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                          ),
                    ),
                  ),
                ),
          SizedBox(height: 20),
          // Animated lead
          _reduceMotion
              ? Text(
                  copy.lead(email),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: CreoColors.onAccent.withValues(alpha: 0.75),
                  ),
                )
              : SlideTransition(
                  position: _leadSlide,
                  child: FadeTransition(
                    opacity: _leadFade,
                    child: Text(
                      copy.lead(email),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: CreoColors.onAccent.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
          // Feature bullets
          if (copy.points.isNotEmpty) ...[
            SizedBox(height: 28),

            Divider(color: CreoColors.onAccent.withValues(alpha: 0.15)),
            SizedBox(height: 20),
            ...copy.points.map((p) => _BulletItem(text: p)),
          ],
          Spacer(),
          // Back to site
          _BackToSiteButton(),
        ],
      ),
    );
  }

  // ── Brand strip (mobile top section) ─────────────────────────────────
  Widget _buildBrandStrip(_ScreenCopy copy, String email) {
    return Container(
      color: CreoColors.accent,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 24,
            runSpacing: 12,
            children: [_Wordmark(), _BackToSiteButton()],
          ),
          SizedBox(height: 12),
          Text(
            copy.eyebrow.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: CreoColors.onAccent.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: 6),
          Text(
            copy.title,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: CreoColors.onAccent,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
            ),
          ),
          SizedBox(height: 6),
          Text(
            copy.lead(email),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CreoColors.onAccent.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  // ── Form panel (right on desktop, bottom on mobile) ───────────────────
  Widget _buildFormPanel(
    _ScreenCopy copy,
    String screen, {
    bool embedded = false,
  }) {
    return SingleChildScrollView(
      controller: embedded ? null : _formScroll,
      primary: false,
      physics: embedded ? NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mode toggle pill
              if (CreoAppearanceScope.maybeOf(context) != null) ...[
                const Align(
                  alignment: Alignment.centerRight,
                  child: CreoThemeToggle(),
                ),
                const SizedBox(height: 12),
              ],
              if (!_registrationPending)
                AbsorbPointer(
                  absorbing: _loading || _destination != null,
                  child: _ModeToggle(selected: _mode, onSelect: _switchMode),
                ),
              SizedBox(height: 28),

              if (widget.sessionMessage != null && _error == null && !_loading)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(widget.sessionMessage!),
                  ),
                ),

              // Error / account-method notice
              if (_error != null)
                Semantics(liveRegion: true, child: _buildErrorBanner(_error!)),
              if (_destination != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Text(
                      'Sign-in accepted. ${_destination!.blocker}',
                      key: Key('destination-status'),
                    ),
                  ),
                ),

              // Forms
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
                AutofillGroup(
                  child: Form(
                    key: _signInKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          key: Key('login-email'),
                          controller: _emailCtrl,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: context.creo.appInk,
                          ),
                          focusNode: _emailFocus,
                          enabled: !_loading && _destination == null,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          autocorrect: false,
                          textCapitalization: TextCapitalization.none,
                          validator: (v) => validateLoginEmail(v ?? ''),
                          onFieldSubmitted: (_) =>
                              _passwordFocus.requestFocus(),
                          decoration: InputDecoration(
                            labelText: 'Work email',
                            hintText: 'name@brand.com',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            errorMaxLines: 4,
                          ),
                        ),
                        SizedBox(height: 24),
                        TextFormField(
                          key: Key('login-password'),
                          controller: _passwordCtrl,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: context.creo.appInk,
                          ),
                          focusNode: _passwordFocus,
                          enabled: !_loading && _destination == null,
                          obscureText: !_showPassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          autofillHints: [AutofillHints.password],
                          validator: (v) => validateLoginPassword(v ?? ''),
                          onFieldSubmitted: (_) => _signIn(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            errorMaxLines: 4,
                            suffixIcon: IconButton(
                              tooltip: _showPassword
                                  ? 'Hide password'
                                  : 'Show password',
                              constraints: BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              onPressed: _loading || _destination != null
                                  ? null
                                  : () => setState(
                                      () => _showPassword = !_showPassword,
                                    ),
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading || _destination != null
                                ? null
                                : _openForgotPassword,
                            child: Text('Forgot password?'),
                          ),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text('Keep me signed in'),
                          value: _rememberMe,
                          onChanged: _loading || _destination != null
                              ? null
                              : (v) => setState(() => _rememberMe = v!),
                        ),
                      ],
                    ),
                  ),
                )
              else
                _SignInOrSignUpForm(
                  mode: _mode,
                  emailCtrl: _emailCtrl,
                  passwordCtrl: _passwordCtrl,
                  fullNameCtrl: _fullNameCtrl,
                  brandCtrl: _brandCtrl,
                  showPassword: _showPassword,
                  onTogglePassword: () =>
                      setState(() => _showPassword = !_showPassword),
                  rememberMe: _rememberMe,
                  onRememberMeChanged: (v) => setState(() => _rememberMe = v),
                  termsAccepted: _termsAccepted,
                  onTermsChanged: (v) => setState(() => _termsAccepted = v),
                  onForgotPassword: _openForgotPassword,
                ),

              SizedBox(height: 20),

              // Submit pill (matches SubmitPill from AuthPieces.tsx)
              _SubmitPill(
                loading: _loading,
                onPressed: _loading || _destination != null
                    ? null
                    : (_registrationPending ? _handleVerify : _handleSubmit),
                label: _submitLabel,
              ),
              if (_loading && _attempt != null && _mode == 'signin')
                TextButton(
                  onPressed: _cancelSignIn,
                  child: Text('Cancel sign-in'),
                ),

              // "Waking up server" notice
              if (_loading && _slowServerWake)
                Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'The server was asleep after a quiet spell. Waking it up can take about 30 seconds.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 15),
                  ),
                ),

              // "— or —" divider + Google button
              if (!_registrationPending) ...[
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Divider(color: context.creo.appLine)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    Expanded(child: Divider(color: context.creo.appLine)),
                  ],
                ),
                SizedBox(height: 20),
                _GooglePill(
                  onPressed: _loading || _destination != null
                      ? null
                      : _startGoogleSignIn,
                ),
              ],

              SizedBox(height: 32),

              // WhatsApp help
              Center(child: Text('Need a hand?')),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(_kWhatsAppUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(
                  'Message us on WhatsApp',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
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

class _Wordmark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacementNamed('/');
        }
      },
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
            color: Color(0xFF1A120C),
          ),
          children: [
            TextSpan(text: 'creo'),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Container(
                width: 7,
                height: 7,
                margin: EdgeInsets.only(left: 1, bottom: 2),
                decoration: BoxDecoration(
                  color: Color(0xFF1A120C),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackToSiteButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacementNamed('/');
        }
      },
      icon: Icon(Icons.arrow_back, size: 14, color: Color(0xFF1A120C)),
      label: Text(
        'Back to site',
        style: TextStyle(fontSize: 15, color: Color(0xFF1A120C)),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: Color(0xFF1A120C).withValues(alpha: 0.15),
          width: 2,
        ),
        shape: StadiumBorder(),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            Icons.check,
            size: 15,
            color: Color(0xFF1A120C).withValues(alpha: 0.75),
            weight: 700,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A120C),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mode toggle ──────────────────────────────────────────────────────────────
class _ModeToggle extends StatelessWidget {
  final String selected;
  final void Function(String) onSelect;
  const _ModeToggle({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: context.creo.appLine, width: 2),
      ),
      child: Row(
        children: [
          _ToggleOption('Sign in', 'signin', selected, onSelect),
          _ToggleOption('Create account', 'signup', selected, onSelect),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final void Function(String) onSelect;
  const _ToggleOption(this.label, this.value, this.selected, this.onSelect);

  @override
  Widget build(BuildContext context) {
    final active = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(value),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : Duration(milliseconds: 180),
          curve: Curves.easeOutQuart,
          constraints: BoxConstraints(minHeight: 48),
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? context.creo.appInk : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: active ? context.creo.appBase : context.creo.appMist,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sign-in / Sign-up form ───────────────────────────────────────────────────
class _SignInOrSignUpForm extends StatelessWidget {
  final String mode;
  final TextEditingController emailCtrl, passwordCtrl, fullNameCtrl, brandCtrl;
  final bool showPassword;
  final VoidCallback onTogglePassword;
  final bool rememberMe;
  final void Function(bool) onRememberMeChanged;
  final bool termsAccepted;
  final void Function(bool) onTermsChanged;
  final VoidCallback onForgotPassword;

  const _SignInOrSignUpForm({
    required this.mode,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.fullNameCtrl,
    required this.brandCtrl,
    required this.showPassword,
    required this.onTogglePassword,
    required this.rememberMe,
    required this.onRememberMeChanged,
    required this.termsAccepted,
    required this.onTermsChanged,
    required this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    final isSignUp = mode == 'signup';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isSignUp) ...[
          _AuthField(
            label: 'Full name',
            child: _textInput(
              context,
              fullNameCtrl,
              hint: 'Your full name',
              textInputAction: TextInputAction.next,
            ),
          ),
          SizedBox(height: 24),
          _AuthField(
            label: 'Brand name',
            hint: 'Optional',
            child: _textInput(
              context,
              brandCtrl,
              hint: 'Your brand',
              textInputAction: TextInputAction.next,
            ),
          ),
          SizedBox(height: 24),
        ],
        _AuthField(
          label: 'Work email',
          child: _textInput(
            context,
            emailCtrl,
            hint: 'name@brand.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
        ),
        SizedBox(height: 24),
        _AuthField(
          label: isSignUp ? 'Create password' : 'Password',
          hint: isSignUp ? '8+ characters' : null,
          hintWidget: !isSignUp
              ? GestureDetector(
                  onTap: onForgotPassword,
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(
                      fontSize: 15,
                      color: context.creo.accent,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: context.creo.accent.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                )
              : null,
          child: Row(
            children: [
              Expanded(
                child: _textInput(
                  context,
                  passwordCtrl,
                  hint: isSignUp ? 'Choose a password' : '••••••••',
                  obscure: !showPassword,
                  textInputAction: TextInputAction.done,
                ),
              ),
              GestureDetector(
                onTap: onTogglePassword,
                child: Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    showPassword ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: context.creo.appMist,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        // Checkbox: remember me (signin) | accept terms (signup)
        GestureDetector(
          onTap: () => isSignUp
              ? onTermsChanged(!termsAccepted)
              : onRememberMeChanged(!rememberMe),
          child: Row(
            children: [
              Checkbox(
                value: isSignUp ? termsAccepted : rememberMe,
                onChanged: (v) =>
                    isSignUp ? onTermsChanged(v!) : onRememberMeChanged(v!),
              ),
              SizedBox(width: 10),
              if (isSignUp)
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        color: context.creo.appMist,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(text: 'I accept the '),
                        TextSpan(
                          text: 'Terms',
                          style: TextStyle(
                            color: context.creo.appInk,
                            decoration: TextDecoration.underline,
                            decorationColor: context.creo.appInk.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: context.creo.appInk,
                            decoration: TextDecoration.underline,
                            decorationColor: context.creo.appInk.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Text(
                  'Keep me signed in',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    color: context.creo.appMist,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _textInput(
    BuildContext context,
    TextEditingController ctrl, {
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    TextInputAction textInputAction = TextInputAction.done,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      obscureText: obscure,
      textInputAction: textInputAction,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: context.creo.appInk,
        letterSpacing: -0.4,
      ),
      decoration: InputDecoration(hintText: hint),
    );
  }
}

class _AuthField extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget? hintWidget;
  final Widget child;
  const _AuthField({
    required this.label,
    required this.child,
    this.hint,
    this.hintWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            if (hintWidget != null)
              hintWidget!
            else if (hint != null)
              Text(
                hint!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 14),
              ),
          ],
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

// ── SubmitPill (matches SubmitPill.tsx) ──────────────────────────────────────
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
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 56),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.creo.accent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: MediaQuery.disableAnimationsOf(context)
                          ? Icon(
                              Icons.hourglass_top,
                              size: 20,
                              color: context.creo.onAccent,
                            )
                          : CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                context.creo.onAccent,
                              ),
                            ),
                    )
                  : Icon(
                      Icons.arrow_forward,
                      size: 20,
                      color: context.creo.onAccent,
                    ),
            ),
          ],
        ),
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
