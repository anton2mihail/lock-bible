#!/bin/bash
# Per-simulator-device offline control for the L26 run. Source only.
# Sets or clears the launchd environment of ONE simulator device. It never changes the host network.
# Default is a dry run. Add --apply to run the commands.
# Usage: l26_offline_ctl.sh status|enable|disable --udid UDID [--shim DYLIB --log FILE] [--apply]
# Only the four John-owned devices below are allowed (Sol review, 6 October 2026). enable needs a Booted device
# and a shim that vtool reports as IOSSIMULATOR. A device shutdown is the reliable way to remove the setting.
set -euo pipefail
ALLOWED_UDIDS=(
  37D1870B-F16D-488A-8F20-959201F970D9
  5FC2D286-6774-4428-A7F8-9B43A9076B6C
  E76B006D-2F32-4D49-98D4-9DC1F15B7EB3
  56AAEED9-CA66-4584-A217-4312910F6E80
)
action="${1:-}"; shift || true
udid=""; shim=""; log=""; apply=0
while [ $# -gt 0 ]; do
  case "$1" in
    --udid) udid="$2"; shift 2 ;;
    --shim) shim="$2"; shift 2 ;;
    --log) log="$2"; shift 2 ;;
    --apply) apply=1; shift ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
udid="$(printf '%s' "$udid" | tr 'a-f' 'A-F')"
[[ "$udid" =~ ^[0-9A-F-]{36}$ ]] || { echo "--udid must be an explicit device UDID (never 'booted')" >&2; exit 2; }
allowed=0
for item in "${ALLOWED_UDIDS[@]}"; do [ "$item" = "$udid" ] && allowed=1; done
if [ "$action" != "status" ] && [ "$allowed" != 1 ]; then
  echo "refused: $udid is not one of the four John-owned devices" >&2; exit 2
fi
run() { echo "+ $*"; if [ "$apply" = 1 ]; then "$@"; fi; }
device_state() { xcrun simctl list devices | grep -F "$udid" | sed -E 's/.*\(([A-Za-z]+)\)[[:space:]]*$/\1/' | head -1; }
case "$action" in
  status)
    # Read only. Prints the device state and the two environment values.
    xcrun simctl list devices | grep -F "$udid" || echo "device not listed"
    if [ "$(device_state)" = "Booted" ]; then
      for name in DYLD_INSERT_LIBRARIES OFFLINE_SHIM_LOG; do
        printf '%s=' "$name"; xcrun simctl spawn "$udid" launchctl getenv "$name" || true; echo
      done
    else
      echo "device is not Booted: environment values are not readable (a shut down device has none)"
    fi ;;
  enable)
    [ -f "$shim" ] || { echo "--shim must name the built sim dylib" >&2; exit 2; }
    [ -n "$log" ] || { echo "--log must name a host file for the blocked-call log" >&2; exit 2; }
    state="$(device_state)"
    [ "$state" = "Booted" ] || { echo "refused: device state is '$state', not Booted" >&2; exit 2; }
    platform="$(vtool -show-build "$shim" 2>/dev/null | awk '$1=="platform"{print $2; exit}')"
    [ "$platform" = "IOSSIMULATOR" ] || { echo "refused: shim platform is '$platform', not IOSSIMULATOR" >&2; exit 2; }
    echo "shim SHA-256: $(shasum -a 256 "$shim" | awk '{print $1}')"
    run xcrun simctl spawn "$udid" launchctl setenv OFFLINE_SHIM_LOG "$log"
    run xcrun simctl spawn "$udid" launchctl setenv DYLD_INSERT_LIBRARIES "$shim" ;;
  disable)
    run xcrun simctl spawn "$udid" launchctl unsetenv DYLD_INSERT_LIBRARIES
    run xcrun simctl spawn "$udid" launchctl unsetenv OFFLINE_SHIM_LOG
    echo "Next: shut the device down, boot it again, run 'status' (both values must be empty), then run the raw probe (expect REACHED)." ;;
  *) echo "usage: $0 status|enable|disable --udid UDID [--shim DYLIB --log FILE] [--apply]" >&2; exit 2 ;;
esac
