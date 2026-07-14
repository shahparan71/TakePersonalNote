import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../config/google_auth_config.dart';
import 'backup_service.dart';
import 'preference_service.dart';

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

class GoogleDriveSyncService extends ChangeNotifier {
  static const String backupFileName = 'take_personal_note_backup.json';
  static const Duration autoSyncMinInterval = Duration(minutes: 15);

  static final GoogleDriveSyncService _instance = GoogleDriveSyncService._internal();
  factory GoogleDriveSyncService() => _instance;
  GoogleDriveSyncService._internal();

  String? _lastAuthError;
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  void _setSyncing(bool value) {
    if (_isSyncing != value) {
      _isSyncing = value;
      notifyListeners();
    }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      drive.DriveApi.driveFileScope,
    ],
    serverClientId: kGoogleSignInWebClientId,
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  bool get isSignedIn => _googleSignIn.currentUser != null;

  String? get lastAuthError => _lastAuthError;

  /// Signs in when needed (interactive). Use before manual sync/fetch.
  Future<bool> ensureSignedIn() async {
    if (_googleSignIn.currentUser != null) return true;
    final silent = await _googleSignIn.signInSilently();
    if (silent != null) return true;
    return (await signIn()) != null;
  }

  Future<GoogleSignInAccount?> signIn() async {
    _lastAuthError = null;
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        _lastAuthError = 'Sign-in was cancelled.';
      }
      return account;
    } on PlatformException catch (e) {
      _lastAuthError = _formatPlatformSignInError(e);
      debugPrint('Google sign-in PlatformException: ${e.code} ${e.message}');
      return null;
    } catch (e, st) {
      _lastAuthError = 'Sign-in failed: $e';
      debugPrint('Google sign-in error: $e\n$st');
      return null;
    }
  }

  Future<void> signOut() => _googleSignIn.signOut();

  String _signInFailureMessage() {
    return _lastAuthError ??
        'Google sign-in failed. Add your debug SHA-1 in Firebase, enable Google '
        'sign-in, enable Drive API, and replace android/app/google-services.json '
        '(see docs/FIREBASE_GOOGLE_DRIVE_SETUP.md).';
  }

  Future<drive.DriveApi?> _driveApi() async {
    _lastAuthError = null;
    try {
      var account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signInSilently();
      account ??= await signIn();
      if (account == null) {
        return null;
      }

      final client = await _googleSignIn.authenticatedClient();
      if (client == null) {
        _lastAuthError =
            'Could not obtain Google API access token. Ensure Google Sign-In is '
            'enabled in Firebase Authentication and your Web OAuth client is configured '
            '(set kGoogleSignInWebClientId or update google-services.json).';
        return null;
      }
      return drive.DriveApi(client);
    } on PlatformException catch (e) {
      _lastAuthError = _formatPlatformSignInError(e);
      debugPrint('Google Drive auth PlatformException: ${e.code} ${e.message}');
      return null;
    } catch (e, st) {
      _lastAuthError = 'Authentication failed: $e';
      debugPrint('Google Drive auth error: $e\n$st');
      return null;
    }
  }

  String _formatPlatformSignInError(PlatformException e) {
    final code = e.code;
    final message = e.message ?? '';
    if (code == 'sign_in_failed' || message.contains('10')) {
      return 'Sign-in configuration error (ApiException 10). Register your app SHA-1 '
          'in Firebase and re-download google-services.json.';
    }
    if (code == 'network_error') {
      return 'Network error during sign-in. Check your connection and try again.';
    }
    return 'Google sign-in error ($code): $message';
  }

  Future<GoogleDriveSyncResult> syncToDrive({List<String>? folders}) async {
    _setSyncing(true);
    try {
      final api = await _driveApi();
      if (api == null) {
        return GoogleDriveSyncResult(success: false, message: _signInFailureMessage());
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

      final preferenceService = PreferenceService();
      await preferenceService.setNotesPendingDriveSync(false);
      await preferenceService.setTasksPendingDriveSync(false);

      return GoogleDriveSyncResult(
        success: true,
        message: 'Backup synced to Google Drive successfully.',
      );
    } catch (e, st) {
      debugPrint('Drive sync error: $e\n$st');
      return GoogleDriveSyncResult(success: false, message: 'Sync failed: $e');
    } finally {
      _setSyncing(false);
    }
  }

  Future<GoogleDriveSyncResult> fetchFromDrive({bool merge = true}) async {
    _setSyncing(true);
    try {
      final api = await _driveApi();
      if (api == null) {
        return GoogleDriveSyncResult(success: false, message: _signInFailureMessage());
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
      final preferenceService = PreferenceService();
      await preferenceService.setNotesPendingDriveSync(false);
      await preferenceService.setTasksPendingDriveSync(false);
      return GoogleDriveSyncResult(
        success: true,
        message: 'Restored ${result.notesCount} notes and ${result.tasksCount} tasks from Drive.',
        folders: result.folders,
      );
    } catch (e, st) {
      debugPrint('Drive fetch error: $e\n$st');
      return GoogleDriveSyncResult(success: false, message: 'Fetch failed: $e');
    } finally {
      _setSyncing(false);
    }
  }

  /// Sync immediately if the user is currently signed in to Google Drive.
  Future<GoogleDriveSyncResult?> syncIfSignedIn({List<String>? folders}) async {
    if (!isSignedIn) {
      return null;
    }
    return await syncToDrive(folders: folders);
  }

  /// Background backup when auto-sync is on. Uses silent sign-in only (no login UI).
  Future<void> runAutoSyncIfEnabled({
    required bool enabled,
    List<String>? folders,
  }) async {
    if (!enabled) return;

    final prefs = PreferenceService();
    final lastMs = await prefs.getDriveLastAutoSyncMs();
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastMs;
    if (elapsed < autoSyncMinInterval.inMilliseconds) return;

    if (_googleSignIn.currentUser == null) {
      final silent = await _googleSignIn.signInSilently();
      if (silent == null) return;
    }

    final result = await syncToDrive(folders: folders);
    if (result.success) {
      await prefs.setDriveLastAutoSyncMs(DateTime.now().millisecondsSinceEpoch);
      debugPrint('Drive auto-sync completed.');
    } else {
      debugPrint('Drive auto-sync skipped: ${result.message}');
    }
  }
}
