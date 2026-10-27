# Repository Guidelines

## Project Structure & Module Organization

TerminalLauncher is a macOS 27 desktop widget app that lists saved folders and opens a Terminal window when one is clicked. Folders are managed from the shell with the `tl` CLI (`tl .`, `tl ls`, `tl rm <n|path>`).

There are three targets defined in `project.yml` (XcodeGen):
- **`TerminalLauncher.app`** (`App/`): Unsandboxed background agent (no Dock icon, no window) that handles `tlaunch://` URLs and launches Terminal.
- **`PathsWidget`** (`Widget/`): Sandboxed WidgetKit extension containing timelines and SwiftUI views.
- **`tl`** (`CLI/main.swift`): Thin CLI entry point (deliberately calls `TL.main()` from inside an async function so Swift selects `AsyncParsableCommand.main()`).

Nearly all logic lives in the local Swift package `Packages/LauncherKit` so the Xcode targets stay thin:
- **`PathStore`** (`Packages/LauncherKit/Sources/PathStore/`): Model (`SavedPath`, `PathList`), JSON store (`PathStore`), `PathCanonicalizer`, `PathDisplay`, `FolderStatus`, `LaunchURL` parsing, `WidgetLayout` (`maxRows` = 10, used with `ViewThatFits`), and `OpenRequestHandler`. Used by the app, widget, and `TLCommands`.
- **`TLCommands`** (`Packages/LauncherKit/Sources/TLCommands/`): Argument parsing (`TL.swift` via `swift-argument-parser`, with `Add` as the default subcommand) and testable command logic (`Commands`). `Commands` takes all side effects as injected dependencies: store factory, `WidgetReloader`, folder-status check, cwd, home, and clock; `LiveDependencies.swift` wires the real ones.
- **Tests**: Matching test targets under `Packages/LauncherKit/Tests/` (`PathStoreTests/`, `TLCommandsTests/`).

Icons are in `App/Assets.xcassets/` (see `docs/app-icon.md`). Design decisions, the implementation plan, and the App Group spike findings are in `docs/superpowers/` (`specs/`, `plans/`, `spikes/`) — check the spec before changing behavior.

Edit `project.yml` for target configuration; never edit `TerminalLauncher.xcodeproj` directly, as it is generated and gitignored.

## Build, Test, and Development Commands

Use Xcode 27 (Swift 6.4), macOS 27+, and XcodeGen. Signed builds require an Apple ID configured in Xcode.

```bash
# Run all package tests from the repository root.
swift test --package-path Packages/LauncherKit
# Run one suite.
swift test --package-path Packages/LauncherKit --filter AddTests
# Run one test.
swift test --package-path Packages/LauncherKit --filter AddTests/addNewFolder
# Generate and build all targets without installing.
xcodegen generate
xcodebuild -project TerminalLauncher.xcodeproj -scheme TerminalLauncher \
  -configuration Debug -derivedDataPath build -allowProvisioningUpdates build
# Build Release, install, link tl, and launch the app.
scripts/install.sh
# View logs from the app and widget (use full path because `log` is a zsh builtin).
/usr/bin/log show --last 5m --predicate 'subsystem == "com.alex.TerminalLauncher"' --style compact
```

`scripts/install.sh` performs a Release build (stamping a fresh Unix-seconds `CURRENT_PROJECT_VERSION` so `chronod` refreshes widget descriptors), stops running `TerminalLauncher` and `PathsWidget` processes, installs to `~/Applications/TerminalLauncher.app`, deletes and unregisters `build/` copies from LaunchServices so `tlaunch://` URLs always reach the installed app, symlinks `~/.local/bin/tl` into the bundle, and launches the agent. Run `scripts/install.sh` after every change before testing the real widget or CLI.

For Xcode development, open the generated project. Widget previews live in `Widget/PathsWidgetView.swift`.

## Coding Style & Naming Conventions

Follow existing Swift style: four-space indentation, `UpperCamelCase` types, and `lowerCamelCase` methods and properties. Name files after their principal type. Keep platform targets thin; put testable behavior in `LauncherKit` and inject side effects through `Commands` dependencies. No formatter or linter is configured.

## Testing Guidelines

Use Swift Testing (`@Suite`, `@Test`, `#expect`). Name files `*Tests.swift`, suites by behavior, and methods descriptively, such as `addExistingMovesToTop`. Use temporary stores and fake dependencies. Cover changed behavior and error cases; no numeric coverage threshold is configured. Run the full package suite before submitting. For UI changes, install and check widget sizes, folder clicks, and refresh behavior manually.

## Commit & Pull Request Guidelines

Follow history: `feat:`, `fix:`, `docs:`, or `chore:`, with optional scopes such as `feat(widget):`. Use concise imperative subjects. PRs should describe behavior changes, link relevant issues, and record verification commands and results. Include screenshots for widget or icon changes.

## Architecture, Invariants & Signing Rules

### Architecture
- **`tl` is the only writer** of `paths.json` in the App Group container (`A5STTR22DU.com.alex.TerminalLauncher`). Each write is atomic. After a change, the CLI opens `tlaunch://reload` in the background without activating the app.
- **`TerminalLauncher.app`** handles two URLs:
  - `tlaunch://reload` calls `WidgetCenter.reloadAllTimelines()`.
  - `tlaunch://open?path=…` opens Terminal. `OpenRequestHandler` only opens a path that **exactly** matches a stored path, preventing untrusted callers (e.g., web pages) from opening Terminal at arbitrary locations via the URL scheme. Keep that check.
- **`PathsWidget`** reads `paths.json` and renders each row as a `tlaunch://open` link across `.systemSmall`, `.systemMedium`, and `.systemLarge`, refreshing every 30 minutes as a fallback.

### Invariants
- Stored paths are canonical: absolute and normalized as strings, with symlinks **not** resolved. `PathCanonicalizer` never touches the file system. For `tl .`, the cwd is the shell's logical `$PWD` (`logicalCwd`), so symlinked folders stay the way the user sees them.
- A file that can't be read or has an unsupported version is never overwritten. Commands report the error, and the widget shows an "unreadable" state.
- `paths.json` has a `version` field (currently `1`). `PathStore.load()` rejects any other version.
- Command names win over folder names in `tl`. A folder called `ls` must be written `tl ./ls`. In `tl rm`, an all-digit argument is always an item number.

### Signing Gotchas
- The team ID `A5STTR22DU` is hard-coded in `project.yml`, all three `.entitlements` files, and `PathStore.appGroupID`. Change all of them together.
- `tl` is signed with `--identifier com.alex.TerminalLauncher.tl` and embedded with `codeSign: false`, so Xcode doesn't re-sign it. Because the App Group ID starts with the team ID, the bare binary can carry the entitlement without a provisioning profile.
- After changing any signing setting, run `rm -rf build`. An incremental build fails with `"nested code is modified or invalid"`.
