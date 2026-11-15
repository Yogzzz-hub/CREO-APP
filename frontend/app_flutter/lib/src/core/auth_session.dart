import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth_repository.dart';
import 'session_store.dart';

class AuthenticatedBytes {
  const AuthenticatedBytes(
    this.bytes,
    this.contentType,
    this.contentDisposition,
  );
  final Uint8List bytes;
  final String contentType;
  final String? contentDisposition;
}

class DestinationIntent {
  const DestinationIntent(this.path, {this.blocker});
  final String? path;
  final String? blocker;

  factory DestinationIntent.forUser(AuthUser user) {
    if (user.mustResetPassword == true) {
      return const DestinationIntent('/set-mandatory-password');
    }
    if ((user.role == 'client' || user.role == 'client_owner') &&
        user.onboardingStage < 8) {
      return const DestinationIntent('/onboarding');
    }
    const homes = {
      'client': '/portal',
      'client_owner': '/portal',
      'admin': '/admin',
      'super_admin': '/admin',
      'editor': '/workstation',
      'designer': '/workstation',
      'team_lead': '/admin/pod-dashboard',
      'sales': '/bde',
      'bde': '/bde',
      'bde_head': '/bde/crm/overview',
      'freelancer': '/freelancer/tasks',
      'investor_relations': '/admin/reports',
    };
    const implemented = [
      'editor',
      'designer',
      'team_lead',
      'freelancer',
      'admin',
      'super_admin',
      'client',
      'client_owner',
      'sales',
      'bde',
      'bde_head',
    ];
    final home = homes[user.role];
    if (home != null && implemented.contains(user.role)) {
      return DestinationIntent(home);
    }
    return DestinationIntent(
      home,
      blocker: home == null
          ? 'This account role has no confirmed mobile destination.'
          : 'The mobile workspace is not implemented yet.',
    );
  }
}

/// The only session-adoption owner. Serial commits and generations protect
/// against disposed screens, competing attempts and account replacement.
enum SessionPhase {
  uninitialized,
  restoring,
  signedOut,
  authenticated,
  unavailable,
  clearing,
  storageFailure,
}

class AuthSession extends ChangeNotifier {
  AuthSession({
    SessionStore? store,
    AuthRepository? repository,
    VoidCallback? clearPrivateData,
    DateTime Function()? now,
  }) : store = store ?? repository?.store ?? defaultSessionStore,
       repository =
           repository ?? AuthRepository(store: store ?? defaultSessionStore),
       _clearPrivateData = clearPrivateData,
       _now = now ?? DateTime.now;
  static final shared = AuthSession();
  final SessionStore store;
  final AuthRepository repository;
  final VoidCallback? _clearPrivateData;
  final DateTime Function() _now;
  int _generation = 0;
  int? _adoptedGeneration;
  Future<void> _commits = Future<void>.value();
  SessionResponse? _current;
  SessionResponse? get current => _current;
  StoredSession? _credentials;
  Future<void>? _restoration;
  Future<void>? _clearing;
  Future<void> Function()? _pendingAccountClear;
  Future<StoredSession>? _refresh;
  int? _refreshGeneration;
  SessionPhase phase = SessionPhase.uninitialized;
  HttpError? issue;
  int navigationEpoch = 0;
  bool _disposed = false;

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  Future<T> _queue<T>(Future<T> Function() operation) {
    final result = _commits.then((_) => operation());
    _commits = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static bool accessIsFresh(String token, DateTime now) {
    try {
      final json =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(token.split('.')[1])),
                ),
              )
              as Map;
      final expiry = json['exp'];
      return expiry is num &&
          expiry * 1000 > now.millisecondsSinceEpoch + 10000;
    } catch (_) {
      return false;
    }
  }

  void _check(int generation) {
    if (!isCurrent(generation) || _disposed) {
      throw const HttpError(
        status: 0,
        code: 'SESSION_CANCELLED',
        message: 'This session operation is no longer active.',
      );
    }
  }

  int beginAttempt() {
    if (phase == SessionPhase.clearing ||
        phase == SessionPhase.storageFailure) {
      throw const HttpError(
        status: 0,
        code: 'SESSION_UNAVAILABLE',
        message: 'Clear the saved session safely before signing in again.',
      );
    }
    _restoration = null;
    return ++_generation;
  }

  bool isCurrent(int attempt) => attempt == _generation;

  /// Read-only operation identity; unlike beginAttempt this does not invalidate
  /// another request or start a login/session adoption.
  int get beginReadGeneration => _generation;
  int? _mandatoryPasswordGeneration;

  Future<void> setMandatoryPassword(String password) async {
    final previous = _current;
    if (phase != SessionPhase.authenticated ||
        previous?.user.mustResetPassword != true) {
      throw const HttpError(
        status: 403,
        code: 'RESET_VERIFICATION_REQUIRED',
        message: 'Use password recovery to change this account password.',
      );
    }
    if (_mandatoryPasswordGeneration != null &&
        isCurrent(_mandatoryPasswordGeneration!)) {
      throw const HttpError(
        status: 0,
        code: 'REQUEST_PENDING',
        message: 'Your password update is already in progress.',
      );
    }
    final attempt = beginAttempt();
    _mandatoryPasswordGeneration = attempt;
    try {
      // Use the session owner so an expired restricted access token can be
      // renewed before the write. AuthSession deliberately never replays
      // writes after a 401, so this does not make the password change unsafe.
      final result = await request(
        'POST',
        '/api/v1/auth/set-mandatory-password',
        body: {'new_password': password},
      );
      _check(attempt);
      final next = SessionResponse.fromJson(result);
      if (next.user.id != previous!.user.id ||
          next.user.mustResetPassword == true ||
          next.accessToken.isEmpty) {
        throw const HttpError(
          status: 0,
          code: 'INVALID_RESPONSE',
          message: 'The updated account could not be verified.',
        );
      }
      if (!await adopt(next, attempt)) _check(attempt);
    } finally {
      if (_mandatoryPasswordGeneration == attempt)
        _mandatoryPasswordGeneration = null;
    }
  }

  void cancel(int attempt) {
    if (isCurrent(attempt)) _generation++;
  }

  Future<bool> adopt(SessionResponse session, int attempt) async {
    final previous = _commits;
    final commit = _commit(previous, session, attempt);
    _commits = commit.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return commit;
  }

  Future<bool> _commit(
    Future<void> previous,
    SessionResponse session,
    int attempt,
  ) async {
    await previous;
    if (!isCurrent(attempt) || _adoptedGeneration == attempt) return false;
    final old = await store.read();
    if (!isCurrent(attempt)) return false;
    if (old != null && old.userId != session.user.id) {
      throw const HttpError(
        status: 0,
        code: 'SESSION_EXISTS',
        message:
            'A different or older saved session exists. End that session before signing in again.',
      );
    }
    try {
      await store.write(
        StoredSession(
          session.accessToken,
          session.refreshToken ?? old?.refreshToken,
          session.user.id,
        ),
      );
      if (!isCurrent(attempt)) {
        await store.write(old);
        return false;
      }
      _current = session;
      _credentials = StoredSession(
        session.accessToken,
        session.refreshToken ?? old?.refreshToken,
        session.user.id,
      );
      _adoptedGeneration = attempt;
      issue = null;
      phase = SessionPhase.authenticated;
      _publish();
      return true;
    } catch (_) {
      // Restore the previous record before another queued commit may run.
      await store.write(old);
      rethrow;
    }
  }

  Future<StoredSession?> _readStorage() async {
    try {
      return await store.read();
    } catch (_) {
      throw const HttpError(
        status: 0,
        code: 'STORAGE_ERROR',
        message:
            'The saved session could not be read safely. Retry, or clear it before signing in.',
      );
    }
  }

  Future<void> restore() {
    if (_clearing != null) return _clearing!;
    if (phase == SessionPhase.storageFailure &&
        ['STORAGE_CLEAR_FAILED', 'CACHE_CLEAR_FAILED'].contains(issue?.code)) {
      return Future<
        void
      >.value(); // A retry must finish clearing, not re-adopt the failed sign-out.
    }
    if (_restoration != null) return _restoration!;
    final generation = _generation;
    final pending = _restore(generation);
    _restoration = pending;
    unawaited(
      pending.whenComplete(() {
        if (identical(_restoration, pending)) _restoration = null;
      }),
    );
    return pending;
  }

  Future<void> resume() {
    if (_restoration != null) return _restoration!;
    // A forced password change invalidates the old token server-side. A
    // simultaneous profile restore can therefore turn a successful password
    // update into an apparent sign-out before its replacement token is adopted.
    if (_mandatoryPasswordGeneration != null &&
        isCurrent(_mandatoryPasswordGeneration!)) {
      return Future<void>.value();
    }
    if (phase != SessionPhase.authenticated &&
        phase != SessionPhase.unavailable) {
      return Future<void>.value();
    }
    return restore();
  }

  Future<void> _restore(int generation) async {
    final previousUser = _current?.user.id;
    phase = SessionPhase.restoring;
    issue = null;
    _current = null; // Cached identity is never fresh authorization.
    _publish();
    try {
      final saved = await _queue(_readStorage);
      _check(generation);
      _credentials = saved;
      if (saved == null) {
        phase = SessionPhase.signedOut;
        _publish();
        return;
      }
      if (saved.accessToken.isEmpty && (saved.refreshToken?.isEmpty ?? true)) {
        throw const FormatException('Empty session');
      }
      final json = await request(
        'GET',
        '/api/v1/auth/me',
        requestTimeout: const Duration(seconds: 15),
      );
      _check(generation);
      late ProfileResponse profile;
      try {
        profile = ProfileResponse.fromJson(json);
      } catch (_) {
        throw const HttpError(
          status: 0,
          code: 'INVALID_RESPONSE',
          message: 'The server returned an invalid profile. Please retry.',
        );
      }
      final credentials = _credentials!;
      if ((saved.userId != null && saved.userId != profile.user.id) ||
          (previousUser != null && previousUser != profile.user.id)) {
        await _reject(
          generation,
          const HttpError(
            status: 401,
            code: 'SESSION_REVOKED',
            message:
                'The saved account no longer matches this session. Please sign in again.',
          ),
        );
        return;
      }
      final next = StoredSession(
        profile.accessToken ?? credentials.accessToken,
        credentials.refreshToken,
        profile.user.id,
      );
      await _persist(next, generation);
      _check(generation);
      _current = SessionResponse(
        accessToken: next.accessToken,
        refreshToken: next.refreshToken,
        user: profile.user,
      );
      phase = SessionPhase.authenticated;
      issue = null;
      _publish();
    } on HttpError catch (error) {
      if (!isCurrent(generation)) return;
      if (error.status == 401 || error.status == 403 || _isEnded(error)) {
        await _reject(generation, error);
      } else {
        phase = error.code == 'STORAGE_ERROR'
            ? SessionPhase.storageFailure
            : SessionPhase.unavailable;
        issue = error;
        _publish();
      }
    } catch (_) {
      if (!isCurrent(generation)) return;
      phase = SessionPhase.storageFailure;
      issue = const HttpError(
        status: 0,
        code: 'STORAGE_ERROR',
        message:
            'The saved session could not be read or saved safely. Retry, or clear it before signing in.',
      );
      _publish();
    }
  }

  /// Auth-entry calls are never renewed. Only safe reads may replay after an
  /// explicit 401; writes are never retried after ambiguous completion.
  Future<AuthUser> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    final generation = _generation;
    final userId = _current?.user.id;
    if (phase != SessionPhase.authenticated || userId == null) {
      throw const HttpError(
        status: 401,
        code: 'UNAUTHORIZED',
        message: 'Please sign in again.',
      );
    }
    final response = await request(
      'PATCH',
      '/api/v1/users/me',
      body: {'full_name': fullName.trim(), 'phone': phone.trim()},
    );
    _check(generation);
    final currentUser = _current!.user;
    final profile = ProfileResponse.fromJson({
      'company_name': currentUser.companyName,
      'onboarding_status': currentUser.onboardingStatus,
      'onboarding_stage': currentUser.onboardingStage,
      'terms_accepted': currentUser.termsAccepted,
      'must_reset_password': currentUser.mustResetPassword,
      'sign_in_methods': currentUser.signInMethods,
      ...response,
    });
    if (profile.user.id != userId) {
      throw const HttpError(
        status: 0,
        code: 'ACCOUNT_MISMATCH',
        message: 'The returned profile belongs to another account.',
      );
    }
    return _queue(() async {
      _check(generation);
      final previous = _credentials;
      if (previous == null) {
        throw const HttpError(
          status: 401,
          code: 'UNAUTHORIZED',
          message: 'Please sign in again.',
        );
      }
      final next = StoredSession(
        profile.accessToken ?? previous.accessToken,
        previous.refreshToken,
        userId,
      );
      try {
        await store.write(next);
        if (!isCurrent(generation)) {
          await store.write(previous);
          _check(generation);
        }
      } catch (error) {
        try {
          await store.write(previous);
        } catch (_) {
          _current = null;
          _credentials = null;
          phase = SessionPhase.storageFailure;
          issue = const HttpError(
            status: 0,
            code: 'STORAGE_ERROR',
            message:
                'The updated session could not be saved or rolled back. Clear the saved session safely before continuing.',
          );
          _publish();
          throw issue!;
        }
        if (error is HttpError) rethrow;
        throw const HttpError(
          status: 0,
          code: 'STORAGE_WRITE_FAILED',
          message:
              'Your profile was saved on the server, but the updated session could not be saved on this device. Your previous saved session was retained.',
        );
      }
      _credentials = next;
      _current = SessionResponse(
        accessToken: next.accessToken,
        refreshToken: next.refreshToken,
        user: profile.user,
      );
      _publish();
      return profile.user;
    });
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
    bool binaryResponse = false,
    Duration? requestTimeout,
    Future<http.BaseRequest> Function(Uri uri)? buildRequest,
  }) async {
    final generation = _generation;
    final verb = method.toUpperCase();
    final authEntry = [
      '/auth/login',
      '/auth/verify-',
      '/auth/register',
      '/auth/resend-',
      '/auth/forgot-',
      '/auth/reset-',
      '/auth/direct-reset-',
      '/auth/refresh',
      '/auth/google/',
    ].any(path.contains);
    if (authEntry) {
      final result = await repository.requestJson(
        verb,
        path,
        body: body,
        headers: headers,
        binaryResponse: binaryResponse,
        requestTimeout: requestTimeout,
        buildRequest: buildRequest,
      );
      _check(generation);
      return result;
    }
    if (phase == SessionPhase.clearing ||
        phase == SessionPhase.storageFailure) {
      throw const HttpError(
        status: 0,
        code: 'SESSION_UNAVAILABLE',
        message: 'Resolve the saved session before continuing.',
      );
    }
    var credentials = _credentials ?? await _queue(_readStorage);
    _check(generation);
    if (credentials == null) {
      throw const HttpError(
        status: 401,
        code: 'UNAUTHORIZED',
        message: 'Please sign in again.',
      );
    }
    _credentials = credentials;
    var renewed = false;
    if (!accessIsFresh(credentials.accessToken, _now()) &&
        credentials.refreshToken != null) {
      renewed = true;
      credentials = await _renew(credentials, generation);
    }
    _check(generation);
    final tokenUsed = credentials.accessToken;
    try {
      final result = await repository.requestJson(
        verb,
        path,
        accessToken: tokenUsed,
        body: body,
        headers: headers,
        binaryResponse: binaryResponse,
        requestTimeout: requestTimeout,
        buildRequest: buildRequest,
      );
      _check(generation);
      return result;
    } on HttpError catch (error) {
      _check(generation);
      if (_isEnded(error)) {
        await _reject(generation, error);
        rethrow;
      }
      if (error.status != 401) {
        rethrow; // Resource 403 is not a signed-out session.
      }
      if (!renewed &&
          credentials.refreshToken != null &&
          ['GET', 'HEAD', 'OPTIONS'].contains(verb)) {
        final latest = _credentials;
        final replacement = latest != null && latest.accessToken != tokenUsed
            ? latest
            : await _renew(credentials, generation);
        _check(generation);
        try {
          final result = await repository.requestJson(
            verb,
            path,
            accessToken: replacement.accessToken,
            body: body,
            headers: headers,
            binaryResponse: binaryResponse,
            requestTimeout: requestTimeout,
            buildRequest: buildRequest,
          );
          _check(generation);
          return result;
        } on HttpError catch (replayError) {
          _check(generation);
          if (replayError.status == 401 || _isEnded(replayError)) {
            await _reject(generation, replayError);
          }
          rethrow;
        }
      }
      if (!['GET', 'HEAD', 'OPTIONS'].contains(verb) &&
          credentials.refreshToken != null) {
        rethrow; // Never replay writes, or mistake their 401 for a rejected refresh.
      }
      await _reject(generation, error);
      rethrow;
    }
  }

  /// Authenticated GET with the same refresh, replay and stale-result rules.
  Future<AuthenticatedBytes> requestBytes(String path) async {
    final result = await request('GET', path, binaryResponse: true);
    final headers = result['headers'] as Map<String, String>;
    return AuthenticatedBytes(
      result['bytes'] as Uint8List,
      headers['content-type'] ?? 'application/octet-stream',
      headers['content-disposition'],
    );
  }

  bool _isEnded(HttpError error) =>
      ['SESSION_REVOKED', 'ACCOUNT_SUSPENDED'].contains(error.code);

  Future<StoredSession> _renew(StoredSession credentials, int generation) {
    _check(generation);
    if (_refresh != null && _refreshGeneration == generation) return _refresh!;
    final pending = _renewOnce(credentials, generation);
    _refreshGeneration = generation;
    _refresh = pending;
    unawaited(
      pending.then<void>(
        (_) {
          if (identical(_refresh, pending)) _refresh = null;
        },
        onError: (Object _, StackTrace __) {
          if (identical(_refresh, pending)) _refresh = null;
        },
      ),
    );
    return pending;
  }

  Future<StoredSession> _renewOnce(
    StoredSession credentials,
    int generation,
  ) async {
    try {
      final access = await repository.refreshAccessToken(
        credentials.refreshToken!,
      );
      _check(generation);
      final next = StoredSession(
        access,
        credentials.refreshToken,
        credentials.userId,
      );
      return await _persist(
        next,
        generation,
        expectedAccess: credentials.accessToken,
      );
    } on HttpError catch (error) {
      if (isCurrent(generation) &&
          (error.status == 401 || error.status == 403 || _isEnded(error))) {
        await _reject(generation, error);
      } else if (isCurrent(generation)) {
        _current = null;
        issue = error;
        phase = error.code == 'STORAGE_ERROR'
            ? SessionPhase.storageFailure
            : SessionPhase.unavailable;
        _publish();
      }
      rethrow;
    }
  }

  Future<StoredSession> _persist(
    StoredSession next,
    int generation, {
    String? expectedAccess,
  }) => _queue(() async {
    _check(generation);
    final old = await _readStorage();
    _check(generation);
    if (old != null &&
        old.userId != null &&
        next.userId != null &&
        old.userId != next.userId) {
      throw const HttpError(
        status: 0,
        code: 'STORAGE_ERROR',
        message:
            'The saved account changed during validation. Clear the session before continuing.',
      );
    }
    if (expectedAccess != null &&
        old != null &&
        old.accessToken != expectedAccess) {
      _credentials =
          old; // A profile validation already committed a newer token.
      return old;
    }
    try {
      await store.write(next);
      if (!isCurrent(generation)) {
        await store.write(old);
        _check(generation);
      }
      _credentials = next;
      if (_current != null) {
        _current = SessionResponse(
          accessToken: next.accessToken,
          refreshToken: next.refreshToken,
          user: _current!.user,
        );
      }
      return next;
    } on HttpError {
      rethrow;
    } catch (_) {
      try {
        await store.write(old);
      } catch (_) {
        /* Explicit blocked storage state below. */
      }
      throw const HttpError(
        status: 0,
        code: 'STORAGE_ERROR',
        message:
            'Your session could not be saved safely. Retry or clear the saved session.',
      );
    }
  });

  Future<void> _reject(int generation, HttpError error) async {
    if (!isCurrent(generation)) return;
    await logout(notifyServer: false, reason: error);
  }

  Future<void> logout({
    bool notifyServer = true,
    HttpError? reason,
    Future<void> Function()? clearAccountData,
  }) {
    if (_clearing != null) return _clearing!;
    _pendingAccountClear = clearAccountData ?? _pendingAccountClear;
    final token = _credentials?.accessToken ?? _current?.accessToken;
    final generation = ++_generation; // Invalidate before awaiting any I/O.
    navigationEpoch++;
    _restoration = null;
    _refresh = null;
    _current = null;
    _credentials = null;
    phase = SessionPhase.clearing;
    issue = reason;
    try {
      _clearPrivateData?.call();
    } catch (_) {
      issue = const HttpError(
        status: 0,
        code: 'CACHE_CLEAR_FAILED',
        message:
            'Local account data could not be cleared. Please retry sign-out.',
      );
    }
    _publish();
    if (notifyServer && token != null && token.isNotEmpty) {
      // The backend only acknowledges logout. Remote failure never blocks local removal.
      unawaited(repository.logoutRemote(token).catchError((Object _) {}));
    }
    final pending = _queue(() async {
      try {
        await store.write(null);
        try {
          await _pendingAccountClear?.call();
          _pendingAccountClear = null;
        } catch (_) {
          issue = const HttpError(
            status: 0,
            code: 'CACHE_CLEAR_FAILED',
            message:
                'Local account settings could not be cleared. Retry sign-out before continuing.',
          );
        }
        if (isCurrent(generation)) {
          phase = issue?.code == 'CACHE_CLEAR_FAILED'
              ? SessionPhase.storageFailure
              : SessionPhase.signedOut;
        }
      } catch (_) {
        phase = SessionPhase.storageFailure;
        issue = const HttpError(
          status: 0,
          code: 'STORAGE_CLEAR_FAILED',
          message:
              'Saved credentials could not be fully cleared. Retry sign-out before continuing.',
        );
      }
      _publish();
    });
    _clearing = pending;
    unawaited(
      pending.whenComplete(() {
        if (identical(_clearing, pending)) _clearing = null;
      }),
    );
    return pending;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
