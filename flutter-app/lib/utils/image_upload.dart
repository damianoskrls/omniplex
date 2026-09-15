import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Resize and re-encode gallery photos as JPEG bytes before chat upload.
Future<Uint8List> prepareMessageImageBytes(String sourcePath) async {
  final source = File(sourcePath);
  if (!await source.exists()) {
    throw StateError('Η εικόνα δεν βρέθηκε');
  }

  final bytes = await source.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Δεν ήταν δυνατή η επεξεργασία της εικόνας. Δοκίμασε άλλη φωτογραφία.');
  }

  const maxDim = 1200;
  final needsResize = decoded.width > maxDim || decoded.height > maxDim;
  final resized = needsResize
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxDim : null,
          height: decoded.height > decoded.width ? maxDim : null,
        )
      : decoded;

  return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
}
