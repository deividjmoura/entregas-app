import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ImageUtils {
  static final _picker = ImagePicker();

  /// Escolhe foto e retorna data-URL base64 (data:image/jpeg;base64,...)
  /// ou null se cancelar. Reduz qualidade para ~70% e max 1280px no lado maior.
  static Future<String?> escolherEConverter({
    ImageSource source = ImageSource.gallery,
    int maxLado = 1280,
    int qualidade = 70,
  }) async {
    final x = await _picker.pickImage(
      source: source,
      maxWidth: maxLado.toDouble(),
      maxHeight: maxLado.toDouble(),
      imageQuality: qualidade,
    );
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    final b64 = base64Encode(bytes);
    final mime = x.mimeType ?? 'image/jpeg';
    return 'data:$mime;base64,$b64';
  }

  static Uint8List? decodeDataUrl(String dataUrl) {
    try {
      final idx = dataUrl.indexOf('base64,');
      if (idx < 0) return base64Decode(dataUrl);
      return base64Decode(dataUrl.substring(idx + 7));
    } catch (e) {
      debugPrint('ImageUtils.decode: $e');
      return null;
    }
  }
}
