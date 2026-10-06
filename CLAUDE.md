# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal macOS 27 desktop widget that lists saved folders. Clicking one opens a Terminal window there. Folders are added from the shell with the `tl` CLI (`tl .`, `tl ls`, `tl rm <n|path>`). There are three targets: the host app, the widget extension and the CLI. They are defined in `project.yml` (XcodeGen). `TerminalLauncher.xcodeproj` is generated and gitignored, so edit `project.yml` and never edit the project file.

## Commands

All logic lives in the local Swift package, and its tests use Swift Testing (`@Suite` / `@Test`):

```bash
cd Packages/LauncherKit && swift test
cd Packages/LauncherKit && swift test --filter AddTests                # one suite
cd Packages/LauncherKit && swift test --filter AddTests/addNewFolder   # one test
```

Build the full app (needs `xcodegen` and an Apple ID signed in to Xcode):

```bash
xcodegen generate && xcodebuild -project TerminalLauncher.xcodeproj -scheme TerminalLauncher -configuration Debug -derivedDataPath build -allowProvisioningUpdates build
```

`scripts/install.sh` does a Release build and installs it to `~/Applications/TerminalLauncher.app`. It also deletes the copies in `build/` and unregisters them from LaunchServices, so `tlaunch://` URLs always reach the installed app. Finally it symlinks `~/.local/bin/tl` into the bundle. Run it again after every change before testing the real widget or CLI.

Logs from the app and widget (use the full path, because `log` is a zsh builtin):

```bash
/usr/bin/log show --last 5m --predicate 'subsystem == "com.alex.TerminalLauncher"' --style compact
```

## Architecture

- **`tl` is the only writer** of `paths.json` in the App Group container (`A5STTR22DU.com.alex.TerminalLauncher`). Each write is atomic. After a change, the CLI opens `tlaunch://reload` in the background without activating the app.
- **TerminalLauncher.app** (`App/`) is an unsandboxed background agent. It has no Dock icon and no window. It handles two URLs:
  - `tlaunch://reload` calls `WidgetCenter.reloadAllTimelines()`.
  - `tlaunch://open?path=…` opens Terminal. `OpenRequestHandler` only opens a path that **exactly** matches a stored path, so a web page can't open Terminal wherever it likes through the URL scheme. Keep that check.
- **PathsWidget** (`Widget/`) is the sandboxed WidgetKit extension. It reads `paths.json` and renders each row as a `tlaunch://open` link. It refreshes every 30 minutes as a fallback.
- **`Packages/LauncherKit`** holds nearly all the logic, so the Xcode targets stay thin:
  - `PathStore`: the model (`SavedPath`), the JSON store, `PathCanonicalizer`, `PathDisplay`, `LaunchURL` parsing, `WidgetLayout` capacities (large 10, medium 4) and `OpenRequestHandler`. The app, the widget and TLCommands all use it.
  - `TLCommands`: argument parsing (`TL.swift`, swift-argument-parser, with `Add` as the default subcommand) and `Commands`, the testable logic. `Commands` takes all side effects as injected dependencies: store factory, `WidgetReloader`, folder-status check, cwd, home and clock. `LiveDependencies.swift` wires the real ones. New behavior should follow this pattern: inject dependencies and test them through `Commands`.
  - `CLI/main.swift` only calls `TL.main()` from inside an async function. This is deliberate (see the comment there).

### Invariants

- Stored paths are canonical: absolute and normalized as strings, with symlinks **not** resolved. `PathCanonicalizer` never touches the file system. For `tl .`, the cwd is the shell's logical `$PWD` (`logicalCwd`), so symlinked folders stay the way the user sees them.
- A file that can't be read or has an unsupported version is never overwritten. Commands report the error, and the widget shows an "unreadable" state.
- `paths.json` has a `version` field (currently 1). `PathStore.load()` rejects any other version.
- Command names win over folder names in `tl`. A folder called `ls` must be written `tl ./ls`. In `tl rm`, an all-digit argument is always an item number.

## Signing gotchas

- The team ID `A5STTR22DU` is hard-coded in `project.yml`, all three `.entitlements` files and `PathStore.appGroupID`. Change all of them together.
- `tl` is signed with `--identifier com.alex.TerminalLauncher.tl` and embedded with `codeSign: false`, so Xcode doesn't re-sign it. Because the App Group ID starts with the team ID, the bare binary can carry the entitlement without a provisioning profile.
- After changing any signing setting, run `rm -rf build`. An incremental build fails with "nested code is modified or invalid".

## Docs

Design decisions, the implementation plan and the App Group spike findings are in `docs/superpowers/` (`specs/`, `plans/`, `spikes/`). Check the spec before changing behavior.
