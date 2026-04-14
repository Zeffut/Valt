#!/bin/zsh
set -e
cd "$(dirname "$0")"

echo "→ Build Release..."
xcodebuild -project Valt.xcodeproj -scheme Valt -configuration Release \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3

echo "→ Installation..."
cp -R build/Build/Products/Release/Valt.app /Applications/

echo "→ Signature (conserve les permissions d'accessibilité)..."
xattr -cr /Applications/Valt.app
codesign --force --deep --sign "Valt Developer" /Applications/Valt.app

echo "→ Relancement..."
pkill -x Valt 2>/dev/null || true
sleep 0.5
open /Applications/Valt.app

echo "✓ Valt déployé"
