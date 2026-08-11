# ScreenTextClip

[![Release](https://img.shields.io/github/v/release/jmwang028/ScreenTextClip-Releases?label=release)](https://github.com/jmwang028/ScreenTextClip-Releases/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-14%2B-black)](#系统要求)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

ScreenTextClip 是一个原生、极简的 macOS 菜单栏屏幕取词工具。按下 `⌃⌘S`，框选屏幕上的文字，App 会在本机完成 OCR、自动复制原文，并在选区旁显示 Apple Translation 翻译结果。

```text
框选屏幕文字 → Apple Vision OCR → 复制原文 → Apple Translation
```

- 不调用第三方 API
- 不上传截图或文字
- 无账号、无历史记录、无云同步
- 无第三方依赖

## 下载

### [下载 ScreenTextClip-0.5.0.dmg](https://github.com/jmwang028/ScreenTextClip-Releases/releases/download/v0.5.0/ScreenTextClip-0.5.0.dmg)

- [v0.5.0 发布说明](https://github.com/jmwang028/ScreenTextClip-Releases/releases/tag/v0.5.0)
- [v0.5.0 源码快照](https://github.com/jmwang028/ScreenTextClip-Releases/releases/download/v0.5.0/ScreenTextClip-0.5.0-source.zip)
- DMG SHA-256：`8e51511fde64899cbed55ffb0b4e98f7bc1f0cd5f3efda9ba2ed801642bdf01b`

安装包同时支持 Apple Silicon 和 Intel Mac。当前公开安装包使用本地签名，未经 Apple Developer ID 签名和 notarization，首次启动时需要在“系统设置 > 隐私与安全性”中点击“仍要打开”。

## 功能

- 使用 ScreenCaptureKit 截取用户主动框选的屏幕区域。
- 每个显示器一个选区遮罩，支持 Retina 和不同缩放比的多显示器。
- Apple Vision 本地 OCR，支持英文、简体中文、繁体中文、日文、韩文和混合语言。
- 清晰截图保持单次 OCR；仅在空结果或明显低置信度时重试一次。
- 根据文字框高度、垂直重叠和位置整理阅读顺序，处理明显双栏内容。
- 英文单词保留正常空格，中日韩文本避免多余空格。
- OCR 原文自动复制到剪贴板。
- macOS 15+ 使用 Apple Translation 本地翻译，混合语言优先由系统自动判断源语言。
- 简繁中文之间使用 macOS 本地文字转换。
- 可拖动、可选择文字的翻译弹窗。
- 菜单中可切换 English / 简体中文界面、管理语言并设置登录时启动。

## 系统要求

- macOS 14 或更高版本：截图和 OCR。
- macOS 15 或更高版本：Apple Translation 本地翻译。
- 需要“屏幕录制”权限。
- 翻译需要下载相应的 Apple 翻译语言包。

翻译语言包位置：

```text
系统设置 > 通用 > 语言与地区 > 翻译语言
```

## 安装

1. 下载并打开 `ScreenTextClip-0.5.0.dmg`。
2. 将 `ScreenTextClip.app` 拖入“应用程序”。
3. 首次打开如果被 macOS 拦截，进入“系统设置 > 隐私与安全性”，点击“仍要打开”。
4. 允许 ScreenTextClip 使用屏幕录制权限，然后退出并重新打开 App。

## 使用

1. 启动 ScreenTextClip，App 会安静常驻菜单栏，不显示 Dock 图标。
2. 按 `Control + Command + S`（`⌃⌘S`），或单击菜单栏 OCR 图标。
3. 框选文字区域并松开鼠标。
4. OCR 原文会自动进入剪贴板，译文显示在选区旁边。
5. 右键或按住 Control 点击菜单栏图标，可管理语言、界面语言和登录启动。

## 从源码构建

需要 Xcode 16 或更高版本。项目没有 Swift Package 或第三方依赖。公开源码默认使用 ad-hoc 签名，不需要开发者证书。

```bash
git clone https://github.com/jmwang028/ScreenTextClip-Releases.git
cd ScreenTextClip-Releases
./script/build_and_run.sh --verify
```

也可以直接打开 `ScreenTextClip.xcodeproj`。构建输出：

```text
dist/Debug/ScreenTextClip.app
dist/Release/ScreenTextClip.app
```

## 测试

```bash
xcodebuild test \
  -project ScreenTextClip.xcodeproj \
  -scheme ScreenTextClip \
  -destination 'platform=macOS' \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=-
```

轻量回归测试在运行时生成英文、简体中文、繁体中文、日文、韩文、混合语言、小字体、深色背景、不同字号、段落和双栏图像，不会把测试资源打包到 App。

## 项目结构

```text
ScreenTextClip/
├── App/                  # App 生命周期、菜单栏、快捷键和主流程
├── Overlay/              # 多显示器选区与翻译弹窗
├── Services/             # 截图、OCR、翻译、剪贴板和权限
├── Assets/               # App 图标
└── Info.plist
ScreenTextClipTests/       # OCR 与文本整理回归测试
script/                    # 本地构建和启动脚本
```

## 隐私与设计边界

- 截图和 OCR 在本机执行。
- 翻译使用 macOS 自带的 Apple Translation。
- App 不保存截图、OCR 结果或翻译历史。
- 不包含账号、云同步、截图标注、浏览器扩展或复杂排版恢复。
- 可用语言受 Apple Vision 和 Apple Translation 支持范围限制。
- 长篇、多语种混合文本的翻译质量取决于 Apple 语言模型。

## 贡献

欢迎提交 Issue 和 Pull Request。请保持项目的本地、极简、快速定位，不引入云服务、第三方 API 或不必要的依赖。

## 开源许可

本项目使用 [MIT License](LICENSE)。
