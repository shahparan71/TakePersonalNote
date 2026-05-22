import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';

class NoteUtils {
  static String getPlainText(String content) {
    if (content.isEmpty) return '';
    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        final doc = Document.fromJson(decoded);
        return doc.toPlainText().trim();
      }
    } catch (_) {}
    return content;
  }
}
