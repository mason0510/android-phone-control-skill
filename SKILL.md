---
name: android-phone-control-skill
description: Use when 需要通过 ADB 直连 Android 手机，检查连接与屏幕常亮状态，启动微信/抖音/小红书等 App，抓取截图与 uiautomator XML，并通过点击前后状态对比判断操作是否生效，而不是误以为 adb input tap 会直接返回成功状态。
---

# Android 手机 ADB 控制与状态验收

## Overview

这个 skill 只做一件事：
**把 Android 手机控制收敛成一条最短可复用链路：连接 → 状态检查 → 启动 App → 截图 / dump UI → 前后对比验收。**

它不是整个 `phone-control` 仓库的等价搬运版，
更不是 Termux fork / Shizuku / Accessibility 的大全。

第一版只保留已经被真实设备验证过、最容易复用的 ADB 主线：

- `adb devices -l` 确认设备在线
- `dumpsys power` / `settings get` 读取屏幕与常亮状态
- `am start -W` 启动目标 App
- `screencap` + `uiautomator dump` 获取真实页面产物
- 用前后状态差异判断点击是否生效

## When to Use

以下场景直接使用本 skill：

- 用户说“连一下 Android 手机 / 小米手机 / USB 调试设备”
- 用户要看“屏幕是否亮着 / 是否常亮 / 当前 Activity 是谁”
- 用户要打开微信、抖音、小红书等 App 并看首页现场
- 用户要你证明某次点击是否真的生效
- 用户误以为 `adb input tap` 自带成功返回，需要你给出真实判定方法

以下场景**不要**直接靠本 skill 收尾：

- 需要复用 App 登录态做复杂业务流程自动化
- 需要无障碍、Shizuku、Root、Termux 内驻服务
- 需要多设备编排、远端设备农场、视频录制、复杂 OCR

## Core Principle

### 1. `adb input tap` 不会返回“点击成功”

真相只有一个：

- `adb shell input tap x y` 只是**注入一次触摸事件**
- 它不会告诉你业务有没有响应
- 所以“点击状态”必须靠**前后状态对比**判断

标准链路：

1. 点击前抓一次 `focus / resumed activity / screenshot / ui xml`
2. 执行 tap
3. 点击后再抓一次
4. 对比是否发生以下变化：
   - 当前 Activity 改变
   - 当前焦点窗口改变
   - XML 内容改变
   - 截图内容改变
   - 新元素出现 / 旧元素消失 / 选中态变化

### 2. `/health` 思维不适用于手机点击验收

对手机控制来说：

- “设备在线” ≠ “页面已打开”
- “App 启动命令返回 0” ≠ “首页真的稳定渲染”
- “tap 已发送” ≠ “业务动作成功”

必须拿**当次真实截图和 UI dump**说话。

## Standard Workflow

### 1. 先做设备连通性检查

```bash
./scripts/adb-device-check.sh
./scripts/adb-device-check.sh -s <serial>
```

重点看：

- 设备是否处于 `device` 状态
- 型号是否正确
- `mWakefulness` 与 `Display Power: state`
- `stay_on_while_plugged_in` 当前值
- 当前 `mCurrentFocus` / `mResumedActivity`

### 2. 启动目标 App 并抓当前页面产物

```bash
./scripts/app-snapshot.sh --package com.tencent.mm
./scripts/app-snapshot.sh --package com.ss.android.ugc.aweme
./scripts/app-snapshot.sh --package com.xingin.xhs
```

脚本会：

- 自动解析默认 launcher activity（或使用你显式传入的 activity）
- `am start -W` 启动 App
- 等待页面渲染
- 保存：
  - `*.png`
  - `*.xml`
  - `*.focus.txt`
  - `*.resumed.txt`

### 3. 判断点击是否生效

先抓 before：

```bash
./scripts/app-snapshot.sh --package com.tencent.mm --out /tmp/wx_before --prefix before
```

执行点击：

```bash
adb shell input tap 540 1200
```

再抓 after：

```bash
./scripts/app-snapshot.sh --package com.tencent.mm --out /tmp/wx_after --prefix after
```

对比：

```bash
./scripts/verify-action-by-diff.sh /tmp/wx_before /tmp/wx_after
```

如果 diff 报告显示：

- `focus changed = yes`
- `resumed changed = yes`
- `xml changed = yes`
- `png changed = yes`

那才说明这次点击有真实证据支撑。

## Supporting Scripts

### `scripts/adb-device-check.sh`

用途：

- 找设备
- 打印屏幕 / 常亮 / Activity / 电量现场

### `scripts/app-snapshot.sh`

用途：

- 启动 App
- 抓截图、UI XML、当前焦点窗口、当前 resumed activity

### `scripts/verify-action-by-diff.sh`

用途：

- 比较点击前后两组产物
- 输出“有变化 / 没变化”的最小证据摘要

## Quick Reference

### 常亮状态

```bash
adb shell settings get global stay_on_while_plugged_in
```

常见值：

- `0`：不保持常亮
- `1`：仅 AC 充电常亮
- `2`：仅 USB 充电常亮
- `3`：AC + USB 充电常亮
- 某些 ROM 还可能出现包含无线充电位的更高位组合

### 屏幕当前状态

```bash
adb shell dumpsys power | grep -E "mWakefulness=|Display Power: state="
```

### 启动 App

```bash
adb shell am start -W -n com.tencent.mm/.ui.LauncherUI
```

### 抓真实 UI

```bash
adb shell screencap -p /sdcard/Download/current.png
adb shell uiautomator dump /sdcard/Download/current.xml
```

## Boundaries

第一版**不纳入**以下内容：

- `termux-app/` fork 与其构建链
- Shizuku 安装与权限教程
- Claude / Anthropic / OpenAI 相关 API 测试脚本
- 复杂多设备调度
- 无障碍点击、OCR、视频录制、音频分析
- 任何带真实 secret 的脚本或配置

## Notes

- 默认优先用**真实设备现场产物**验收，不要嘴上说“应该打开了”。
- 若目标 App 存在启动页、广告页、系统弹窗，`am start -W` 返回成功也不代表已经到首页。
- 若用户中途打断，必须重新抓一轮现场，不能沿用旧截图旧 XML 下结论。
