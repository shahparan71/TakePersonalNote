# lib/ — Flutter Application Source Code

Client-side application codebase for Take Personal Note. UI is built with Flutter Material 3, state is managed with Provider, data persists locally via SQLite, and background reminders use system alarms.

| Folder or file | What lives there | Read before changing |
|---|---|---|
| `main.dart` | App bootstrap, MultiProvider setup, theme, locale & top-level routing | [lib/main.dart](main.dart) |
| `config/` | Google OAuth client configuration for Drive backup | [google_auth_config.dart](config/google_auth_config.dart) |
| `l10n/` | Localization strings (ARB files for en, es, fr) and generated delegates | [app_en.arb](l10n/app_en.arb) |
| `models/` | Data models: `MyNote`, `Task`, `RecurringInterval` with serialization | [note.dart](models/note.dart) |
| `routes/` | Centralized route names (`AppRoutes`) and MaterialPageRoute generator | [app_routes.dart](routes/app_routes.dart) |
| `screens/` | Primary views: Home, Notes, Tasks, Note/Task Edit, Calendar, Dashboard, Settings, Trash, Archive, Lock | [note_edit_screen.dart](screens/note_edit_screen.dart) |
| `services/` | Business logic & providers: SQLite DB, state providers, notifications, security, Google Drive sync | [database_service.dart](services/database_service.dart) |
| `theme/` | Color constants (`AppColors`) and Light, Dark, Eye Warming ThemeData (`AppTheme`) | [app_theme.dart](theme/app_theme.dart) |
| `utils/` | Helpers: URL extraction & deep-linking, checklist parsing, date formatting, custom text controller | [url_utils.dart](utils/url_utils.dart) |
| `widgets/` | Reusable UI components: cards, dialogs, banners, bottom sheet safe area, sync indicator | [design_widgets.dart](widgets/design_widgets.dart), [syncing_indicator.dart](widgets/syncing_indicator.dart) |

### Area rules
- **State mutation**: UI widgets must not modify raw database directly; dispatch changes through `NoteProvider`, `TaskProvider`, or `FolderProvider`.
- **Safe dismissal**: Screens with active input (`NoteEditScreen`, `TaskEditScreen`) must auto-save and use `Navigator.maybePop` on back navigation.
- **Reminders**: When modifying note/task reminder times, always synchronize with `NotificationService`.
