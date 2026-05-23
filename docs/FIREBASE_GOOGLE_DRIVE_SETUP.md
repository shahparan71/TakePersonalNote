# Firebase & Google Drive backup setup

Google Sign-In fails when `android/app/google-services.json` has an empty `oauth_client` array. That happens until you register your app signing certificate in Firebase.

## 1. Register debug SHA-1 in Firebase

1. Open [Firebase Console](https://console.firebase.google.com/) → project **takepersonalnote**.
2. **Project settings** → **Your apps** → Android app `com.paran.bd.take.personal.note`.
3. **Add fingerprint** and paste your **debug** SHA-1:

   ```
   92:C5:56:98:2D:91:52:53:B4:7A:73:C1:D7:AA:DA:95:05:D3:14:06
   ```

4. For release builds, also add your release keystore SHA-1 (`keytool -list -v -keystore <your-release.jks>`).

## 2. Enable Google Sign-In

1. Firebase Console → **Build** → **Authentication** → **Sign-in method**.
2. Enable **Google** and save.

## 3. Add a Web app (for OAuth client)

1. Firebase Console → **Project settings** → **Your apps** → **Add app** → **Web**.
2. Register the web app (nickname only is fine).
3. Copy the **Web client ID** (ends with `.apps.googleusercontent.com`).

Optional: set it in code if sign-in still fails:

`lib/config/google_auth_config.dart`:

```dart
const String? kGoogleSignInWebClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';
```

## 4. Replace google-services.json

1. Firebase Console → **Project settings** → Android app → **Download google-services.json**.
2. Replace `android/app/google-services.json`.
3. Confirm the file contains `oauth_client` entries (not `[]`).

## 5. Enable Google Drive API

1. [Google Cloud Console](https://console.cloud.google.com/) → project **takepersonalnote**.
2. **APIs & Services** → **Library** → enable **Google Drive API**.
3. **OAuth consent screen**: configure if prompted (testing mode is fine for development).

## 6. Rebuild the app

```bash
flutter clean
flutter pub get
flutter run
```

## Verify

Settings → Google Drive Backup → **Sign in with Google** → **Sync to Drive**.

If you see **ApiException 10**, SHA-1 or package name does not match Firebase. If you see **serverClientId**, add the Web client ID (step 3).
