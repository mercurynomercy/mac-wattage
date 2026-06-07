#!/bin/bash
set -e

# Build MacWattage and copy to dist/ folder.
cd "$(dirname "$0")" || exit 1

# Ensure output directory exists (fix: mkdir before copy)
mkdir -p dist/

xcodebuild -scheme MacWattage -configuration Debug -destination 'generic/platform=macOS' build

BUILT_APP=$(find ~/Library/Developer/Xcode/DerivedData/MacWattage-* -name 'MacWattage.app' -path '*/Build/Products/*Debug*' ! -path '*Index.noindex*' | head -1)

if [[ -z "$BUILT_APP" ]]; then
    echo "❌ Error: No MacWattage.app found in DerivedData" >&2
    exit 1
fi

rm -rf dist/MacWattage.app
cp -R "$BUILT_APP" dist/

echo "Built → dist/MacWattage.app"
