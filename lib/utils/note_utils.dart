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

  static String getDisplayTitle({required String title, required String content}) {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isNotEmpty) return trimmedTitle;

    final plainText = getPlainText(content).trim();
    if (plainText.isEmpty) return 'Untitled';

    final firstLine = plainText.split('\n').firstWhere((line) => line.trim().isNotEmpty, orElse: () => plainText).trim();
    return firstLine.isEmpty ? 'Untitled' : firstLine;
  }
}
