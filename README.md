# TerminalLauncher

A macOS desktop widget that lists folders you work in. Click a folder and a new
Terminal window opens in it, already `cd`'d there. You add folders from the
shell:

```bash
cd ~/Projects/api
tl .
```

`~/Projects/api` shows up in the widget a moment later.

It's built for personal use on one Mac. It isn't on the App Store, and it isn't
notarized.

## Requirements

- macOS 27 or later
- Xcode 27, which includes Swift 6.4
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- An Apple ID signed in to Xcode. A free Personal Team is enough (see
  [Signing](#signing)).
- `~/.local/bin` on your `PATH`

## Install

```bash
scripts/install.sh
```

The script does the following:

1. Generates the Xcode project.
2. Builds the Release configuration.
3. Stops any running copy of the app.
4. Installs `TerminalLauncher.app` to `~/Applications`.
5. Unregisters the copies in `build/` so `tlaunch://` links always reach the
   installed app.
6. Registers the installed copy with LaunchServices.
7. Links `~/.local/bin/tl` into the app bundle.
8. Launches the app once, so macOS registers the URL scheme and the widget.

Re-run the script after every change. It's safe to run more than once.

Then add the widget: right-click the desktop → **Edit Widgets** → search for
**TerminalLauncher** ("Terminal Folders") → add the medium or large size.

## Usage

| Command | What it does |
|---|---|
| `tl .` or `tl <path>` | Adds the folder at the top of the list. Adding a folder that's already listed moves it to the top. |
| `tl ls` | Prints the numbered list, newest first. Folders that no longer exist are marked `(missing)`. |
| `tl rm <n>` | Removes item number `n` from `tl ls`. |
| `tl rm <path>` | Removes a folder by path. This also works when the folder has been deleted from disk. |

```
$ tl ls
 1  ~/Projects/api
 2  ~/Documents
 3  ~/old/thing   (missing)
$ tl rm 3
Removed ~/old/thing
```

Notes:
- Paths are resolved against the current directory, and a leading `~` is
  expanded. Symlinks are kept the way you typed them (or, for `tl .`, the way your shell
  shows the current folder).
- Command names win over folder names. To add a folder called `ls`, `rm` or `3`,
  write `tl ./ls`.
- Errors go to stderr and exit with status 1. Running `tl` with no arguments
  prints the usage.

### The widget

- **Large** shows up to 10 folders and **medium** shows up to 4. If you have more,
  the last row reads `+N more · tl ls`.
- Each row shows the folder name and its parent folder, e.g. `api  ~/Projects`.
- **Clicking a row** opens a new Terminal window in that folder.
- **Clicking a deleted folder** shows an alert with the `tl rm` command that
  removes it.
- The widget updates right after `tl add` or `tl rm`. As a fallback, it also
  refreshes itself every 30 minutes.

## How it works

```
tl add .  ──writes──▶  App Group container: paths.json  ◀──reads──  widget
   │                                  ▲                                │ click
   └── tlaunch://reload ──▶  TerminalLauncher.app  ◀── tlaunch://open?path=…
                               │                │
         WidgetCenter.reloadAllTimelines()     NSWorkspace → Terminal.app
```

- **`tl` (CLI)** is the only thing that writes the list. The list is
  `~/Library/Group Containers/A5STTR22DU.com.alex.TerminalLauncher/paths.json`.
  Each write is atomic. After every change, the CLI opens `tlaunch://reload` in
  the background.
- **TerminalLauncher.app** is a background agent: no Dock icon, no window, and
  not sandboxed. It handles two URLs:
  - `tlaunch://reload` refreshes the widget.
  - `tlaunch://open?path=…` opens Terminal at that path, but **only if the path
    is in the list**. That way a web page can't use the URL scheme to open
    Terminal windows wherever it likes.
- **PathsWidget** is the sandboxed WidgetKit extension. It reads `paths.json`
  and turns each row into a `tlaunch://open` link.

The data file looks like this:

```json
{
  "version": 1,
  "items": [
    { "path": "/Users/alex/Documents", "addedAt": "2026-10-05T11:02:00Z" }
  ]
}
```

If the file can't be read, nothing overwrites it. The CLI reports the error and
the widget shows `Couldn't read list · run tl ls`. Fix the file or delete it to
start over.

## Project layout

```
project.yml                  XcodeGen definition: app, widget and CLI targets
App/                         Host app: URL handling, opening Terminal, alerts
Widget/                      WidgetKit extension: timeline provider and views
CLI/main.swift               Entry point for tl
Packages/LauncherKit/        All the logic, as a local Swift package
  Sources/PathStore/         Model, JSON store, path handling, tlaunch:// URLs,
                             click handling
  Sources/TLCommands/        tl commands and argument parsing
  Tests/                     Swift Testing suites
scripts/install.sh           Build and install
docs/superpowers/            Design spec, implementation plan, spike findings
```

`TerminalLauncher.xcodeproj` is generated by XcodeGen and is not committed.

## Development

Run the unit tests. These cover all the logic: storage, path handling, URLs,
click handling and the CLI commands.

```bash
cd Packages/LauncherKit && swift test
```

Build without installing:

```bash
xcodegen generate && xcodebuild -project TerminalLauncher.xcodeproj -scheme TerminalLauncher -configuration Debug -derivedDataPath build -allowProvisioningUpdates build
```

To work in Xcode, run `xcodegen generate` and open
`TerminalLauncher.xcodeproj`. The widget previews are in
`Widget/PathsWidgetView.swift`.

The app and the widget log to the unified log under the subsystem
`com.alex.TerminalLauncher`:

```bash
/usr/bin/log show --last 5m --predicate 'subsystem == "com.alex.TerminalLauncher"' --style compact
```

Use the full path `/usr/bin/log`, because in zsh `log` is a built-in command.

## Signing

The team ID `A5STTR22DU` is hard-coded in these files:

- `project.yml` (`DEVELOPMENT_TEAM`)
- `App/TerminalLauncher.entitlements` (App Group)
- `Widget/PathsWidget.entitlements` (App Group)
- `CLI/tl.entitlements` (App Group)
- `Packages/LauncherKit/Sources/PathStore/PathStore.swift` (`PathStore.appGroupID`)

To build under a different team, replace it in all of these files. Your team ID is
the **OU** field of your "Apple Development" certificate:

```bash
security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject
```

The ID in brackets in the certificate's name is **not** the team ID.

Points that came up during the spike (details in
`docs/superpowers/spikes/2026-10-05-app-group-findings.md`):
- The App Group ID starts with the team ID. That lets the bare `tl` binary carry
  the App Group entitlement without a provisioning profile.
- `tl` is signed with `--identifier com.alex.TerminalLauncher.tl`. It is copied
  into `Contents/MacOS` with `codeSign: false`, so Xcode doesn't re-sign it
  under a different identifier.
- After you change any signing setting, run `rm -rf build` before building. An
  incremental build fails with "nested code is modified or invalid".
- Free Personal Team profiles expire after a while. If the app or the widget
  stops launching, run `scripts/install.sh` again.

## Troubleshooting

| Symptom | What to try |
|---|---|
| The widget doesn't update after `tl .` | Check that the app is running with `pgrep -x TerminalLauncher`. If `tl` warns `couldn't reach TerminalLauncher.app`, run `scripts/install.sh`. |
| A click does nothing | The path may not match the list exactly. Check `tl ls` and the log (see [Development](#development)). |
| TerminalLauncher is missing from Edit Widgets | Launch the app once with `open ~/Applications/TerminalLauncher.app`, then reopen Edit Widgets. |
| `tl: command not found` | Add `~/.local/bin` to your `PATH`. |

## Uninstall

1. Remove the widget from the desktop.
2. Run:

```bash
pkill -x TerminalLauncher; rm -rf ~/Applications/TerminalLauncher.app ~/.local/bin/tl
```

3. To also delete the saved list:

```bash
rm -rf ~/Library/Group\ Containers/A5STTR22DU.com.alex.TerminalLauncher
```
