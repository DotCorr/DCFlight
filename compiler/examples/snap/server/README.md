# Snap service 0.1.0

A real self-hostable single-node backend for the generated Snap iOS and Android apps. Accounts, friendships, messages, private photos, stories and opted-in locations persist in SQLite. The native clients talk directly to this service over ordinary HTTPS. This service introduces no dcflight runtime into applications.

## Run locally

Use Python 3.12+ from this directory:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/uvicorn snap_service.main:create_app --factory --host 127.0.0.1 --port 8000 --no-access-log --no-proxy-headers
```

Data defaults to `./data/snap.sqlite3`; set `SNAP_DATABASE` to change it. iOS simulator uses `http://127.0.0.1:8000`; Android emulator uses `http://10.0.2.2:8000`. Local HTTP is explicitly development-only. Native apps must use HTTPS with platform certificate validation for remote deployment. There are no built-in accounts, seed credentials, fixtures, simulated message delivery or public media URLs.

## Native client contract

`api-contract.json` specifies exact response fields, endpoint bodies, privacy rules and limits. `openapi.json` is generated from FastAPI routes and describes input validation and bearer authorization; regenerate with `python export_openapi.py`. Output response shapes are specified in the companion contract rather than inferred from untyped OpenAPI response objects. `/docs` serves the API explorer. All `/v1` routes except register/login require `Authorization: Bearer <token>`.

Register/login return `{token, expires_at, user: {id, username, display_name}}`. Store the token in native Keychain/Keystore-backed storage, never in URLs, preferences, logs or project source. Sessions expire after seven days; logout revokes the current session. Account deletion requires password confirmation and revokes every session. Passwords have a 12-character minimum; no email recovery is implemented.

The friendship flow is search → send request → recipient accepts → create conversation → send/poll messages. Message POST means the database transaction committed; it does not claim a push notification, read receipt or delivery to a device. Poll `messages?after=<last integer id>` and continue while the returned page contains 100 messages. Text is trimmed and limited to 2,000 Unicode scalar values; photo-only messages are supported.

Upload raw JPEG/PNG/WebP bytes to `/v1/media` with the bearer header (not multipart). Maximum input is 8 MiB and 20 million decoded pixels; animated images are rejected. Images are reencoded to JPEG, maximum 2048 pixels per side, stripping EXIF/GPS/XMP/ICC metadata. The response media ID can be attached to a message or story. Download bytes through the authenticated media endpoint into a private in-memory/native cache. The account quota is 100 MiB of normalized images.

Stories are visible to the owner and current accepted friends for exactly 24 hours. Location sharing defaults off; clients must obtain both an explicit sharing decision and OS location permission before PUT. Coordinates are integer microdegrees. Friends see only the latest opted-in point, expiring after one hour; disabling sharing deletes it immediately. The server cannot attest an OS permission dialog, so it independently enforces explicit `enabled`, authorization, ranges and expiry.

Unfriending immediately removes story/map access and prevents new messages. Existing conversation messages and delivered photo attachments remain readable by their two participants. Account deletion removes the account's media, messages, stories, locations, sessions and associated friendships/conversations through foreign-key cascades. It does not remotely erase copies a recipient previously saved. Orphan drafts are removed after seven days by maintenance.

## Deployment and operation

`docker compose up --build -d` runs a non-root server bound only to host loopback with a persistent named volume. `Caddyfile.example` shows a host reverse proxy with automatic TLS; supply your real domain and configure DNS/firewall before exposing it. The Docker recipe has not been deployed to a remote production host. Pin the Python image to a reviewed digest in your deployment, scan dependencies and build images in your own release pipeline. Direct runtime dependencies are pinned in `requirements.txt`; use a platform-specific resolved lock for reproducible production images.

Default application rate limits are 20 authentication requests and 240 other requests per source IP per minute. Proxied traffic shares the proxy's limit unless the operator explicitly configures Uvicorn `--proxy-headers --forwarded-allow-ips=<trusted-proxy-IP>` and removes `--no-proxy-headers`. Never trust forwarded headers from arbitrary peers. The included command disables access logging; do not enable request/body/header logging at the proxy. The service never emits passwords, tokens, message contents or coordinates to logs.

SQLite uses WAL, foreign keys, busy timeouts and serialized write transactions; use a local reliable filesystem, one service instance and one worker. Back up with SQLite's online backup API, not a bare copy of an active database. Encrypt the deployment volume and backups and define retention/restore controls. Account deletion is a logical database deletion; old backups/WAL/storage snapshots need an operator retention policy. Do not expose database or volume files publicly.

Run `python -m snap_service.maintenance` periodically under the same `SNAP_DATABASE`: it deletes expired sessions/stories/locations, old rate counters and unreferenced seven-day-old media and prints counts only. Expiry authorization works even if this command has not run. Monitor disk capacity, HTTP failure counts and latency without retaining sensitive request data.

This is tested application functionality, not a claim of completed production security review. Remaining deployment/product work includes recovery/verification, reporting/blocking/moderation, stronger distributed abuse controls, push delivery, infrastructure load testing, availability/backups drills and an independent security review. HTTP authentication is not end-to-end encrypted messaging; the server processes and stores message/photo content.

## Verification

```sh
.venv/bin/python -m pip install -r requirements-test.txt
.venv/bin/python -m pytest -q
.venv/bin/python verify_network.py
```

Tests exercise real ASGI requests and SQLite transactions across separate accounts, including third-user denial, owner-only uploads, EXIF removal, story/location/session expiry, deletion, body limits and rate limits. The network harness starts a real loopback Uvicorn process and completes registration, friendship, text/photo exchange, metadata stripping, stories, explicit location opt-in/disable, unfriend revocation, account deletion and logout across three newly registered accounts in a temporary database. Unauthorized third-party reads are denied. It prints counts/status only and destroys its temporary data.

Implementation references: [FastAPI security](https://fastapi.tiangolo.com/tutorial/security/first-steps/), [FastAPI dependencies](https://fastapi.tiangolo.com/reference/dependencies/), [Pillow image security](https://pillow.readthedocs.io/en/stable/handbook/security.html). Runtime packages are server dependencies only and are never bundled in the generated mobile apps.
