# SecureShield AI Flutter app - development instructions

Flutter (Dart, Riverpod, GoRouter, Dio) with a Kotlin native layer under `android/`. The backend lives in a separate repository (`SecureShield-Backend`,
checked out as `../backend`).

## Commands

* `flutter analyze` must report no issues; `flutter test` must pass. Release build: `flutter build apk --release` **fails unless an external upload key is configured** (`SECURESHIELD_*` environment variables or git-ignored `android/key.properties`; see `docs/ANDROID_RELEASE.md`); there is no debug-key fallback. After building, run `python tool/verify_apk_signature.py <apk> --expect-sha256 <upload-cert fingerprint>`.
* Pin the backend for a release build with `--dart-define=API_BASE_URL=https://.../api/v1`; never ship a build that probes LAN hosts.
* Localisation: edit `lib/l10n/app_en.arb` and the five other ARB files together, then `flutter gen-l10n`; `test/l10n/localization_test.dart` enforces key parity.

## Non-negotiable rules

* Never commit keystores, `key.properties`, tokens, API keys or personal data. Tokens and keys live only in `flutter_secure_storage`.
* Screens that show evidence, codes, personal data or private conversations must be wrapped with `ScreenshotPrevention.protect` (see `_secure(...)` in `lib/core/router.dart`); it is reference-counted, so nesting is safe. Its method names are checked against `MainActivity.kt` by a test. Do not log tokens, OTPs or phone numbers.
* Every new native channel needs a matching Dart caller and Kotlin handler with the same method names and a test of the Dart side.

## Audit documentation rule (mandatory)

The project's living status record is `../backend/docs/audit/` (in the backend repository). **Whenever a feature is developed, modified or completed:**

1. Reassess its actual implementation (UI -> state -> API -> router -> service -> model -> provider), reading the code rather than trusting screens or documents.
2. Run `flutter analyze` and `flutter test` (and the backend tests if the API contract changed) and record the real results.
3. Update the feature's status and scores in `docs/audit/feature-completion-matrix.md`, plus any affected architecture, security, QA, readiness and roadmap pages.
4. Add a dated entry with commit ids and test evidence to `docs/audit/audit-history.md`, and recompute `docs/audit/project-status.md`.
5. Never mark a feature TESTED or PRODUCTION without supporting evidence (TESTED = passing automated test; REVIEWED = documented security review + mutation-checked tests; PRODUCTION = real-provider, deployed and device verification).

Commit the documentation update in the backend repository and reference the Flutter commit id there.
