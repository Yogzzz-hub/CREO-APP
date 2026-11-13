import 'package:flutter/services.dart';

/// Android and desktop: copy to the clipboard. Android 10+ stops background apps reading it.
/// The web build uses save_csv_web.dart instead, which downloads a file.
Future<String> saveCsv(String name, String csv) async {
  await Clipboard.setData(ClipboardData(text: csv));
  return 'Copied as CSV';
}
