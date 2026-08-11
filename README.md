# ScreenTextClip

[![Release](https://img.shields.io/github/v/release/jmwang028/ScreenTextClip-Releases?label=release)](https://github.com/jmwang028/ScreenTextClip-Releases/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-14%2B-black)](#system-requirements)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

ScreenTextClip is an open-source, native, local-first macOS menu bar tool for screen OCR and translation. Press `⌃⌘S`, select text anywhere on your screen, and the app will recognize it locally, copy the original text, and display the Apple Translation result next to your selection.

```text
Select text on screen → Apple Vision OCR → Copy original text → Apple Translation
```

- No third-party APIs
- No screenshot or text uploads
- No accounts, history, or cloud sync
- No third-party dependencies

## Download

### [Download ScreenTextClip-0.5.0.dmg](https://github.com/jmwang028/ScreenTextClip-Releases/releases/download/v0.5.0/ScreenTextClip-0.5.0.dmg)

- [v0.5.0 release notes](https://github.com/jmwang028/ScreenTextClip-Releases/releases/tag/v0.5.0)
- [v0.5.0 source snapshot](https://github.com/jmwang028/ScreenTextClip-Releases/releases/download/v0.5.0/ScreenTextClip-0.5.0-source.zip)
- DMG SHA-256: `8e51511fde64899cbed55ffb0b4e98f7bc1f0cd5f3efda9ba2ed801642bdf01b`

The installer is a Universal app for both Apple Silicon and Intel Macs. The current public build is locally signed but does not use an Apple Developer ID and is not notarized. On first launch, open **System Settings > Privacy & Security** and click **Open Anyway** if macOS blocks the app.

## Features

- Captures only the screen region selected by the user with ScreenCaptureKit.
- Uses one selection overlay per display and supports multi-display setups with Retina and different scaling factors.
- Runs Apple Vision OCR locally for English, Simplified Chinese, Traditional Chinese, Japanese, Korean, and mixed-language content.
- Keeps clear screenshots on the fast single-pass OCR path and retries once only for empty or clearly low-confidence results.
- Organizes reading order using text-box height, vertical overlap, and position, including straightforward two-column content.
- Preserves normal spaces between English words while avoiding unnecessary spaces in Chinese, Japanese, and Korean text.
- Automatically copies the recognized original text to the clipboard.
- Uses Apple Translation locally on macOS 15 or later and lets the system detect the source language for mixed-language text.
- Converts between Simplified and Traditional Chinese locally with macOS text conversion.
- Displays translation results in a movable popup with selectable text.
- Provides English and Simplified Chinese interfaces, language management, and launch-at-login controls from the menu bar.

## System Requirements

- macOS 14 or later for screen capture and OCR.
- macOS 15 or later for local Apple Translation.
- Screen Recording permission.
- The required Apple translation language packs.

Translation language packs can be managed in:

```text
System Settings > General > Language & Region > Translation Languages
```

## Installation

1. Download and open `ScreenTextClip-0.5.0.dmg`.
2. Drag `ScreenTextClip.app` into the Applications folder.
3. If macOS blocks the first launch, open **System Settings > Privacy & Security** and click **Open Anyway**.
4. Allow ScreenTextClip to use Screen Recording, then quit and reopen the app.

## Usage

1. Launch ScreenTextClip. It runs quietly in the menu bar without a Dock icon.
2. Press `Control + Command + S` (`⌃⌘S`) or click the OCR menu bar icon.
3. Drag to select a text region and release the pointer.
4. The recognized original text is copied to the clipboard, and the translation appears next to the selection.
5. Right-click or Control-click the menu bar icon to manage languages, the interface language, and launch-at-login behavior.

## Build from Source

Xcode 16 or later is required. The project has no Swift Package or third-party dependencies. Public source builds use ad-hoc signing by default and do not require a developer certificate.

```bash
git clone https://github.com/jmwang028/ScreenTextClip-Releases.git
cd ScreenTextClip-Releases
./script/build_and_run.sh --verify
```

You can also open `ScreenTextClip.xcodeproj` directly. Build outputs:

```text
dist/Debug/ScreenTextClip.app
dist/Release/ScreenTextClip.app
```

## Tests

```bash
xcodebuild test \
  -project ScreenTextClip.xcodeproj \
  -scheme ScreenTextClip \
  -destination 'platform=macOS' \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=-
```

The lightweight regression suite generates English, Simplified Chinese, Traditional Chinese, Japanese, Korean, mixed-language, small-text, dark-background, varied-font-size, paragraph, and two-column fixtures at runtime. Test resources are not included in the app bundle.

## Project Structure

```text
ScreenTextClip/
├── App/                  # App lifecycle, menu bar, shortcut, and main flow
├── Overlay/              # Multi-display selection overlays and translation popup
├── Services/             # Capture, OCR, translation, clipboard, and permissions
├── Assets/               # App icon
└── Info.plist
ScreenTextClipTests/       # OCR and text-organization regression tests
script/                    # Local build and launch scripts
```

## Privacy and Design Scope

- Screenshots and OCR are processed locally.
- Translation uses Apple Translation built into macOS.
- The app does not save screenshots, OCR results, or translation history.
- The app has no accounts, cloud sync, screenshot annotation, browser extension, or complex layout-recovery system.
- Available languages are limited to those supported by Apple Vision and Apple Translation.
- Translation quality for long or heavily mixed-language text depends on Apple's language models.

## Contributing

Issues and pull requests are welcome. Please preserve the project's local-first, minimal, and fast design, and avoid cloud services, third-party APIs, or unnecessary dependencies.

## License

This project is available under the [MIT License](LICENSE).
