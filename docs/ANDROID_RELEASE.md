# Android release signing

Release builds are signed **only** with an upload key that lives outside this repository. If it is missing or invalid, `flutter build apk --release` /
`appbundle --release` **fails immediately** with a message naming the problem (never a password). There is no debug-key fallback. Debug and profile builds are unaffected.

## One-time setup (owner action; this repository never creates or stores keys)

1. Create the upload keystore on a trusted machine with your own tooling (for example `keytool -genkeypair -v -keystore <path outside the repo>/secureshield-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`), choose strong passwords, and back the file up in a password manager / vault. Losing it means a Play upload-key reset.
2. Enrol the app in **Play App Signing** so Google holds the app signing key and this keystore is only the upload key.
3. Provide the credentials to the build, either:
   * **Local:** copy `android/key.properties.example` to `android/key.properties` (git-ignored) and fill in `storeFile` (absolute path outside the repository), `storePassword`, `keyAlias`, `keyPassword`; or
   * **CI:** set `SECURESHIELD_KEYSTORE_PATH`, `SECURESHIELD_KEYSTORE_PASSWORD`, `SECURESHIELD_KEY_ALIAS`, `SECURESHIELD_KEY_PASSWORD` as masked secrets (the keystore file is restored from a secret store at build time). Environment variables take precedence.

## What the build enforces (`android/app/build.gradle.kts`)

Only when a release task is requested: credentials present; no value empty or a `CHANGE_ME`/`YOUR_` placeholder; the keystore file exists; the keystore is **not** inside the project folder (so it cannot be committed). Git ignores `key.properties`, `*.jks`, `*.keystore`, `*.p12`, `*.pfx`, `upload-keystore*`.

## Verify a built APK

```
flutter build apk --release --dart-define=API_BASE_URL=https://<your-api>/api/v1
python tool/verify_apk_signature.py build/app/outputs/flutter-apk/app-release.apk --expect-sha256 <SHA-256 of your upload certificate>
```

The script uses `apksigner` from the Android SDK build-tools, requires a verified v2/v3 signature, **fails on the Android debug certificate**, and prints only the
public certificate subject and fingerprint. Compare the fingerprint with the one shown in your keystore (`keytool -list -v`) or Play Console.

Reproducibility: `python tool/compare_apks.py first.apk second.apk` compares two builds ignoring signature files and lists any differing entry. Flutter/Gradle output is
not guaranteed bit-for-bit reproducible (timestamps, build paths); treat a clean result as a bonus, not a requirement.

Tool tests: `python -m unittest discover -s tool -p "test_apk_tools.py"`.

## Status of this configuration

* Fail-closed behaviour: verified by running `flutter build apk --release` with no configuration, with placeholders, with a missing keystore, with a keystore inside the project and with an empty alias (all rejected in seconds, nothing built).
* **Not verified:** a successful signed build (it needs a real upload keystore, which this repository never generates) and a signed-APK check against a real fingerprint. Until then no APK built from this repository is distributable.
