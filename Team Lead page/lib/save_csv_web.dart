import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web: download a .csv file, so invoice data never sits on the clipboard where other pages can read it.
Future<String> saveCsv(String name, String csv) async {
  final url = web.URL.createObjectURL(web.Blob([csv.toJS].toJS, web.BlobPropertyBag(type: 'text/csv')));
  (web.HTMLAnchorElement()
        ..href = url
        ..download = name)
      .click();
  web.URL.revokeObjectURL(url);
  return 'Downloaded $name';
}
