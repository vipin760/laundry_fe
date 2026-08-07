import 'invoice_saver_mobile.dart'
    if (dart.library.js_interop) 'invoice_saver_web.dart' as platform;

/// Cross-platform "save a downloaded invoice PDF" so the user can actually
/// get the file.
///
/// Mobile: writes the bytes to a temp file and opens the native share sheet.
/// Web: `path_provider`'s temporary directory and `dio.download()`-to-a-path
/// both rely on `dart:io`, which doesn't exist on web — using them there
/// throws a plain (non-Dio) exception that surfaces as a generic "Something
/// went wrong" error. Web instead triggers a normal browser download via a
/// Blob URL, since there's no filesystem or share sheet to use.
class InvoiceSaver {
  static Future<void> save(List<int> bytes, String filename) =>
      platform.saveInvoice(bytes, filename);
}
