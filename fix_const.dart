import 'dart:io';

void main() {
  final dir = Directory('lib/screens');
  final files = dir.listSync(recursive: true).whereType<File>();
  
  for (var file in files) {
    if (file.path.endsWith('.dart')) {
      String content = file.readAsStringSync();
      bool changed = false;
      
      // Fix "const Text(AppLocalizations" -> "Text(AppLocalizations"
      if (content.contains('const Text(AppLocalizations')) {
        content = content.replaceAll('const Text(AppLocalizations', 'Text(AppLocalizations');
        changed = true;
      }
      
      // Fix "const Center(child: Text(AppLocalizations" -> "Center(child: Text(AppLocalizations"
      if (content.contains('const Center(child: Text(AppLocalizations')) {
        content = content.replaceAll('const Center(child: Text(AppLocalizations', 'Center(child: Text(AppLocalizations');
        changed = true;
      }
      
      // Fix "const ListTile(title: Text(AppLocalizations" -> "ListTile(title: Text(AppLocalizations"
      if (content.contains('const ListTile(title: Text(AppLocalizations')) {
        content = content.replaceAll('const ListTile(title: Text(AppLocalizations', 'ListTile(title: Text(AppLocalizations');
        changed = true;
      }
      
      // Fix const DropdownMenuItem items lists that contain AppLocalizations
      // "items: const [" where items contain AppLocalizations -> "items: ["
      // We need a regex to find "items: const [" followed by AppLocalizations within the list
      final itemsConstRegex = RegExp(r'items:\s*const\s*\[');
      if (itemsConstRegex.hasMatch(content) && content.contains('AppLocalizations')) {
        content = content.replaceAll(itemsConstRegex, 'items: [');
        changed = true;
      }

      // Fix "const Text(\n" followed by AppLocalizations on the next line
      // This handles multi-line const Text patterns  
      final multilineConstText = RegExp(r'const Text\(\s*\n\s*AppLocalizations');
      if (multilineConstText.hasMatch(content)) {
        content = content.replaceAllMapped(multilineConstText, (Match m) {
          return m[0]!.replaceFirst('const Text(', 'Text(');
        });
        changed = true;
      }
      
      if (changed) {
        file.writeAsStringSync(content);
        print('Fixed: ${file.path}');
      }
    }
  }
}
