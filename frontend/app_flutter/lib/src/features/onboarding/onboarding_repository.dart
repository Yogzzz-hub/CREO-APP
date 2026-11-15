import '../../core/auth_session.dart';
import '../../core/auth_repository.dart';
import '../workstation/workstation_files.dart';

class ClientOnboardingRepository {
  ClientOnboardingRepository(this.session)
    : _generation = session.beginReadGeneration;
  final AuthSession session;
  final int _generation;
  Future<void> removeLogo() async {
    _check();
    if (!_writes.add('logo'))
      throw const HttpError(
        status: 409,
        code: 'WRITE_UNCONFIRMED',
        message: 'The previous logo action is pending or unconfirmed.',
      );
    try {
      final result = await session.request(
        'DELETE',
        '/api/v1/onboarding/questionnaire/logo',
      );
      _check();
      if (result['status'] != 'ok')
        throw const FormatException('Deletion unconfirmed');
      _writes.remove('logo');
    } catch (error) {
      if (error is HttpError &&
          error.status >= 400 &&
          error.status < 500 &&
          !{
            'TIMEOUT',
            'NETWORK_ERROR',
            'INVALID_RESPONSE',
          }.contains(error.code)) {
        _writes.remove('logo');
        rethrow;
      }
      throw const HttpError(
        status: 0,
        code: 'WRITE_UNCONFIRMED',
        message:
            'Logo removal is unconfirmed. Refresh saved brand details before retrying.',
      );
    }
  }

  Future<String?> uploadLogo() async {
    _check();
    final file = await WorkstationFileTransfer.pick(mediaOnly: false);
    if (file == null) return null;
    try {
      final extension = file.name.toLowerCase().split('.').last;
      if (!{'png', 'jpg', 'jpeg', 'svg'}.contains(extension) ||
          file.size <= 0 ||
          file.size > 10 * 1024 * 1024) {
        throw const HttpError(
          status: 400,
          code: 'INVALID_LOGO',
          message: 'Choose a PNG, JPG or SVG logo up to 10 MB.',
        );
      }
      _check();
      if (!_writes.add('logo')) {
        throw const HttpError(
          status: 409,
          code: 'WRITE_UNCONFIRMED',
          message: 'The previous logo upload is pending or unconfirmed.',
        );
      }
      final result = await WorkstationFileTransfer(
        session,
      ).upload('/api/v1/onboarding/questionnaire/logo', file, mediaOnly: false);
      _check();
      if (result['logo_url'] is! String) {
        throw const FormatException('Logo not confirmed');
      }
      _writes.remove('logo');
      return result['logo_url'] as String;
    } catch (error) {
      if (error is HttpError &&
          error.status >= 400 &&
          error.status < 500 &&
          !{
            'TIMEOUT',
            'NETWORK_ERROR',
            'INVALID_RESPONSE',
          }.contains(error.code)) {
        if (error.code != 'WRITE_UNCONFIRMED') _writes.remove('logo');
        rethrow;
      }
      throw const HttpError(
        status: 0,
        code: 'WRITE_UNCONFIRMED',
        message:
            'The logo upload outcome is unconfirmed. Refresh saved brand details before trying again.',
      );
    } finally {
      await WorkstationFileTransfer.release(file);
    }
  }

  static final _blocked = Expando<Map<int, Set<String>>>();
  Set<String> get _writes =>
      (_blocked[session] ??= {}).putIfAbsent(_generation, () => {});
  void _check() {
    if (!session.isCurrent(_generation) ||
        session.phase != SessionPhase.authenticated ||
        !{'client', 'client_owner'}.contains(session.current?.user.role) ||
        session.current?.user.mustResetPassword == true) {
      throw const HttpError(
        status: 403,
        code: 'FORBIDDEN',
        message: 'This onboarding session has ended.',
      );
    }
  }

  Future<Map<String, dynamic>> read(String endpoint) async {
    _check();
    final value = await session.request('GET', '/api/v1/onboarding/$endpoint');
    _check();
    return value;
  }

  Future<Map<String, dynamic>> write(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    _check();
    if (!_writes.add(endpoint)) {
      throw const HttpError(
        status: 409,
        code: 'WRITE_UNCONFIRMED',
        message:
            'The previous request is pending or unconfirmed. Refresh server progress before continuing.',
      );
    }
    try {
      final value = await session.request(
        'POST',
        '/api/v1/onboarding/$endpoint',
        body: body,
      );
      _check();
      final verified = switch (endpoint) {
        'terms' => value['status'] == 'ok',
        'questionnaire/sections' => value['version'] is num,
        'complete' => value['status'] == 'completed',
        'brand' => value['status'] is String,
        _ => false,
      };
      if (!verified)
        throw const FormatException('The save response was not confirmed.');
      _writes.remove(endpoint);
      return value;
    } catch (error) {
      if (error is HttpError &&
          error.status >= 400 &&
          error.status < 500 &&
          !{
            'TIMEOUT',
            'NETWORK_ERROR',
            'INVALID_RESPONSE',
          }.contains(error.code)) {
        _writes.remove(endpoint);
        rethrow;
      }
      throw const HttpError(
        status: 0,
        code: 'WRITE_UNCONFIRMED',
        message:
            'The outcome is unconfirmed. Your answers remain on this screen. Verify saved progress before another submission.',
      );
    }
  }

  Future<Map<String, dynamic>> save(
    String section,
    Map<String, dynamic> original,
    Map<String, dynamic> edits,
  ) {
    if (!'abcdefg'.split('').contains(section)) {
      throw ArgumentError('Invalid section');
    }
    return write(
      'questionnaire/sections',
      body: {
        'sections': {
          section: {...original, ...edits},
        },
        'active_section': section,
      },
    );
  }
}
