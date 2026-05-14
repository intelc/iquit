# Changelog

## 0.1.6

- Added Sparkle-powered in-app updates with quiet background checks and manual Check for Updates controls.
- Added a local release script that builds, notarizes, signs the appcast, and publishes GitHub release assets.

## 0.1.5

- Added live idle duration text to cleanup prompts.
- Added a hoverable Open affordance on prompt app icons to bring the app forward without dismissing the prompt.

## 0.1.4

- Polished the floating prompt into a tighter two-row rounded card.
- Smoothed the prompt countdown bar animation.
- Fixed inline minute editing so only the number is editable and the unit stays visible.
- Documented the sanitized Codex prompt export.

## 0.1.3

- Refreshed README screenshots for the current menu, dashboard, and prompt UI.
- Reduced stale settings/dead code while keeping migrations for older saved settings.
- Improved dev launch safety around mounted DMGs and TCC registration.
- Added adaptive cleanup evaluation to reduce unnecessary polling.

## 0.1.2

- Replaced the hand-drawn icon generator with a generated source icon used for Finder, DMG, and system display.
- Added a rounded README logo card that uses the same app icon artwork.

## 0.1.1

- Added a generated minimal app icon for Finder, DMG, and system display.

## 0.1.0

- Added native macOS menu bar app for monitoring unused apps.
- Added visible-window cleanup prompts with Hide or Quit actions.
- Added idle background app cleanup prompts with Quit actions.
- Added per-app protection, Never for idle quit, prompt cooldown, and prompt queueing.
- Added optional Accessibility-backed per-window minimization.
- Added first-run onboarding.
- Added signed bundle and DMG build scripts.
