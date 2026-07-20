# ScreenTextClip

ScreenTextClip 是一个极简的 macOS 菜单栏屏幕取词工具。

按下 `⌃⌘S`，框选屏幕上的文字，原文会自动复制到剪贴板，同时在选区旁显示本地翻译结果。

## 下载安装包

### [点击这里下载 ScreenTextClip-0.2.0.dmg](https://github.com/jmwang028/ScreenTextClip-Releases/releases/download/v0.2.0/ScreenTextClip-0.2.0.dmg)

下载后得到的 `ScreenTextClip-0.2.0.dmg` 就是 macOS 安装包。

不要点击 GitHub 页面里的绿色 `Code`，也不要下载 `Source code (zip)` 或 `Source code (tar.gz)`，这些都不是安装包。

安装包同时支持 Apple Silicon 和 Intel Mac。

## 功能

- 多显示器框选 OCR
- 支持英文、简体中文、日文和韩文识别
- OCR 原文自动复制到剪贴板
- 使用 Apple Translation 进行本地翻译
- 可选择翻译为简体中文、英文、日文或韩文
- 可拖动、可选择文字的翻译弹窗
- 安静常驻菜单栏，不显示 Dock 图标
- 不保存截图和历史记录，不调用第三方云端 API

## 系统要求

- macOS 14 或更高版本：截图和 OCR
- macOS 15 或更高版本：本地翻译
- 首次翻译需要下载 Apple 翻译语言包

语言包位置：

```text
系统设置 > 通用 > 语言与地区 > 翻译语言
```

## 安装

1. 点击上方链接下载 `ScreenTextClip-0.2.0.dmg`。
2. 打开 DMG，将 `ScreenTextClip.app` 拖入“应用程序”。
3. 第一次双击启动时，macOS 会因为 App 未经过 Apple 公证而阻止打开。
4. 打开“系统设置 > 隐私与安全性”，向下找到 ScreenTextClip，点击“仍要打开”。
5. 按提示输入 Mac 登录密码。
6. 允许 ScreenTextClip 使用屏幕录制权限，然后退出并重新打开 App。

“仍要打开”通常只需要操作一次。Apple 的相关说明见[在 Mac 上覆盖安全性设置以打开 App](https://support.apple.com/guide/mac-help/mh40617/mac)。

## 使用

- 按 `Control + Command + S`（`⌃⌘S`）开始框选。
- 也可以左键点击菜单栏的 `STC`。
- 右键或按住 Control 点击 `STC`，可以选择翻译目标语言或退出。
- 框选完成后，OCR 原文自动进入剪贴板；译文显示在选区旁边。

## 屏幕录制权限

ScreenTextClip 需要读取用户主动框选的屏幕区域：

```text
系统设置 > 隐私与安全性 > 屏幕录制
```

授权后如果仍无法截图，请退出并重新打开 ScreenTextClip。

## 隐私

- 截图和 OCR 在本机处理。
- 翻译使用 macOS 自带的 Apple Translation。
- App 不保存截图、OCR 结果或翻译历史。
- App 不需要账号，也不连接第三方服务。

## 关于安全提示

这是提供给朋友测试的本地签名版本，没有 Developer ID，也没有经过 Apple notarization。macOS 首次启动时会显示安全提醒，这是当前测试版的已知行为，不影响 App 功能。

请只从本仓库的 Releases 页面下载安装包，并可使用同一 Release 中的 SHA-256 文件核对下载完整性。
