import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService() : _storage = const FlutterSecureStorage();

  static const String _accessTokenKey = 'creo_access_token';
  static const String _refreshTokenKey = 'creo_refresh_token';
  static const String _userIdKey = 'creo_user_id';
  static const String _userRoleKey = 'creo_user_role';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? userId,
    String? role,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    if (userId != null) await _storage.write(key: _userIdKey, value: userId);
    if (role != null) await _storage.write(key: _userRoleKey, value: role);
  }

  Future<String?> getAccessToken() async => await _storage.read(key: _accessTokenKey);
  Future<String?> getRefreshToken() async => await _storage.read(key: _refreshTokenKey);
  Future<String?> getUserId() async => await _storage.read(key: _userIdKey);
  Future<String?> getUserRole() async => await _storage.read(key: _userRoleKey);

  Future<void> clearSession() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _userRoleKey);
  }
}

