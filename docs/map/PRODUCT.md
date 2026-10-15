# Map — product code

Start here for any code change. Find the area, open its README router, then only what the task needs.

| Area | What lives there | Design doc |
|---|---|---|
| [lib/README.md](../../lib/README.md) | Flutter application code: screens, state providers, models, SQLite database, services, themes, widgets | [DOCS.md](DOCS.md) |
| [test/README.md](../../test/README.md) | Unit and widget test suite | [OPERATIONS.md](OPERATIONS.md) |
| `android/` | Android native project, Gradle build scripts, AndroidManifest.xml, app signing keystore | [docs/FIREBASE_GOOGLE_DRIVE_SETUP.md](../FIREBASE_GOOGLE_DRIVE_SETUP.md) |
| `ios/` | iOS native Runner project and Xcode workspace | [DOCS.md](DOCS.md) |
| `assets/` | Static application assets (app icon `assets/app_icon_2.png`) | [lib/README.md](../../lib/README.md) |

### Architecture overview
- **UI & Presentation**: `lib/screens/` and `lib/widgets/` build the responsive Material Design UI.
- **State Management**: `Provider` package (`MultiProvider` in `lib/main.dart`) binds services and providers to UI.
- **Persistence**: `lib/services/database_service.dart` manages the local SQLite database (`take_personal_note.db`).
- **Reminders**: `lib/services/notification_service.dart` schedules alarms and recurring notifications via `flutter_local_notifications`.
- **Cloud Sync**: `lib/services/google_drive_sync_service.dart` handles optional, user-initiated Google Drive backup and restore.
