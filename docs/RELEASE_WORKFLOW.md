# Release Workflow

iQuit uses Sparkle 2 for in-app updates and GitHub Releases for hosting release
artifacts. The installed app checks
`https://github.com/intelc/iquit/releases/latest/download/appcast.xml`,
downloads the matching DMG from GitHub Releases, verifies the Sparkle EdDSA
signature, and lets Sparkle install the update quietly when the app quits.

## User Experience

- Automatic update checks are enabled by default.
- Updates are downloaded and installed in the background when possible.
- If the app has not quit for a week after an update is ready, Sparkle may show
  its standard install prompt.
- Users can still run a manual check from **Check for Updates...** in the app
  menu or iQuit window.

## One-Time Setup

1. Generate Sparkle keys:

   ```sh
   swift build --product iQuit
   .build/artifacts/sparkle/Sparkle/bin/generate_keys
   .build/artifacts/sparkle/Sparkle/bin/generate_keys -x sparkle-private-key.txt
   ```

2. Keep `sparkle-private-key.txt` local and private. It is ignored by git.

3. Configure local Apple notarization once, using
   `Config/iQuit.local.xcconfig` and `notarytool` credentials as described in
   the README.

No Apple signing or notarization secrets are required in GitHub.

## Release Steps

1. Add a new `CHANGELOG.md` section named exactly like the version:

   ```md
   ## 0.1.6

   - Release note.
   ```

2. Commit the release changes.

3. Run the local release script:

   ```sh
   ./Scripts/release-local.sh 0.1.6
   ```

   The script:

   - requires a clean working tree
   - pushes the current branch
   - creates and pushes `v<version>` if needed
   - builds `iQuit.app`
   - embeds and signs `Sparkle.framework`
   - builds `iQuit.dmg`
   - notarizes and staples the DMG locally
   - generates signed Sparkle `appcast.xml`
   - creates or updates the GitHub release
   - uploads `iQuit.dmg`, `iQuit-<version>.dmg`, and `appcast.xml`

4. Verify the appcast:

   ```sh
   curl -fsSL https://github.com/intelc/iquit/releases/latest/download/appcast.xml
   ```

   Then install the previous public version and choose **Check for Updates...**.

## Local Dry Run

For a local signed build with Sparkle enabled, set these in
`Config/iQuit.local.xcconfig`:

```xcconfig
DEVELOPMENT_TEAM = YOUR_TEAM_ID
IQUIT_BUNDLE_IDENTIFIER = com.yourname.iquit
IQUIT_VERSION = 0.1.6
IQUIT_BUILD_NUMBER = 1006
IQUIT_APPCAST_URL = https://github.com/intelc/iquit/releases/latest/download/appcast.xml
SPARKLE_PUBLIC_ED_KEY = public-key-from-generate_keys
CODE_SIGN_IDENTITY = Developer ID Application: Your Name (YOUR_TEAM_ID)
NOTARY_KEYCHAIN_PROFILE = iquit-notary
```

Then run:

```sh
./Scripts/build-dmg.sh
./Scripts/notarize-dmg.sh
./Scripts/generate-appcast.sh
```

For actual releases, prefer `./Scripts/release-local.sh <version>` so the tag,
release assets, and appcast stay in sync.
