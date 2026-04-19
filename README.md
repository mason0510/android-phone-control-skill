# android-phone-control-skill

一个面向 Codex / Claude Code 的 Android 手机控制 Skill。

它聚焦最短可复用链路：

- 用 ADB 连接 Android 手机
- 检查屏幕亮灭与常亮状态
- 启动微信 / 抖音 / 小红书等 App
- 抓取截图与 `uiautomator` XML
- 用前后状态对比判断点击是否真的生效

## 适用场景

当你需要：

- 确认 Android 手机是否已连接
- 查看当前屏幕、电量、前台 Activity
- 打开 App 并抓取真实页面现场
- 验证 `adb shell input tap` 之后到底有没有发生真实变化

就用这个 skill。

## 文件结构

```text
android-phone-control-skill/
├── SKILL.md
├── README.md
├── LICENSE
├── .gitignore
└── scripts/
    ├── adb-device-check.sh
    ├── app-snapshot.sh
    └── verify-action-by-diff.sh
```

## 快速开始

### 1. 准备环境

- 安装 Android Platform Tools（确保 `adb` 在 PATH 中）
- 手机开启开发者模式与 USB 调试
- 首次连接时在手机上授权本机

### 2. 检查设备状态

```bash
./scripts/adb-device-check.sh
./scripts/adb-device-check.sh -s <serial>
```

### 3. 启动 App 并抓现场

```bash
./scripts/app-snapshot.sh --package com.tencent.mm
./scripts/app-snapshot.sh --package com.ss.android.ugc.aweme
./scripts/app-snapshot.sh --package com.xingin.xhs
```

### 4. 验证一次点击是否真的生效

```bash
./scripts/app-snapshot.sh --package com.tencent.mm --out /tmp/wx_before --prefix before
adb shell input tap 540 1200
./scripts/app-snapshot.sh --package com.tencent.mm --out /tmp/wx_after --prefix after
./scripts/verify-action-by-diff.sh /tmp/wx_before /tmp/wx_after
```

## 重要原则

### `adb input tap` 不会返回“点击成功”

它只会注入一次触摸事件。

真正的验收方式必须是：

- 点击前抓截图 / XML / focus / resumed
- 点击后再抓一次
- 对比前后是否出现真实变化

## 安全边界

本仓库不包含：

- API Key
- Access Token
- Refresh Token
- 私有网关地址
- 设备截图 / UI XML 验收产物

请不要把运行时生成的以下产物提交进仓库：

- `artifacts/`
- `*.png`
- `*.xml`
- `*.focus.txt`
- `*.resumed.txt`


## Q&A

**Does `adb input tap` return a success status?**  
No. `adb shell input tap` only injects a touch event. It does **not** tell you whether the UI actually responded. The recommended way to verify a tap is to capture before/after evidence: screenshot, UI XML, focused window, and resumed activity.

**Does this project support multiple devices?**  
Not in the first version. The current scripts support a single online device by default, or an explicitly selected device via `-s <serial>`. A larger multi-device orchestration layer is intentionally out of scope for now.

**Does it include screenshots and UI XML dumps?**  
Yes. The minimal workflow already includes `screencap` and `uiautomator dump`, because real verification needs real artifacts instead of guesswork.

**Does it require Termux, Shizuku, or root?**  
No. This skill is built around standard ADB only. It does not require Termux, Shizuku, Accessibility, or root to run the core workflow.

**Why does the project focus on a minimal workflow?**  
Because the goal is reliability first. Device connection, state inspection, app launch, screenshot capture, UI dump, and before/after comparison are the smallest set of steps that can prove a mobile action really happened.

## Help This Project Grow

If this skill is useful in your workflow, here are the most practical ways to help it grow:

- **Star the repo** to make it easier for other developers to discover it.
- **Open an issue** if you hit device-specific quirks, ADB edge cases, or documentation gaps.
- **Submit a PR** if you improve scripts, compatibility, or verification logic.
- **Share your use case** — for example, QA automation, Android agent workflows, or remote device control. Real usage feedback helps shape the next iteration.

## License

MIT
