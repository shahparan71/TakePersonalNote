import 'package:flutter_test/flutter_test.dart';
import 'package:take_personal_note/utils/note_utils.dart';

void main() {
  group('NoteUtils', () {
    test('uses the first body line as the display title when the title is empty', () {
      expect(
        NoteUtils.getDisplayTitle(title: '', content: 'First line\nSecond line'),
        'First line',
      );
    });

    test('falls back to Untitled when both title and body are empty', () {
      expect(NoteUtils.getDisplayTitle(title: '', content: ''), 'Untitled');
    });
  });
}
