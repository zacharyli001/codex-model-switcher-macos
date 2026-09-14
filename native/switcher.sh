#!/bin/zsh
set -euo pipefail

SERVICE="com.codex-model-switcher.api-key"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
CONFIG="$CODEX_DIR/config.toml"
MODELS="$CODEX_DIR/models.json"
STATE="$CODEX_DIR/model-switcher"
BACKUP="$STATE/last-backup"
RESOURCE_DIR="${0:A:h}"
SCRIPT_PATH="${0:A}"
REAL_CODEX_DIR="$HOME/.codex"

save_key() {
  /usr/bin/security add-generic-password -U -s "$SERVICE" -a "$1" -w "$2" >/dev/null
}

has_key() {
  /usr/bin/security find-generic-password -s "$SERVICE" -a "$1" -w >/dev/null
}

list_siliconflow_models() {
  local key response
  key="$(/usr/bin/security find-generic-password -s "$SERVICE" -a siliconflow -w)"
  response="$(/usr/bin/curl -fsS --connect-timeout 12 --max-time 25 -H "Authorization: Bearer $key" 'https://api.siliconflow.cn/v1/models')"
  print -r -- "$response" | /usr/bin/sed 's/},{/}\n{/g' | /usr/bin/sed -nE 's/.*"id"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | /usr/bin/sort -u
}

save_siliconflow_model() {
  mkdir -p "$REAL_CODEX_DIR/model-switcher"
  print -r -- "$1" > "$REAL_CODEX_DIR/model-switcher/siliconflow-model.txt"
}

cc_app_path() {
  for candidate in "/Applications/CC Switch.app" "$HOME/Applications/CC Switch.app"; do
    [[ -d "$candidate" ]] && { print -r -- "$candidate"; return 0; }
  done
  return 1
}

install_cc_switch() {
  local app_path="$HOME/Applications/CC Switch.app" release_json asset_url download_dir dmg mount_dir
  cc_app_path >/dev/null 2>&1 && { cc_app_path; return 0; }
  download_dir="$(mktemp -d "${TMPDIR:-/tmp}/codex-switcher-cc.XXXXXX")"
  release_json="$download_dir/release.json"
  dmg="$download_dir/CC-Switch.dmg"
  mount_dir="$download_dir/mount"
  mkdir -p "$mount_dir" "$HOME/Applications"
  /usr/bin/curl -fL --retry 2 --connect-timeout 15 'https://api.github.com/repos/farion1231/cc-switch/releases/latest' -o "$release_json"
  asset_url="$(/usr/bin/sed -nE 's/.*"browser_download_url":[[:space:]]*"([^"]*[Mm]ac[Oo][Ss][^"]*\.dmg)".*/\1/p' "$release_json" | /usr/bin/head -1)"
  [[ -n "$asset_url" ]] || { print -u2 '无法在官方发行版中找到 macOS DMG。'; return 1; }
  /usr/bin/curl -fL --retry 2 --connect-timeout 15 "$asset_url" -o "$dmg"
  /usr/bin/hdiutil attach "$dmg" -nobrowse -readonly -mountpoint "$mount_dir" >/dev/null
  local source_app
  source_app="$(/usr/bin/find "$mount_dir" -maxdepth 2 -name 'CC Switch.app' -print -quit)"
  if [[ -z "$source_app" ]]; then /usr/bin/hdiutil detach "$mount_dir" >/dev/null 2>&1 || true; print -u2 '安装包内未找到 CC Switch.app。'; return 1; fi
  /usr/bin/ditto "$source_app" "$app_path"
  /usr/bin/hdiutil detach "$mount_dir" >/dev/null
  rm -rf "$download_dir"
  print -r -- "$app_path"
}

backup_now() {
  mkdir -p "$STATE"
  rm -rf "$BACKUP"
  mkdir -p "$BACKUP"
  [[ -f "$CONFIG" ]] && cp "$CONFIG" "$BACKUP/config.toml" && print 'config=true' > "$BACKUP/manifest" || print 'config=false' > "$BACKUP/manifest"
  [[ -f "$MODELS" ]] && cp "$MODELS" "$BACKUP/models.json" && print 'models=true' >> "$BACKUP/manifest" || print 'models=false' >> "$BACKUP/manifest"
}

restore_last() {
  [[ -f "$BACKUP/manifest" ]] || { print -u2 '还没有可恢复的备份。'; exit 1; }
  if grep -q '^config=true$' "$BACKUP/manifest"; then cp "$BACKUP/config.toml" "$CONFIG"; else rm -f "$CONFIG"; fi
  if grep -q '^models=true$' "$BACKUP/manifest"; then cp "$BACKUP/models.json" "$MODELS"; else rm -f "$MODELS"; fi
}

patch_config() {
  local profile="$1" model provider base account catalog tmp
  case "$profile" in
    openai) model='gpt-5.6-sol'; provider='openai'; base=''; account=''; catalog='' ;;
    deepseek-flash) model='deepseek-flash'; provider='deepseek'; base='https://api.deepseek.com/'; account='deepseek'; catalog='yes' ;;
    deepseek-pro) model='deepseek-v4-pro'; provider='deepseek'; base='https://api.deepseek.com/'; account='deepseek'; catalog='yes' ;;
    siliconflow) model='deepseek-ai/DeepSeek-V4-Flash'; provider='siliconflow'; base='http://127.0.0.1:3456/v1'; account='siliconflow'; catalog='' ;;
    *) print -u2 '未知模型配置。'; exit 1 ;;
  esac
  mkdir -p "$CODEX_DIR"
  [[ -f "$CONFIG" ]] || : > "$CONFIG"
  tmp="$(mktemp "$CODEX_DIR/config.toml.switcher.XXXXXX")"
  /usr/bin/awk '
    BEGIN { section=0; skip=0 }
    /^\[/ { section=1 }
    section==0 && $0 ~ /^(model|model_provider|preferred_auth_method|forced_login_method|model_reasoning_effort|web_search|model_catalog_json)[[:space:]]*=/ { next }
    /^\[model_providers\.(deepseek|siliconflow)(\]|\.)/ { skip=1; next }
    skip && /^\[/ { skip=0 }
    !skip { print }
  ' "$CONFIG" > "$tmp.body"
  {
    print "model = \"$model\""
    print "model_provider = \"$provider\""
    if [[ "$provider" != openai ]]; then
      print 'preferred_auth_method = "apikey"'
      print 'forced_login_method = "api"'
      print 'model_reasoning_effort = "high"'
      print 'web_search = "disabled"'
    fi
    [[ -n "$catalog" ]] && print 'model_catalog_json = "~/.codex/models.json"'
    print ''
    cat "$tmp.body"
    if [[ -n "$base" ]]; then
      print ''
      print "[model_providers.$provider]"
      print "name = \"$provider\""
      print "base_url = \"$base\""
      print 'wire_api = "responses"'
      print ''
      print "[model_providers.$provider.auth]"
      print 'command = "/usr/bin/security"'
      print "args = [\"find-generic-password\", \"-s\", \"$SERVICE\", \"-a\", \"$account\", \"-w\"]"
      print 'timeout_ms = 5000'
      print 'refresh_interval_ms = 0'
    fi
  } > "$tmp"
  mv "$tmp" "$CONFIG"
  rm -f "$tmp.body"
  if [[ -n "$catalog" ]]; then
    [[ -s "$RESOURCE_DIR/deepseek-models.json" ]] || { print -u2 '应用内缺少 DeepSeek 模型目录。'; exit 1; }
    cp "$RESOURCE_DIR/deepseek-models.json" "$MODELS"
  fi
}

find_codex() {
  local found
  found="$(command -v codex 2>/dev/null || true)"
  [[ -n "$found" ]] || found="/Applications/ChatGPT.app/Contents/Resources/codex"
  [[ -x "$found" ]] || { print -u2 '没有找到 Codex 命令行程序，请先安装或更新 Codex。'; exit 1; }
  print -r -- "$found"
}

prepare_session() {
  local profile="$1" session_home="$REAL_CODEX_DIR/model-switcher/sessions/$profile"
  mkdir -p "$session_home"
  if [[ -f "$REAL_CODEX_DIR/config.toml" ]]; then
    cp "$REAL_CODEX_DIR/config.toml" "$session_home/config.toml"
  else
    : > "$session_home/config.toml"
  fi
  CODEX_HOME="$session_home" "$SCRIPT_PATH" switch "$profile"
  for shared in auth.json AGENTS.md skills plugins; do
    if [[ -e "$REAL_CODEX_DIR/$shared" && ! -e "$session_home/$shared" ]]; then
      ln -s "$REAL_CODEX_DIR/$shared" "$session_home/$shared"
    fi
  done
  print -r -- "$session_home"
}

launch_session() {
  local profile="$1" project="$2" mode="$3" session_home codex_bin launcher launch_dir
  [[ -d "$project" ]] || { print -u2 '选择的项目文件夹不存在。'; exit 1; }
  session_home="$(prepare_session "$profile")"
  codex_bin="$(find_codex)"
  launch_dir="$REAL_CODEX_DIR/model-switcher/launchers"
  mkdir -p "$launch_dir"
  launcher="$launch_dir/codex-${profile}-$(date +%Y%m%d-%H%M%S).command"
  {
    print '#!/bin/zsh'
    print 'set -e'
    printf 'export CODEX_HOME=%q\n' "$session_home"
    printf 'cd %q\n' "$project"
    if [[ "$mode" == worktree ]]; then
      printf 'exec %q -C %q --worktree\n' "$codex_bin" "$project"
    else
      printf 'exec %q -C %q\n' "$codex_bin" "$project"
    fi
  } > "$launcher"
  chmod 700 "$launcher"
  if [[ "${CODEX_SWITCHER_NO_OPEN:-}" != 1 ]]; then /usr/bin/open -a Terminal "$launcher"; fi
  print -r -- "$launcher"
}

case "${1:-}" in
  save-key) save_key "${2:?}" "${3:?}" ;;
  has-key) has_key "${2:?}" ;;
  get-key) /usr/bin/security find-generic-password -s "$SERVICE" -a "${2:?}" -w ;;
  list-siliconflow-models) list_siliconflow_models ;;
  save-siliconflow-model) save_siliconflow_model "${2:?}" ;;
  cc-status) cc_app_path ;;
  install-cc-switch) install_cc_switch ;;
  switch) backup_now; patch_config "${2:?}" ;;
  launch-session) launch_session "${2:?}" "${3:?}" "${4:?}" ;;
  restore) restore_last ;;
  *) print -u2 '无效操作。'; exit 2 ;;
esac
