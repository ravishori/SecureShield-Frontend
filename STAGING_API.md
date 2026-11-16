# Pointing a Flutter build at the Railway staging API

The client has no hosted URL by default (it probes emulator/LAN hosts on
`http://<host>:8000`). To use the Railway staging API without touching the
default behaviour:

1. Run any build (`flutter run` / install the APK).
2. Settings -> Server URL -> enter
   `https://secureshield-api-production-73ea.up.railway.app/api/v1`
   (this is the staging service; the URL is pinned per device via
   `AppConfig.setCustomUrl`). "Reset" returns to LAN auto-detection.

`AppConfig._isReachable` probes `<scheme>://host:port/health`, so https URLs
survive an app restart.
