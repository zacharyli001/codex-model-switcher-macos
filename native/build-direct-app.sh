#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
APP="$ROOT/outputs/Codex Model Switcher.app"
mkdir -p "$ROOT/outputs"
if [[ -e "$APP" ]]; then
  old_app="${TMPDIR:-/tmp}/Codex-Model-Switcher.previous.$(date +%s).app"
  mv "$APP" "$old_app"
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
clang -O2 -fobjc-arc -framework Cocoa "$ROOT/native/app-entrypoint.m" -o "$APP/Contents/MacOS/CodexModelSwitcher"
cp "$ROOT/native/launcher.js" "$APP/Contents/Resources/launcher.js"
cp "$ROOT/native/switcher.sh" "$APP/Contents/Resources/switcher.sh"
cp "$ROOT/Sources/CodexModelSwitcher/deepseek-models.json" "$APP/Contents/Resources/deepseek-models.json"
chmod +x "$APP/Contents/Resources/switcher.sh"
/usr/bin/codesign --force --deep --sign - "$APP" >/dev/null
print "$APP"
