# iQuit

iQuit is a small, open-source macOS menu bar app that clears attention clutter by hiding or gracefully quitting apps after they have been idle for a while.

The idea came from wanting a maintained, native alternative to MagicQuit: conservative by default, friendly to configure, and focused on "this app is just sitting here taking space in my head."

## Download

Download the latest `iQuit.dmg` from GitHub Releases, drag `iQuit.app` into Applications, and launch it from there.

The first launch explains the two cleanup systems and offers to enable Accessibility access. Accessibility access is optional, but it lets iQuit minimize individual windows instead of hiding an entire app.

## Features

- Native SwiftUI menu bar app for macOS 14+
- Tracks foreground app usage with `NSWorkspace`
- Detects visible app windows with CoreGraphics
- Uses bundle identifiers for stable per-app rules
- Visible-window cleanup: asks whether to hide or quit after 20 minutes by default
- Background idle cleanup: asks whether to quit after 1 hour by default
- Protected apps
- Floating custom review prompt with a 30-second timeout
- 10-minute cooldown after ignored or skipped prompts
- Accessibility-backed per-window minimize when Window access is granted
- Graceful quit via `NSRunningApplication.terminate()`
- First-run onboarding for permissions and the two cleanup systems

## Safety Model

iQuit does not force quit apps. A quit request is the same polite system-level quit apps normally receive, so apps with unsaved work can still show their own prompts.

iQuit asks before cleanup by default. If you ignore, skip, or time out a prompt, that app enters a short cooldown so it will not immediately ask again. Protected apps are never hidden or quit automatically.

## How It Works

- **Visible Windows**: if an inactive app still has visible windows after 20 minutes, iQuit asks whether to Hide or Quit.
- **Idle Quit**: if a background app stays idle after 1 hour, iQuit asks whether to Quit.
- **Never**: turn off Idle Quit per app for apps that should stay running.
- **Protect**: use the lock button or prompt hand button to ignore an app completely.

## Run From Source

```sh
swift run iQuit
```

For permission-sensitive testing, prefer the signed bundle flow below. macOS privacy grants attach to the app bundle identity, so repeatedly launching raw command-line binaries is less stable for TCC.

## Stable Signed Bundle

```sh
cp Config/iQuit.local.xcconfig.example Config/iQuit.local.xcconfig
./Scripts/launch_bundle.sh
```

Edit `Config/iQuit.local.xcconfig` if you want a different stable bundle identifier. The default local signing path uses ad-hoc signing (`CODE_SIGN_IDENTITY = -`) and launches the same `.build/iQuit.app` bundle path each time, mirroring Mosspath Lite's source-build TCC flow.

## Build a DMG

```sh
./Scripts/build-dmg.sh
```

The packaged disk image is written to `.build/iQuit.dmg`.

## Notarized Release

Developer ID signing and notarization use ignored local config plus a keychain profile, so Apple credentials are never committed.

Create `Config/iQuit.local.xcconfig`:

```xcconfig
DEVELOPMENT_TEAM = YOUR_TEAM_ID
IQUIT_BUNDLE_IDENTIFIER = com.yourname.iquit
CODE_SIGN_IDENTITY = Developer ID Application: Your Name (YOUR_TEAM_ID)
NOTARY_KEYCHAIN_PROFILE = iquit-notary
```

Store notarization credentials in the macOS keychain:

```sh
xcrun notarytool store-credentials iquit-notary --team-id YOUR_TEAM_ID
```

Then build, submit, and staple:

```sh
./Scripts/build-dmg.sh
./Scripts/notarize-dmg.sh
```

## Roadmap

- Launch at login
- Import and export rules
- Accessibility-powered window rules for known clutter windows
- Learning mode for repeated manual cleanup
- Optional local classification on Apple Intelligence-compatible Macs, used only to suggest rules

## License

MIT
