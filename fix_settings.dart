import 'dart:io';

void main() {
  final file = File('lib/screens/settings_screen.dart');
  String content = file.readAsStringSync();
  
  final target = '''              ListTile(
                leading: const Icon(Icons.language),
                title: Text(AppLocalizations.of(context)!.appLanguage),
                trailing: const Text('English'),
                onTap: () {},
              ),''';
              
  final replacement = '''              ListTile(
                leading: const Icon(Icons.language),
                title: Text(AppLocalizations.of(context)!.appLanguage),
                trailing: DropdownButton<String>(
                  value: settings.locale.languageCode,
                  onChanged: (val) {
                    if (val != null) settings.setLocale(val);
                  },
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'es', child: Text('Español')),
                    DropdownMenuItem(value: 'fr', child: Text('Français')),
                  ],
                ),
              ),''';

  if (content.contains(target)) {
    content = content.replaceFirst(target, replacement);
    file.writeAsStringSync(content);
    print('Fixed settings_screen.dart');
  } else {
    print('Target not found in settings_screen.dart');
  }
}
