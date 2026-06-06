#!/usr/bin/env bash
set -euo pipefail

# ─── Config ──────────────────────────────────────────────
PROJECT="MacWattage.xcodeproj"
SCHEME="MacWattage"
DIST_DIR="$(dirname "$0")/../dist"

# ─── 1. Archive (Release) ──────────────────────────────
BUILD_DIR="$HOME/Desktop/MacWattage-build"

echo "→ Building archive..."
xcrun xcodebuild clean archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "${BUILD_DIR}/MacWattage.xcarchive" \
    -destination "platform=macOS,arch=arm64,name=My Mac" \
    ONLY_ACTIVE_ARCH=NO \
    COMPILER_INDEX_STORE_PATH=0

APP="${BUILD_DIR}/MacWattage.xcarchive/Products/Applications/MacWattage.app"

# ─── 2. Copy to dist/ ──────────────────────────────
mkdir -p "$DIST_DIR"

# Remove old app if exists (rm -rf on .app is safe)
if [[ -e "$DIST_DIR/MacWattage.app" ]]; then
    rm -rf "$DIST_DIR/MacWattage.app"
fi

cp -R "$APP" "$DIST_DIR/"
echo "→ Copied to $DIST_DIR/MacWattage.app"

# ─── 3. Unquarantine so macOS allows opening (personal use) ──
xattr -d com.apple.quarantine "$DIST_DIR/MacWattage.app" 2>/dev/null || true

echo ""
echo "✅ App ready: $DIST_DIR/MacWattage.app"
echo "   Open with: open \"$DIST_DIR/MacWattage.app\""
