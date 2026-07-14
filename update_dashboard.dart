import 'dart:io';

void main() {
  final file = File('lib/screens/dashboard_screen.dart');
  String content = file.readAsStringSync();
  
  // 1. Remove _buildEmptyRestoreBanner(context),
  content = content.replaceAll('_buildEmptyRestoreBanner(context),', '');
  
  // 2. Remove the _buildEmptyRestoreBanner method
  final bannerRegex = RegExp(r'Widget _buildEmptyRestoreBanner\(BuildContext context\) \{[\s\S]*?return Container\([\s\S]*?\);\s*\}', multiLine: true);
  content = content.replaceAll(bannerRegex, '');
  
  // 3. Fix const DesignSectionTitle
  content = content.replaceAll('const DesignSectionTitle(title: AppLocalizations', 'DesignSectionTitle(title: AppLocalizations');
  
  // 4. Inject _checkPendingSync into initState, PRESERVING existing initState content
  final initStateRegex = RegExp(r'void initState\(\)\s*\{([\s\S]*?)\}');
  if (initStateRegex.hasMatch(content)) {
    content = content.replaceFirstMapped(initStateRegex, (match) {
      final existingBody = match.group(1);
      return '''void initState() {
    _checkPendingSync();\$existingBody}
    
  Future<void> _checkPendingSync() async {
    final prefs = PreferenceService();
    final hasPendingNotes = await prefs.hasNotesPendingDriveSync();
    final hasPendingTasks = await prefs.hasTasksPendingDriveSync();
    if (hasPendingNotes || hasPendingTasks) {
      GoogleDriveSyncService().syncIfSignedIn();
    }
  }''';
    });
  }
  
  file.writeAsStringSync(content);
  print('dashboard_screen.dart successfully updated.');
}
