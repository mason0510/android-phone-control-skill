#!/bin/bash
# 用 ADB 输出 Android 手机当前连接与屏幕状态。

set -euo pipefail

SERIAL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--serial)
      SERIAL="${2:-}"
      shift 2
      ;;
    -h|--help)
      cat <<'USAGE'
用法：
  adb-device-check.sh                自动选择唯一在线设备
  adb-device-check.sh -s <serial>    指定设备序列号
USAGE
      exit 0
      ;;
    *)
      echo "未知参数：$1" >&2
      exit 1
      ;;
  esac
done

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

printf '设备序列号：%s\n' "$SERIAL"
printf '设备型号：%s\n' "$(${ADB[@]} shell getprop ro.product.model | tr -d '\r')"
printf 'Android 版本：%s\n' "$(${ADB[@]} shell getprop ro.build.version.release | tr -d '\r')"
printf '\n[电源/屏幕]\n'
${ADB[@]} shell 'dumpsys power | grep -E "mWakefulness=|Display Power: state=" || true'
printf 'stay_on_while_plugged_in=%s\n' "$(${ADB[@]} shell settings get global stay_on_while_plugged_in | tr -d '\r')"
printf 'screen_off_timeout=%s\n' "$(${ADB[@]} shell settings get system screen_off_timeout | tr -d '\r')"

printf '\n[窗口/Activity]\n'
${ADB[@]} shell 'dumpsys window | grep mCurrentFocus | tail -n 1 || true'
${ADB[@]} shell 'dumpsys activity activities | grep mResumedActivity | tail -n 1 || true'

printf '\n[电池]\n'
${ADB[@]} shell 'dumpsys battery | grep -E "AC powered|USB powered|Wireless powered|status:|level:" || true'
