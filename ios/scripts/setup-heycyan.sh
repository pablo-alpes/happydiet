#!/bin/bash
# Setup HeyCyan Smart Glasses SDK for HappyDiet
# Run from project root: ./ios/scripts/setup-heycyan.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$IOS_DIR/.." && pwd)"
SDK_DIR="$PROJECT_ROOT/HeyCyanSDK"

echo "=== HeyCyan SDK Setup ==="
echo "iOS dir: $IOS_DIR"
echo "Project root: $PROJECT_ROOT"

if [ ! -d "$SDK_DIR" ]; then
  echo "Cloning HeyCyanSmartGlassesSDK..."
  cd "$PROJECT_ROOT"
  git clone --depth 1 https://github.com/ebowwa/HeyCyanSmartGlassesSDK.git HeyCyanSDK
  cd -
else
  echo "HeyCyanSDK already exists at $SDK_DIR"
fi

FRAMEWORK_SRC="$SDK_DIR/ios/QCSDK.framework"
FRAMEWORK_DST="$IOS_DIR/Frameworks/QCSDK.framework"

if [ ! -d "$FRAMEWORK_SRC" ]; then
  echo "Error: QCSDK.framework not found at $FRAMEWORK_SRC"
  exit 1
fi

mkdir -p "$IOS_DIR/Frameworks"
if [ -d "$FRAMEWORK_DST" ]; then
  rm -rf "$FRAMEWORK_DST"
fi
cp -R "$FRAMEWORK_SRC" "$FRAMEWORK_DST"
echo "Copied QCSDK.framework to $FRAMEWORK_DST"

echo ""
echo "Next steps in Xcode:"
echo "1. Add QCSDK.framework: Drag ios/Frameworks/QCSDK.framework into the HappyDiet target"
echo "2. In target → General → Frameworks: set QCSDK.framework to 'Embed & Sign'"
echo "3. In target → Build Settings → Swift Compiler: add HEYCYAN_SDK_LINKED to Active Compilation Conditions"
echo "4. Add bridging header: Build Settings → Objective-C Bridging Header = HappyDiet/HappyDiet-Bridging-Header.h"
echo ""
echo "See docs/heycyan-integration.md for full details."
