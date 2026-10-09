#!/bin/bash
set -euo pipefail

# Runs PositiveNoticeUITests.testSimulatedNotificationResponsesRouteAcrossTabs.
# It uses simctl push to deliver remote-push test payloads, then waits for the
# XCTest to tap each real SpringBoard notification. This does not test local
# notification scheduling or the L22 request payloads.

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <simulator-udid> <xctestrun-path> <new-evidence-directory>" >&2
  exit 2
fi

SIMULATOR_UDID="$1"
XCTESTRUN_PATH="$2"
EVIDENCE_DIR="$3"
APP_BUNDLE_ID="${L22_NOTICE_BUNDLE_ID:-}"
NOTICE_ROUTE_DATE="${NOTICE_ROUTE_DATE:-$(date '+%Y-%m-%d')}"
NOTICE_ROUTE_RUN_ID="$(date -u '+%Y%m%dT%H%M%SZ')-$$"
OVERALL_TIMEOUT_SEC="${NOTICE_ROUTE_OVERALL_TIMEOUT_SEC:-1200}"
MARKER_TIMEOUT_SEC="${NOTICE_ROUTE_MARKER_TIMEOUT_SEC:-120}"

for required_name in L22_NOTICE_BUNDLE_ID L22_NOTICE_SEED_ID L22_NOTICE_SNAPSHOT_RELATIVE_PATH; do
  if [[ -z "${!required_name:-}" ]]; then
    echo "Set $required_name before you run this script." >&2
    exit 2
  fi
done
if [[ "${L22_NOTICE_INITIAL_AUTHORIZATION:-}" != "authorized" ]]; then
  echo "Set L22_NOTICE_INITIAL_AUTHORIZATION=authorized for the task-only seed." >&2
  exit 2
fi
for timeout_value in "$OVERALL_TIMEOUT_SEC" "$MARKER_TIMEOUT_SEC"; do
  if [[ ! "$timeout_value" =~ ^[0-9]+$ ]] || (( timeout_value < 1 )); then
    echo "Notification route timeouts must be positive whole seconds." >&2
    exit 2
  fi
done
if [[ ! "$NOTICE_ROUTE_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "NOTICE_ROUTE_DATE must use yyyy-MM-dd." >&2
  exit 2
fi
if [[ ! -f "$XCTESTRUN_PATH" ]]; then
  echo "Missing xctestrun file: $XCTESTRUN_PATH" >&2
  exit 2
fi
if [[ -e "$EVIDENCE_DIR" ]]; then
  echo "Evidence directory already exists: $EVIDENCE_DIR" >&2
  exit 2
fi

mkdir -p "$(dirname "$EVIDENCE_DIR")"
mkdir "$EVIDENCE_DIR"
export NOTICE_ROUTE_DATE NOTICE_ROUTE_RUN_ID

DEVICE_LOG="$EVIDENCE_DIR/simulator-notification-route.log"
HOST_LOG="$EVIDENCE_DIR/host-driver.log"
XCODEBUILD_LOG="$EVIDENCE_DIR/xcodebuild.log"
RESULT_BUNDLE="$EVIDENCE_DIR/result.xcresult"
CLONED_XCTESTRUN="$EVIDENCE_DIR/notification-routes.xctestrun"
MANIFEST="$EVIDENCE_DIR/driver-manifest.json"

# Xcode reads EnvironmentVariables from the test target in the .xctestrun file.
# Keep the original file intact. Rewrite __TESTROOT__ to the original Products
# directory because this evidence copy is stored outside that directory.
python3 - "$XCTESTRUN_PATH" "$CLONED_XCTESTRUN" "$APP_BUNDLE_ID" \
  "$L22_NOTICE_SEED_ID" "$L22_NOTICE_SNAPSHOT_RELATIVE_PATH" \
  "$NOTICE_ROUTE_DATE" "$NOTICE_ROUTE_RUN_ID" "$MANIFEST" <<'PY'
import hashlib
import json
import plistlib
import sys
from pathlib import Path

source_path = Path(sys.argv[1]).resolve()
clone_path = Path(sys.argv[2]).resolve()
bundle_id, seed_id, snapshot_path, route_date, run_id = sys.argv[3:8]
manifest_path = Path(sys.argv[8])
with source_path.open("rb") as source_file:
    run = plistlib.load(source_file)
if not isinstance(run, dict) or "JohnUITests" not in run:
    raise SystemExit("The xctestrun file does not contain the JohnUITests target.")
target = run["JohnUITests"]
if not isinstance(target.get("EnvironmentVariables"), dict):
    raise SystemExit("JohnUITests.EnvironmentVariables is missing or has the wrong type.")
target["EnvironmentVariables"].update({
    "L22_NOTICE_BUNDLE_ID": bundle_id,
    "L22_NOTICE_SEED_ID": seed_id,
    "L22_NOTICE_INITIAL_AUTHORIZATION": "authorized",
    "L22_NOTICE_SNAPSHOT_RELATIVE_PATH": snapshot_path,
    "NOTICE_ROUTE_DATE": route_date,
    "NOTICE_ROUTE_RUN_ID": run_id,
})
products_root = str(source_path.parent)

def rewrite_test_root(value):
    if isinstance(value, str):
        return value.replace("__TESTROOT__", products_root)
    if isinstance(value, list):
        return [rewrite_test_root(item) for item in value]
    if isinstance(value, dict):
        return {key: rewrite_test_root(item) for key, item in value.items()}
    return value

run = rewrite_test_root(run)
with clone_path.open("wb") as output_file:
    plistlib.dump(run, output_file, fmt=plistlib.FMT_XML, sort_keys=True)

def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for block in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()

manifest = {
    "sourceXctestrun": str(source_path),
    "sourceXctestrunSHA256": sha256(source_path),
    "clonedXctestrun": str(clone_path),
    "clonedXctestrunSHA256": sha256(clone_path),
    "testTarget": "JohnUITests",
    "testEnvironmentVariables": {
        "L22_NOTICE_BUNDLE_ID": bundle_id,
        "L22_NOTICE_SEED_ID": seed_id,
        "L22_NOTICE_INITIAL_AUTHORIZATION": "authorized",
        "L22_NOTICE_SNAPSHOT_RELATIVE_PATH": snapshot_path,
        "NOTICE_ROUTE_DATE": route_date,
        "NOTICE_ROUTE_RUN_ID": run_id,
    },
    "testRoot": products_root,
}
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
PY

OVERALL_DEADLINE=$((SECONDS + OVERALL_TIMEOUT_SEC))
xcrun simctl spawn "$SIMULATOR_UDID" log stream --style compact --level info \
  --predicate 'eventMessage CONTAINS "NOTICE_ROUTE_WAIT" OR eventMessage CONTAINS "NOTICE_ROUTE_DONE"' \
  >"$DEVICE_LOG" 2>&1 &
LOG_STREAM_PID=$!
XCODEBUILD_PID=""
sleep 1
if ! kill -0 "$LOG_STREAM_PID" 2>/dev/null; then
  echo "Simulator log stream did not stay active." >&2
  cat "$DEVICE_LOG" >&2
  exit 1
fi

cleanup() {
  if [[ -n "$XCODEBUILD_PID" ]] && kill -0 "$XCODEBUILD_PID" 2>/dev/null; then
    kill "$XCODEBUILD_PID" 2>/dev/null || true
    for _ in {1..8}; do
      kill -0 "$XCODEBUILD_PID" 2>/dev/null || break
      sleep 0.25
    done
    kill -KILL "$XCODEBUILD_PID" 2>/dev/null || true
    wait "$XCODEBUILD_PID" 2>/dev/null || true
  fi
  if kill -0 "$LOG_STREAM_PID" 2>/dev/null; then
    kill "$LOG_STREAM_PID" 2>/dev/null || true
    wait "$LOG_STREAM_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

xcodebuild test-without-building \
  -xctestrun "$CLONED_XCTESTRUN" \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  -parallel-testing-enabled NO \
  -only-testing:JohnUITests/PositiveNoticeUITests/testSimulatedNotificationResponsesRouteAcrossTabs \
  -resultBundlePath "$RESULT_BUNDLE" \
  >"$XCODEBUILD_LOG" 2>&1 &
XCODEBUILD_PID=$!

wait_for_marker() {
  local marker="$1"
  local case_key="$2"
  local phase="$3"
  local marker_deadline=$((SECONDS + MARKER_TIMEOUT_SEC))
  while ! rg -Fq "$marker" "$DEVICE_LOG" 2>/dev/null; do
    if (( SECONDS >= OVERALL_DEADLINE )); then
      echo "Overall timeout while waiting for $phase marker: $case_key" | tee -a "$HOST_LOG" >&2
      tail -100 "$XCODEBUILD_LOG" >&2
      return 1
    fi
    if (( SECONDS >= marker_deadline )); then
      echo "Timed out after ${MARKER_TIMEOUT_SEC}s waiting for $phase marker: $case_key" | tee -a "$HOST_LOG" >&2
      tail -100 "$XCODEBUILD_LOG" >&2
      return 1
    fi
    if ! kill -0 "$XCODEBUILD_PID" 2>/dev/null; then
      local status=0
      wait "$XCODEBUILD_PID" || status=$?
      XCODEBUILD_PID=""
      echo "xcodebuild exited with status $status before $phase marker: $case_key" | tee -a "$HOST_LOG" >&2
      tail -100 "$XCODEBUILD_LOG" >&2
      return 1
    fi
    sleep 0.25
  done
}

push_route() {
  local case_key="$1"
  local route="$2"
  local title="NATIVE ROUTE TEST $NOTICE_ROUTE_RUN_ID $case_key"
  local wait_marker="NOTICE_ROUTE_WAIT run=$NOTICE_ROUTE_RUN_ID case=$case_key"
  local done_marker="NOTICE_ROUTE_DONE run=$NOTICE_ROUTE_RUN_ID case=$case_key"
  local payload="$EVIDENCE_DIR/payload-$case_key.json"

  wait_for_marker "$wait_marker" "$case_key" "wait"
  cat >"$payload" <<JSON
{
  "aps": {
    "alert": {
      "title": "$title",
      "body": "Tap to open the requested page."
    },
    "sound": "default"
  },
  "url": "$route"
}
JSON

  echo "NOTICE_ROUTE_PUSH run=$NOTICE_ROUTE_RUN_ID case=$case_key route=$route title=$title" | tee -a "$HOST_LOG"
  if ! xcrun simctl push "$SIMULATOR_UDID" "$APP_BUNDLE_ID" "$payload" 2>&1 | tee -a "$HOST_LOG"; then
    echo "simctl push failed for $case_key. No notification callback is claimed." | tee -a "$HOST_LOG" >&2
    return 1
  fi
  wait_for_marker "$done_marker" "$case_key" "completion"
}

push_route daily-today "/daily?date=$NOTICE_ROUTE_DATE"
push_route daily-pray "/daily?date=$NOTICE_ROUTE_DATE"
push_route daily-read-pushed "/daily?date=$NOTICE_ROUTE_DATE"
push_route rosary-pray "/pray/rosary"
push_route rosary-today "/pray/rosary"
push_route rosary-read-pushed "/pray/rosary"

while kill -0 "$XCODEBUILD_PID" 2>/dev/null; do
  if (( SECONDS >= OVERALL_DEADLINE )); then
    echo "Overall timeout while waiting for xcodebuild to finish." | tee -a "$HOST_LOG" >&2
    tail -100 "$XCODEBUILD_LOG" >&2
    exit 1
  fi
  sleep 0.25
done
XCODEBUILD_STATUS=0
wait "$XCODEBUILD_PID" || XCODEBUILD_STATUS=$?
XCODEBUILD_PID=""
echo "Notification response UI test exit status: $XCODEBUILD_STATUS" | tee -a "$HOST_LOG"
if (( XCODEBUILD_STATUS != 0 )); then
  tail -100 "$XCODEBUILD_LOG" >&2
fi
exit "$XCODEBUILD_STATUS"
