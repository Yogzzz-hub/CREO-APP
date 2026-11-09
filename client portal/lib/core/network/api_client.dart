import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';
import '../storage/secure_storage_service.dart';

class ApiClient {
  late final Dio dio;
  final SecureStorageService _storage;

  ApiClient({SecureStorageService? storage})
      : _storage = storage ?? SecureStorageService() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.defaultBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // Token renewal flow on 401
          if (error.response?.statusCode == 401) {
            final refreshToken = await _storage.getRefreshToken();
            if (refreshToken != null && !error.requestOptions.path.contains('/auth/')) {
              try {
                final refreshResponse = await Dio().post(
                  '${ApiEndpoints.defaultBaseUrl}${ApiEndpoints.refresh}',
                  data: {'refresh_token': refreshToken},
                );
                final newAccessToken = refreshResponse.data['access_token'];
                final newRefreshToken = refreshResponse.data['refresh_token'] ?? refreshToken;
                await _storage.saveTokens(
                  accessToken: newAccessToken,
                  refreshToken: newRefreshToken,
                );

                // Retry original request with new token
                error.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                final retryResponse = await dio.fetch(error.requestOptions);
                return handler.resolve(retryResponse);
              } catch (_) {
                await _storage.clearSession();
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }
}

