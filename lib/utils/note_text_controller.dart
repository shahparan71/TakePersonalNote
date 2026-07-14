import 'package:flutter/material.dart';

class NoteTextController extends TextEditingController {
  final List<TextEditingValue> _undoStack = [];
  bool isHighlighterActive = false;
  double fontSize = 18.0;

  NoteTextController({String? text}) : super(text: text) {
    if (text != null) {
      _undoStack.add(value);
    }
    
    addListener(_handleTextUpdate);
  }

  void _handleTextUpdate() {
    // If highlighter is active and text was added, wrap it in ==
    if (isHighlighterActive && value.text.length > (_undoStack.isEmpty ? 0 : _undoStack.last.text.length)) {
      final oldText = _undoStack.isEmpty ? '' : _undoStack.last.text;
      final newChar = value.text.substring(oldText.length);
      
      // Only wrap if it's a single char being typed (standard typing)
      if (newChar.length == 1 && !newChar.contains('=') && !newChar.contains('\n')) {
        final newText = oldText + '==' + newChar + '==';
        
        removeListener(_handleTextUpdate);
        value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length - 2),
        );
        addListener(_handleTextUpdate);
      }
    }

    // Only push to stack if text actually changed (not just selection)
    if (_undoStack.isEmpty || _undoStack.last.text != value.text) {
      // Limit stack size to 500 for performance
      if (_undoStack.length > 500) _undoStack.removeAt(0);
      _undoStack.add(value);
    }
  }

  void undo() {
    if (_undoStack.length > 1) {
      _undoStack.removeLast(); // Remove current state
      final previousState = _undoStack.last;
      
      // Temporarily remove listener to avoid pushing back to stack
      removeListener(_handleTextUpdate);
      value = previousState;
      addListener(_handleTextUpdate);
    }
  }

  bool get canUndo => _undoStack.length > 1;

  void toggleHighlighter() {
    isHighlighterActive = !isHighlighterActive;
    notifyListeners();
  }

  void updateFontSize(double newSize) {
    fontSize = newSize;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final List<TextSpan> children = [];
    final pattern = RegExp(r'(\*\*.*?\*\*|__.*?__|==.*?==)');
    final matches = pattern.allMatches(text);

    int lastMatchIndex = 0;
    for (final match in matches) {
      if (match.start > lastMatchIndex) {
        children.add(TextSpan(text: text.substring(lastMatchIndex, match.start)));
      }

      final matchedText = match.group(0)!;
      if (matchedText.startsWith('**')) {
        children.add(TextSpan(
          text: matchedText.substring(2, matchedText.length - 2),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else if (matchedText.startsWith('__')) {
        children.add(TextSpan(
          text: matchedText.substring(2, matchedText.length - 2),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      } else if (matchedText.startsWith('==')) {
        children.add(TextSpan(
          text: matchedText.substring(2, matchedText.length - 2),
          style: const TextStyle(backgroundColor: Colors.yellowAccent),
        ));
      }
      lastMatchIndex = match.end;
    }

    if (lastMatchIndex < text.length) {
      children.add(TextSpan(text: text.substring(lastMatchIndex)));
    }

    return TextSpan(style: style?.copyWith(fontSize: fontSize), children: children.isEmpty ? null : children);
  }
}
