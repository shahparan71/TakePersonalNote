import 'package:flutter_test/flutter_test.dart';
import 'package:take_personal_note/services/backup_service.dart';

void main() {
  group('BackupService.foldersFromBackup', () {
    test('includes note categories when folder metadata is missing', () {
      final folders = BackupService.foldersFromBackup({
        'notes': [
          {'category': 'ind'},
          {'category': 'abc'},
          {'category': null},
          {'category': '  '},
        ],
      });

      expect(folders, ['ind', 'abc']);
    });

    test('combines explicit folders and note categories without duplicates', () {
      final folders = BackupService.foldersFromBackup({
        'folders': ['ind', ' work '],
        'notes': [
          {'category': 'ind'},
          {'category': 'personal'},
        ],
      });

      expect(folders, ['ind', 'work', 'personal']);
    });
  });
}