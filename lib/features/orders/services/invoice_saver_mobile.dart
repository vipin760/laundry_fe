import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile/desktop backend for [InvoiceSaver] — writes the PDF to a temp file
/// and opens the native share sheet so the user can save/open it.
Future<void> saveInvoice(List<int> bytes, String filename) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$filename';
  final file = File(path);
  await file.writeAsBytes(Uint8List.fromList(bytes));
  await Share.shareXFiles([XFile(path)], text: filename);
}
