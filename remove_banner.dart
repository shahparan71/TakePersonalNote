import 'dart:io';

void main() {
  final file = File('lib/screens/dashboard_screen.dart');
  String content = file.readAsStringSync();
  
  // Remove reference to _buildEmptyRestoreBanner
  content = content.replaceAll('_buildEmptyRestoreBanner(context),', '');
  
  // Remove the method itself
  final bannerRegex = RegExp(r'Widget _buildEmptyRestoreBanner\(BuildContext context\) \{[\s\S]*?return Container\([\s\S]*?\);\s*\}', multiLine: true);
  content = content.replaceAll(bannerRegex, '');
  
  file.writeAsStringSync(content);
}
