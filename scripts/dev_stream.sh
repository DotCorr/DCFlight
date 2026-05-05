#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/packages/examples/todo_app"
PLATFORM="ios"
DEVICE=""
NO_ANALYZE=0
NO_PLATFORM_LOGS=0
declare -a EXTRA_FLUTTER_ARGS=()
declare -a STREAM_PIDS=()

usage() {
  cat <<'EOF'
DCFlight monitored dev stream

Usage:
  ./scripts/dev_stream.sh [options] [-- <extra flutter run args>]

Options:
  --platform ios|android   Target platform. Default: ios
  --device <id-or-name>    Explicit Flutter device id or name
  --app-dir <path>         Flutter app directory. Default: packages/examples/todo_app
  --no-analyze             Skip the upfront flutter analyze pass
  --no-platform-logs       Skip adb logcat / iOS simulator log streaming
  --help                   Show this help

Examples:
  ./scripts/dev_stream.sh --platform ios
  ./scripts/dev_stream.sh --platform android --device R5CW41XAS7L
  ./scripts/dev_stream.sh --platform ios -- --dart-define=DCF_VERBOSE=true

Behavior:
  - runs flutter analyze once before launch unless disabled
  - keeps flutter run in the foreground so hot reload keys still work
  - streams prefixed Flutter output to stdout and to .logs/dev-stream/<timestamp>/flutter.log
  - tails iOS simulator logs or adb logcat in parallel when available
EOF
}

prefix_stream() {
  local tag="$1"
  awk -v tag="$tag" '{
    print "[" tag "] " $0;
    fflush();
  }'
}

cleanup() {
  local pid
  for pid in "${STREAM_PIDS[@]:-}"; do
    if kill -0 "$pid" >/dev/null 2>&1; then
      kill "$pid" >/dev/null 2>&1 || true
    fi
  done
}

trap cleanup EXIT INT TERM

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    --device)
      DEVICE="$2"
      shift 2
      ;;
    --app-dir)
      APP_DIR="$2"
      shift 2
      ;;
    --no-analyze)
      NO_ANALYZE=1
      shift
      ;;
    --no-platform-logs)
      NO_PLATFORM_LOGS=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      EXTRA_FLUTTER_ARGS+=("$@")
      break
      ;;
    *)
      EXTRA_FLUTTER_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ "$PLATFORM" != "ios" && "$PLATFORM" != "android" ]]; then
  echo "Unsupported platform: $PLATFORM" >&2
  exit 1
fi

if [[ ! -f "$APP_DIR/pubspec.yaml" ]]; then
  echo "No pubspec.yaml found at $APP_DIR" >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is required but was not found in PATH" >&2
  exit 1
fi

select_default_device() {
  if [[ -n "$DEVICE" ]]; then
    return
  fi

  if [[ "$PLATFORM" == "ios" ]]; then
    if flutter devices | grep -q 'iPhone 17 Pro'; then
      DEVICE='iPhone 17 Pro'
      return
    fi

    DEVICE="$(flutter devices | awk -F '•' '/iOS|iPhone|iPad/ {gsub(/^ +| +$/, "", $1); print $1; exit}')"
  else
    if ! command -v adb >/dev/null 2>&1; then
      echo "adb is required for Android monitoring but was not found in PATH" >&2
      exit 1
    fi

    DEVICE="$(adb devices | awk 'NR > 1 && $2 == "device" {print $1; exit}')"
  fi

  if [[ -z "$DEVICE" ]]; then
    echo "Could not auto-select a $PLATFORM device. Pass --device explicitly." >&2
    exit 1
  fi
}

start_background_stream() {
  local name="$1"
  local logfile="$2"
  shift 2

  (
    "$@" 2>&1 | prefix_stream "$name" | tee -a "$logfile"
  ) &
  STREAM_PIDS+=("$!")
}

run_flutter_stream() {
  if command -v stdbuf >/dev/null 2>&1; then
    stdbuf -oL -eL flutter "$@"
  else
    flutter "$@"
  fi
}

select_default_device

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="$APP_DIR/.logs/dev-stream/$TIMESTAMP"
mkdir -p "$LOG_DIR"

echo "Starting monitored dev stream"
echo "  app:      $APP_DIR"
echo "  platform: $PLATFORM"
echo "  device:   $DEVICE"
echo "  logs:     $LOG_DIR"

if [[ $NO_ANALYZE -eq 0 ]]; then
  (
    cd "$APP_DIR"
    flutter analyze
  ) 2>&1 | prefix_stream "ANALYZE" | tee "$LOG_DIR/analyze.log"
fi

if [[ $NO_PLATFORM_LOGS -eq 0 ]]; then
  if [[ "$PLATFORM" == "ios" ]]; then
    if command -v xcrun >/dev/null 2>&1 && xcrun simctl list devices booted | grep -q '(Booted)'; then
      start_background_stream \
        "IOS" \
        "$LOG_DIR/ios.log" \
        xcrun simctl spawn booted log stream --style compact --level debug --predicate 'eventMessage CONTAINS[c] "dcflight" OR process == "Runner"'
    else
      echo "[INFO] No booted iOS simulator log stream available; continuing without iOS device logs."
    fi
  else
    start_background_stream \
      "ADB" \
      "$LOG_DIR/android.log" \
      adb -s "$DEVICE" logcat -T 1 -v time flutter:D DartVM:D dcflight:D DCFlightJni:D AndroidRuntime:E '*:S'
  fi
fi

(
  cd "$APP_DIR"
  if [[ ${#EXTRA_FLUTTER_ARGS[@]} -gt 0 ]]; then
    run_flutter_stream run -d "$DEVICE" "${EXTRA_FLUTTER_ARGS[@]}"
  else
    run_flutter_stream run -d "$DEVICE"
  fi
) 2>&1 | prefix_stream "FLUTTER" | tee "$LOG_DIR/flutter.log"