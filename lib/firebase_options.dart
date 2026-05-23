// File generated from android/app/google-services.json (Firebase project: takepersonalnote).
// Re-run `flutterfire configure` after adding SHA-1 fingerprints or new platforms.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCuBuYzQnNE_N5I13uUAvfqk7PjLotU-ng',
    appId: '1:964868838422:android:4d1c9e105f802edc15d137',
    messagingSenderId: '964868838422',
    projectId: 'takepersonalnote',
    storageBucket: 'takepersonalnote.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDlvkU1Ad0vHVS4GefiIol8jwM05--_aWE',
    appId: '1:964868838422:ios:8566a36b61c262ca15d137',
    messagingSenderId: '964868838422',
    projectId: 'takepersonalnote',
    storageBucket: 'takepersonalnote.firebasestorage.app',
    androidClientId: '964868838422-7e0sshnjko3r6g3dqhf0v5lmkksv8cef.apps.googleusercontent.com',
    iosClientId: '964868838422-bpe7v9br29ghl5tmsqmnelr8cvg6008r.apps.googleusercontent.com',
    iosBundleId: 'com.paran.bd.take.personal.note',
  );

}