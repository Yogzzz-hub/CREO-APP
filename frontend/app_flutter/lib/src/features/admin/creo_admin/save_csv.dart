import 'dart:convert';
import 'dart:typed_data';
import '../../workstation/workstation_files.dart';

/// Export only after the user selects a destination in the system save sheet.
Future<String> saveCsv(String name, String csv) async {
  final saved = await WorkstationFileTransfer.saveBytes(
    bytes: Uint8List.fromList(utf8.encode(csv)),
    name: name,
    mimeType: 'text/csv',
  );
  return saved ? 'Saved CSV' : 'Save cancelled';
}
