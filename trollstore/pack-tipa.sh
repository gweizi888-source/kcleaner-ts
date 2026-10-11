#!/usr/bin/env bash
# Run on macOS after: make && make trollsign
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/kcleaner_ts"
APP_ID="com.kcleaner.ts"
APP_NAME="KCleanerTS"
BUILD="$ROOT/build/tipa"
PAYLOAD="$BUILD/Payload/${APP_NAME}.app"

if [[ ! -f "$BIN" ]]; then
  echo "Missing $BIN — run 'make' in $ROOT first."
  exit 1
fi

rm -rf "$BUILD"
mkdir -p "$PAYLOAD"

cp "$BIN" "$PAYLOAD/kcleaner_ts"
chmod +x "$PAYLOAD/kcleaner_ts"

cat > "$PAYLOAD/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>kcleaner_ts</string>
  <key>CFBundleIdentifier</key>
  <string>com.kcleaner.ts</string>
  <key>CFBundleName</key>
  <string>KCleanerTS</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>MinimumOSVersion</key>
  <string>15.0</string>
  <key>UIDeviceFamily</key>
  <array>
    <integer>1</integer>
  </array>
</dict>
</plist>
PLIST

if command -v ldid >/dev/null 2>&1; then
  ldid -S"$ROOT/trollstore/entitlements.plist" "$PAYLOAD/kcleaner_ts"
fi

TIPA="$ROOT/build/${APP_NAME}.tipa"
(cd "$BUILD" && zip -qr "$TIPA" Payload)
echo "Created $TIPA"
echo "Install with TrollStore, then run via SSH/NewTerm: kcleaner_ts -L"
