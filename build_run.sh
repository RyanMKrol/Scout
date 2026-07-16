#!/usr/bin/env bash
#
# build_run.sh — generate, build, install, launch, and screenshot Scout on the iOS
# simulator, entirely from the CLI (no Xcode GUI). This is the command
# .harness/config/harness.env's VISUAL_VERIFY_HOOK points at, so a visual check
# always screenshots the FRESHLY-BUILT current code, not whatever happens to be booted.
#
# Usage: ./build_run.sh [simulator-name-or-udid]
# Default is the DEDICATED "Scout-Sim" device so this loop's screenshots never clash with
# another iOS loop on the same Mac (two loops sharing a by-name device fight over the
# foreground app and reset each other's sims mid-test). Create it once (T001 does this):
#   xcrun simctl create "Scout-Sim" \
#     com.apple.CoreSimulator.SimDeviceType.iPhone-16 <an installed iOS-26 runtime id>
# List runtimes/device types with `xcrun simctl list runtimes devicetypes`.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

APP_NAME="Scout"
BUNDLE_ID="com.ryankrol.scout"
SIM_NAME="${1:-Scout-Sim}"   # dedicated device by name; pass a UDID to pin a specific one

# Resolve the argument to a concrete UDID. For the dedicated default device, tools/loop_sim.sh
# ENSURES it exists (idempotent create on the newest iOS runtime) and prints its UDID — so a
# fresh machine self-heals. For any other name, prefer an already-booted match, else the newest
# available. Every grep pipeline ends in `|| true` — under `set -euo pipefail` a grep that
# matches nothing would otherwise abort the whole script silently before the first echo.
if [[ "$SIM_NAME" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f-]{27}$ ]]; then
  SIM="$SIM_NAME"
elif [ "$SIM_NAME" = "${SCOUT_SIM_NAME:-Scout-Sim}" ]; then
  SIM="$("$PROJECT_DIR/tools/loop_sim.sh")"
else
  SIM_ID="$(xcrun simctl list devices booted | grep -F "$SIM_NAME (" | grep -Eo '[0-9A-Fa-f-]{36}' | head -1 || true)"
  if [ -z "$SIM_ID" ]; then
    SIM_ID="$(xcrun simctl list devices available | grep -F "$SIM_NAME (" | grep -Eo '[0-9A-Fa-f-]{36}' | tail -1 || true)"
  fi
  SIM="${SIM_ID:-$SIM_NAME}"
fi

BUILD_DIR="$PROJECT_DIR/build"
APP_PATH="$BUILD_DIR/Debug-iphonesimulator/$APP_NAME.app"
SHOT_DIR="$PROJECT_DIR/screenshots"
SHOT_PATH="$SHOT_DIR/latest.png"

echo "▸ Generating Xcode project…"
xcodegen generate >/dev/null

echo "▸ Building $APP_NAME for the simulator…"
xcodebuild \
  -project "$APP_NAME.xcodeproj" \
  -target "$APP_NAME" \
  -sdk iphonesimulator \
  -configuration Debug \
  build \
  SUPPORTED_PLATFORMS="iphonesimulator" \
  SYMROOT="$BUILD_DIR" \
  | tail -3

echo "▸ Booting simulator '$SIM_NAME'…"
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" >/dev/null 2>&1 || true
open -a Simulator || true

# Reset persistent simulator settings that survive between runs and silently corrupt shots.
# Dynamic Type is PERSISTENT — a prior accessibility task can leave it cranked up so every
# later screenshot looks wrongly oversized. Note the UNDERSCORE: `content-size` (hyphen) just
# prints simctl usage and does nothing on Xcode 26.
xcrun simctl ui "$SIM" content_size large >/dev/null 2>&1 || true

echo "▸ Installing + launching…"
xcrun simctl install "$SIM" "$APP_PATH"
xcrun simctl launch "$SIM" "$BUNDLE_ID"

mkdir -p "$SHOT_DIR"
sleep 3   # let SwiftUI paint before capturing
xcrun simctl io "$SIM" screenshot "$SHOT_PATH" >/dev/null
echo "▸ Screenshot → $SHOT_PATH"
