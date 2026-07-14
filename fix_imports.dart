import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>();
  
  final oldImport = "import 'package:flutter_gen/gen_l10n/app_localizations.dart';";
  final newImport = "import 'package:take_personal_note/l10n/app_localizations.dart';";
  
  for (var file in files) {
    if (file.path.endsWith('.dart')) {
      String content = file.readAsStringSync();
      
      if (content.contains(oldImport)) {
        content = content.replaceAll(oldImport, newImport);
        file.writeAsStringSync(content);
        print('Fixed import: ${file.path}');
      }
    }
  }
}
