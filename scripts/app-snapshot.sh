#!/bin/bash
# 启动 Android App，并抓取截图、UI XML、focus、resumed activity。

set -euo pipefail

SERIAL=""
PACKAGE=""
ACTIVITY=""
WAIT_SECONDS=5
OUT_DIR="./artifacts"
PREFIX="snapshot"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--serial)
      SERIAL="${2:-}"
      shift 2
      ;;
    -p|--package)
      PACKAGE="${2:-}"
      shift 2
      ;;
    -a|--activity)
      ACTIVITY="${2:-}"
      shift 2
      ;;
    -w|--wait)
      WAIT_SECONDS="${2:-}"
      shift 2
      ;;
    -o|--out)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --prefix)
      PREFIX="${2:-}"
      shift 2
      ;;
    -h|--help)
      cat <<'USAGE'
用法：
  app-snapshot.sh --package com.tencent.mm
  app-snapshot.sh -s <serial> --package com.ss.android.ugc.aweme --out /tmp/douyin --prefix home
  app-snapshot.sh --package com.xingin.xhs --activity .index.v2.IndexActivityV2
USAGE
      exit 0
      ;;
    *)
      echo "未知参数：$1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$PACKAGE" ]]; then
  echo "必须传入 --package。" >&2
  exit 1
fi

if ! command -v adb >/dev/null 2>&1; then
  echo "未找到 adb，请先安装 Android Platform Tools。" >&2
  exit 1
fi

resolve_serial() {
  if [[ -n "$SERIAL" ]]; then
    echo "$SERIAL"
    return
  fi

  local devices
  devices=$(adb devices | awk 'NR>1 && $2=="device" {print $1}')
  local count
  count=$(printf '%s\n' "$devices" | sed '/^$/d' | wc -l | tr -d ' ')

  if [[ "$count" == "0" ]]; then
    echo "当前没有在线 Android 设备。" >&2
    exit 1
  fi

  if [[ "$count" != "1" ]]; then
    echo "检测到多个在线设备，请用 -s 显式指定序列号：" >&2
    printf '%s\n' "$devices" >&2
    exit 1
  fi

  printf '%s\n' "$devices"
}

SERIAL="$(resolve_serial)"
ADB=(adb -s "$SERIAL")

if [[ -z "$ACTIVITY" ]]; then
  ACTIVITY="$(${ADB[@]} shell cmd package resolve-activity --brief "$PACKAGE" | tr -d '\r' | tail -n 1)"
fi

if [[ -z "$ACTIVITY" || "$ACTIVITY" == "No activity found" ]]; then
  echo "无法解析包 $PACKAGE 的默认 activity。" >&2
  exit 1
fi

if [[ "$ACTIVITY" != */* ]]; then
  COMPONENT="$PACKAGE/$ACTIVITY"
else
  COMPONENT="$ACTIVITY"
fi

mkdir -p "$OUT_DIR"
STAMP="$(date +%Y%m%d_%H%M%S)"
BASE="$OUT_DIR/${PREFIX}_${STAMP}"
REMOTE_BASE="/sdcard/Download/${PREFIX}_${STAMP}"

printf '设备序列号：%s\n' "$SERIAL"
printf '目标组件：%s\n' "$COMPONENT"
printf '输出前缀：%s\n' "$BASE"

${ADB[@]} shell am start -W -n "$COMPONENT" >/tmp/app_snapshot_start.log 2>&1 || true
sleep "$WAIT_SECONDS"

${ADB[@]} shell "dumpsys window | grep mCurrentFocus | tail -n 1" | tr -d '\r' > "${BASE}.focus.txt"
${ADB[@]} shell "dumpsys activity activities | grep mResumedActivity | tail -n 1" | tr -d '\r' > "${BASE}.resumed.txt"
${ADB[@]} shell screencap -p "${REMOTE_BASE}.png"
${ADB[@]} shell uiautomator dump "${REMOTE_BASE}.xml" >/tmp/app_snapshot_dump.log 2>&1 || true
${ADB[@]} pull "${REMOTE_BASE}.png" "${BASE}.png" >/dev/null
${ADB[@]} pull "${REMOTE_BASE}.xml" "${BASE}.xml" >/dev/null || true

printf '\n生成产物：\n'
printf '  %s\n' "${BASE}.png" "${BASE}.xml" "${BASE}.focus.txt" "${BASE}.resumed.txt"
printf '\n启动日志：\n'
cat /tmp/app_snapshot_start.log
