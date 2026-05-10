#!/usr/bin/env bash
set -euo pipefail

# Automated cross-platform UI hotflow monitor for DCFlight Inspector.
# Captures before/after screenshots, fires taps, and checks logs for known regressions.

INSPECTOR_URL="${INSPECTOR_URL:-http://localhost:7070}"
OUT_DIR="${OUT_DIR:-/tmp/dcflight_hotflow}"
ITERATIONS="${ITERATIONS:-3}"
LOG_LINES="${LOG_LINES:-180}"

ANDROID_DEVICE_ID="${ANDROID_DEVICE_ID:-R5CW41XAS7L}"
IOS_DEVICE_ID="${IOS_DEVICE_ID:-09BF4F23-F3F3-4114-A824-93D87AD2CDF0}"

ANDROID_TAP_X="${ANDROID_TAP_X:-540}"
ANDROID_TAP_Y="${ANDROID_TAP_Y:-1100}"
IOS_TAP_X="${IOS_TAP_X:-195}"
IOS_TAP_Y="${IOS_TAP_Y:-740}"
ANDROID_BUNDLE_ID="${ANDROID_BUNDLE_ID:-com.dotcorr.dcf_go}"

mkdir -p "$OUT_DIR"
RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$OUT_DIR/$RUN_STAMP"
mkdir -p "$RUN_DIR"

have_python() {
  command -v python3 >/dev/null 2>&1
}

decode_screenshot() {
  local json_file="$1"
  local out_file="$2"
  python3 - "$json_file" "$out_file" <<'PY'
import base64, json, sys
in_file, out_file = sys.argv[1], sys.argv[2]
with open(in_file, 'r', encoding='utf-8') as f:
    payload = json.load(f)
b64 = payload.get('screenshot')
if not b64:
    raise SystemExit(f"No screenshot field in {in_file}: {payload}")
with open(out_file, 'wb') as f:
    f.write(base64.b64decode(b64))
print(len(b64))
PY
}

api_post() {
  local endpoint="$1"
  local body="$2"
  local out="$3"
  curl -sS -X POST "$INSPECTOR_URL$endpoint" \
    -H "Content-Type: application/json" \
    -d "$body" > "$out"
}

api_get() {
  local endpoint="$1"
  local out="$2"
  curl -sS "$INSPECTOR_URL$endpoint" > "$out"
}

take_cycle() {
  local platform="$1"
  local device_id="$2"
  local tap_x="$3"
  local tap_y="$4"
  local iter="$5"

  local prefix="$RUN_DIR/${platform}_iter${iter}"
  local before_json="${prefix}_before.json"
  local after_json="${prefix}_after.json"
  local tap_json="${prefix}_tap.json"
  local logs_json="${prefix}_logs.json"

  # Keep Android in foreground during hot-reload cycles to avoid launcher black captures.
  if [[ "$platform" == "android" ]]; then
    api_post "/api/launch" "{\"deviceId\":\"$device_id\",\"platform\":\"android\",\"bundleId\":\"$ANDROID_BUNDLE_ID\"}" "${prefix}_launch.json"
  fi

  api_post "/api/screenshot" "{\"deviceId\":\"$device_id\",\"platform\":\"$platform\"}" "$before_json"
  decode_screenshot "$before_json" "${prefix}_before.jpg" >/dev/null

  api_post "/api/tap" "{\"deviceId\":\"$device_id\",\"platform\":\"$platform\",\"x\":$tap_x,\"y\":$tap_y}" "$tap_json"

  api_post "/api/screenshot" "{\"deviceId\":\"$device_id\",\"platform\":\"$platform\"}" "$after_json"
  decode_screenshot "$after_json" "${prefix}_after.jpg" >/dev/null

  api_get "/api/logs?deviceId=$device_id&platform=$platform&lines=$LOG_LINES" "$logs_json"
}

if ! have_python; then
  echo "python3 is required" >&2
  exit 1
fi

DEVICES_JSON="$RUN_DIR/devices.json"
api_get "/api/devices" "$DEVICES_JSON"

for i in $(seq 1 "$ITERATIONS"); do
  take_cycle "android" "$ANDROID_DEVICE_ID" "$ANDROID_TAP_X" "$ANDROID_TAP_Y" "$i"
  take_cycle "ios" "$IOS_DEVICE_ID" "$IOS_TAP_X" "$IOS_TAP_Y" "$i"
done

SUMMARY_TXT="$RUN_DIR/summary.txt"
python3 - "$RUN_DIR" "$ITERATIONS" <<'PY' > "$SUMMARY_TXT"
import json, os, re, sys
run_dir = sys.argv[1]
iterations = int(sys.argv[2])

patterns = {
    "invalid_dims": re.compile(r"\b(0x0|width\s*=\s*0|height\s*=\s*0|Ignored invalid dimension snapshot)\b", re.IGNORECASE),
    "event_chain": re.compile(r"EventRegistry\.handleEvent|Found handler|sendEvent|onPress", re.IGNORECASE),
    "reconcile": re.compile(r"setChildren|Removed child logicalViewId|deleteView|commitBatchUpdate", re.IGNORECASE),
}

print(f"run_dir={run_dir}")
for platform in ("android", "ios"):
    print(f"\n[{platform}]")
    for i in range(1, iterations + 1):
        logs_path = os.path.join(run_dir, f"{platform}_iter{i}_logs.json")
        tap_path = os.path.join(run_dir, f"{platform}_iter{i}_tap.json")
        before_img = os.path.join(run_dir, f"{platform}_iter{i}_before.jpg")
        after_img = os.path.join(run_dir, f"{platform}_iter{i}_after.jpg")
        line_blob = ""
        tap_ok = False
        tap_error = ""
        if os.path.exists(tap_path):
            with open(tap_path, "r", encoding="utf-8") as f:
                tap_payload = json.load(f)
            tap_ok = bool(tap_payload.get("ok") is True)
            if not tap_ok:
                tap_error = str(tap_payload.get("error", ""))[:140].replace("\n", " ")
        if os.path.exists(logs_path):
            with open(logs_path, "r", encoding="utf-8") as f:
                payload = json.load(f)
            logs = payload.get("logs", [])
            if isinstance(logs, list):
                line_blob = "\n".join(str(x) for x in logs)
            else:
                line_blob = str(logs)

        sizes = {
            "before": os.path.getsize(before_img) if os.path.exists(before_img) else -1,
            "after": os.path.getsize(after_img) if os.path.exists(after_img) else -1,
        }
        delta = sizes["after"] - sizes["before"] if sizes["before"] >= 0 and sizes["after"] >= 0 else -1

        invalid_count = len(patterns["invalid_dims"].findall(line_blob))
        event_count = len(patterns["event_chain"].findall(line_blob))
        reconcile_count = len(patterns["reconcile"].findall(line_blob))

        print(
            f"iter={i} tap_ok={tap_ok} before={sizes['before']} after={sizes['after']} delta={delta} "
            f"invalid_dim_hits={invalid_count} event_hits={event_count} reconcile_hits={reconcile_count} "
            f"tap_error='{tap_error}'"
        )

print("\nArtifacts:")
for name in sorted(os.listdir(run_dir)):
    if name.endswith((".jpg", ".txt", ".json")):
        print(name)
PY

echo "Hotflow monitor complete."
echo "Run dir: $RUN_DIR"
echo "Summary: $SUMMARY_TXT"
cat "$SUMMARY_TXT"
