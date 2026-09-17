# Snap — complete example application

Snap is a **product example**, not part of the DCFlight framework. It demonstrates
the full surface: a shared Dart application definition, generated native iOS and
Android apps, a development API server, and the QA harnesses used to verify them.

```
snap/
  shared/    Shared Dart app (screens, state, requests, navigation) + compiled decisions
  server/    Development API service (FastAPI), contract in api-contract.json
  app/       Legacy feature templates (compatibility)
  tools/     Verification harnesses (iOS, Android, UI, network, packaging)
  tests/     Source-level evaluation tests and native fixtures
  docs/      Product and platform-generation notes
```

Compile the shared app:

```
python3 -m dcflight compile snap/shared/app.dart --out /absolute/path/out
```

Everything here is self-contained and safe to delete without affecting the compiler.
