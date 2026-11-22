import 'dart:async';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_repository.dart';
import 'auth_session.dart';

class GooglePkcePair {
  const GooglePkcePair(this.verifier, this.challenge);
  final String verifier, challenge;
}

abstract class GoogleOAuthPlatform {
  Stream<Uri> get links;
  Future<void> attach();
  Future<GooglePkcePair> createPkce();
  void dispose();
}

/// Platform CSPRNG and SHA-256; no reusable secret or custom cryptography in Dart.
class NativeGoogleOAuthPlatform implements GoogleOAuthPlatform {
  static const channel = MethodChannel('creo/oauth');
  static NativeGoogleOAuthPlatform? _owner;
  final _links = StreamController<Uri>.broadcast();
  @override
  Stream<Uri> get links => _links.stream;
  @override
  Future<void> attach() async {
    _owner = this;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'link' &&
          call.arguments is String &&
          !_links.isClosed) {
        final uri = Uri.tryParse(call.arguments as String);
        if (uri != null) _links.add(uri);
      }
    });
    // A cold callback has no in-memory verifier; the flow ignores it and
    // requires a fresh sign-in rather than adopting an unsolicited token.
    await channel.invokeMethod<String>('takeInitialLink');
  }

  @override
  Future<GooglePkcePair> createPkce() async {
    final pair = await channel.invokeMapMethod<String, dynamic>('createPkce');
    final verifier = pair?['verifier'], challenge = pair?['challenge'];
    if (verifier is! String ||
        challenge is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(verifier) ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(challenge)) {
      throw const HttpError(
        status: 0,
        code: 'GOOGLE_CONFIGURATION_ERROR',
        message: 'A secure Google sign-in request could not be created.',
      );
    }
    return GooglePkcePair(verifier, challenge);
  }

  @override
  void dispose() {
    if (identical(_owner, this)) {
      _owner = null;
      channel.setMethodCallHandler(null);
    }
    unawaited(_links.close());
  }
}

class _GoogleAttempt {
  _GoogleAttempt(this.generation, this.verifier, this.redirect, this.state);
  final int generation;
  final String verifier, redirect, state;
  final result = Completer<AuthUser>();
  bool consumed = false;
}

/// Browser handoff reuses the deployed web bridge. Tokens never travel in links.
abstract interface class GoogleAuthFlow {
  Future<AuthUser> signIn();
  void cancel({String message = 'Google sign-in was cancelled.'});
  void dispose();
}

class GoogleSignInFlow implements GoogleAuthFlow {
  GoogleSignInFlow({
    required this.session,
    required this.repository,
    GoogleOAuthPlatform? platform,
    Future<bool> Function(Uri)? launch,
    this.timeout = const Duration(minutes: 10),
    this.webOrigin = const String.fromEnvironment(
      'GOOGLE_OAUTH_WEB_ORIGIN',
      defaultValue: 'https://creo.yogalakshmibaskar20.workers.dev',
    ),
  }) : platform = platform ?? NativeGoogleOAuthPlatform(),
       launch =
           launch ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)) {
    session.addListener(_sessionChanged);
  }
  final AuthSession session;
  final AuthRepository repository;
  final GoogleOAuthPlatform platform;
  final Future<bool> Function(Uri) launch;
  final Duration timeout;
  final String webOrigin;
  StreamSubscription<Uri>? _subscription;
  _GoogleAttempt? _pending;
  int? _generation;
  Timer? _timer;
  bool _starting = false, _disposed = false;
  void _sessionChanged() {
    final generation = _generation;
    if (generation != null && !session.isCurrent(generation)) cancel();
  }

  @override
  Future<AuthUser> signIn() async {
    if (_starting || _pending != null) {
      throw const HttpError(
        status: 0,
        code: 'REQUEST_PENDING',
        message: 'Google sign-in is already in progress.',
      );
    }
    if (_disposed || session.current != null) {
      throw const HttpError(
        status: 0,
        code: 'ACCOUNT_SWITCH_REQUIRED',
        message: 'Sign out before choosing another Google account.',
      );
    }
    _starting = true;
    final generation = session.beginAttempt();
    _generation = generation;
    try {
      final origin = Uri.tryParse(webOrigin);
      if (origin == null ||
          origin.scheme != 'https' ||
          origin.host.isEmpty ||
          origin.userInfo.isNotEmpty ||
          origin.hasQuery ||
          origin.hasFragment ||
          !{'', '/'}.contains(origin.path)) {
        throw const HttpError(
          status: 0,
          code: 'GOOGLE_CONFIGURATION_ERROR',
          message: 'Google sign-in needs a valid web handoff origin.',
        );
      }
      _subscription ??= platform.links.listen(
        (uri) => unawaited(_receive(uri)),
      );
      await platform.attach();
      final pair = await platform.createPkce();
      _check(generation);
      final redirect = origin.resolve('/auth/google/callback').toString();
      final url = await repository.getGoogleAuthUrl(redirect, pair.challenge);
      _check(generation);
      final state = Uri.parse(url).queryParameters['state']!;
      final pending = _GoogleAttempt(
        generation,
        pair.verifier,
        redirect,
        state,
      );
      // Attach an error handler before browser callbacks can arrive.
      unawaited(
        pending.result.future.then<void>(
          (_) {},
          onError: (Object _, StackTrace __) {},
        ),
      );
      _pending = pending;
      _timer = Timer(
        timeout,
        () => cancel(message: 'Google sign-in expired. Please start again.'),
      );
      final opened = await launch(
        origin.resolve('/app-oauth').replace(queryParameters: {'to': url}),
      );
      _check(generation);
      if (!opened) {
        throw const HttpError(
          status: 0,
          code: 'GOOGLE_BROWSER_UNAVAILABLE',
          message:
              'Google sign-in could not open your browser. Please try again.',
        );
      }
      return await pending.result.future;
    } on MissingPluginException {
      cancel();
      throw const HttpError(
        status: 0,
        code: 'GOOGLE_PLATFORM_UNAVAILABLE',
        message: 'Google sign-in requires the updated Android or iOS app.',
      );
    } catch (error) {
      if (_generation == generation) cancel();
      rethrow;
    } finally {
      _starting = false;
    }
  }

  void _check(int generation) {
    if (_disposed || !session.isCurrent(generation)) {
      throw const HttpError(
        status: 0,
        code: 'SESSION_CANCELLED',
        message: 'This Google sign-in attempt has ended.',
      );
    }
  }

  Future<void> _receive(Uri uri) async {
    final pending = _pending;
    if (pending == null ||
        pending.consumed ||
        uri.scheme != 'com.creo.app' ||
        uri.host != 'app' ||
        uri.path != '/auth/google/callback') {
      return;
    }
    try {
      _check(pending.generation);
      if (uri.userInfo.isNotEmpty ||
          uri.hasFragment ||
          uri.queryParametersAll.values.any((values) => values.length != 1) ||
          uri.queryParameters['state'] != pending.state ||
          uri.queryParameters.containsKey('token') ||
          uri.queryParameters.containsKey('access_token')) {
        throw const HttpError(
          status: 0,
          code: 'GOOGLE_STATE_MISMATCH',
          message:
              'This Google sign-in response does not match your current attempt. Please start again.',
        );
      }
      pending.consumed = true;
      _timer?.cancel();
      if (uri.queryParameters.containsKey('error')) {
        throw const HttpError(
          status: 0,
          code: 'GOOGLE_CANCELLED',
          message: 'Google sign-in was cancelled or denied.',
        );
      }
      final code = uri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw const HttpError(
          status: 0,
          code: 'GOOGLE_INVALID_CALLBACK',
          message:
              'Google did not return an authorization code. Please start again.',
        );
      }
      final response = await repository.exchangeGoogleCode(
        code: code,
        redirectUri: pending.redirect,
        verifier: pending.verifier,
      );
      _check(pending.generation);
      if (!await session.adopt(response, pending.generation)) {
        _check(pending.generation);
        throw const HttpError(
          status: 0,
          code: 'SESSION_CANCELLED',
          message: 'The Google session could not be adopted.',
        );
      }
      _pending = null;
      _generation = null;
      if (!pending.result.isCompleted) pending.result.complete(response.user);
    } catch (error, stack) {
      if (identical(_pending, pending)) {
        _pending = null;
        _generation = null;
        session.cancel(pending.generation);
      }
      if (!pending.result.isCompleted) {
        pending.result.completeError(error, stack);
      }
    }
  }

  @override
  void cancel({String message = 'Google sign-in was cancelled.'}) {
    _timer?.cancel();
    _timer = null;
    final pending = _pending;
    _pending = null;
    final generation = _generation;
    _generation = null;
    if (generation != null) session.cancel(generation);
    if (pending != null && !pending.result.isCompleted) {
      pending.result.completeError(
        HttpError(status: 0, code: 'GOOGLE_CANCELLED', message: message),
      );
    }
  }

  @override
  void dispose() {
    session.removeListener(_sessionChanged);
    // Adoption publishes before the host removes the login route. Do not
    // invalidate an already committed session when that route is disposed.
    if (session.current != null && _pending?.consumed == true) {
      _pending = null;
      _generation = null;
      _timer?.cancel();
    } else {
      cancel();
    }
    _disposed = true;
    unawaited(_subscription?.cancel());
    platform.dispose();
  }
}
