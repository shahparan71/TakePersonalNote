# Map — operations

Operations, build, test, and release procedures for Take Personal Note.

| Task | Where / Command | Notes |
|---|---|---|
| Local setup | `fvm flutter pub get` | Flutter 3.35.4 managed via FVM (`.fvmrc`) |
| Clean environment | `fvm flutter clean` | Clears build artifacts and caches |
| Code generation | `fvm flutter pub run build_runner build --delete-conflicting-outputs` | Runs build_runner for code generation |
| Localization generation | `fvm flutter gen-l10n` | Generates localization files defined in `l10n.yaml` |
| Checks before PR | `fvm flutter analyze` && `fvm flutter test` | Linter rules in `analysis_options.yaml`; tests in `test/` |
| Run debug | `fvm flutter run` | Launches app on connected device or emulator |
| Run release | `fvm flutter run --release` | Launches release build on device for performance profiling |
| Build release APK | `fvm flutter build apk --release` | Outputs APK in `build/app/outputs/flutter-apk/` |
| Build release AppBundle | `fvm flutter build appbundle --release` | Outputs AAB in `build/app/outputs/bundle/release/` |
| Open release folder (Win) | `explorer build\app\outputs\bundle\release` | Quick access to release bundles |
| Release versioning | `pubspec.yaml` (`version: x.y.z+build`) | Increment semantic version and build number for releases |
| Firebase & Drive setup | [docs/FIREBASE_GOOGLE_DRIVE_SETUP.md](../FIREBASE_GOOGLE_DRIVE_SETUP.md) | SHA-1 registration, Google Sign-In, and Drive API setup |
| Keystore & Signing | `android/app/build.gradle`, `TakeNote.jks` | Android release signing configuration; keep passwords private |
| Database migrations | [database_service.dart](../../lib/services/database_service.dart) | SQLite schema versioning; write `onUpgrade` migrations |
