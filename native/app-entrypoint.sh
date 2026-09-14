#!/bin/zsh
set -euo pipefail

RESOURCES="${0:A:h:h}/Resources"
export CODEX_SWITCHER_RESOURCES="$RESOURCES"
exec /usr/bin/osascript -l JavaScript "$RESOURCES/launcher.js"
