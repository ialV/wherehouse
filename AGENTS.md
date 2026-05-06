# Repository Guidelines

## Project Structure & Module Organization

Wherehouse is a Flutter MVP for household item storage and retrieval. App code lives under `lib/`: screens in `lib/screens/`, reusable UI in `lib/widgets/`, state wiring in `lib/providers/`, local persistence in `lib/database/`, domain objects in `lib/models/`, and integrations/utilities in `lib/services/`. The entry points are `lib/main.dart` and `lib/app.dart`. Tests live in `test/`, currently focused on local database behavior. CI configuration is in `codemagic.yaml`; product and architecture context is captured in `docs/adr/ADR-001-mvp.md`.

## Build, Test, and Development Commands

- `flutter pub get`: install Dart and Flutter dependencies.
- `flutter test`: run the test suite in `test/`.
- `flutter analyze`: run static analysis with the repository lint rules.
- `flutter run`: launch the app on a connected device or emulator.
- `flutter build apk --release`: build the Android release APK. CI generates Android platform files first with `flutter create --platforms android .`.

## Coding Style & Naming Conventions

Use Dart defaults with `package:flutter_lints/flutter.yaml`, plus `prefer_single_quotes` and `sort_constructors_first` from `analysis_options.yaml`. Format Dart files with `dart format lib test` before submitting changes. Use two-space indentation, `PascalCase` for classes and widgets, `camelCase` for methods, fields, and providers, and `snake_case.dart` filenames such as `thing_card.dart` or `llm_service.dart`. Keep UI components small and place shared widgets in `lib/widgets/` rather than duplicating screen-local code.

## Testing Guidelines

Use `flutter_test` for unit and widget tests. Name test files with the `_test.dart` suffix and keep them under `test/`. Prefer focused tests around persistence, provider behavior, and user-visible screen flows. For database work, follow the existing pattern in `test/app_test.dart`: use `AppDatabase.inMemory()` and assert persisted fields and relationships. Run `flutter test` and `flutter analyze` before opening a PR.

## Commit & Pull Request Guidelines

Git history uses concise Conventional Commit-style subjects, for example `feat: optional photo pin + text-only mode` and `fix: add INTERNET permission for release build`. Use `feat:`, `fix:`, `test:`, `docs:`, or `chore:` with an imperative summary. Pull requests should include a short description, test results, related issue or context, and screenshots or screen recordings for UI changes. Note any configuration or secret-handling changes explicitly.

## Security & Configuration Tips

Runtime configuration is loaded from `.env`, which is listed as a Flutter asset. Keep real secrets local or in CI secret storage; use `.env.example` for placeholders. The Codemagic workflow injects `DASHSCOPE_API_KEY` and ensures Android INTERNET permission for release builds, so avoid hardcoding API keys in Dart source.
