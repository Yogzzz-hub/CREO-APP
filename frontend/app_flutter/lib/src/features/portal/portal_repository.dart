import 'dart:math';

import 'package:http/http.dart' as http;

import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';
import '../workstation/workstation_files.dart';

typedef PortalRecord = Map<String, dynamic>;

List<PortalRecord> portalRows(Object? value) {
  if (value == null) return const [];
  if (value is! List || value.any((row) => row is! Map<String, dynamic>)) {
    throw const FormatException('The server returned an invalid list.');
  }
  return value.cast<PortalRecord>();
}

String _newIdempotencyKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String portalText(Object? value, [String fallback = '']) =>
    value == null ? fallback : value.toString();

/// One account boundary for all portal reads and writes. Ambiguous writes are
/// retained across reopened pages, preventing an automatic second submission.
class PortalRepository {
  PortalRepository(this.session)
    : generation = session.beginReadGeneration,
      accountId = session.current?.user.id;

  final AuthSession session;
  final int generation;
  final String? accountId;
  static final _journals = Expando<Map<String, int>>();

  void check() {
    if (session.phase != SessionPhase.authenticated ||
        !session.isCurrent(generation) ||
        session.current?.user.id != accountId ||
        !{'client', 'client_owner'}.contains(session.current?.user.role) ||
        session.current?.user.mustResetPassword == true) {
      throw const HttpError(
        status: 403,
        code: 'PORTAL_FORBIDDEN',
        message: 'Sign in with your client account to continue.',
      );
    }
  }

  Future<PortalRecord> read(String path) async {
    check();
    final result = await session.request('GET', path);
    check();
    return result;
  }

  Future<PortalRecord> write(
    String method,
    String path,
    PortalRecord body, {
    bool Function(PortalRecord)? accepts,
    Future<PortalRecord> Function()? operation,
    Map<String, String> headers = const {},
  }) async {
    check();
    final journal = _journals[session] ??= {};
    final key = '$method:$path';
    if (journal[key] == generation) {
      throw const HttpError(
        status: 0,
        code: 'WRITE_UNCONFIRMED',
        message:
            'The previous request is still pending or unconfirmed. Contact support before submitting it again.',
      );
    }
    journal[key] = generation;
    try {
      final result =
          await (operation?.call() ??
              session.request(method, path, body: body, headers: headers));
      check();
      if (result['status'] == 'error' || result['success'] == false) {
        throw HttpError(
          status: 422,
          code: 'VALIDATION_FAILED',
          message: portalText(result['message'], 'The request was rejected.'),
        );
      }
      final confirmed =
          accepts?.call(result) ??
          (result['success'] == true ||
              result['status'] is String ||
              portalText(result['id']).isNotEmpty);
      if (!confirmed) {
        throw const FormatException(
          'The server response could not be confirmed.',
        );
      }
      journal.remove(key);
      return result;
    } catch (error) {
      if (method == 'PUT' ||
          error is HttpError &&
              error.status >= 400 &&
              error.status < 500 &&
              error.code != 'TIMEOUT') {
        journal.remove(key);
      }
      if (journal[key] == generation && session.isCurrent(generation)) {
        throw const HttpError(
          status: 0,
          code: 'WRITE_UNCONFIRMED',
          message:
              'The server response was interrupted. This request may have completed. Your input has been retained. Contact support before submitting it again.',
        );
      }
      rethrow;
    }
  }

  Future<PortalRecord> profile() => read('/api/v1/portal/profile');
  Future<PortalRecord> saveProfile(PortalRecord values) => write(
    'PUT',
    '/api/v1/portal/profile',
    values,
    accepts: (result) => result['status'] == 'success',
  );
  Future<PortalRecord> regenerateBrandDna(PortalRecord answers) => write(
    'POST',
    '/api/v1/portal/brand-dna/regenerate',
    answers,
    accepts: (result) =>
        result['status'] == 'success' && result['brand_dna'] is Map,
  );
  Future<PortalRecord> changePassword(String current, String next) => write(
    'POST',
    '/api/v1/portal/change-password',
    {'current_password': current, 'new_password': next},
    accepts: (result) => result['status'] == 'success',
  );
  Future<PortalRecord> calendar() => read('/api/v1/portal/calendar');
  Future<List<PortalRecord>> calendarEntries() async =>
      portalRows((await read('/api/v1/calendar/entries'))['items']);

  Future<PortalRecord> approveConcept(
    String slotId, {
    PortalRecord? selectedHook,
  }) => write(
    'POST',
    '/api/v1/calendar/slots/${Uri.encodeComponent(slotId)}/approve-concept',
    {'selected_hook': selectedHook, 'notes': 'Client approved concept'},
    accepts: (result) =>
        result['status'] == 'concept_approved' && result['slot_id'] == slotId,
  );

  Future<PortalRecord> requestConceptChanges(String slotId, String notes) =>
      write(
        'POST',
        '/api/v1/calendar/slots/${Uri.encodeComponent(slotId)}/request-changes',
        {'notes': notes},
        accepts: (result) =>
            result['status'] == 'revision_requested' &&
            result['slot_id'] == slotId,
      );

  Future<PortalRecord> approveDeliverable(
    String id, {
    String? publishingFingerprint,
  }) => write(
    'POST',
    '/api/v1/deliverables/${Uri.encodeComponent(id)}/approve',
    {
      if (publishingFingerprint != null)
        'publishing_fingerprint': publishingFingerprint,
    },
    headers: {'Idempotency-Key': _newIdempotencyKey()},
    accepts: (result) =>
        result['status'] == 'approved' && result['deliverable_id'] == id,
  );
  Future<PortalRecord> approveCycle(String id) => write(
    'POST',
    '/api/v1/portal/cycles/${Uri.encodeComponent(id)}/approve',
    {},
    accepts: (result) =>
        result['status'] == 'active' && result['cycle_id'] == id,
  );
  Future<PortalRecord> commentCycle(String id, String body, {String? slot}) =>
      write(
        'POST',
        '/api/v1/portal/cycles/${Uri.encodeComponent(id)}/comment',
        {'body': body, if (slot != null) 'slot_id': slot},
        accepts: (result) => result['status'] == 'comment_received',
      );
  Future<PortalRecord> tickets() => read('/api/v1/tickets');
  Future<PortalRecord> ticket(String id) =>
      read('/api/v1/tickets/${Uri.encodeComponent(id)}');
  Future<PortalRecord> createTicket(
    String title,
    String description,
    String priority,
  ) => write('POST', '/api/v1/tickets', {
    'title': title,
    'description': description,
    'priority': priority,
  }, accepts: (result) => portalText(result['id']).isNotEmpty);
  Future<PortalRecord> reply(String id, String message) => write(
    'POST',
    '/api/v1/tickets/${Uri.encodeComponent(id)}/messages',
    {'message': message},
    accepts: (result) => portalText(result['id']).isNotEmpty,
  );

  Future<AuthenticatedBytes> approvedAssetsArchive() async {
    check();
    final result = await session.requestBytes(
      '/api/v1/portal/deliverables/download-zip',
    );
    check();
    final mediaType = result.contentType.split(';').first.trim().toLowerCase();
    if (result.bytes.isEmpty ||
        !{
          'application/zip',
          'application/x-zip-compressed',
        }.contains(mediaType)) {
      throw const FormatException(
        'The approved asset archive could not be verified.',
      );
    }
    return result;
  }

  Future<PortalRecord> requestDeliverableChanges(
    String id,
    String comment, {
    String? voiceNoteUrl,
    int? voiceNoteDuration,
  }) => write(
    'POST',
    '/api/v1/deliverables/${Uri.encodeComponent(id)}/request-changes',
    {
      'rejection_comment': comment,
      if (voiceNoteUrl != null) 'voice_note_url': voiceNoteUrl,
      if (voiceNoteDuration != null) 'voice_note_duration': voiceNoteDuration,
    },
    accepts: (result) =>
        result['status'] == 'revision_requested' &&
        result['deliverable_id'] == id,
  );

  Future<PortalRecord> uploadVoiceNote(
    String deliverableId,
    WorkstationFile file,
  ) {
    check();
    const audioExtensions = {'aac', 'm4a', 'mp3', 'ogg', 'opus', 'wav', 'webm'};
    final extension = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : '';
    if ((!file.mimeType.startsWith('audio/') &&
            !audioExtensions.contains(extension)) ||
        file.size <= 0 ||
        file.size > 25 * 1024 * 1024) {
      throw const HttpError(
        status: 0,
        code: 'INVALID_AUDIO_FILE',
        message: 'Choose an audio file up to 25 MB.',
      );
    }
    final path =
        '/api/v1/deliverables/${Uri.encodeComponent(deliverableId)}/upload-voice-note';
    return write(
      'POST',
      path,
      const {},
      accepts: (result) => portalText(result['voice_note_url']).isNotEmpty,
      operation: () => session.request(
        'POST',
        path,
        requestTimeout: const Duration(minutes: 10),
        buildRequest: (uri) async {
          final request = http.MultipartRequest('POST', uri);
          request.files.add(
            await http.MultipartFile.fromPath(
              'audio',
              file.path,
              filename: file.name,
              contentType: http.MediaType.parse(file.mimeType),
            ),
          );
          return request;
        },
      ),
    );
  }

  Future<PortalRecord> billing() => read('/api/v1/payments/subscription');
  Future<PortalRecord> plans() => read('/api/v1/payments/plans');
  Future<PortalRecord> pod() => read('/api/v1/portal/pod');
  Future<PortalRecord> callAvailability() =>
      read('/api/v1/portal/pod-calls/availability');
  Future<PortalRecord> bookCall(String startsAt) => write(
    'POST',
    '/api/v1/portal/pod-calls',
    {'starts_at': startsAt},
    accepts: (result) =>
        portalText(result['id']).isNotEmpty && result['starts_at'] != null,
  );
}
