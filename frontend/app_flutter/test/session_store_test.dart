import 'package:app_flutter/src/core/session_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class DeleteFailureStorage extends FlutterSecureStorage {
  bool fail = true;
  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (fail && key == 'creo_access_token') throw StateError('delete failed');
    await super.delete(
      key: key,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('single secure record supports refresh-only restoration', () async {
    const store = SecureSessionStore();
    await store.write(const StoredSession('', 'opaque-refresh', 'account-a'));
    final session = await store.read();
    expect(session?.accessToken, '');
    expect(session?.refreshToken, 'opaque-refresh');
  });
  test(
    'legacy records remain readable but have no invented account identity',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'creo_access_token': 'legacy-access',
        'creo_refresh_token': 'legacy-refresh',
      });
      final value = await const SecureSessionStore().read();
      expect(value?.userId, null);
      expect(value?.accessToken, 'legacy-access');
    },
  );
  test(
    'partial legacy deletion reports failure but tombstone prevents resurrection',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'creo_access_token': 'legacy-access',
        'creo_refresh_token': 'legacy-refresh',
      });
      final storage = DeleteFailureStorage();
      final store = SecureSessionStore(storage: storage);
      await expectLater(store.write(null), throwsStateError);
      expect(await store.read(), null);
      expect(await SecureSessionStore(storage: storage).read(), null);
      storage.fail = false;
      await store.write(null);
      expect(await store.read(), null);
    },
  );
  test(
    'corrupted secure record is not silently treated as signed out',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'creo_session_v1': 'invalid json',
      });
      await expectLater(
        const SecureSessionStore().read(),
        throwsFormatException,
      );
    },
  );
  test(
    'empty token pair is corrupted; tombstone is a deliberate signed-out state',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'creo_session_v1': '{"access_token":""}',
      });
      await expectLater(
        const SecureSessionStore().read(),
        throwsFormatException,
      );
      FlutterSecureStorage.setMockInitialValues({
        'creo_session_v1': '{"signed_out":true}',
        'creo_access_token': 'old',
      });
      expect(await const SecureSessionStore().read(), null);
    },
  );
}
