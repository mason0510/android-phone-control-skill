#!/bin/bash
# 对比两次 Android 页面抓取产物，判断操作后是否出现可观测变化。

set -euo pipefail

BEFORE_DIR="${1:-}"
AFTER_DIR="${2:-}"

if [[ -z "$BEFORE_DIR" || -z "$AFTER_DIR" ]]; then
  cat <<'USAGE' >&2
用法：
  verify-action-by-diff.sh <before目录> <after目录>

说明：
  目录里应至少包含一组 *.png / *.xml / *.focus.txt / *.resumed.txt。
USAGE
  exit 1
fi

pick_latest() {
  local dir="$1"
  local suffix="$2"
  find "$dir" -maxdepth 1 -type f -name "*${suffix}" | sort | tail -n 1
}

BEFORE_PNG="$(pick_latest "$BEFORE_DIR" '.png')"
AFTER_PNG="$(pick_latest "$AFTER_DIR" '.png')"
BEFORE_XML="$(pick_latest "$BEFORE_DIR" '.xml')"
AFTER_XML="$(pick_latest "$AFTER_DIR" '.xml')"
BEFORE_FOCUS="$(pick_latest "$BEFORE_DIR" '.focus.txt')"
AFTER_FOCUS="$(pick_latest "$AFTER_DIR" '.focus.txt')"
BEFORE_RESUMED="$(pick_latest "$BEFORE_DIR" '.resumed.txt')"
AFTER_RESUMED="$(pick_latest "$AFTER_DIR" '.resumed.txt')"

hash_or_na() {
  local file="$1"
  if [[ -n "$file" && -f "$file" ]]; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    echo "N/A"
  fi
}

same_or_changed() {
  local left="$1"
  local right="$2"
  if [[ -z "$left" || -z "$right" || ! -f "$left" || ! -f "$right" ]]; then
    echo "unknown"
    return
  fi
  if cmp -s "$left" "$right"; then
    echo "no"
  else
    echo "yes"
  fi
}

printf 'before_focus=%s\n' "$( [[ -f "$BEFORE_FOCUS" ]] && cat "$BEFORE_FOCUS" || echo 'N/A' )"
printf 'after_focus=%s\n' "$( [[ -f "$AFTER_FOCUS" ]] && cat "$AFTER_FOCUS" || echo 'N/A' )"
printf 'focus_changed=%s\n' "$(same_or_changed "$BEFORE_FOCUS" "$AFTER_FOCUS")"
printf '\n'
printf 'before_resumed=%s\n' "$( [[ -f "$BEFORE_RESUMED" ]] && cat "$BEFORE_RESUMED" || echo 'N/A' )"
printf 'after_resumed=%s\n' "$( [[ -f "$AFTER_RESUMED" ]] && cat "$AFTER_RESUMED" || echo 'N/A' )"
printf 'resumed_changed=%s\n' "$(same_or_changed "$BEFORE_RESUMED" "$AFTER_RESUMED")"
printf '\n'
printf 'before_xml_sha256=%s\n' "$(hash_or_na "$BEFORE_XML")"
printf 'after_xml_sha256=%s\n' "$(hash_or_na "$AFTER_XML")"
printf 'xml_changed=%s\n' "$(same_or_changed "$BEFORE_XML" "$AFTER_XML")"
printf '\n'
printf 'before_png_sha256=%s\n' "$(hash_or_na "$BEFORE_PNG")"
printf 'after_png_sha256=%s\n' "$(hash_or_na "$AFTER_PNG")"
printf 'png_changed=%s\n' "$(same_or_changed "$BEFORE_PNG" "$AFTER_PNG")"
printf '\n结论：\n'
printf '  adb tap 本身不返回业务成功；请以上述变化项作为最小验收证据。\n'
