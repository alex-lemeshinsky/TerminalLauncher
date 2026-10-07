# TerminalLauncher — Design

Date: 2026-10-05
Status: Approved in conversation, pending written-spec review

## 1. Goal

A macOS desktop widget that lists folders I work in. Clicking a folder opens
Terminal already `cd`'d into it. Folders are added from the shell: inside any
folder, `tl .` adds it to the widget.

**Success looks like:**
- `tl .` makes the folder appear in the widget within about 2 seconds.
- One click on a row opens a new Terminal window in that folder.

### What was asked for vs. what was decided

| Asked for | Decided in conversation |
|---|---|
| A widget on the macOS desktop | A real WidgetKit widget, not a floating panel |
| A list of paths | About 10 or fewer, newest first |
| Click opens "the default terminal" at the path | Terminal.app, a new window per click (macOS has no "default terminal" setting, and Terminal.app is the only terminal installed) |
| `mytool .` adds the current folder | The CLI is named `tl`. Folders are added and removed only through the CLI. |
| — | Personal use on this Mac only: no App Store, no distribution |

### Non-goals

- Other terminals (iTerm, Ghostty, …), or opening tabs instead of windows
- Reordering, groups, pinning, usage-based sorting
- Managing the list from the widget or from an app window
- A small widget size, or per-widget configuration
- Sync between Macs, or distribution and notarization

## 2. Stack

- Swift 6.4, Swift 6 language mode, deployment target macOS 27.0
- SwiftUI and WidgetKit for the widget
- AppKit for the host app (`NSApplicationDelegate`; no SwiftUI scenes are needed)
- Swift Argument Parser (latest 1.x, via Swift Package Manager) for the CLI
- Swift Testing (`@Test`) for unit tests
- XcodeGen (`project.yml`) to generate the Xcode project; the `.xcodeproj` is not committed
- Signing: the existing "Apple Development" identity, team `A5STTR22DU`

## 3. Architecture

```
tl add .  ──writes──▶  App Group container: paths.json  ◀──reads──  PathsWidget
   │                                  ▲                               │
   │                                  │ reads (membership check)      │ click: Link
   └── tlaunch://reload (bg) ──▶    TerminalLauncher.app  ◀── tlaunch://open?path=…
                                       │        │
              WidgetCenter.reloadAllTimelines()  NSWorkspace.open(folder, with: Terminal.app)
```

### Identifiers

| Thing | Value |
|---|---|
| App Group | `A5STTR22DU.com.alex.TerminalLauncher` (team-prefixed, so the CLI needs no provisioning profile) |
| App bundle ID | `com.alex.TerminalLauncher` |
| Widget bundle ID | `com.alex.TerminalLauncher.PathsWidget` |
| CLI signing identifier | `com.alex.TerminalLauncher.tl` |
| URL scheme | `tlaunch` |
| Data file | `~/Library/Group Containers/A5STTR22DU.com.alex.TerminalLauncher/paths.json` |

### Units

**`LauncherKit`** is a local Swift package with two library modules.

*`PathStore`* depends on Foundation only. Every other part imports it.
- `SavedPath` / `PathList`: the model.
- `PathStore`: load and save `paths.json`. It is created with the folder that
  holds the file, so tests can pass a temp directory.
- Canonicalization: turn a path into an absolute, standardized one, resolved
  against a given working directory.
- Display formatting: abbreviate the home folder to `~`, split a path into its
  folder name and parent folder.
- `LaunchURL`: build and parse `tlaunch://` URLs. The widget builds them and the
  app parses them, so both directions live in one place.

*`TLCommands`* depends on `PathStore` and ArgumentParser. It holds the `tl`
commands and their logic. The store, the widget reloader and the output streams
are injected, so tests never touch the real App Group or the app.

**`TerminalLauncher.app`** (host app)
- `LSUIElement = YES`: no Dock icon, no menu bar item, no windows.
- Not sandboxed. It has the App Group entitlement.
- Handles `tlaunch://open?path=…` and `tlaunch://reload` (see section 6).
- Opening Terminal sits behind a small `TerminalOpener` protocol so the router
  logic can be tested with a fake.
- After its first launch it keeps running, so later clicks are fast.

**`PathsWidget`** (widget extension)
- Sandboxed, as all widget extensions are. It has the App Group entitlement.
- Reads `paths.json` and draws the list (see section 5).

**`tl`** (CLI executable)
- A thin entry point that calls `TLCommands`.
- Built into `TerminalLauncher.app/Contents/MacOS/tl`, signed with the same team
  and the App Group entitlement.
- Installed as the symlink `~/.local/bin/tl`, which points into the app bundle,
  so rebuilding the app also updates the CLI.

### Writers and readers

- Only the CLI writes `paths.json`.
- The app and the widget only read it.
- Every write is atomic (write to a temp file, then rename). No locking is used,
  and if two `tl` commands run at the same moment, the last write wins.

## 4. Data format and CLI

### `paths.json`

```json
{
  "version": 1,
  "items": [
    { "path": "/Users/alex/Documents", "addedAt": "2026-10-05T11:02:00Z" }
  ]
}
```

- The order of `items` is the display order, newest first.
- `path` is absolute and standardized: `.`, `..`, repeated `/` and a trailing
  `/` are removed.
- Symlinks are **not** resolved, so the path is stored the way you see it.
- `addedAt` is an ISO 8601 date and is informational only.
- The file is missing on first run. That counts as an empty list.
- If the file can't be parsed, or `version` is not `1`, that is an error (see
  section 7). The file is never overwritten in that case.

### Commands

`add` is the default command, so `tl <path>` means `tl add <path>`.

| Command | Behavior |
|---|---|
| `tl add <path>` | Resolve `<path>` against the current folder and canonicalize it. If it doesn't exist or isn't a folder, print an error and exit with status 1. If it's already in the list, move it to the top, update `addedAt`, and print `~/X already saved, moved to top`. Otherwise insert it at the top and print `Added ~/X`. |
| `tl rm <n>` | `<n>` is made only of digits, so it's the 1-based number from `tl ls`. Remove that item and print `Removed ~/X`. A number out of range is an error (status 1). |
| `tl rm <path>` | Canonicalize the same way as `add` and remove the exact match. If there is no match, it's an error (status 1). |
| `tl ls` | Print the numbered list with `~` abbreviation, adding `(missing)` after folders that no longer exist. With an empty list, print `No folders yet. Run "tl ." in a folder.` |
| `tl` (no arguments) | Print the usage and exit with ArgumentParser's usage-error status (64). |

- Command names win over paths: to add a folder named `ls`, `rm` or `3`, write
  `tl ./ls`.
- When an `add` makes the list longer than 10 items, also print:
  `Note: the widget shows up to 10 folders; N are hidden.`
  N is the same number as the large widget's `+N more` row (section 5), so
  with 11 items N is 2.
- After every successful `add` or `rm`, run the widget reload: open
  `tlaunch://reload` with `NSWorkspace`, without bringing the app to the front
  (`activates = false`). If that fails, print this warning to stderr and still
  exit with status 0:
  `Saved, but couldn't reach TerminalLauncher.app; the widget will update within 30 minutes.`
- Errors go to stderr. Normal output goes to stdout.

## 5. Widget

- Families: `.systemMedium` and `.systemLarge`. `StaticConfiguration`, with no
  per-widget settings.
- Capacity: each size shows as many rows as fit its height, up to 10
  (`ViewThatFits` tries 10 rows, then 9, and so on). If there are more items
  than that, the last row becomes **`+N more · tl ls`**, so the large size
  shows 9 items plus that row, and the medium size as many as fit plus it.
- Each row is one SwiftUI `Link` to `tlaunch://open?path=<percent-encoded>`.
  It contains:
  - the SF Symbol `folder`,
  - the folder name (last path component) in semibold,
  - the parent folder with `~` abbreviation in a secondary color, shortened in
    the middle if it doesn't fit.
- Empty state: the text **No folders yet: run `tl .` in a folder**.
- Read error: a single row, **Couldn't read list · run `tl ls`**.
- Uses primary and secondary foreground styles only, so the widget stays
  readable in the desktop's dimmed/vibrant mode and in tinted modes.
- The widget does **not** check whether folders exist. A sandboxed extension
  can't see arbitrary paths, so the app checks on click.
- Timeline: one entry with the policy `.after(now + 30 minutes)`. That is a
  safety net; normal updates come from `tlaunch://reload`.

## 6. Click flow and URL handling

`URLRouter`, a pure function, turns a URL into one of three actions:

- `tlaunch://open?path=<p>` → `.open(p)`
- `tlaunch://reload` → `.reload`
- anything else → `.invalid`

The app then handles each action:

- **`.reload`:** call `WidgetCenter.shared.reloadAllTimelines()`.
- **`.open(p)`:**
  1. Load `paths.json`. If `p` isn't in it, ignore the request and log a line.
     This stops any web page or app from using a `tlaunch://` link to open
     Terminal windows at arbitrary paths.
  2. If `p` no longer exists or isn't a folder, show an alert:
     *"~/X no longer exists. Remove it with tl rm '~/X'."* The path in the
     command is wrapped in single quotes, with each `'` inside it written as
     `'\''`, so it can be pasted into a shell as-is.
  3. Otherwise, find Terminal with
     `NSWorkspace.urlForApplication(withBundleIdentifier: "com.apple.Terminal")`
     and call `NSWorkspace.open([folderURL], withApplicationAt:
     terminalURL, configuration:)`. Terminal opens a new window in the
     folder and comes to the front.
  4. If opening fails, show an alert with the error.
- **`.invalid`:** ignore it and log a line.

The first click after login takes about half a second because the app has to
start. After that the app is already running and clicks feel instant.

## 7. Error handling

| Situation | CLI | Widget | App |
|---|---|---|---|
| `paths.json` missing | Empty list | Empty state | Treats every `open` as not in the list |
| `paths.json` corrupt or unknown version | Prints the file path and the parse error to stderr, exits 1, never writes | Read-error row | Logs the error and ignores the `open` |
| App Group container not reachable | Error naming the container path, exit 1 | Read-error row | Logs the error |
| Invalid `add` or `rm` argument | Error message, exit 1 | — | — |
| Clicked folder was deleted | — | — | Alert telling you to run `tl rm` |
| Malformed URL, or a path not in the list | — | — | Ignored and logged |
| Terminal fails to open | — | — | Alert with the error |

The app and the widget log through `os.Logger` with the subsystem
`com.alex.TerminalLauncher` (categories `app` and `widget`), which you can read
in Console.app.

## 8. Testing

Write tests first for all logic in `LauncherKit`, and run them with `swift test`
inside the package.

- **`PathStore`:**
  - canonicalizing: relative paths, `.`, `..`, trailing `/`, `~`-style display
  - adding a new path and adding an existing one (moves it to the top)
  - `rm` by number and by path, including out of range and no match
  - JSON round-trip
  - a missing file, a corrupt file, an unknown version
- **`LaunchURL` / `URLRouter`:**
  - build → parse round-trip, including spaces and non-ASCII characters in paths
  - rejecting other schemes, unknown hosts and a missing `path`
- **`TLCommands`:** use an in-memory store and a fake reloader. Check stdout,
  stderr and exit codes for every command in section 4, including the warning
  when the reload fails and the over-10 note.
- **App open handling:** use a fake `TerminalOpener` and a temp store. Check that
  a path not in the list doesn't open, a missing folder produces the alert, and a
  valid path calls the opener.
- **Widget:** SwiftUI `#Preview`s with 0, 3 and 12 items, plus the read-error
  state, in both sizes.

**Manual end-to-end checklist** (run after `scripts/install.sh`):

1. `cd ~/Documents && tl .` → `~/Documents` appears in the widget within about 2 seconds.
2. Click the row → a new Terminal window opens with `pwd` = `~/Documents`.
3. `tl ls` shows it, `tl rm 1` removes it, and the widget updates.
4. Add a temp folder, delete it, then click its row → the alert appears.
5. `open "tlaunch://open?path=/"` → nothing happens (`/` isn't in the list).
6. Add 12 folders → the large widget shows 9 rows plus `+3 more · tl ls`.

## 9. Build and install

- `project.yml` (XcodeGen) defines three targets:
  - the app `TerminalLauncher`
  - the widget extension `PathsWidget`, embedded in the app
  - the command-line tool `tl`, copied into `Contents/MacOS` of the app with a
    Copy Files build phase

  It also references the local package `LauncherKit` and Swift Argument
  Parser.
- `scripts/install.sh`:
  1. `xcodegen generate`
  2. `xcodebuild -scheme TerminalLauncher -configuration Release` build
  3. Copy the built app to `~/Applications/TerminalLauncher.app`, replacing any
     old copy.
  4. `ln -sf ~/Applications/TerminalLauncher.app/Contents/MacOS/tl ~/.local/bin/tl`
  5. `open ~/Applications/TerminalLauncher.app` once, so macOS registers the URL
     scheme and the widget.
- Adding the widget is manual: right-click the desktop → **Edit Widgets** →
  TerminalLauncher.

### Repository layout

```
TerminalLauncher/
  project.yml
  Packages/LauncherKit/          Package.swift, Sources/{PathStore,TLCommands}, Tests/
  App/                           AppDelegate.swift, URLRouter.swift, TerminalOpener.swift,
                                 Info.plist, TerminalLauncher.entitlements
  Widget/                        PathsWidget.swift, PathRow.swift, Info.plist,
                                 PathsWidget.entitlements
  CLI/                           main.swift, tl.entitlements
  scripts/install.sh
  docs/superpowers/specs/
```

## 10. Risks and the first spike

The first implementation task is a throwaway spike that answers three
questions before any real code is written:

1. Can the bare `tl` binary, signed with the team-prefixed App Group
   entitlement, read and write the group container **without** macOS showing
   "would like to access data from other apps"?
2. Can the sandboxed widget read the file the CLI wrote?
3. Does the widget gallery pick up an app installed in `~/Applications`?

**Fallbacks:**
- **If 1 fails:** use approach B for writes. `tl add` and `tl rm` check the
  path locally, then send `tlaunch://add?path=…` or `tlaunch://rm?path=…`, and
  the app becomes the only writer of `paths.json`. This also lets any app add
  or remove list entries through a URL, which is acceptable for a
  personal tool. The app also keeps a copy at
  `~/Library/Application Support/TerminalLauncher/paths.json` for `tl ls` to
  read. The router gains two actions, and nothing else in this design changes.
- **If 3 fails:** `install.sh` copies the app to `/Applications` instead.
  Admin users can write there without `sudo`.
