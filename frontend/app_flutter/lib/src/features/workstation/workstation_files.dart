import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';

class WorkstationFile {
  const WorkstationFile({
    required this.path,
    required this.name,
    required this.size,
    required this.mimeType,
  });
  final String path, name, mimeType;
  final int size;
}

/// OS document picker copies only the selected document into private temporary
/// cache. No filesystem permission, permanent copy or credential is shared.
class WorkstationFileTransfer {
  WorkstationFileTransfer(this.session);
  final AuthSession session;
  static const channel = MethodChannel('creo/workstation_files');

  static Future<WorkstationFile?> pick({bool mediaOnly = true}) async {
    try {
      final result = await channel.invokeMapMethod<String, dynamic>('pick', {
        'mediaOnly': mediaOnly,
      });
      if (result == null) return null;
      return WorkstationFile(
        path: result['path'] as String,
        name: result['name'] as String,
        size: (result['size'] as num).toInt(),
        mimeType: result['mimeType'] as String,
      );
    } on MissingPluginException {
      throw const HttpError(
        status: 0,
        code: 'PICKER_UNAVAILABLE',
        message:
            'File selection is available in the Android and iOS application.',
      );
    } on PlatformException catch (error) {
      throw HttpError(
        status: 0,
        code: 'FILE_SELECTION_FAILED',
        message: error.message ?? 'Unable to read the selected file.',
      );
    }
  }

  static Future<void> release(WorkstationFile file) async {
    try {
      await channel.invokeMethod<void>('release', {'path': file.path});
    } on MissingPluginException {
      /* Browser preview has no local file. */
    } on PlatformException {
      // Best-effort deletion only; a failed cleanup must not create an
      // unhandled Future after a delivery screen has been disposed.
    }
  }

  static Future<void> preview(WorkstationFile file) async {
    try {
      await channel.invokeMethod<void>('preview', {'path': file.path});
    } on MissingPluginException {
      throw const HttpError(
        status: 0,
        code: 'PREVIEW_UNAVAILABLE',
        message: 'Local media preview is available in the mobile application.',
      );
    } on PlatformException catch (error) {
      throw HttpError(
        status: 0,
        code: 'PREVIEW_UNAVAILABLE',
        message: error.message ?? 'No application could preview this file.',
      );
    }
  }

  /// Sends authenticated download bytes to the operating system's save sheet.
  static Future<bool> saveBytes({
    required Uint8List bytes,
    required String name,
    required String mimeType,
  }) async {
    if (bytes.isEmpty || name.trim().isEmpty || mimeType.trim().isEmpty) {
      throw const HttpError(
        status: 0,
        code: 'INVALID_DOWNLOAD',
        message: 'The downloaded file is empty or incomplete.',
      );
    }
    try {
      return await channel.invokeMethod<bool>('save', {
            'bytes': bytes,
            'name': name,
            'mimeType': mimeType,
          }) ??
          false;
    } on MissingPluginException {
      throw const HttpError(
        status: 0,
        code: 'SAVE_UNAVAILABLE',
        message:
            'Saving files is available in the Android and iOS application.',
      );
    } on PlatformException catch (error) {
      throw HttpError(
        status: 0,
        code: 'SAVE_FAILED',
        message: error.message ?? 'Unable to save the downloaded file.',
      );
    }
  }

  static String? validate(WorkstationFile file) {
    const supported = [
      'video/mp4',
      'video/quicktime',
      'image/png',
      'image/jpeg',
      'image/webp',
      'image/gif',
    ];
    if (!supported.contains(file.mimeType)) {
      return 'Choose MP4/MOV video or PNG/JPG/WEBP/GIF images.';
    }
    if (file.size <= 0) return 'This file is empty.';
    final video = file.mimeType.startsWith('video/');
    if (video && file.size < 1024) {
      return 'This video is too small (less than 1 KB).';
    }
    if (file.size > (video ? 500 : 10) * 1024 * 1024) {
      return 'Maximum size is 10 MB for images and 500 MB for videos.';
    }
    return null;
  }

  Future<Map<String, dynamic>> upload(
    String path,
    WorkstationFile file, {
    String? notes,
    void Function(double)? onProgress,
    Map<String, String> fields = const {},
    bool mediaOnly = true,
  }) async {
    final problem = mediaOnly
        ? validate(file)
        : file.size <= 0 || file.size > 50 * 1024 * 1024
        ? 'Attachments must be between 1 byte and 50 MB.'
        : null;
    if (problem != null) {
      throw HttpError(status: 0, code: 'INVALID_FILE', message: problem);
    }
    final generation = session.beginReadGeneration;
    return session.request(
      'POST',
      path,
      requestTimeout: const Duration(minutes: 10),
      buildRequest: (uri) async {
        final request = http.MultipartRequest('POST', uri);
        request.fields.addAll(fields);
        if (notes?.isNotEmpty ?? false) request.fields['notes'] = notes!;
        final source = await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: file.name,
        );
        var sent = 0;
        request.files.add(
          http.MultipartFile(
            'file',
            source.finalize().map((chunk) {
              if (!session.isCurrent(generation)) {
                throw const HttpError(
                  status: 0,
                  code: 'SESSION_CANCELLED',
                  message: 'This upload belongs to an ended session.',
                );
              }
              sent += chunk.length;
              onProgress?.call((sent / file.size).clamp(0, 1));
              return chunk;
            }),
            source.length,
            filename: file.name,
          ),
        );
        return request;
      },
    );
  }
}
