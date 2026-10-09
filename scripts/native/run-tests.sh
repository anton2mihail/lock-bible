#!/bin/bash
# Run John UI tests on one simulator with the env values that some tests need.
# Usage: scripts/native/run-tests.sh [--xxxl] [TestClass[/testName] ...]
# Default simulator: 1BA50F09-ECBB-4811-A5B2-D4B591206970 (override with SIM_ID).
set -euo pipefail
SIM_ID="${SIM_ID:-1BA50F09-ECBB-4811-A5B2-D4B591206970}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DD="${DERIVED_DATA:-/tmp/john-dd}"
XXXL=0
only=()
for arg in "$@"; do
  if [ "$arg" = "--xxxl" ]; then XXXL=1; else only+=("-only-testing:JohnUITests/$arg"); fi
done
env_args=()
# The release build test runs only if com.nrsv.verse is installed.
if xcrun simctl get_app_container "$SIM_ID" com.nrsv.verse >/dev/null 2>&1; then
  env_args+=("TEST_RUNNER_JOHN_RELEASE_BUNDLE_INSTALLED=1")
fi
restore_size() { xcrun simctl ui "$SIM_ID" content_size "${ORIGINAL_SIZE:-large}" >/dev/null 2>&1 || true; }
if [ "$XXXL" = 1 ]; then
  ORIGINAL_SIZE="$(xcrun simctl ui "$SIM_ID" content_size 2>/dev/null || echo large)"
  trap restore_size EXIT
  xcrun simctl ui "$SIM_ID" content_size accessibility-extra-extra-extra-large
  env_args+=("TEST_RUNNER_L25_CONTENT_SIZE=accessibility-extra-extra-extra-large")
fi
cd "$ROOT/native/John"
env ${env_args[@]+"${env_args[@]}"} xcodebuild test -project John.xcodeproj -scheme "John Development" \
  -destination "id=$SIM_ID" ARCHS=arm64 ONLY_ACTIVE_ARCH=YES -derivedDataPath "$DD" \
  ${only[@]+"${only[@]}"}
