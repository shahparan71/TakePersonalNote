import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'backup_service.dart';

class GoogleDriveSyncResult {
  final bool success;
  final String message;
  final List<String> folders;

  GoogleDriveSyncResult({
    required this.success,
    required this.message,
    this.folders = const [],
  });
}

class GoogleDriveSyncService {
  static const String backupFileName = 'take_personal_note_backup.json';

  static final GoogleDriveSyncService _instance = GoogleDriveSyncService._internal();
  factory GoogleDriveSyncService() => _instance;
  GoogleDriveSyncService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() => _googleSignIn.signOut();

  Future<drive.DriveApi?> _driveApi() async {
    var account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    account ??= await signIn();
    if (account == null) return null;

    final client = await _googleSignIn.authenticatedClient();
    if (client == null) return null;
    return drive.DriveApi(client);
  }

  Future<GoogleDriveSyncResult> syncToDrive({List<String>? folders}) async {
    try {
      final api = await _driveApi();
      if (api == null) {
        return GoogleDriveSyncResult(success: false, message: 'Google sign-in cancelled or failed.');
      }

      final jsonString = await BackupService().exportAllToJson(folders: folders);
      final media = drive.Media(
        Stream.value(utf8.encode(jsonString)),
        jsonString.length,
        contentType: 'application/json',
      );

      final existing = await api.files.list(
        q: "name='$backupFileName' and trashed=false",
        spaces: 'drive',
        $fields: 'files(id,name)',
      );

      if (existing.files != null && existing.files!.isNotEmpty) {
        final fileId = existing.files!.first.id!;
        await api.files.update(
          drive.File()..name = backupFileName,
          fileId,
          uploadMedia: media,
        );
      } else {
        await api.files.create(
          drive.File()..name = backupFileName,
          uploadMedia: media,
        );
      }

      return GoogleDriveSyncResult(
        success: true,
        message: 'Backup synced to Google Drive successfully.',
      );
    } catch (e) {
      return GoogleDriveSyncResult(success: false, message: 'Sync failed: $e');
    }
  }

  Future<GoogleDriveSyncResult> fetchFromDrive({bool merge = true}) async {
    try {
      final api = await _driveApi();
      if (api == null) {
        return GoogleDriveSyncResult(success: false, message: 'Google sign-in cancelled or failed.');
      }

      final list = await api.files.list(
        q: "name='$backupFileName' and trashed=false",
        spaces: 'drive',
        $fields: 'files(id,name)',
      );

      if (list.files == null || list.files!.isEmpty) {
        return GoogleDriveSyncResult(success: false, message: 'No backup found on Google Drive.');
      }

      final fileId = list.files!.first.id!;
      final response = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final chunks = <int>[];
      await for (final chunk in response.stream) {
        chunks.addAll(chunk);
      }
      final jsonString = utf8.decode(chunks);

      final result = await BackupService().importFromJson(jsonString, merge: merge);
      return GoogleDriveSyncResult(
        success: true,
        message: 'Restored ${result.notesCount} notes and ${result.tasksCount} tasks from Drive.',
        folders: result.folders,
      );
    } catch (e) {
      return GoogleDriveSyncResult(success: false, message: 'Fetch failed: $e');
    }
  }
}
