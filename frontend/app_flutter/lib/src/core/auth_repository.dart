// ─────────────────────────────────────────────────────────────────────────────
// AuthRepository
// Mirrors the HTTP calls in frontend/src/lib/auth-context.tsx
//
// Endpoints (all relative to the base URL):
//   POST /api/v1/auth/login               → SessionResponse
//   POST /api/v1/auth/register-intent     → RegistrationCodeResult
//   POST /api/v1/auth/resend-registration → RegistrationCodeResult
//   POST /api/v1/auth/verify-registration → SessionResponse
//   GET  /api/v1/auth/google/url          → { url, state }
//   POST /api/v1/auth/forgot-password     → { status, message }
//   POST /api/v1/auth/verify-reset-otp    → PasswordResetVerification
//   POST /api/v1/auth/reset-password      → SessionResponse
//   GET  /api/v1/auth/me                  → AuthUser (+ optional access_token)
//   POST /api/v1/auth/refresh             → { access_token }
//   POST /api/v1/auth/logout
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_store.dart';

// ── Token keys ──────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class AuthUser {
  final String id;
  final String email;
  final String fullName;
  final String? companyName;
  final String role;
  final String accountStatus;
  final int onboardingStage;
  final String? onboardingStatus;
  final bool? termsAccepted;
  final bool? mustResetPassword;
  final List<String> signInMethods;

  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.companyName,
    required this.role,
    required this.accountStatus,
    required this.onboardingStage,
    this.onboardingStatus,
    this.termsAccepted,
    this.mustResetPassword,
    this.signInMethods = const [],
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id: j['id'] as String? ?? '',
    email: j['email'] as String? ?? '',
    fullName: j['full_name'] as String? ?? '',
    companyName: j['company_name'] as String?,
    role: j['role'] as String? ?? '',
    accountStatus: j['account_status'] as String? ?? '',
    onboardingStage: (j['onboarding_stage'] as num?)?.toInt() ?? 0,
    onboardingStatus: j['onboarding_status'] as String?,
    termsAccepted: j['terms_accepted'] as bool?,
    mustResetPassword: j['must_reset_password'] as bool?,
    signInMethods: (j['sign_in_methods'] as List?)?.cast<String>() ?? [],
  );
}

class SessionResponse {
  final String accessToken;
  final String? refreshToken;
  final AuthUser user;

  const SessionResponse({
    required this.accessToken,
    this.refreshToken,
    required this.user,
  });

  factory SessionResponse.fromJson(Map<String, dynamic> j) => SessionResponse(
    accessToken: j['access_token'] as String,
    refreshToken: j['refresh_token'] as String?,
    user: AuthUser.fromJson(j['user'] as Map<String, dynamic>),
  );
}

/// /auth/me returns the profile itself, not a session response envelope.
class ProfileResponse {
  const ProfileResponse(this.user, this.accessToken);
  final AuthUser user;
  final String? accessToken;

  factory ProfileResponse.fromJson(Map<String, dynamic> json) {
    final user = AuthUser.fromJson(json);
    if (user.id.isEmpty || user.email.isEmpty || user.role.isEmpty) {
      throw const FormatException('Incomplete profile');
    }
    final access = json['access_token'] as String?;
    if (access != null && access.isEmpty) {
      throw const FormatException('Empty access token');
    }
    return ProfileResponse(user, access);
  }
}

class RegistrationCodeResult {
  final String status; // "sent"
  final String message;
  final String email;
  final bool emailDelivered;
  final int expiresInSeconds;

  const RegistrationCodeResult({
    required this.status,
    required this.message,
    required this.email,
    required this.emailDelivered,
    required this.expiresInSeconds,
  });

  factory RegistrationCodeResult.fromJson(Map<String, dynamic> j) =>
      RegistrationCodeResult(
        status: j['status'] as String? ?? '',
        message: j['message'] as String? ?? '',
        email: j['email'] as String? ?? '',
        emailDelivered: j['email_delivered'] == true,
        expiresInSeconds: (j['expires_in_seconds'] as num?)?.toInt() ?? 600,
      );
}

class HttpError implements Exception {
  final int status;
  final String code;
  final String message;
  final Map<String, dynamic> details;

  const HttpError({
    required this.status,
    required this.code,
    required this.message,
    this.details = const {},
  });

  @override
  String toString() => 'HttpError($status, $code): $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Repository
// ─────────────────────────────────────────────────────────────────────────────

class AuthRepository {
  AuthRepository({
    http.Client? client,
    Uri? origin,
    SessionStore? store,
    this.timeout = const Duration(seconds: 60),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _origin =
           origin ??
           Uri.tryParse(
             const String.fromEnvironment(
               'CREO_API_ORIGIN',
               // Existing React Pages API origin and Worker upstream:
               // frontend/src/lib/http.ts and wrangler.jsonc. Native bearer
               // authentication requires no privileged gateway headers.
               defaultValue: 'https://creo-api-singapore.onrender.com',
             ),
           ),
       store = store ?? defaultSessionStore;

  final http.Client _client;
  final bool _ownsClient;
  final Uri? _origin;
  final SessionStore store;
  final Duration timeout;

  Uri _url(String path) {
    final origin = _origin;
    if (origin == null ||
        origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        (origin.path.isNotEmpty && origin.path != '/')) {
      throw const HttpError(
        status: 0,
        code: 'API_NOT_CONFIGURED',
        message:
            'The mobile API origin has not been confirmed. Configure a supported HTTPS origin before connecting.',
      );
    }
    return origin.resolve(path);
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  /// Public media links never receive bearer headers. Relative upload URLs use
  /// the same configured HTTPS origin as API calls.
  Uri? resolveMediaUri(String value) {
    try {
      final candidate = Uri.parse(value.trim());
      final resolved = candidate.hasScheme
          ? candidate
          : _url('/').resolveUri(candidate);
      return resolved.scheme == 'https' &&
              resolved.host.isNotEmpty &&
              resolved.userInfo.isEmpty
          ? resolved
          : null;
    } catch (_) {
      return null;
    }
  }

  // ── Token helpers ──────────────────────────────────────────────────────
  Future<String?> getAccessToken() async => (await store.read())?.accessToken;

  // ── HTTP helpers ───────────────────────────────────────────────────────
  Future<Map<String, String>> _headers({bool auth = false}) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await getAccessToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  Map<String, dynamic> _parseError(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['error'] is Map<String, dynamic>) {
        return body['error'] as Map<String, dynamic>;
      }
      final detail = body['detail'];
      if (detail is Map<String, dynamic>) return detail;
      if (detail is List) {
        return {
          'code': 'VALIDATION_ERROR',
          'message': detail
              .whereType<Map>()
              .map((e) {
                final loc = (e['loc'] is List ? e['loc'] as List : const [])
                    .where((v) => v != 'body')
                    .join('.');
                return '${loc.isEmpty ? '' : '$loc: '}${e['msg'] ?? 'Invalid value'}';
              })
              .join('; '),
          'details': {'fields': detail},
        };
      }
      if (detail is String) {
        return {'code': 'VALIDATION_ERROR', 'message': detail};
      }
    } catch (_) {}
    return {
      'code': res.statusCode == 429 ? 'RATE_LIMITED' : 'HTTP_ERROR',
      'message': res.statusCode == 429
          ? 'Too many attempts. Please wait before trying again.'
          : res.statusCode >= 500
          ? 'The server could not complete sign-in. Please try again.'
          : 'HTTP ${res.statusCode}: ${res.reasonPhrase ?? 'Request failed'}',
    };
  }

  void _throwIfError(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final e = _parseError(res);
    throw HttpError(
      status: res.statusCode,
      code: e['code'] as String? ?? 'HTTP_ERROR',
      message: e['message'] as String? ?? 'Unknown error',
      details: e['details'] is Map<String, dynamic>
          ? e['details'] as Map<String, dynamic>
          : e,
    );
  }

  /// One transport/error boundary. Renewal and adoption belong to AuthSession.
  Future<Map<String, dynamic>> requestJson(
    String method,
    String path, {
    String? accessToken,
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
    bool binaryResponse = false,
    Duration? requestTimeout,
    Future<http.BaseRequest> Function(Uri uri)? buildRequest,
  }) async {
    if (!path.startsWith('/api/')) {
      throw ArgumentError('Only local API paths are supported');
    }
    try {
      final uri = _url(path);
      final request = buildRequest == null
          ? http.Request(method.toUpperCase(), uri)
          : await buildRequest(uri);
      if (request.url != uri || request.method != method.toUpperCase()) {
        throw ArgumentError(
          'Request must match the authenticated API operation',
        );
      }
      if (headers.keys.any(
        (key) => {'authorization', 'content-type'}.contains(key.toLowerCase()),
      )) {
        throw ArgumentError(
          'Authentication and content type belong to the shared transport',
        );
      }
      request.headers.addAll(headers);
      if (buildRequest == null) {
        request.headers['Content-Type'] = 'application/json';
      }
      if (accessToken != null && accessToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $accessToken';
      }
      if (body != null && request is http.Request) {
        request.body = jsonEncode(body);
      }
      final response =
          await (() async => http.Response.fromStream(
            await _client.send(request),
          ))().timeout(
            requestTimeout ??
                (method.toUpperCase() == 'GET'
                    ? const Duration(seconds: 20)
                    : timeout),
          );
      _throwIfError(response);
      if (binaryResponse)
        return {'bytes': response.bodyBytes, 'headers': response.headers};
      if (response.statusCode == 204 ||
          response.statusCode == 205 ||
          response.body.isEmpty) {
        return {};
      }
      final decoded = jsonDecode(response.body);
      // Preserve direct array contracts through the existing map-based session
      // transport. Existing object responses retain their exact shape.
      if (decoded is List) return {'items': decoded};
      return decoded as Map<String, dynamic>;
    } on HttpError {
      rethrow;
    } on TimeoutException {
      throw const HttpError(
        status: 0,
        code: 'TIMEOUT',
        message: 'The request timed out. Please try again.',
      );
    } on http.ClientException {
      throw const HttpError(
        status: 0,
        code: 'NETWORK_ERROR',
        message: 'Unable to connect. Check your connection and try again.',
      );
    } on FormatException {
      throw const HttpError(
        status: 0,
        code: 'INVALID_RESPONSE',
        message: 'The server returned an invalid response. Please try again.',
      );
    } on TypeError {
      throw const HttpError(
        status: 0,
        code: 'INVALID_RESPONSE',
        message: 'The server returned an invalid response. Please try again.',
      );
    }
  }

  Future<String> refreshAccessToken(String refreshToken) async {
    final json = await requestJson(
      'POST',
      '/api/v1/auth/refresh',
      body: {'refresh_token': refreshToken},
      requestTimeout: const Duration(seconds: 15),
    );
    final token = json['access_token'];
    if (token is! String || token.isEmpty) {
      throw const HttpError(
        status: 0,
        code: 'INVALID_RESPONSE',
        message: 'The server did not return a renewed session.',
      );
    }
    return token;
  }

  Future<void> logoutRemote(String accessToken) async {
    await requestJson(
      'POST',
      '/api/v1/auth/logout',
      accessToken: accessToken,
      requestTimeout: const Duration(seconds: 15),
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await _client
        .post(_url(path), headers: await _headers(), body: jsonEncode(body))
        .timeout(timeout);
    _throwIfError(res);
    if (res.statusCode == 204 || res.body.isEmpty) return {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Auth API calls ─────────────────────────────────────────────────────

  /// POST /api/v1/auth/login
  Future<SessionResponse> loginWithPassword(
    String email,
    String password,
  ) async {
    try {
      final json = await _post('/api/v1/auth/login', {
        'email': email.trim(),
        'password': password,
      });
      final session = SessionResponse.fromJson(json);
      if (session.accessToken.isEmpty ||
          session.user.id.isEmpty ||
          session.user.email.isEmpty ||
          session.user.role.isEmpty) {
        throw const FormatException('Incomplete session');
      }
      return session; // No side effects: only AuthSession may adopt a response.
    } on HttpError {
      rethrow;
    } on TimeoutException {
      throw const HttpError(
        status: 0,
        code: 'TIMEOUT',
        message: 'The request timed out. Please try again.',
      );
    } on http.ClientException {
      throw const HttpError(
        status: 0,
        code: 'NETWORK_ERROR',
        message: 'Unable to connect. Check your connection and try again.',
      );
    } on FormatException {
      throw const HttpError(
        status: 0,
        code: 'INVALID_RESPONSE',
        message:
            'The server returned an invalid sign-in response. Please try again.',
      );
    } on TypeError {
      throw const HttpError(
        status: 0,
        code: 'INVALID_RESPONSE',
        message:
            'The server returned an invalid sign-in response. Please try again.',
      );
    }
  }

  /// POST /api/v1/auth/register-intent  → sends OTP email, no session yet
  Future<RegistrationCodeResult> registerIntent(
    String email,
    String password,
    String fullName,
  ) async {
    final json = await _post('/api/v1/auth/register-intent', {
      'email': email,
      'password': password,
      'full_name': fullName,
    });
    return RegistrationCodeResult.fromJson(json);
  }

  /// POST /api/v1/auth/resend-registration
  Future<RegistrationCodeResult> resendRegistration(String email) async {
    final json = await _post('/api/v1/auth/resend-registration', {
      'email': email,
    });
    return RegistrationCodeResult.fromJson(json);
  }

  /// POST /api/v1/auth/verify-registration  → confirms OTP, starts session
  Future<SessionResponse> verifyRegistration(
    String email,
    String code, {
    String? password,
    String? fullName,
  }) async {
    final json = await _post('/api/v1/auth/verify-registration', {
      'email': email,
      'code': code,
      if (password != null) 'password': password,
      if (fullName != null) 'full_name': fullName,
    });
    final session = SessionResponse.fromJson(json);
    return session;
  }

  /// Existing web requests omit PKCE; native requests require explicit S256 support.
  Future<String> getGoogleAuthUrl([
    String? callbackUrl,
    String? codeChallenge,
  ]) async {
    final callback = callbackUrl?.trim();
    if (codeChallenge != null &&
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(codeChallenge))
      throw const HttpError(
        status: 0,
        code: 'GOOGLE_CONFIGURATION_ERROR',
        message: 'A secure Google authorization request could not be created.',
      );
    if (callback != null && callback.isNotEmpty && !_secureCallback(callback))
      throw const HttpError(
        status: 0,
        code: 'GOOGLE_CONFIGURATION_ERROR',
        message: 'Google sign-in needs a valid registered HTTPS callback.',
      );
    final query = <String, String>{
      if (callback != null && callback.isNotEmpty) 'redirect_uri': callback,
      if (codeChallenge != null) 'code_challenge': codeChallenge,
      if (codeChallenge != null) 'code_challenge_method': 'S256',
    };
    final result = await requestJson(
      'GET',
      Uri(
        path: '/api/v1/auth/google/url',
        queryParameters: query.isEmpty ? null : query,
      ).toString(),
    );
    final value = result['url'];
    final uri = value is String ? Uri.tryParse(value) : null;
    final state = result['state'];
    if (codeChallenge != null &&
        (result['pkce_supported'] != true ||
            uri?.queryParameters['code_challenge'] != codeChallenge ||
            uri?.queryParameters['code_challenge_method'] != 'S256'))
      throw const HttpError(
        status: 0,
        code: 'GOOGLE_MOBILE_NOT_READY',
        message:
            'Google mobile sign-in needs the compatible server update. Please use email sign-in until it is deployed.',
      );
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'accounts.google.com' ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        !{'/o/oauth2/v2/auth', '/o/oauth2/auth'}.contains(uri.path) ||
        state is! String ||
        state.isEmpty ||
        uri.queryParameters['state'] != state ||
        (uri.queryParameters['client_id'] ?? '').isEmpty ||
        uri.queryParameters['client_id']!.startsWith('mock_') ||
        !_secureCallback(uri.queryParameters['redirect_uri'] ?? '') ||
        (callback != null &&
            callback.isNotEmpty &&
            uri.queryParameters['redirect_uri'] != callback))
      throw const HttpError(
        status: 0,
        code: 'GOOGLE_CONFIGURATION_ERROR',
        message:
            'Google sign-in configuration could not be verified. Please contact your administrator.',
      );
    return value as String;
  }

  Future<SessionResponse> exchangeGoogleCode({
    required String code,
    required String redirectUri,
    required String verifier,
  }) async {
    try {
      final json = await _post('/api/v1/auth/google/callback', {
        'code': code,
        'redirect_uri': redirectUri,
        'code_verifier': verifier,
      });
      final session = SessionResponse.fromJson(json);
      if (session.accessToken.isEmpty ||
          session.user.id.isEmpty ||
          session.user.email.isEmpty ||
          session.user.role.isEmpty)
        throw const FormatException('Incomplete Google session');
      return session;
    } on HttpError {
      rethrow;
    } on FormatException {
      throw const HttpError(
        status: 0,
        code: 'INVALID_RESPONSE',
        message:
            'Google returned an incomplete sign-in response. Please try again.',
      );
    } on TypeError {
      throw const HttpError(
        status: 0,
        code: 'INVALID_RESPONSE',
        message:
            'Google returned an incomplete sign-in response. Please try again.',
      );
    }
  }

  Future<String> getAndroidGoogleServerClientId() async {
    try {
      final data = await requestJson(
        'GET',
        '/api/v1/auth/google/android/config',
      );
      final client = data['server_client_id'];
      if (client is! String ||
          !RegExp(
            r'^\d+-[A-Za-z0-9]+\.apps\.googleusercontent\.com$',
          ).hasMatch(client)) {
        throw const FormatException('Invalid Google server client');
      }
      return client;
    } on HttpError catch (error) {
      if (error.status != 404) rethrow;
      throw const HttpError(
        status: 404,
        code: 'GOOGLE_ANDROID_NOT_READY',
        message:
            'Android Google sign-in needs the server update. Please use email sign-in until it is deployed.',
      );
    } on FormatException {
      throw const HttpError(
        status: 0,
        code: 'GOOGLE_CONFIGURATION_ERROR',
        message: 'Google sign-in configuration could not be verified.',
      );
    }
  }

  Future<SessionResponse> exchangeAndroidGoogleCode(String code) async {
    final data = await _post('/api/v1/auth/google/android/callback', {
      'code': code,
    });
    try {
      final response = SessionResponse.fromJson(data);
      if (response.accessToken.isEmpty ||
          (response.refreshToken ?? '').isEmpty ||
          response.user.id.isEmpty ||
          response.user.email.isEmpty ||
          response.user.role.isEmpty) {
        throw const FormatException('Incomplete Google session');
      }
      return response;
    } on FormatException {
      throw const HttpError(
        status: 0,
        code: 'INVALID_RESPONSE',
        message:
            'Google returned an incomplete sign-in response. Please try again.',
      );
    } on TypeError {
      throw const HttpError(
        status: 0,
        code: 'INVALID_RESPONSE',
        message:
            'Google returned an incomplete sign-in response. Please try again.',
      );
    }
  }

  static bool _secureCallback(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.fragment.isEmpty;
  }

  /// POST /api/v1/auth/forgot-password
  Future<void> forgotPassword(String email) async {
    await _post('/api/v1/auth/forgot-password', {'email': email});
  }

  /// POST /api/v1/auth/reset-password
  Future<SessionResponse> resetPassword(
    String resetToken,
    String newPassword,
  ) async {
    final json = await _post('/api/v1/auth/reset-password', {
      'reset_token': resetToken,
      'new_password': newPassword,
    });
    final session = SessionResponse.fromJson(json);
    return session;
  }
}
