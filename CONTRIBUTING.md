# Contributing

Thanks for helping improve iQuit.

## Local Setup

```sh
swift test
swift run iQuit
```

For permission-sensitive development, use the stable signed bundle:

```sh
./Scripts/launch_bundle.sh
```

macOS privacy grants attach to the app bundle identity, so the signed bundle path gives more predictable Accessibility behavior than repeatedly launching raw command-line builds.

## Release Build

```sh
./Scripts/build-dmg.sh
```

The app bundle is written to `.build/iQuit.app`; the disk image is written to `.build/iQuit.dmg`.

For notarized releases, iQuit follows Mosspath's release shape: Developer ID signing with hardened runtime, signed DMG, `notarytool`, stapling, and Gatekeeper validation. Put Developer ID and notary profile settings in ignored `Config/iQuit.local.xcconfig`, store credentials with `xcrun notarytool store-credentials`, then run:

```sh
./Scripts/notarize-dmg.sh
```

## Code Notes

- Keep cleanup decisions in `iQuitCore` where they can be tested without AppKit.
- Keep macOS permission and window-management code isolated in the app target.
- Prefer conservative defaults: prompt first, never force quit, and make protection easy.
- Run `Scripts/scan-secrets.sh` before release commits to catch local Apple signing values, private keys, tokens, and machine-specific paths.
