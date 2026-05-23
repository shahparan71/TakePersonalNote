import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

void main() {
  final controller = QuillController.basic();
  
  QuillEditor.basic(
    controller: controller,
    focusNode: FocusNode(),
  );

  QuillSimpleToolbar(
    controller: controller,
    config: const QuillSimpleToolbarConfig(
      showBoldButton: true,
      showItalicButton: true,
      showListBullets: true,
      showBackgroundColorButton: true,
      showFontSize: true,
    ),
  );
}
