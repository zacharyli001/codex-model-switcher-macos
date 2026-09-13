#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT"
swift build -c release
APP="$ROOT/outputs/Codex Model Switcher.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/CodexModelSwitcher" "$APP/Contents/MacOS/CodexModelSwitcher"
cp "Sources/CodexModelSwitcher/deepseek-models.json" "$APP/Contents/Resources/deepseek-models.json"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
echo "$APP"
