#!/bin/bash
set -e

APP_NAME="task_manager"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=$(grep "appVersion" "$PROJECT_DIR/lib/version.dart" | grep -o "'[0-9.]*'" | tr -d "'")
DMG_PATH="$PROJECT_DIR/TaskManager_v${VERSION}_macos.dmg"
APP_PATH="$PROJECT_DIR/build/macos/Build/Products/Release/$APP_NAME.app"

echo "==> Building macOS release..."
cd "$PROJECT_DIR"
flutter build macos --release

echo "==> Creating DMG..."
rm -f "$DMG_PATH" 2>/dev/null || true

# Create a temporary read-only DMG with proper code signing
/usr/bin/hdiutil create -volname "TaskManager" -srcfolder "$APP_PATH" -format UDZO -quiet "$DMG_PATH"

echo "==> Done: $DMG_PATH"
ls -lh "$DMG_PATH"

echo ""
echo "==> To install: open '$DMG_PATH' and drag task_manager.app to Applications"