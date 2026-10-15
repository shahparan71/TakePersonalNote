# test/ — Test Suite

Unit, widget, and utility tests for Take Personal Note.

| Folder or file | What lives there | Read before changing |
|---|---|---|
| `drive_sync_banner_test.dart` | Tests for Google Drive backup sync banner display conditions | [drive_sync_utils.dart](../lib/utils/drive_sync_utils.dart) |
| `widget_test.dart` | Smoke test placeholder for widget tree | [lib/main.dart](../lib/main.dart) |

### Test rules
- Run tests via `fvm flutter test`.
- New business logic and utility functions must be accompanied by unit tests.
- Mock platform channels (notifications, SQLite, secure storage) when writing widget tests.
