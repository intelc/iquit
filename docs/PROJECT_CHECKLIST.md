# Project Checklist

This repo follows the practical parts of [amilajack/project-checklist](https://github.com/amilajack/project-checklist) for a small native app release.

## Initial Presentation

- README starts with the value proposition and the simplest install path.
- README describes the two main workflows before listing lower-level details.
- GitHub Releases carries a ready-to-run DMG.

## Value Proposition

- iQuit is positioned as a maintained, native, conservative alternative for reducing macOS window and background-app clutter.
- The distinctive feature is visible-window detection: apps with lingering windows can be hidden or quit separately from ordinary background idle quitting.

## Project Quality

- Cleanup decision logic is isolated in `iQuitCore`.
- Tests cover active-app ignoring, visible-window cleanup, and idle-background quit decisions.
- Release packaging is scripted with stable bundle signing and DMG creation.

## Branding and Onboarding

- The app has a memorable name, a simple moon icon motif, and distinct colors for the two cleanup systems.
- First launch includes native onboarding for Visible Windows, Idle Quit, protected apps, and Accessibility access.

## Infrastructure

- Build, launch, test, and package commands are documented.
- Local signing overrides are ignored through `Config/iQuit.local.xcconfig`.
- Generated build artifacts and local credentials are ignored.
