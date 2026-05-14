# Find window-closing app

- Session: `019e183c-c75e-73d2-8b5d-ac92b2a68327`
- Source: `live`
- Started: `2026-05-11T18:11:36.926Z`
- CWD: `[HOME]/codestuff/aiexperiments/mosspath-lite`
- Source file: `[HOME]/.codex/sessions/2026/05/11/rollout-2026-05-11T14-11-36-019e183c-c75e-73d2-8b5d-ac92b2a68327.jsonl`

## 1. User (2026-05-11T18:12:46.653Z)

on my mac i often have windows that im not using open, it can be very obvious like a microsoft word that's open on create new doc page. they take up my attention and clutter my windows. is there any app/github repo that address this issue buy somehow detecting and close them?

## 2. Assistant (2026-05-11T18:12:50.041Z)

I’ll take a quick look for current macOS tools and repos in this niche, then I’ll separate “already exists” from “probably needs a small custom automation.”

## 3. Assistant (2026-05-11T18:13:40.369Z)

Yes. The closest match is **[MagicQuit](https://magicquit.com/)**. It is free, open source, offline, and automatically quits apps you have not used for a configurable time. It also avoids force-quitting, so if an app has unsaved work it should prompt rather than silently destroying it. It supports macOS 13+.

Other related options:

- **[Swift Quit](https://github.com/onebadidea/swiftquit)**: quits apps when you close their last window. Good for “red X should really quit,” less good for “detect random unused window.”
- **[Quitty](https://github.com/iad1tya/Quitty)**: newer open-source quit/cleanup utility, but I’d treat it as less proven.
- **[Quitter](https://www.macobserver.com/tips/automatically-quit-apps/)**: older/simple tool that hides or quits chosen apps after inactivity.
- **[Hammerspoon](https://www.hammerspoon.org/docs/hs.window.html)**: best if you want rule-based detection, e.g. “close Microsoft Word windows whose title is `Document1` after 20 minutes.” It can inspect visible windows and close matching ones via `hs.window:close()`.

My read: **install MagicQuit first**. If your annoyance is specifically “empty starter windows like Word’s new document screen,” that probably wants a tiny Hammerspoon rule, because general apps avoid guessing which windows are safe to close. That’s the right kind of automation: conservative whitelist, never broad auto-close.

## 4. User (2026-05-11T18:23:53.544Z)

is magicquit still up to date/ being maintained? what's the last update for each of these repos, also list stars

## 5. Assistant (2026-05-11T18:24:10.094Z)

I’ll verify this against GitHub directly, because stars and activity dates drift and “maintained” is exactly the kind of thing that goes stale fast. I’ll treat “last update” as latest code push unless noted otherwise.

## 6. Assistant (2026-05-11T18:24:20.259Z)

A small wrinkle already: MagicQuit’s website says “Download MagicQuit 1.4,” but its GitHub repo has no GitHub Releases object, so I’m checking tags/commits too instead of relying on the release endpoint alone.

## 7. Assistant (2026-05-11T18:24:48.831Z)

I checked GitHub on **May 11, 2026**. Short version: **MagicQuit is not abandoned, but it does not look actively maintained on `main`**.

| Tool | Repo | Stars | Last code activity | Maintenance read |
|---|---:|---:|---|---|
| MagicQuit | [BigBerny/magicquit](https://github.com/BigBerny/magicquit) | 337 | `main`: Dec 21, 2023; other branch: Jun 22, 2025 | Usable, not archived, but not very active. No GitHub releases/tags. |
| Swift Quit | [onebadidea/swiftquit](https://github.com/onebadidea/swiftquit) | 517 | Jan 29, 2026 | More recent repo activity, but latest release is old: v1.5 on Mar 13, 2023. |
| Quitty, newer/lightweight one | [chentao1006/Quitty](https://github.com/chentao1006/Quitty) | 46 | May 11, 2026 | Actively maintained right now, but very new/small. |
| Quitty, “all-in-one utility” one | [iad1tya/Quitty](https://github.com/iad1tya/Quitty) | 147 | Apr 20, 2026 | **Archived**, so I would not pick this. |
| Hammerspoon | [Hammerspoon/hammerspoon](https://github.com/Hammerspoon/hammerspoon) | 15,396 | Feb 26, 2026 | Mature and maintained, best for custom rules/scripts. |

For your actual use case, I’d revise my recommendation slightly: **MagicQuit is still probably fine to try**, but if you want something maintained *right now*, I’d look harder at **chentao1006/Quitty** for “quit after last window closes,” or **Hammerspoon** for a custom “close obvious junk windows like Word’s blank start/new doc window” rule. MagicQuit’s repo activity feels a little sleepy.

## 8. User (2026-05-11T22:11:52.497Z)

swift quit and quitty both focus on quitty after last window is closed. quitty archived, i think magic quit is closed to what i what.

## 9. Assistant (2026-05-11T22:11:59.469Z)

Yeah, I agree with that read. **MagicQuit is the closest off-the-shelf match** for “apps/windows I am not using should get out of my attention field,” because it’s inactivity-based rather than “last window closed”-based.

The catch is that MagicQuit seems to work at the **app level**, not the “this specific Word start window is useless” level. So it can help with whole unused apps, but it probably won’t reliably distinguish:

- Word open on a blank/new-doc screen
- Preview sitting on an old PDF
- Settings window forgotten in the background
- A real app with unsaved work you actually care about

For your exact pain, I’d think of it as two layers:

1. **Use MagicQuit for broad cleanup**: quit apps you haven’t touched after N minutes.
2. **Use Hammerspoon for narrow “obvious clutter” rules**: close or hide specific windows with known titles/classes, like Word’s start/new document window, maybe only after they’ve been unfocused for a while.

That combination feels safer than trying to find one app that guesses intent globally. MagicQuit can reduce general background app clutter; Hammerspoon can target the “this window is obviously just visual noise” cases.

## 10. User (2026-05-11T22:15:13.372Z)

rent magic quit code, any updates we can make/ given new mac os releases or new features we may be able to add with apple intelligence?

## 11. Assistant (2026-05-11T22:15:23.973Z)

I’ll read the MagicQuit repo itself and treat this as a product/code review: what it currently does, where macOS has moved since, and which upgrades would be realistic versus wishful Apple Intelligence frosting.

## 12. Assistant (2026-05-11T22:15:29.503Z)

The repo is small and old-school Xcode project shaped, not a Swift Package. I’m going through the app entry points and permission/window-management code now.

## 13. Assistant (2026-05-11T22:15:56.691Z)

There’s also a `feature-autoclose` branch in the repo from 2025, which is interestingly close to your “close obvious clutter windows” idea. I’m checking whether it contains anything useful or just an abandoned experiment.

## 14. Assistant (2026-05-11T22:16:44.211Z)

I read the MagicQuit code. Yes: it is a good base, but it is very simple right now.

Current MagicQuit is basically:

- watch running apps with `NSWorkspace`
- remember when an app was last deactivated
- after `hoursUntilClose`, call `NSRunningApplication.terminate()`
- expose per-app toggles in the menu bar
- no real window inspection, despite the name/idea

The most useful updates I’d make:

1. **Use bundle IDs instead of app names**
   Current settings are keyed by `localizedName`, which can collide or change. Use `bundleIdentifier`, with display name only for UI.

2. **Add per-app idle durations**
   Word might be 30 minutes, Xcode 8 hours, Messages never. This is probably the highest value low-risk feature.

3. **Add actions: hide, quit, close windows**
   Not every cleanup should quit the app. A “hide after idle” mode would be much safer for attention clutter.

4. **Add Accessibility-based window rules**
   This is the big one for your use case. With macOS Accessibility APIs, MagicQuit could inspect app windows by title/role/subrole and close or hide only known junk windows, e.g. `Microsoft Word` + `Document1` + no edited state + idle for 15 minutes.

5. **Add a “review before cleanup” notification**
   Instead of immediately quitting, show “MagicQuit will hide/quit Word in 60s” with Skip, Always allow, Never for this app.

6. **Add a learning mode**
   “I manually closed this kind of window three times; suggest an auto-rule.” That would feel much closer to your actual problem than a global idle timer.

There is also an abandoned-looking `feature-autoclose` branch in the repo that adds Accessibility monitoring for “quit app when last window closes.” That overlaps more with Swift Quit than your goal, and the patch looks rough, but it proves the repo owner was at least experimenting in the right API area.

On **Apple Intelligence**: yes, there is a plausible new direction. Apple’s **Foundation Models framework** is available on macOS 26 for Apple Intelligence-compatible Macs, runs on-device/offline, and supports structured output. That could classify window/app metadata into decisions like:

```text
safe_to_hide
safe_to_quit
ask_user
never_touch
```

But I would not let AI directly close windows. The solid design is: deterministic rules first, Apple Intelligence only as a local suggestion/classifier, and user approval for any new rule. Apple’s [Foundation Models](https://developer.apple.com/documentation/FoundationModels) and [App Intents](https://developer.apple.com/documentation/appintents) docs are the relevant modern pieces here.

My take: MagicQuit is forkable, and the best fork would become **“attention clutter cleanup”**, not just “auto quit idle apps.” The killer feature is conservative, whitelist-based window cleanup.
