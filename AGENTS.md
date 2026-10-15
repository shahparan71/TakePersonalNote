# Take Personal Note — operating guide

Take Personal Note is a Flutter mobile application for personal notes, checklists, and tasks with local-first SQLite persistence, rich text editing, system reminder alarms, and optional Google Drive backup sync. It runs primarily on Android (and iOS) and must never compromise local user data, privacy, or alarm reliability.

## Read first
1. [docs/map/PRODUCT.md](docs/map/PRODUCT.md)
2. [docs/map/OPERATIONS.md](docs/map/OPERATIONS.md)
3. [docs/map/DOCS.md](docs/map/DOCS.md)

When documents disagree: active code is the primary authority for app behavior, followed by `AGENTS.md` for workflow rules, then task routers and reference guides.

## Hard rules
- **Never drop or wipe user data**: Any SQLite schema changes in `lib/services/database_service.dart` must provide non-destructive `onUpgrade` migrations.
- **Local-first privacy**: Notes, tasks, and settings reside locally on the device; cloud sync to Google Drive is strictly opt-in and user-authorized.
- **Use FVM**: Always invoke Flutter and Dart tooling through FVM (`fvm flutter ...`, `fvm dart ...`) as specified in `.fvmrc`.
- **Safe navigation & auto-save**: Note and task editor screens must persist changes automatically and use `Navigator.maybePop` for clean route dismissal.
- **Never commit secrets**: Do not commit private keystores (`*.jks`), private API keys, or OAuth credentials to Git.
- **Preserve application code**: Token optimization and documentation refactoring must never alter application code or runtime behavior.

## Workflow
- **Branching**: Develop features and fixes on dedicated branches (e.g. `dev_paran`), merging into `main` for tagged production releases.
- **Commit style**: Use concise, imperative commit messages describing the change (e.g. `Reschedules reminders after Drive import.`).
- **Pre-commit verification**: Always verify changes by running `fvm flutter test` and `fvm flutter analyze` before pushing.
- **Documentation upkeep**: Update the corresponding router in `docs/map/` or area README whenever files are added, moved, or deleted.

## Commands
```bash
fvm flutter pub get
fvm flutter test
fvm flutter analyze
fvm flutter pub run build_runner build --delete-conflicting-outputs
fvm flutter build apk --release
fvm flutter build appbundle --release
```

## Reflexes
| When you are about to… | Do this |
|---|---|
| Change database schema | Increment `_databaseVersion` in `lib/services/database_service.dart` and add an `onUpgrade` migration block. |
| Add or modify an app screen | Register the route in `lib/routes/app_routes.dart` and verify back-stack navigation. |
| Add or adjust reminders/alarms | Register channels in `lib/services/notification_channels.dart` and schedule via `NotificationService`. |
| Add new UI text or labels | Add keys to `lib/l10n/app_en.arb`, `app_es.arb`, and `app_fr.arb`, then run `fvm flutter gen-l10n`. |
| Modify note or task models | Update `lib/models/`, ensure copyWith & serialization methods are kept in sync with the database. |
| Add or move files named in routers | Update the corresponding table in `docs/map/` or area README in the same commit. |

## Project map
Before opening files, read the router for the task, then only the files it points to:
- [docs/map/PRODUCT.md](docs/map/PRODUCT.md): where the code for each area lives
- [docs/map/OPERATIONS.md](docs/map/OPERATIONS.md): build, test, CI, release, deploy, configuration
- [docs/map/DOCS.md](docs/map/DOCS.md): which design or reference document answers which question

The map guides what to read first. It never replaces the rules above or a release gate.

**Keep the map true.** A change that adds, moves or removes a file a router names updates that router in the same change. Each code area keeps its own short README router, linked from PRODUCT.md, except folders that ship to users, which are routed from docs/map/ instead. Routers stay about 15–35 lines, link only to files that exist, and never hold secrets. Reference material goes in docs/, not here.
