#!/bin/bash
set -e

# Build MacWattage and copy to dist/ folder.
xcodebuild -scheme MacWattage -configuration Debug -destination 'generic/platform=macOS' build

BUILT_APP=$(find ~/Library/Developer/Xcode/DerivedData/MacWattage-* -name 'MacWattage.app' -path '*/Build/Products/*Debug*' ! -path '*Index.noindex*' | head -1)
rm -rf dist/MacWattage.app
cp -R "$BUILT_APP" dist/

echo "Built → dist/MacWattage.app"
