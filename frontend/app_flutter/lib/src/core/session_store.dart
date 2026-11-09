import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredSession {
  const StoredSession(this.accessToken, this.refreshToken, this.userId);
  final String accessToken;
  final String? refreshToken;
  final String? userId;
}

abstract interface class SessionStore {
  Future<StoredSession?> read();
  Future<void> write(StoredSession? session);
}

/// A single secure record commits the token pair together. Old token keys remain
/// readable; an unidentified legacy session must be explicitly ended, not replaced.
class SecureSessionStore implements SessionStore {
  const SecureSessionStore({this.storage = const FlutterSecureStorage()});
  final FlutterSecureStorage storage;
  static const _record = 'creo_session_v1';

  @override
  Future<StoredSession?> read() async {
    final record = await storage.read(key: _record);
    if (record != null) {
      final json = jsonDecode(record) as Map<String, dynamic>;
      if (json['signed_out'] == true) return null;
      final access = json['access_token'] as String? ?? '';
      final refresh = json['refresh_token'] as String?;
      if (access.isEmpty && (refresh == null || refresh.isEmpty)) {
        throw const FormatException('Empty session');
      }
      return StoredSession(access, refresh, json['user_id'] as String?);
    }
    final access = await storage.read(key: 'creo_access_token');
    final refresh = await storage.read(key: 'creo_refresh_token');
    if (access == null && refresh == null) return null;
    return StoredSession(access ?? '', refresh, null);
  }

  @override
  Future<void> write(StoredSession? session) async {
    if (session == null) {
      // A durable tombstone prevents a partially failed legacy-key deletion
      // from restoring that account on the next launch. Keep it until adoption.
      await storage.write(key: _record, value: '{"signed_out":true}');
      Object? failure;
      for (final key in ['creo_access_token', 'creo_refresh_token']) {
        try {
          await storage.delete(key: key);
        } catch (error) {
          failure = error;
        }
      }
      if (failure != null) throw failure;
    } else {
      await storage.write(
        key: _record,
        value: jsonEncode({
          'access_token': session.accessToken,
          'refresh_token': session.refreshToken,
          'user_id': session.userId,
        }),
      );
    }
  }
}

const defaultSessionStore = SecureSessionStore();
