# Security and Privacy

iQuit is local-only. It does not send app names, bundle identifiers, window state, or settings to any server.

## Permissions

iQuit can run without Accessibility access. When Accessibility access is granted, iQuit uses it to minimize individual windows for the Hide action. Without that permission, Hide falls back to hiding the whole app.

## Cleanup Behavior

iQuit requests graceful termination through macOS. It does not force quit apps, and apps with unsaved work may still show their own prompts.

## Reporting Issues

Please open a GitHub issue with:

- macOS version
- iQuit version
- whether Accessibility access was enabled
- the affected app name and bundle identifier, if relevant

Do not include private document names, screenshots with sensitive content, or logs that contain personal data.
