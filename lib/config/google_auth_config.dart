/// Web OAuth 2.0 client ID for Google Sign-In + Drive API on Android.
///
/// After Firebase setup, set this to the Web client ID:
/// - Firebase Console → Project settings → Your apps → Web app → Web client ID, or
/// - `google-services.json` → `oauth_client` entry with `"client_type": 3` → `client_id`
///
/// Leave null to rely only on `google-services.json` (requires non-empty `oauth_client`).
const String? kGoogleSignInWebClientId = null;
