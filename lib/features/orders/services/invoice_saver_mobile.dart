import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile/desktop backend for [InvoiceSaver] — writes the PDF to a temp file
/// and opens the native share sheet so the user can save/open it.
Future<void> saveInvoice(List<int> bytes, String filename) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/${_safeFilename(filename)}';
  final file = File(path);
  await file.writeAsBytes(Uint8List.fromList(bytes));
  await Share.shareXFiles([XFile(path)], text: filename);
}

/// Reduces a server-supplied invoice name to a plain filename.
///
/// The name comes from the backend's `invoiceNumber`, so path separators or
/// `..` segments in it would otherwise decide where this file gets written.
String _safeFilename(String filename) {
  final base = filename.split(RegExp(r'[/\\]')).last;
  final cleaned = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final trimmed = cleaned.replaceAll(RegExp(r'^\.+'), '');
  return trimmed.isEmpty ? 'invoice.pdf' : trimmed;
}
