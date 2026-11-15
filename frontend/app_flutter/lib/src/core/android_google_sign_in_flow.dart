import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_repository.dart';
import 'auth_session.dart';
import 'google_sign_in_flow.dart';

abstract interface class AndroidGoogleIdentity {
  Future<String> serverCode(String serverClientId);
}

/// Google's SDK resolves the Android client from the installed package and SHA.
/// The web client is the audience of the one-use code exchanged by our server.
class SdkAndroidGoogleIdentity implements AndroidGoogleIdentity {
  static Future<void>? _initialization;
  static String? _serverClientId;
  static bool _pending = false;

  @override
  Future<String> serverCode(String serverClientId) async {
    if (_pending) {
      throw const HttpError(
        status: 0,
        code: 'REQUEST_PENDING',
        message:
            'Close the previous Google account picker before starting again.',
      );
    }
    _pending = true;
    try {
      if (_serverClientId != null && _serverClientId != serverClientId) {
        throw const HttpError(
          status: 0,
          code: 'GOOGLE_CONFIGURATION_ERROR',
          message: 'Google configuration changed. Please restart the app.',
        );
      }
      if (_initialization == null) {
        _serverClientId = serverClientId;
        _initialization = GoogleSignIn.instance.initialize(
          serverClientId: serverClientId,
        );
      }
      try {
        await _initialization;
      } catch (_) {
        _initialization = null;
        _serverClientId = null;
        rethrow;
      }
      // An explicit sign-in always gives the user control over account selection.
      await GoogleSignIn.instance.signOut();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['openid', 'email', 'profile'],
      );
      final authorization = await account.authorizationClient.authorizeServer(
        const ['openid', 'email', 'profile'],
      );
      final code = authorization?.serverAuthCode;
      if (code == null || code.isEmpty) {
        throw const HttpError(
          status: 0,
          code: 'GOOGLE_AUTHORIZATION_MISSING',
          message: 'Google did not authorize server sign-in. Please try again.',
        );
      }
      return code;
    } on GoogleSignInException catch (error) {
      final cancelled = error.code == GoogleSignInExceptionCode.canceled;
      final configuration =
          error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError;
      throw HttpError(
        status: 0,
        code: cancelled
            ? 'GOOGLE_CANCELLED'
            : configuration
            ? 'GOOGLE_CONFIGURATION_ERROR'
            : 'GOOGLE_UNAVAILABLE',
        message: cancelled
            ? 'Google sign-in was cancelled. If this repeats after choosing an account, check the Android package and signing certificate registration.'
            : configuration
            ? 'Google could not recognize this Android build. Check its package, signing certificate and OAuth project.'
            : 'Google sign-in could not finish. Check your connection and try again.',
      );
    } finally {
      _pending = false;
    }
  }
}

class AndroidGoogleSignInFlow implements GoogleAuthFlow {
  AndroidGoogleSignInFlow({
    required this.session,
    required this.repository,
    AndroidGoogleIdentity? identity,
    Future<String> Function()? loadRegistration,
    this.timeout = const Duration(minutes: 3),
  }) : identity = identity ?? SdkAndroidGoogleIdentity(),
       loadRegistration =
           loadRegistration ??
           (() => rootBundle.loadString(
             'assets/auth/google_android_client.json',
           )) {
    session.addListener(_sessionChanged);
  }
  final AuthSession session;
  final AuthRepository repository;
  final AndroidGoogleIdentity identity;
  final Future<String> Function() loadRegistration;
  final Duration timeout;
  Completer<AuthUser>? _pending;
  int? _generation;
  Timer? _timer;
  bool _disposed = false, _adopting = false;

  void _sessionChanged() {
    final generation = _generation;
    if (generation != null && !session.isCurrent(generation)) cancel();
  }

  @override
  Future<AuthUser> signIn() {
    if (_disposed || session.current != null) {
      return Future.error(
        const HttpError(
          status: 0,
          code: 'ACCOUNT_SWITCH_REQUIRED',
          message: 'Sign out before choosing another Google account.',
        ),
      );
    }
    if (_pending != null) {
      return Future.error(
        const HttpError(
          status: 0,
          code: 'REQUEST_PENDING',
          message: 'Google sign-in is already in progress.',
        ),
      );
    }
    final generation = session.beginAttempt();
    final result = Completer<AuthUser>();
    _pending = result;
    _generation = generation;
    _timer = Timer(
      timeout,
      () => cancel(message: 'Google sign-in expired. Please start again.'),
    );
    unawaited(_run(generation, result));
    return result.future;
  }

  bool _active(int generation) =>
      !_disposed && _generation == generation && session.isCurrent(generation);

  Future<void> _run(int generation, Completer<AuthUser> result) async {
    try {
      final registration =
          jsonDecode(await loadRegistration()) as Map<String, dynamic>;
      final androidClient = registration['client_id'];
      if (androidClient is! String ||
          !RegExp(
            r'^\d+-[A-Za-z0-9]+\.apps\.googleusercontent\.com$',
          ).hasMatch(androidClient)) {
        throw const FormatException('Invalid Android OAuth registration');
      }
      if (!_active(generation)) return;
      final serverClient = await repository.getAndroidGoogleServerClientId();
      if (!_active(generation)) return;
      if (androidClient == serverClient ||
          androidClient.split('-').first != serverClient.split('-').first) {
        throw const HttpError(
          status: 0,
          code: 'GOOGLE_CONFIGURATION_ERROR',
          message:
              'Android and server Google clients must belong to the same Google Cloud project.',
        );
      }
      final code = await identity.serverCode(serverClient);
      if (!_active(generation)) return;
      if (code.isEmpty) {
        throw const FormatException('Missing Google authorization code');
      }
      final response = await repository.exchangeAndroidGoogleCode(code);
      if (!_active(generation)) return;
      _adopting = true;
      final adopted = await session.adopt(response, generation);
      if (!adopted) {
        throw const HttpError(
          status: 0,
          code: 'SESSION_CANCELLED',
          message: 'This Google sign-in attempt has ended.',
        );
      }
      if (!result.isCompleted) result.complete(response.user);
    } catch (error, stack) {
      final failure = error is FormatException || error is TypeError
          ? const HttpError(
              status: 0,
              code: 'GOOGLE_CONFIGURATION_ERROR',
              message: 'Google sign-in configuration could not be verified.',
            )
          : error;
      if (!result.isCompleted) result.completeError(failure, stack);
      if (_generation == generation) session.cancel(generation);
    } finally {
      if (identical(_pending, result)) {
        _timer?.cancel();
        _timer = null;
        _pending = null;
        _generation = null;
        _adopting = false;
      }
    }
  }

  @override
  void cancel({String message = 'Google sign-in was cancelled.'}) {
    _timer?.cancel();
    final result = _pending;
    final generation = _generation;
    _pending = null;
    _generation = null;
    if (generation != null) session.cancel(generation);
    if (result != null && !result.isCompleted) {
      result.completeError(
        HttpError(status: 0, code: 'GOOGLE_CANCELLED', message: message),
      );
    }
  }

  @override
  void dispose() {
    session.removeListener(_sessionChanged);
    // Adoption may remove the login screen synchronously while notifying listeners.
    if (_adopting && session.current != null) {
      _timer?.cancel();
    } else {
      cancel();
    }
    _disposed = true;
  }
}
