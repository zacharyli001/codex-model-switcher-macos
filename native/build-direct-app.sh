#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
APP="$ROOT/outputs/Codex Model Switcher.app"
mkdir -p "$ROOT/outputs"
/usr/bin/osacompile -l JavaScript -o "$APP" "$ROOT/native/launcher.js"
cp "$ROOT/native/switcher.sh" "$APP/Contents/Resources/switcher.sh"
cp "$ROOT/Sources/CodexModelSwitcher/deepseek-models.json" "$APP/Contents/Resources/deepseek-models.json"
chmod +x "$APP/Contents/Resources/switcher.sh"
/usr/bin/codesign --force --deep --sign - "$APP" >/dev/null
print "$APP"
