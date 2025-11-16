#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CameraPreview"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"

echo "Building ${APP_NAME} for ${ARCH} using SDK ${SDK_PATH}" >&2
swiftc \
  -target "${ARCH}-apple-macosx13.3" \
  -sdk "$SDK_PATH" \
  -O \
  "$ROOT_DIR"/Sources/*.swift \
  -o "$MACOS_DIR/${APP_NAME}" \
  -framework SwiftUI \
  -framework AVFoundation \
  -framework Vision \
  -framework AppKit

cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleExecutable -string "$APP_NAME" "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleName -string "$APP_NAME" "$CONTENTS_DIR/Info.plist"

echo "Created app at $APP_DIR"

echo "Run: open \"$APP_DIR\"" >&2
